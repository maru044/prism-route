extends SceneTree
## Resolve resource dependencies directly; headless filesystem caches can omit them.
const ROOTS := [
	"res://scenes/map_1021.tscn", "res://assets/world/current_map_validation/current_region.glb",
	"res://assets/world/current_map_validation/landscape_mask.res", "res://assets/world/current_map_validation/landscape.gdshader",
	"res://assets/world/cliff_b_test/architecture.tres", "res://scripts/water/water_manager.gd",
	"res://addons/vrm/bin/vrm_physics.gdextension", "res://tools/verify_export_1021.gd"]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var config:=ConfigFile.new()
	assert(config.load("res://export_presets.cfg")==OK)
	var queue: Array[String]=[];queue.assign(ROOTS)
	for clip in ["A01","A05","A06","A18","A19","A20","A25"]:
		queue.append("res://assets/characters/motion_review/"+clip+".tres")
	for name in ["painted_clumps_v1.png","painted_small_canopy_8view_v1.png","painted_broad_canopy_8view_v1.png","painted_upright_canopy_8view_v1.png"]:
		var path: String="res://assets/vegetation/painted_lod/"+name
		if ResourceLoader.exists(path):queue.append(path)
	var literals:=RegEx.new();literals.compile("[\"']([^\"'\\r\\n]+)[\"']")
	var classes: Array=ProjectSettings.get_global_class_list()
	var visited: Dictionary={}
	var missing: Array[String]=[]
	while not queue.is_empty():
		var path: String=queue.pop_back()
		if visited.has(path):continue
		if not ResourceLoader.exists(path):missing.append(path);continue
		visited[path]=true
		var dependencies: PackedStringArray=ResourceLoader.get_dependencies(path)
		# Imported scenes may refer to external materials and textures.
		if FileAccess.file_exists(path+".import"):
			var imported:=ConfigFile.new()
			if imported.load(path+".import")==OK and imported.has_section_key("remap","path"):
				dependencies.append_array(ResourceLoader.get_dependencies(imported.get_value("remap","path")))
		# GDScript literal preloads/inheritance and named global classes are not
		# reported by get_dependencies() in this engine's headless runtime.
		if path.get_extension() in ["gd","gdshader","gdshaderinc"]:
			var source:=FileAccess.get_file_as_string(path)
			for match_result in literals.search_all(source):
				var literal: String=match_result.get_string(1)
				if not literal.begins_with("res://"):
					literal=path.get_base_dir().path_join(literal).simplify_path()
				if ResourceLoader.exists(literal):dependencies.append(literal)
			if path.ends_with(".gd"):
				for row: Dictionary in classes:
					var class_use:=RegEx.new();class_use.compile("\\b"+str(row["class"])+"\\b")
					if class_use.search(source):dependencies.append(str(row.path))
		for dep in dependencies:
			var parts:=dep.split("::")
			var resolved: String=parts[parts.size()-1]
			if resolved.begins_with("uid://"):
				resolved=ResourceUID.get_id_path(ResourceUID.text_to_id(resolved))
			if not resolved.begins_with("res://") or not ResourceLoader.exists(resolved):
				missing.append(path+" -> "+dep);continue
			queue.append(resolved)
	var files:=PackedStringArray(visited.keys());files.sort()
	config.set_value("preset.0","export_files",files)
	var includes: String=config.get_value("preset.0","include_filter","")
	for feature_manifest: String in ["assets/world/initial_ruin_1029/manifest.json","assets/world/initial_ruin_1029/walk_collision.json","assets/world/architecture_details_1029/trial_settings.json","assets/audio/world_1030/settings.json","assets/audio/world_1030/manifest.json","assets/audio/world_1030/CREDITS.txt","assets/world/upper_ring_1030/manifest.json","assets/world/upper_ring_1030/height_field.json","assets/world/upper_ring_1030/materials.json","assets/world/tree_planting/world_edits.json","assets/world/island_saddle_1031/manifest.json"]:
		if not feature_manifest in includes.split(","):includes+=("," if not includes.is_empty() else "")+feature_manifest
	config.set_value("preset.0","include_filter",includes)
	var exclusions: PackedStringArray=["docs/*","screenshots/*","archive/*","experiments/*","assets/water/review/*","assets/world/current_map_validation/review/*","assets/world/current_map_validation/grass_bake/manifest_part_*.json","*.3dm","*.3dmbak","*.blend","*.blend1","*.TMP"]
	var bake_root: String="res://assets/world/current_map_validation/grass_bake/"
	var bake: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(bake_root+"manifest.json"))
	for name in DirAccess.get_files_at(bake_root):
		if name.ends_with(".grass") and not bake.cells.has(name.trim_suffix(".grass")):
			exclusions.append(bake_root.trim_prefix("res://")+name)
	config.set_value("preset.0","exclude_filter",",".join(exclusions))
	assert(config.save("res://export_presets.cfg")==OK)
	var report: Dictionary={"resource_roots_and_dependencies":files,"count":files.size(),"missing":missing}
	FileAccess.open("res://.current_map_build/export_1021_dependencies.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("EXPORT_DEPENDENCIES ",files.size()," missing=",missing.size())
	if not missing.is_empty():push_error(str(missing))
	quit(0 if missing.is_empty() else 1)
