extends SceneTree
## Exact parity against abfc7e4 sampler + actual-map Jolt surfaces and masks.
const STREAM := preload("res://scripts/grass_volume_streamer.gd")
const VEG := preload("res://scripts/map_1021_vegetation.gd")
const BUFFER := preload("res://scripts/grass_instance_buffer.gd")
const STORE := preload("res://scripts/grass_baked_store.gd")
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	var scene=load("res://scenes/map_1021.tscn").instantiate()
	scene.automation_enabled=true;scene.vegetation_bake_only=true;root.add_child(scene)
	while not scene.test_ready:await process_frame
	var vegetation:=VEG.new();vegetation.world_scene=scene;scene.add_child(vegetation)
	vegetation.target=scene.camera;vegetation.biome_noise_texture=scene._noise();vegetation._load_meshes_and_materials()
	var stream:=STREAM.new();vegetation.add_child(stream);stream.initialize(vegetation,scene);stream.capture_roots=true
	var reference=load("res://.current_map_build/grass_streamer_issue13_baseline.gd").new()
	vegetation.add_child(reference);reference.initialize(vegetation,scene)
	var cells: Array[Vector3i]=[]
	for point in [scene.resolved_spawns[0].floor_position,scene.resolved_spawns[7].floor_position,Vector3(-203.37573,39.5049438,1182.29857),scene.resolved_spawns[6].floor_position]:
		var cell:=Vector3i(floori(point.x/24),floori(point.y/24),floori(point.z/24))
		cells.append(cell);cells.append(cell+Vector3i(1,0,0))
	var rows: Array=[]
	for cell in cells:
		reference._begin(cell);stream._begin(cell)
		for i in vegetation.GRASS_SAMPLES_PER_CHUNK:reference._sample();stream._sample()
		var data:=stream.payload()
		var old_near:=BUFFER.pack(reference.work.near,reference.work.near_data)
		var old_far:=BUFFER.pack(reference.work.far,reference.work.far_data)
		check(old_near.to_byte_array()==data.near.to_byte_array(),"Legacy near parity "+str(cell))
		check(old_far.to_byte_array()==data.far.to_byte_array(),"Legacy far parity "+str(cell))
		var reconstructed:=BUFFER.from_roots(PackedFloat64Array(stream.work.roots),PackedInt64Array(stream.work.root_states),.2,vegetation.grass_mesh.get_aabb(),int(stream.work.rng.seed))
		check(reconstructed.near.to_byte_array()==old_near.to_byte_array(),"Root record reconstruction near "+str(cell))
		check(reconstructed.far.to_byte_array()==old_far.to_byte_array(),"Root record reconstruction far "+str(cell))
		rows.append({"cell":str(cell),"instances":(old_near.size()+old_far.size())/16,"roots":stream.work.root_states.size()})
		stream.work={};reference.work={}
	var store:=STORE.new();store.mesh_bounds=vegetation.grass_mesh.get_aabb()
	check(store.open(scene.ASSETS+"grass_bake",STORE.signature(scene)),"Pilot manifest is stale or missing")
	var stale:=STORE.new();check(not stale.open(scene.ASSETS+"grass_bake","invalid"),"Stale bake was accepted")
	var sample_cell:=Vector3i.ZERO
	for id: String in store.manifest.get("cells",{}):
		if int(store.manifest.cells[id].instances)>0:
			var parts:=id.split("_");sample_cell=Vector3i(int(parts[0]),int(parts[1]),int(parts[2]));break
	store.request(sample_cell)
	while not store.jobs.is_empty():await process_frame;store.poll()
	var loaded:=store.get_data(sample_cell);check(not loaded.is_empty(),"Async pilot read failed")
	if not loaded.is_empty():
		for i in 150:store.put_data(Vector3i(i,999,0),loaded)
		check(store.cache_bytes<=STORE.MAX_CACHE_BYTES,"CPU LRU exceeded its limit")
	var cache_report:=store.metrics();store.close()
	var corrupt:=STORE.new();corrupt.directory="res://.current_map_build/issue13_corrupt"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(corrupt.directory))
	var id:=STORE.key(sample_cell)
	var row: Dictionary=store.manifest.cells[id].duplicate(true);row.sha256="invalid"
	corrupt.manifest={"cells":{id:row}}
	var damaged:=FileAccess.open(corrupt.directory+"/"+id+".grass",FileAccess.WRITE);damaged.store_buffer(PackedByteArray([1,2,3]));damaged.close()
	corrupt.request(sample_cell)
	while not corrupt.jobs.is_empty():await process_frame;corrupt.poll()
	check(corrupt.corrupt==1 and not corrupt.contains(sample_cell),"Corrupt bake did not fall back to online generation")
	corrupt.close()
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"reference":"abfc7e4","cells":rows,"cache_test":cache_report,"corrupt_fallback":corrupt.corrupt==1,"parity":"Exact PackedFloat32Array bytes, including every transform and INSTANCE_CUSTOM; roots retain seed and RNG state"}
	var file:=FileAccess.open("res://assets/world/current_map_validation/review/issue13_bake_parity.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("ISSUE13_BAKE_VERIFY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
