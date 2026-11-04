extends SceneTree
## Repack complete affected cells from original roots; untouched roots keep RNG state.
const STORE=preload("res://scripts/grass_baked_store.gd")
const BUFFER=preload("res://scripts/grass_instance_buffer.gd")
const VEG=preload("res://scripts/map_1021_vegetation.gd")
const DEST="res://assets/world/church_ruins_1105/grass_bake/"
func _initialize() -> void:call_deferred("run")
func sha(bytes: PackedByteArray) -> String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(bytes);return h.finish().hex_encode()
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var trees_sha:=FileAccess.get_sha256("res://assets/world/tree_planting/world_edits.json")
	var base_path:="res://assets/world/current_map_validation/grass_bake/";var global_sha:=FileAccess.get_sha256(base_path+"manifest.json")
	var world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true;world.vegetation_bake_only=true;root.add_child(world)
	while not world.test_ready:await process_frame
	var vegetation=VEG.new();world.add_child(vegetation);vegetation.world_scene=world;vegetation._load_meshes_and_materials()
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base_path+"manifest.json"));assert(source.signature==STORE.signature(world))
	for key: String in source.cells:
		if not source.cells[key].has("resource_path"):source.cells[key]["resource_path"]=base_path+key+".grass"
	for overlay: String in [world.oval_atrium.GRASS_BAKE,world.earth_pavilion.GRASS_BAKE,world.terrain_repairs.GRASS_BAKE]:
		if FileAccess.file_exists(overlay):
			var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(overlay))
			if data.get("complete",false) and data.get("signature","")==source.signature:source.cells.merge(data.cells,true)
	var baked: Dictionary={"version":2,"complete":true,"signature":source.signature,"source_geometry_sha256":FileAccess.get_sha256("res://assets/world/church_ruins_1105/church.glb"),"cut_sha256":FileAccess.get_sha256("res://assets/world/church_ruins_1105/grass_cut.rf"),"cells":{}}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST));var removed:=0;var kept:=0;var originals:=0
	for coords: Array in world.church_ruins.grass_config.cells:
		var cell:=Vector3i(coords[0],coords[1],coords[2]);var id:=STORE.key(cell)
		if not source.cells.has(id):continue
		var row: Dictionary=source.cells[id];var roots:=PackedFloat64Array();var states:=PackedInt64Array()
		if int(row.root_count)>0:
			var compressed:=FileAccess.get_file_as_bytes(row.resource_path);assert(sha(compressed)==row.sha256)
			var raw:=compressed.decompress(int(row.raw_bytes),FileAccess.COMPRESSION_ZSTD)
			roots=raw.slice(0,int(row.root_count)*48).to_float64_array();states=raw.slice(int(row.root_count)*48).to_int64_array()
		var filtered:=PackedFloat64Array();var filtered_states:=PackedInt64Array();var cut:=0
		for i in states.size():
			var at:=i*6;var p:=Vector3(cell)*24.+Vector3(roots[at],roots[at+2],roots[at+1])
			if world.church_ruins.blocks_grass(p):cut+=1;continue
			filtered.append_array(roots.slice(at,at+6));filtered_states.append(states[i])
		var data:=BUFFER.from_roots(filtered,filtered_states,.2,vegetation.grass_mesh.get_aabb(),int(row.seed))
		var raw:=filtered.to_byte_array();raw.append_array(filtered_states.to_byte_array());var compressed:=PackedByteArray() if raw.is_empty() else raw.compress(FileAccess.COMPRESSION_ZSTD)
		FileAccess.open(DEST+id+".grass",FileAccess.WRITE).store_buffer(compressed)
		baked.cells[id]={"instances":filtered_states.size()*4,"root_count":filtered_states.size(),"near_count":data.near.size()/16,"far_count":data.far.size()/16,"seed":row.seed,"raw_bytes":raw.size(),"compressed_bytes":compressed.size(),"sha256":sha(compressed),"bounds":data.bounds,"resource_path":DEST+id+".grass","removed_roots":cut}
		removed+=cut;kept+=filtered_states.size();originals+=states.size();print("CHURCH_GRASS_CELL ",id," removed=",cut," retained=",filtered_states.size())
		await process_frame
	assert(removed>0);FileAccess.open(DEST+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify(baked))
	assert(FileAccess.get_sha256(base_path+"manifest.json")==global_sha);assert(FileAccess.get_sha256("res://assets/world/tree_planting/world_edits.json")==trees_sha)
	var report: Dictionary={"passed":true,"cells":baked.cells.size(),"original_roots":originals,"retained_roots":kept,"removed_roots":removed,"removed_blades":removed*4,"untouched_roots_preserve_position_normal_rng":true,"global_bake_unchanged":true,"tree_save_unchanged":true,"tree_save_sha256":trees_sha,"global_manifest_sha256":global_sha,"cut_sha256":baked.cut_sha256}
	FileAccess.open("res://docs/church_performance_1105/grass_bake.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n");print("CHURCH_GRASS_BAKED ",JSON.stringify(report));quit()
