extends SceneTree
## Resolve resource dependencies directly; headless filesystem caches can omit them.
const ROSTER := preload("res://scripts/characters/character_roster_database.gd")
const GRASS_SOURCE := preload("res://scripts/world/grass_source_geometry.gd")
const GRASS_INPUTS := {
	"assets/world/current_map_validation/current_region.glb": ["assets/world/terrain_repairs_1103/manifest.json", "road_shoulder", "source_mesh_sha256"],
	"assets/world/terrain_repairs_1103/terrain.glb": ["assets/world/terrain_repairs_1103/grass_bake/manifest.json", "source_geometry_sha256"],
	"assets/world/oval_atrium_1031/atrium.glb": ["assets/world/oval_atrium_1031/grass_bake/manifest.json", "source_geometry_sha256"],
	"assets/world/east_earth_pavilion_1102/pavilion.glb": ["assets/world/east_earth_pavilion_1102/grass_bake/manifest.json", "source_geometry_sha256"],
	"assets/world/cape_town_1110/town.glb": ["assets/world/cape_town_1110/grass_bake.json", "geometry_sha"],
}
const ROOTS := [
	"res://scenes/ui/title_screen.tscn",
	"res://scenes/main.tscn",
	"res://scenes/map_1021.tscn", "res://assets/world/current_map_validation/current_region.glb",
	"res://assets/world/current_map_validation/landscape_mask.res", "res://assets/world/current_map_validation/landscape.gdshader",
	"res://assets/world/cliff_b_test/architecture.tres", "res://scripts/water/water_manager.gd",
	"res://addons/vrm/bin/vrm_physics.gdextension", "res://tools/verify_export_1021.gd"]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var config:=ConfigFile.new()
	assert(config.load("res://export_presets.cfg")==OK)
	if not _prepare_grass_geometry():
		quit(1)
		return
	var queue: Array[String]=[];queue.assign(ROOTS)
	var foliage_entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://assets/world/architecture_details_1029/preview_entry.json"))
	for source: Dictionary in foliage_entry.sources:
		queue.append(source.texture)
	# The gallery loads textures by character ID, so dependency scanning cannot discover them.
	for entry: Dictionary in ROSTER.get_all_entries():
		queue.append(ROSTER.PORTRAIT_DIR.path_join(entry.file))
	for clip in ["A01","A05","A06","A18","A19","A20","A25"]:
		queue.append("res://assets/characters/motion_review/"+clip+".tres")
	for name in ["painted_clumps_v1.png","painted_small_canopy_8view_v1.png","painted_broad_canopy_8view_v1.png","painted_upright_canopy_8view_v1.png"]:
		var path: String="res://assets/vegetation/painted_lod/"+name
		if ResourceLoader.exists(path):queue.append(path)
	for group: String in ["avatars", "presentation", "motions"]:
		var directory := "res://assets/npc/" + group
		for file in DirAccess.get_files_at(directory):
			if file.ends_with(".json"):
				var data = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(file)))
				if data is Dictionary:
					_collect_npc_resources(data, queue)
	var literals:=RegEx.new();literals.compile("[\"']([^\"'\\r\\n]+)[\"']")
	var classes: Array=ProjectSettings.get_global_class_list()
	var visited: Dictionary={}
	var missing: Array[String]=[]
	while not queue.is_empty():
		var path: String=queue.pop_back()
		if path.begins_with("res://.current_map_build/"):continue
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
	config.set_value("preset.0","export_path","../builds/PrismRoute1021.exe")
	config.set_value("preset.0.options","binary_format/embed_pck",true)
	config.set_value("preset.0.options","debug/export_console_wrapper",2)
	var includes: String=config.get_value("preset.0","include_filter","")
	var grass_export_manifest := GRASS_SOURCE.EXPORT_MANIFEST.trim_prefix("res://")
	if not grass_export_manifest in includes.split(","):
		includes += "," + grass_export_manifest
	for feature_manifest: String in ["assets/world/initial_ruin_1029/manifest.json","assets/world/initial_ruin_1029/walk_collision.json","assets/world/architecture_details_1029/trial_settings.json","assets/audio/world_1030/settings.json","assets/audio/world_1030/manifest.json","assets/audio/world_1030/CREDITS.txt","assets/world/upper_ring_1030/manifest.json","assets/world/upper_ring_1030/height_field.json","assets/world/upper_ring_1030/materials.json","assets/world/tree_planting/world_edits.json","assets/world/island_saddle_1031/manifest.json"]:
		if not feature_manifest in includes.split(","):includes+=("," if not includes.is_empty() else "")+feature_manifest
	for feature_file: String in ["assets/world/terrain_repairs_1103/manifest.json","assets/world/terrain_repairs_1103/ground_grass.json","assets/world/terrain_repairs_1103/support_*.rf","assets/world/terrain_repairs_1103/road_shoulder_mask.rgh","assets/world/terrain_repairs_1103/grass_bake/manifest.json","assets/world/terrain_repairs_1103/grass_bake/*.grass"]:
		if not feature_file in includes.split(","):includes+=("," if not includes.is_empty() else "")+feature_file
	for feature_file:String in ["assets/world/sunken_archive_1103/manifest.json","assets/world/sunken_archive_1103/grass_cut.rf"]:
		if not feature_file in includes.split(","):includes+=("," if not includes.is_empty() else "")+feature_file
	for feature_file: String in ["assets/world/church_ruins_1105/manifest.json","assets/world/church_ruins_1105/ground_grass.json","assets/world/church_ruins_1105/grass_cut.rf","assets/world/church_ruins_1105/grass_bake/manifest.json","assets/world/church_ruins_1105/grass_bake/*.grass"]:
		if not feature_file in includes.split(","):includes+=("," if not includes.is_empty() else "")+feature_file
	for beach_file: String in ["assets/world/beach_slope_1107/manifest.json","assets/environment/beach_sand/sources.json"]:
		if not beach_file in includes.split(","):includes+=("," if not includes.is_empty() else "")+beach_file
	if not "assets/construction/basic_kit/catalog.json" in includes.split(","):includes+=",assets/construction/basic_kit/catalog.json"
	for waypoint_file: String in ["assets/world/npc_waypoint_ruins/*.json", "assets/world/npc_waypoint_ruins/*.grass"]:
		if not waypoint_file in includes.split(","):includes+=","+waypoint_file
	if not "assets/ai/worldbook/*.md" in includes.split(","):includes+=",assets/ai/worldbook/*.md"
	if not "assets/ai/personas/*.md" in includes.split(","):includes+=",assets/ai/personas/*.md"
	if not "assets/ai/local_airp/*.json" in includes.split(","):includes+=",assets/ai/local_airp/*.json"
	if not "assets/npc/**/*.json" in includes.split(","):includes+=",assets/npc/**/*.json"
	config.set_value("preset.0","include_filter",includes)
	var exclusions: PackedStringArray=["docs/*","screenshots/*","archive/*","experiments/*","assets/ai/reference/*","assets/water/review/*","assets/world/current_map_validation/review/*","assets/world/current_map_validation/grass_bake/manifest_part_*.json","*.3dm","*.3dmbak","*.blend","*.blend1","*.TMP"]
	exclusions.append(".current_map_build/*")
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


func _collect_npc_resources(value: Variant, queue: Array[String]) -> void:
	if value is Dictionary:
		for member in value.values():
			_collect_npc_resources(member, queue)
	elif value is Array:
		for member in value:
			_collect_npc_resources(member, queue)
	elif value is String and value.begins_with("res://"):
		queue.append(value)


func _prepare_grass_geometry() -> bool:
	var fingerprints := {}
	for file: String in GRASS_INPUTS:
		var path := "res://" + file
		var bake_keys: Array = GRASS_INPUTS[file]
		var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://" + bake_keys[0]))
		for key: String in bake_keys.slice(1):
			expected = expected.get(key) if expected is Dictionary else null
		var source_sha256 := FileAccess.get_sha256(path)
		if source_sha256.is_empty() or source_sha256 != expected:
			push_error("Grass bake source is missing or stale: " + path)
			return false
		var remap := ConfigFile.new()
		if remap.load(path + ".import") != OK:
			push_error("Grass bake source is not imported: " + path)
			return false
		var target: String = remap.get_value("remap", "path", "")
		var cache := FileAccess.get_file_as_string(target.get_basename() + ".md5")
		var source_md5 := FileAccess.get_md5(path)
		var target_md5 := FileAccess.get_md5(target)
		if source_md5.is_empty() or target_md5.is_empty() \
				or not cache.contains('source_md5="%s"' % source_md5) \
				or not cache.contains('dest_md5="%s"' % target_md5):
			push_error("Grass bake geometry import needs to be refreshed: " + path)
			return false
		fingerprints[path] = {"source_sha256": source_sha256, "imported": target, "imported_md5": target_md5}
	var output := FileAccess.open(GRASS_SOURCE.EXPORT_MANIFEST, FileAccess.WRITE)
	if output == null:
		push_error("Could not write grass geometry manifest: " + GRASS_SOURCE.EXPORT_MANIFEST)
		return false
	output.store_string(JSON.stringify(fingerprints, "\t"))
	return output.get_error() == OK
