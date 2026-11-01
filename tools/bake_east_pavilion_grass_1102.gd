extends SceneTree
## Full affected cells use the production sampler; global cache stays immutable.
const VEG=preload("res://scripts/map_1021_vegetation.gd")
const STREAM=preload("res://scripts/grass_volume_streamer.gd")
const STORE=preload("res://scripts/grass_baked_store.gd")
const BUFFER=preload("res://scripts/grass_instance_buffer.gd")
const DEST="res://assets/world/east_earth_pavilion_1102/grass_bake/"
const REPORT="res://docs/east_earth_pavilion_1102/game/grass_bake_report.json"
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
	var vegetation:=VEG.new();vegetation.world_scene=world;world.add_child(vegetation)
	vegetation.target=world.camera;vegetation.biome_noise_texture=world._noise();vegetation._load_meshes_and_materials()
	var stream:=STREAM.new();vegetation.add_child(stream);stream.initialize(vegetation,world)
	stream.use_baked=false;stream.capture_roots=true
	var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.earth_pavilion.GRASS_CONFIG))
	var baked: Dictionary={"version":2,"complete":true,"signature":STORE.signature(world),
		"ground_config_sha256":FileAccess.get_sha256(world.earth_pavilion.GRASS_CONFIG),
		"support_sha256":FileAccess.get_sha256("res://assets/world/east_earth_pavilion_1102/grass_support.rgf"),
		"source_geometry_sha256":FileAccess.get_sha256("res://assets/world/east_earth_pavilion_1102/pavilion.glb"),"cells":{}}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	Engine.max_fps=0
	var started:=Time.get_ticks_msec();var blades:=0;var pavilion_blades:=0;var cells_with_pavilion:=0
	for values: Array in config.cells:
		var cell:=Vector3i(values[0],values[1],values[2]);var id:=STORE.key(cell);var origin:=Vector3(cell)*24.
		stream._begin(cell)
		for i in vegetation.GRASS_SAMPLES_PER_CHUNK:stream._sample()
		var data: Dictionary=stream.payload()
		var roots:=PackedFloat64Array(stream.work.roots);var states:=PackedInt64Array(stream.work.root_states)
		var seed_value: int=stream.work.rng.seed
		var reconstructed:=BUFFER.from_roots(roots,states,.2,vegetation.grass_mesh.get_aabb(),seed_value)
		assert(reconstructed.near.to_byte_array()==data.near.to_byte_array() and reconstructed.far.to_byte_array()==data.far.to_byte_array(),"Grass bake reconstruction differs")
		var local_roots:=0
		for i in states.size():
			var a:=i*6;var p:=origin+Vector3(roots[a],roots[a+2],roots[a+1])
			if world.earth_pavilion.affected_xz(p) and not world.earth_pavilion.blocks_grass(p):local_roots+=1
		if local_roots>0:cells_with_pavilion+=1
		pavilion_blades+=local_roots*4
		var raw:=roots.to_byte_array();raw.append_array(states.to_byte_array())
		var compressed:=PackedByteArray() if raw.is_empty() else raw.compress(FileAccess.COMPRESSION_ZSTD)
		FileAccess.open(DEST+id+".grass",FileAccess.WRITE).store_buffer(compressed)
		var count: int=(data.near.size()+data.far.size())/16
		baked.cells[id]={"instances":count,"root_count":states.size(),"near_count":data.near.size()/16,"far_count":data.far.size()/16,
			"seed":seed_value,"raw_bytes":raw.size(),"compressed_bytes":compressed.size(),"sha256":sha(compressed),"bounds":data.bounds,
			"resource_path":DEST+id+".grass","pavilion_blades":local_roots*4}
		blades+=count;stream.work={}
		print("PAVILION_GRASS_BAKE_CELL ",id," pavilion_blades=",local_roots*4)
		await process_frame
	assert(pavilion_blades>30000,"Courtyard grass density is unexpectedly low")
	assert(FileAccess.get_sha256("res://assets/world/tree_planting/world_edits.json")==trees_sha,"User tree save changed during bake")
	assert(FileAccess.get_sha256("res://assets/world/current_map_validation/grass_bake/manifest.json")==global_sha,"Global bake modified")
	baked["pavilion_blades"]=pavilion_blades
	FileAccess.open(DEST+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify(baked))
	var report: Dictionary={"passed":true,"cells":baked.cells.size(),"cells_with_pavilion_grass":cells_with_pavilion,
		"pavilion_blades":pavilion_blades,"total_cell_blades":blades,"seconds":(Time.get_ticks_msec()-started)/1000.,
		"mesh":config.grass_mesh,"palette":"green","ground_color":"project_green_meadow",
		"user_tree_save_sha256":trees_sha,"user_trees_unchanged":true,"global_bake_unchanged":true,"root_buffer_parity":true}
	FileAccess.open(REPORT,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PAVILION_GRASS_BAKED ",JSON.stringify(report));quit()
