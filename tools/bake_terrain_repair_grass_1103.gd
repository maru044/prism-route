extends SceneTree
## Rebuild full affected cells using the unchanged production sampling/RNG.
const VEG=preload("res://scripts/map_1021_vegetation.gd")
const STREAM=preload("res://scripts/grass_volume_streamer.gd")
const STORE=preload("res://scripts/grass_baked_store.gd")
const BUFFER=preload("res://scripts/grass_instance_buffer.gd")
const DEST="res://assets/world/terrain_repairs_1103/grass_bake/"
var world
func _initialize() -> void:call_deferred("run")
func sha(bytes: PackedByteArray) -> String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():hash.update(bytes)
	return hash.finish().hex_encode()
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var trees_sha:=FileAccess.get_sha256("res://assets/world/tree_planting/world_edits.json")
	var global_sha:=FileAccess.get_sha256("res://assets/world/current_map_validation/grass_bake/manifest.json")
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true;world.vegetation_bake_only=true
	root.add_child(world)
	while not world.test_ready:await process_frame
	await physics_frame;await physics_frame
	if "--road-shoulder" in OS.get_cmdline_user_args():
		await bake_road_shoulder()
		quit()
		return
	var vegetation:=VEG.new();vegetation.world_scene=world;world.add_child(vegetation)
	vegetation.target=world.camera;vegetation.biome_noise_texture=world._noise();vegetation._load_meshes_and_materials()
	var stream:=STREAM.new();vegetation.add_child(stream);stream.initialize(vegetation,world)
	stream.use_baked=false;stream.capture_roots=true
	var feature=world.terrain_repairs
	var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(feature.GRASS_CONFIG))
	var baked: Dictionary={"version":2,"complete":true,"signature":STORE.signature(world),
		"ground_config_sha256":FileAccess.get_sha256(feature.GRASS_CONFIG),
		"source_geometry_sha256":FileAccess.get_sha256("res://assets/world/terrain_repairs_1103/terrain.glb"),"cells":{}}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	Engine.max_fps=0
	var started:=Time.get_ticks_msec();var blades:=0;var count_cells:=0;var parity_cells:=0
	for values: Array in config.cells:
		var cell:=Vector3i(values[0],values[1],values[2]);var id:=STORE.key(cell)
		stream._begin(cell)
		for i in vegetation.GRASS_SAMPLES_PER_CHUNK:stream._sample()
		var data: Dictionary=stream.payload()
		var roots:=PackedFloat64Array(stream.work.roots);var states:=PackedInt64Array(stream.work.root_states)
		var seed_value: int=stream.work.rng.seed
		if count_cells%40==0 and not roots.is_empty():
			var reconstructed:=BUFFER.from_roots(roots,states,.2,vegetation.grass_mesh.get_aabb(),seed_value)
			assert(reconstructed.near.to_byte_array()==data.near.to_byte_array() and reconstructed.far.to_byte_array()==data.far.to_byte_array(),"Grass root buffer parity failed")
			parity_cells+=1
		var raw:=roots.to_byte_array();raw.append_array(states.to_byte_array())
		var compressed:=PackedByteArray() if raw.is_empty() else raw.compress(FileAccess.COMPRESSION_ZSTD)
		FileAccess.open(DEST+id+".grass",FileAccess.WRITE).store_buffer(compressed)
		var count: int=(data.near.size()+data.far.size())/16
		baked.cells[id]={"instances":count,"root_count":states.size(),"near_count":data.near.size()/16,"far_count":data.far.size()/16,
			"seed":seed_value,"raw_bytes":raw.size(),"compressed_bytes":compressed.size(),"sha256":sha(compressed),"bounds":data.bounds,"resource_path":DEST+id+".grass"}
		blades+=count;stream.work={};count_cells+=1
		if count_cells%10==0:print("TERRAIN_GRASS_BAKE ",count_cells,"/",config.cells.size()," blades=",blades)
		await process_frame
	assert(FileAccess.get_sha256("res://assets/world/tree_planting/world_edits.json")==trees_sha)
	assert(FileAccess.get_sha256("res://assets/world/current_map_validation/grass_bake/manifest.json")==global_sha)
	FileAccess.open(DEST+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify(baked))
	var report: Dictionary={"passed":true,"cells":baked.cells.size(),"blades":blades,"seconds":(Time.get_ticks_msec()-started)/1000.,
		"root_buffer_parity_cells":parity_cells,"user_trees_unchanged_during_bake":true,"global_bake_unchanged":true,"signature":baked.signature}
	FileAccess.open("res://docs/terrain_seams_1102/grass_bake_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TERRAIN_GRASS_BAKED ",JSON.stringify(report))
	if world.terrain_repairs.manifest.has("road_shoulder"):await bake_road_shoulder()
	quit()

func bake_road_shoulder() -> void:
	var feature=world.terrain_repairs
	assert(feature.shoulder_image!=null,"Road shoulder mask was not installed")
	var config: Dictionary=feature.manifest.road_shoulder
	var prior: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DEST+"manifest.json"))
	assert(prior.signature==STORE.signature(world),"Base local bake is stale")
	var trees_sha:=FileAccess.get_sha256("res://assets/world/tree_planting/world_edits.json")
	var global_sha:=FileAccess.get_sha256("res://assets/world/current_map_validation/grass_bake/manifest.json")
	var source_sha:=FileAccess.get_sha256(world.ASSETS+"current_region.glb")
	var vegetation:=VEG.new();vegetation.world_scene=world;world.add_child(vegetation)
	vegetation.target=world.camera;vegetation.biome_noise_texture=world._noise();vegetation._load_meshes_and_materials()
	var stream:=STREAM.new();vegetation.add_child(stream);stream.initialize(vegetation,world)
	stream.use_baked=false;stream.capture_roots=true
	var temporary:="res://.current_map_build/road_shoulder.grass"
	var destination:=DEST+"road_shoulder.grass"
	var bundle:=FileAccess.open(temporary,FileAccess.WRITE)
	var cells: Dictionary={};var count_cells:=0;var blade_count:=0;var shoulder_roots:=0;var parity:=0
	var started:=Time.get_ticks_msec()
	Engine.max_fps=0
	for values: Array in config.cells:
		var cell:=Vector3i(values[0],values[1],values[2]);var id:=STORE.key(cell)
		stream._begin(cell)
		for i in vegetation.GRASS_SAMPLES_PER_CHUNK:stream._sample()
		var payload: Dictionary=stream.payload()
		var roots:=PackedFloat64Array(stream.work.roots);var states:=PackedInt64Array(stream.work.root_states)
		var seed_value: int=stream.work.rng.seed
		if count_cells%30==0 and not roots.is_empty():
			var reconstructed:=BUFFER.from_roots(roots,states,.2,vegetation.grass_mesh.get_aabb(),seed_value)
			assert(reconstructed.near.to_byte_array()==payload.near.to_byte_array() and reconstructed.far.to_byte_array()==payload.far.to_byte_array(),"Road shoulder buffer parity")
			parity+=1
		for i in states.size():
			var p:=Vector3(cell)*24.+Vector3(roots[i*6],roots[i*6+2],roots[i*6+1])
			var band: int=feature.road_shoulder_band(p,.55)
			assert(band!=1,"Grass root on white road edge")
			if band==0:shoulder_roots+=1
		var raw:=roots.to_byte_array();raw.append_array(states.to_byte_array())
		var compressed:=PackedByteArray() if raw.is_empty() else raw.compress(FileAccess.COMPRESSION_ZSTD)
		var offset:=bundle.get_position();bundle.store_buffer(compressed)
		var instances: int=(payload.near.size()+payload.far.size())/16
		cells[id]={"instances":instances,"root_count":states.size(),"near_count":payload.near.size()/16,"far_count":payload.far.size()/16,
			"seed":seed_value,"raw_bytes":raw.size(),"compressed_bytes":compressed.size(),"sha256":sha(compressed),
			"bounds":payload.bounds,"resource_path":destination,"resource_offset":offset}
		blade_count+=instances;count_cells+=1;stream.work={}
		if count_cells%10==0:print("ROAD_SHOULDER_BAKE ",count_cells,"/",config.cells.size()," seconds=",(Time.get_ticks_msec()-started)/1000.)
		await process_frame
	bundle.close()
	assert(FileAccess.get_sha256("res://assets/world/tree_planting/world_edits.json")==trees_sha)
	assert(FileAccess.get_sha256("res://assets/world/current_map_validation/grass_bake/manifest.json")==global_sha)
	assert(FileAccess.get_sha256(world.ASSETS+"current_region.glb")==source_sha)
	if FileAccess.file_exists(destination):assert(DirAccess.remove_absolute(destination)==OK)
	assert(DirAccess.rename_absolute(temporary,destination)==OK)
	for id: String in cells:prior.cells[id]=cells[id]
	prior["road_shoulder_config"]=config
	prior["road_shoulder_manifest_sha256"]=FileAccess.get_sha256(feature.MANIFEST)
	prior["road_shoulder_report"]={"cells":cells.size(),"blades":blade_count,"shoulder_roots":shoulder_roots,"white_edge_roots":0,
		"root_buffer_parity_cells":parity,"seconds":(Time.get_ticks_msec()-started)/1000.,
		"global_bake_unchanged":true,"user_trees_unchanged":true,"source_mesh_unchanged":true,"bundle_sha256":FileAccess.get_sha256(destination)}
	FileAccess.open(DEST+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify(prior))
	print("ROAD_SHOULDER_BAKED ",JSON.stringify(prior.road_shoulder_report))


