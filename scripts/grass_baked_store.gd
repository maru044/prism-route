extends RefCounted
## Independent-file prototype: compressed immutable CPU buffers; bounded LRU.
## Workers access file bytes only, never the scene, physics or GPU.
const MAX_CACHE_BYTES := 96*1024*1024
const MAX_JOBS := 2
const FORMAT_VERSION := 2
const BUFFER := preload("res://scripts/grass_instance_buffer.gd")
const LEGACY_BUFFER_SHA256 := "28afa632669717b63398a84c43c4087fd1e4a64ed5a51c47409a1f9cab42f255"
# This revision preserves the root-to-instance output. Any later buffer
# revision participates in the bake signature under its own hash.
const VERIFIED_BUFFER_SHA256 := "c790a3bdea83eb6f6a65ee30d515237d1428b1c3edf617af8acf2efb3442c6be"
const ALLOCATION_RETRY_USEC := 1000000
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
var allocation_failures := 0
var _allocation_retry_at := 0

static func key(cell: Vector3i) -> String:return "%d_%d_%d"%[cell.x,cell.y,cell.z]

static func signature(world) -> String:
	var root: String=world.ASSETS
	var text: String=str(FORMAT_VERSION)+str(world.metadata.get("mesh_sha256",""))+str(Engine.get_version_info().hash)+str(ProjectSettings.get_setting("physics/3d/physics_engine"))
	if world.metadata.has("static_features"):
		# Reuse only a verified render-only revision. A later feature edit must
		# invalidate this exception rather than pinning future bake signatures.
		var features: Dictionary=world.metadata.static_features.duplicate(true)
		var overrides: Dictionary=world.metadata.get("grass_render_only_overrides",{})
		for key: String in overrides:
			var rule: Dictionary=overrides[key]
			var current: Dictionary=features.get(key,{})
			if current.get("mesh_sha256","")==rule.render_mesh_sha256 and current.get("manifest_sha256","")==rule.render_manifest_sha256:
				features[key]=rule.generation_feature
		text+=JSON.stringify(features)
		text+=FileAccess.get_sha256("res://scripts/world/initial_ruin_mask.gd")
		if world.metadata.static_features.has("upper_ring_1030"):text+=FileAccess.get_sha256("res://scripts/world/upper_ring_mask.gd")
	# Include generation code/constants and the actual SDF bytes, not only mesh.
	for path in [root+"landscape_mask.res",root+"surface_roles.json","res://scripts/vegetation_lod_streamer.gd","res://scripts/map_1021_vegetation.gd"]:
		text+=FileAccess.get_sha256(path)
	text+=buffer_bake_hash(FileAccess.get_sha256("res://scripts/grass_instance_buffer.gd"))
	# Queue/profiling-only edits must not force a geometry rebake. Generation
	# routines and the query configuration remain part of the signature.
	var include:=false
	for line in FileAccess.get_file_as_string("res://scripts/grass_volume_streamer.gd").split("\n"):
		if line.begins_with("func "):
			include=line.get_slice(" ",1).get_slice("(",0) in ["initialize","sample_surfaces","_sample","_begin"]
		if include or line.begins_with("const CELL "):text+=line+"\n"
	return text.sha256_text()

static func buffer_bake_hash(source_hash: String) -> String:
	return LEGACY_BUFFER_SHA256 if source_hash == VERIFIED_BUFFER_SHA256 else source_hash

func open(path: String,expected_signature: String) -> bool:
	directory=path
	if not FileAccess.file_exists(path+"/manifest.json"):return false
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path+"/manifest.json"))
	if not parsed is Dictionary or parsed.get("signature","")!=expected_signature:
		last_error="Grass bake is stale; using online generation";return false
	manifest=parsed;return true

func contains(cell: Vector3i) -> bool:return manifest.get("cells",{}).has(key(cell))
func is_empty(cell: Vector3i) -> bool:return contains(cell) and int(manifest.cells[key(cell)].instances)==0

func allocation_paused() -> bool:
	return Time.get_ticks_usec() < _allocation_retry_at

func defer_allocation() -> void:
	allocation_failures += 1
	if not allocation_paused():
		push_warning("Grass allocation failed; pausing new grass loads briefly")
	_allocation_retry_at = Time.get_ticks_usec() + ALLOCATION_RETRY_USEC

func _can_queue(id: String) -> bool:
	return not jobs.has(id) and jobs.size() < MAX_JOBS and not allocation_paused()

func request(cell: Vector3i) -> void:
	var id:=key(cell)
	if cache.has(id):
		hits+=1;lru.erase(id);lru.append(id);return
	if not _can_queue(id) or not contains(cell) or is_empty(cell):return
	var row: Dictionary=manifest.cells[id]
	jobs[id]=WorkerThreadPool.add_task(_read.bind(id,row),false,"Grass buffer "+id)

static func read_payload(row: Dictionary,fallback_path: String="") -> PackedByteArray:
	var path: String=row.get("resource_path",fallback_path)
	if not FileAccess.file_exists(path):return PackedByteArray()
	if not row.has("resource_offset"):return FileAccess.get_file_as_bytes(path)
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:return PackedByteArray()
	file.seek(int(row.resource_offset))
	return file.get_buffer(int(row.compressed_bytes))

func _read(id: String,row: Dictionary) -> void:
	var start:=Time.get_ticks_usec()
	var path: String=row.get("resource_path",directory+"/"+id+".grass")
	var bytes:=read_payload(row,path)
	var read_time:=Time.get_ticks_usec()-start;start=Time.get_ticks_usec()
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():hash.update(bytes)
	var data: Dictionary={}
	var retry := false
	if not bytes.is_empty() and hash.finish().hex_encode()==row.sha256:
		var raw:=bytes.decompress(int(row.raw_bytes),FileAccess.COMPRESSION_ZSTD)
		var root_count := int(row.root_count)
		if int(row.raw_bytes) == root_count * 56 and int(row.instances) == root_count * 4:
			if raw.size() == int(row.raw_bytes):
				var root_bytes := root_count * 48
				var roots := raw.slice(0, root_bytes).to_float64_array()
				var states := raw.slice(root_bytes).to_int64_array()
				if roots.size() == root_count * 6 and states.size() == root_count:
					data = BUFFER.from_roots(roots, states, .20, mesh_bounds, int(row.seed))
				retry = data.is_empty()
			elif raw.is_empty():
				# The compressed bytes still match the bake; a failed decode
				# must not discard that entry and trigger heavier online sampling.
				retry = true
	mutex.lock();completed.append({"id":id,"data":data,"retry":retry,"read_usec":read_time,"decode_usec":Time.get_ticks_usec()-start});mutex.unlock()

func pack_async(cell: Vector3i,snapshot: Dictionary,mesh_bounds: AABB) -> bool:
	var id:=key(cell)
	if not _can_queue(id):return false
	jobs[id]=WorkerThreadPool.add_task(_pack.bind(id,snapshot,mesh_bounds),false,"Pack grass "+id)
	return true

func _pack(id: String,snapshot: Dictionary,mesh_bounds: AABB) -> void:
	var start:=Time.get_ticks_usec()
	var data := BUFFER.pack_populations(snapshot.near, snapshot.near_data, snapshot.far, snapshot.far_data, mesh_bounds)
	mutex.lock();completed.append({"id":id,"data":data,"retry":data.is_empty(),"read_usec":0,"decode_usec":0,"pack_usec":Time.get_ticks_usec()-start});mutex.unlock()

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
		if result.retry:
			defer_allocation()
			continue
		if result.data.is_empty():
			corrupt+=1;manifest.cells.erase(result.id);continue
		if cache.has(result.id):
			cache_bytes-=cache[result.id].bytes
			lru.erase(result.id)
		cache[result.id]=result.data;lru.append(result.id);cache_bytes+=result.data.bytes
		while cache_bytes>MAX_CACHE_BYTES and lru.size()>1:
			var oldest: String=lru.pop_front()
			if cache.has(oldest):
				cache_bytes-=cache[oldest].bytes
				cache.erase(oldest)
				evictions+=1

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
	return {"cache_mib":cache_bytes/1048576.0,"cache_hits":hits,"disk_reads":reads,"inflight":jobs.size(),"evictions":evictions,"corrupt":corrupt,"allocation_failures":allocation_failures,"allocation_paused":allocation_paused(),"io_ms":io_usec/1000.0,"decode_ms":decode_usec/1000.0,"pack_worker_ms":pack_usec/1000.0,"baked_cells":manifest.get("cells",{}).size(),"status":last_error}
