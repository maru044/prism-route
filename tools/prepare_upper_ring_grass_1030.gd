extends SceneTree
## Reuse proven unchanged cells; only the feature's footprint needs resampling.
const STORE=preload("res://scripts/grass_baked_store.gd")
const VEG=preload("res://scripts/map_1021_vegetation.gd")
const STREAM=preload("res://scripts/grass_volume_streamer.gd")
const BASE="res://assets/world/current_map_validation/"
const BACKUP="res://.current_map_build/upper_ring_import_1030_before/"
func _initialize() -> void:call_deferred("run")
func put(path: String,value) -> void:FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(value))
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var world=load("res://scenes/map_1021.tscn").instantiate()
	world.automation_enabled=true;world.vegetation_bake_only=true;root.add_child(world)
	while not world.test_ready:await process_frame
	var old_metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BACKUP+"assets/world/current_map_validation/metadata.json"))
	assert(world.metadata.mesh_sha256==old_metadata.mesh_sha256)
	var features: Dictionary=world.metadata.static_features.duplicate(true);features.erase("upper_ring_1030")
	assert(features==old_metadata.static_features,"Unexpected additional world changes")
	var protected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BACKUP+"hashes.json"))
	for path: String in protected:assert(FileAccess.get_sha256("res://"+path)==protected[path])
	var vegetation:=VEG.new();vegetation.world_scene=world;world.add_child(vegetation)
	vegetation.target=world.camera;vegetation.biome_noise_texture=world._noise();vegetation._load_meshes_and_materials()
	var stream:=STREAM.new();vegetation.add_child(stream);stream.initialize(vegetation,world);stream.use_baked=false
	var signature:=STORE.signature(world)
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BACKUP+"assets/world/current_map_validation/grass_bake/manifest.json"))
	var candidates: Array[Vector3i]=[]
	for column: Array in stream.columns.values():
		for cell: Vector3i in column:candidates.append(cell)
	candidates.sort()
	var region: Rect2=world.upper_ring.planting_mask.bounds.grow(3.)
	var parts: Array[Dictionary]=[]
	for i in 4:parts.append({"version":2,"signature":signature,"scope":"full-map generation shard; unchanged cells reused outside upper ring footprint","complete":false,"shard_index":i,"shard_count":4,"cells":{}})
	var changed: Array[String]=[];var preserved:=0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUP+"grass_cells"))
	for i in candidates.size():
		var cell:=candidates[i];var id:=STORE.key(cell)
		var rect:=Rect2(Vector2(cell.x*24.,cell.z*24.),Vector2(24,24))
		var affected:=rect.intersects(region) and cell.y in [2,3]
		if affected or not original.cells.has(id):
			changed.append(id)
			var file:=BASE+"grass_bake/"+id+".grass"
			if FileAccess.file_exists(file) and not FileAccess.file_exists(BACKUP+"grass_cells/"+id+".grass"):
				FileAccess.open(BACKUP+"grass_cells/"+id+".grass",FileAccess.WRITE).store_buffer(FileAccess.get_file_as_bytes(file))
		else:parts[i%4].cells[id]=original.cells[id];preserved+=1
	for i in 4:put(BASE+"grass_bake/manifest_part_%d.json"%i,parts[i])
	var report: Dictionary={"previous_signature":original.signature,"signature":signature,"changed_cells":changed,"preserved_cells":preserved,"total_cells":candidates.size(),"base_map_unchanged":true,"scope":"Only upper ring footprint at elevations 48-96m; original geometry, sampler, fixed layout and remote terrain unchanged", "broad_crown_bounds":str(vegetation.tree_large_broad_leaf_mesh.get_aabb()),"small_crown_bounds":str(vegetation.tree_near_leaf_mesh.get_aabb())}
	put("res://.current_map_build/upper_ring_grass_preparation_1030.json",report)
	print("UPPER_RING_GRASS_PREPARED ",JSON.stringify({"changed":changed.size(),"preserved":preserved,"signature":signature,"broad_crown":report.broad_crown_bounds}));quit()
