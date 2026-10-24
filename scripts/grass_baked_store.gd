extends RefCounted
## Independent-file prototype: compressed immutable CPU buffers; bounded LRU.
## Workers access file bytes only, never the scene, physics or GPU.
const MAX_CACHE_BYTES := 96*1024*1024
const MAX_JOBS := 2
const FORMAT_VERSION := 2
const BUFFER := preload("res://scripts/grass_instance_buffer.gd")
var manifest: Dictionary = {}
var directory := ""
var mesh_bounds:=AABB()
var cache: Dictionary = {}
var lru: Array[String] = []
var cache_bytes := 0
var jobs: Dictionary = {}
var mutex:=Mutex.new()
var completed: Array[Dictionary] = []
var hits:=0
var reads:=0
var corrupt:=0
var evictions:=0
var io_usec:=0
var decode_usec:=0
var pack_usec:=0
var last_error := ""

static func key(cell: Vector3i) -> String:return "%d_%d_%d"%[cell.x,cell.y,cell.z]

static func signature(world) -> String:
	var root: String=world.ASSETS
	var text: String=str(FORMAT_VERSION)+str(world.metadata.get("mesh_sha256",""))+str(Engine.get_version_info().hash)+str(ProjectSettings.get_setting("physics/3d/physics_engine"))
	# Include generation code/constants and the actual SDF bytes, not only mesh.
	for path in [root+"landscape_mask.res",root+"surface_roles.json","res://scripts/vegetation_lod_streamer.gd","res://scripts/map_1021_vegetation.gd","res://scripts/grass_instance_buffer.gd"]:
		text+=FileAccess.get_sha256(path)
	# Queue/profiling-only edits must not force a geometry rebake. Generation
	# routines and the query configuration remain part of the signature.
	var include:=false
	for line in FileAccess.get_file_as_string("res://scripts/grass_volume_streamer.gd").split("\n"):
		if line.begins_with("func "):
			include=line.get_slice(" ",1).get_slice("(",0) in ["initialize","sample_surfaces","_sample","_begin"]
		if include or line.begins_with("const CELL "):text+=line+"\n"
	return text.sha256_text()

func open(path: String,expected_signature: String) -> bool:
	directory=path
	if not FileAccess.file_exists(path+"/manifest.json"):return false
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path+"/manifest.json"))
	if not parsed is Dictionary or parsed.get("signature","")!=expected_signature:
		last_error="Grass bake is stale; using online generation";return false
	manifest=parsed;return true

func contains(cell: Vector3i) -> bool:return manifest.get("cells",{}).has(key(cell))
func is_empty(cell: Vector3i) -> bool:return contains(cell) and int(manifest.cells[key(cell)].instances)==0

func request(cell: Vector3i) -> void:
	var id:=key(cell)
	if cache.has(id):
		hits+=1;lru.erase(id);lru.append(id);return
	if jobs.has(id) or jobs.size()>=MAX_JOBS or not contains(cell) or is_empty(cell):return
	var row: Dictionary=manifest.cells[id]
	jobs[id]=WorkerThreadPool.add_task(_read.bind(id,row),false,"Grass buffer "+id)

func _read(id: String,row: Dictionary) -> void:
	var start:=Time.get_ticks_usec()
	var path:=directory+"/"+id+".grass"
	var bytes:=FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var read_time:=Time.get_ticks_usec()-start;start=Time.get_ticks_usec()
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():hash.update(bytes)
	var data: Dictionary={}
	if not bytes.is_empty() and hash.finish().hex_encode()==row.sha256:
		var raw:=bytes.decompress(int(row.raw_bytes),FileAccess.COMPRESSION_ZSTD)
		if raw.size()==int(row.raw_bytes) and raw.size()==int(row.root_count)*56 and int(row.instances)==int(row.root_count)*4:
			var root_bytes:=int(row.root_count)*48
			data=BUFFER.from_roots(raw.slice(0,root_bytes).to_float64_array(),raw.slice(root_bytes).to_int64_array(),.20,mesh_bounds,int(row.seed))
	mutex.lock();completed.append({"id":id,"data":data,"read_usec":read_time,"decode_usec":Time.get_ticks_usec()-start});mutex.unlock()

func pack_async(cell: Vector3i,snapshot: Dictionary,mesh_bounds: AABB) -> void:
	var id:=key(cell)
	if jobs.has(id):return
	jobs[id]=WorkerThreadPool.add_task(_pack.bind(id,snapshot,mesh_bounds),false,"Pack grass "+id)

func _pack(id: String,snapshot: Dictionary,mesh_bounds: AABB) -> void:
	var start:=Time.get_ticks_usec()
	var data: Dictionary={"near":BUFFER.pack(snapshot.near,snapshot.near_data),"far":BUFFER.pack(snapshot.far,snapshot.far_data),"bounds":[],"bytes":0}
	for group: String in ["near","far"]:
		var b:=BUFFER.bounds(data[group],mesh_bounds)
		data.bounds.append([b.position.x,b.position.y,b.position.z,b.size.x,b.size.y,b.size.z])
		data.bytes+=(data[group] as PackedFloat32Array).size()*4
	mutex.lock();completed.append({"id":id,"data":data,"read_usec":0,"decode_usec":0,"pack_usec":Time.get_ticks_usec()-start});mutex.unlock()

func poll() -> void:
	mutex.lock();var done:=completed;completed=[];mutex.unlock()
	for result: Dictionary in done:
		var task: int=jobs[result.id]
		# Posting a result can precede thread-local cleanup. Never block the
		# gameplay thread on that tail; collect it on the next frame instead.
		if not WorkerThreadPool.is_task_completed(task):
			mutex.lock();completed.append(result);mutex.unlock();continue
		WorkerThreadPool.wait_for_task_completion(task);jobs.erase(result.id)
		if result.has("pack_usec"):pack_usec+=result.pack_usec
		else:reads+=1
		io_usec+=result.read_usec;decode_usec+=result.decode_usec
		if result.data.is_empty():
			corrupt+=1;manifest.cells.erase(result.id);continue
		cache[result.id]=result.data;lru.append(result.id);cache_bytes+=result.data.bytes
		while cache_bytes>MAX_CACHE_BYTES and lru.size()>1:
			var oldest: String=lru.pop_front();cache_bytes-=cache[oldest].bytes;cache.erase(oldest);evictions+=1

func get_data(cell: Vector3i) -> Dictionary:
	var id:=key(cell)
	if not cache.has(id):return {}
	hits+=1;lru.erase(id);lru.append(id)
	return cache[id]

func put_data(cell: Vector3i,data: Dictionary) -> void:
	var id:=key(cell)
	if cache.has(id):cache_bytes-=cache[id].bytes;lru.erase(id)
	cache[id]=data;cache_bytes+=data.bytes;lru.append(id)
	while cache_bytes>MAX_CACHE_BYTES and lru.size()>1:
		var oldest: String=lru.pop_front();cache_bytes-=cache[oldest].bytes;cache.erase(oldest);evictions+=1

func close() -> void:
	for task: int in jobs.values():WorkerThreadPool.wait_for_task_completion(task)
	jobs.clear()

func metrics() -> Dictionary:
	return {"cache_mib":cache_bytes/1048576.0,"cache_hits":hits,"disk_reads":reads,"inflight":jobs.size(),"evictions":evictions,"corrupt":corrupt,"io_ms":io_usec/1000.0,"decode_ms":decode_usec/1000.0,"pack_worker_ms":pack_usec/1000.0,"baked_cells":manifest.get("cells",{}).size(),"status":last_error}
