extends Node
## Runtime smoke checks invoked by the Windows export verifier.

const NPC_SITES := preload("res://scripts/world/npc_preview_sites.gd")
const ROSTER := preload("res://scripts/characters/character_roster_database.gd")
const STORE := preload("res://scripts/progress/game_save_store.gd")
const Runtime := preload("res://scripts/world/npc_encounter_runtime.gd")
const HOME_HUD := preload("res://scripts/construction/home_hud.gd")
const WORLD_SCENES := [
	"res://assets/world/current_map_validation/current_region.glb",
	"res://assets/world/terrain_repairs_1103/terrain.glb",
	"res://assets/world/oval_atrium_1031/atrium.glb",
	"res://assets/world/east_earth_pavilion_1102/pavilion.glb",
	"res://assets/world/cape_town_1110/town.glb",
	"res://assets/world/sandbar_pavilion_1109/pavilion.glb",
]

var world: Node
var _checks: Dictionary = {}
var _missing: Array[String] = []
var _observed: Dictionary = {}

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	while get_tree().root.has_node("WorldLoadingScreen"):
		await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(world) and world.has_method("set_npc_lod_enabled"):
		world.set_npc_lod_enabled(false)
		await get_tree().process_frame
		await get_tree().process_frame
	_check_world_assets()
	_checks["local_airp_runtime"] = _check_local_airp()
	var encounters := {}
	var complete := true
	for duel in get_tree().get_nodes_in_group("world_interactive_npcs"):
		var runtime: Runtime = duel.runtime
		var id := runtime.character_id
		encounters[id] = duel
		var spawn: Dictionary = runtime.encounter_bundle.spawn
		if not is_instance_valid(duel.actor.skeleton) or not _has_visible_mesh(duel.actor):
			_missing.append(str(duel.actor.model_resource) + " (NPC visual: " + id + ")")
			complete = false
		if NPC_SITES.resolve_battle_respawn(world, spawn.region, id).is_empty():
			complete = false
	_checks["world_encounters"] = encounters.size() >= 47 and complete
	_observed["npc_count"] = encounters.size()
	_checks["tutorial_npc"] = is_instance_valid(world.initial_ruin.npc_anchor)
	for entry: Dictionary in ROSTER.get_all_entries():
		if ROSTER.load_portrait(entry.id) == null:
			_missing.append(ROSTER.PORTRAIT_DIR.path_join(entry.file))
	_checks["world_assets"] = _missing.is_empty()

	var report_path := ""
	var test_slot := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--export-report="):
			report_path = arg.trim_prefix("--export-report=")
		elif arg.begins_with("--export-test-slot="):
			test_slot = arg.trim_prefix("--export-test-slot=")
	var capture_dir := report_path.get_base_dir()
	if not report_path.is_empty():
		_checks["cave_capture"] = await _capture(capture_dir.path_join("export_1021_cave.png"))
	if not test_slot.is_empty():
		var snapshot := STORE.read(test_slot)
		if not snapshot.is_empty():
			world.game_progress.from_dict(snapshot.sections.progress)
			world.restore_world_save(snapshot.sections.world)
		_checks["npc_reload"] = not snapshot.is_empty() \
			and world.game_progress.is_companion_unlocked("herta") \
			and world.game_progress.is_companion_unlocked("kirara")

	var error := await _play_sample(encounters.get("herta"), capture_dir)
	_checks["npc_combat_and_exit"] = error.is_empty()
	if not error.is_empty():
		push_error("Export NPC combat verification: " + error)
	if not report_path.is_empty():
		world._teleport_to_key("cape_town")
		for frame in range(45):
			await get_tree().process_frame
		_checks["town_capture"] = await _capture(capture_dir.path_join("export_1021_town.png"))
	var passed := not _checks.values().has(false)
	for missing in _missing:
		push_error("Export asset unavailable: " + missing)
	var result := {"passed": passed, "checks": _checks, "observed": _observed, "missing": _missing}
	print("EXPORT_RUNTIME_CHECKS ", JSON.stringify(result))
	if not report_path.is_empty():
		var report := FileAccess.open(report_path, FileAccess.WRITE)
		if report == null:
			push_error("Could not write export verification report: " + report_path)
			get_tree().quit(1)
			return
		report.store_string(JSON.stringify(result, "\t"))
		report.close()
	get_tree().quit(0 if passed else 1)

func _check_world_assets() -> void:
	for path: String in WORLD_SCENES:
		if not ResourceLoader.load(path, "PackedScene") is PackedScene:
			_missing.append(path)
	if not _has_visible_mesh(world.model):
		_missing.append(WORLD_SCENES[0] + " (world instance)")
	if not _has_visible_mesh(world.character):
		_missing.append(str(world.character.character.scene_file_path) + " (player instance)")
	var foliage_entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://assets/world/architecture_details_1029/preview_entry.json"))
	for source: Dictionary in foliage_entry.get("sources", []):
		_check_texture(source.texture)
	for path: String in [HOME_HUD.THUMBNAILS, "res://assets/title/prism_route_wordmark.png",
			"res://assets/title/archaea_studio.png", "res://assets/title/archaea_bubbles.png"]:
		_check_texture(path)
	for airp_path: String in [
		"res://assets/ai/local_airp/templates.json",
		"res://assets/ai/local_airp/wildcards_sparkle.json",
		"res://assets/ai/local_airp/wildcards_keqing.json",
		"res://assets/ai/local_airp/wildcards_scenes.json",
		"res://assets/ai/local_airp/reference_embeddings.json"
	]:
		if not FileAccess.file_exists(airp_path):
			_missing.append(airp_path)

	var installed := {
		"oval_atrium": world.oval_atrium.local_grass_cells,
		"earth_pavilion": world.earth_pavilion.local_grass_cells,
		"terrain_repairs": world.terrain_repairs.local_grass_cells,
		"road_shoulder": world.terrain_repairs.shoulder_installed_cells,
		"church": world.church_ruins.local_grass_cells,
		"cape_town": world.cape_town.installed_cells,
		"waypoint_ruins": world.npc_waypoint_ruins.installed_cells,
	}
	var expected := {}
	var layers := {
		"oval_atrium": world.oval_atrium.GRASS_BAKE,
		"earth_pavilion": world.earth_pavilion.GRASS_BAKE,
		"terrain_repairs": world.terrain_repairs.GRASS_BAKE,
		"church": world.church_ruins.GRASS_BAKE,
		"cape_town": world.cape_town.GRASS_BAKE,
		"waypoint_ruins": world.npc_waypoint_ruins.BAKE,
	}
	for id: String in layers:
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(layers[id]))
		if manifest is Dictionary and not manifest.get("cells", {}).is_empty():
			expected[id] = manifest.cells.size()
		else:
			_missing.append(layers[id])
			expected[id] = -1
	expected["road_shoulder"] = world.terrain_repairs.manifest.road_shoulder.cells.size()
	_observed["grass_cells"] = installed
	_observed["expected_grass_cells"] = expected
	_checks["local_grass_bakes"] = installed == expected and world.terrain_repairs.shoulder_image != null

	var counts := {}
	var complete := true
	for id: String in world.construction.plots:
		var plot: Dictionary = world.construction.plots[id]
		counts[id] = plot.data.pieces.size()
		complete = complete and counts[id] > 0 and counts[id] == plot.nodes.size() \
			and world.construction.grass_cut(plot.root.to_global(Vector3(23.0, 0.2, 23.0)))
	_observed["construction_pieces"] = counts
	_checks["example_homes"] = complete and counts.get("coastal") == 164


func _check_texture(path: String) -> void:
	var texture := ResourceLoader.load(path, "Texture2D") as Texture2D
	if texture == null or texture.get_width() <= 0 or texture.get_height() <= 0:
		_missing.append(path)


func _has_visible_mesh(root: Node) -> bool:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh != null and mesh.is_visible_in_tree():
			return true
	return false


func _capture(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var pixels := get_viewport().get_texture().get_image()
	return pixels != null and not pixels.is_empty() and pixels.save_png(path) == OK


func _play_sample(duel: Node, capture_dir: String) -> String:
	if not is_instance_valid(duel):
		return "Herta encounter missing"
	var runtime: Runtime = duel.runtime
	var original: Transform3D = duel.anchor.global_transform
	for direction in range(8):
		var offset := Vector3.FORWARD.rotated(Vector3.UP, direction * TAU / 8.0) * 1.4
		var position: Variant = world.resolve_character_standing_position(original.origin + offset)
		if position == null:
			continue
		world.character.set_spawn(position, 0.0)
		if world.get_focused_interactive_npc() == duel:
			break
	if world.get_focused_interactive_npc() != duel:
		return "Herta could not be focused from nearby ground"
	_key(KEY_E)
	await get_tree().process_frame
	var dialogue := runtime.dialogue_manager
	if not dialogue.session_active:
		return "E did not open encounter dialogue"
	_key(KEY_ENTER)
	var choices: Array = dialogue.current_graph.nodes.get(dialogue.current_node_id, {}).get("choices", [])
	var option := choices.find_custom(func(row: Dictionary) -> bool: return row.get("action") == "enter_combat")
	if option < 0:
		return "Combat option missing from " + dialogue.current_node_id
	_key(KEY_1 + option)
	await get_tree().process_frame
	if runtime.current_state != Runtime.EncounterState.COMBAT:
		return "Combat option did not start combat"
	if not capture_dir.is_empty():
		_checks["combat_capture"] = await _capture(capture_dir.path_join("export_1021_npc_combat.png"))
	var combat := runtime.combat_manager
	combat.animation_delays = false
	for round_index in range(30):
		if combat.is_resolved:
			break
		duel.hud._open_battle()
		duel.hud._show_group("toy")
		duel.hud._choose_action(duel.hud.ACTIONS.toy_vibe)
		await get_tree().process_frame
	if not combat.is_resolved or runtime.last_battle_winner != "player":
		return "Combat did not reach player victory"
	_key(KEY_1)
	await get_tree().process_frame
	if not duel.is_service_active or not duel.service_hud.text.begins_with("【地面演出】"):
		return "Victory option did not enter the ground stage"
	_key(KEY_E)
	await get_tree().process_frame
	var restored: bool = runtime.current_state == Runtime.EncounterState.COMPLETED \
		and world.character.is_control_enabled() and world.is_world_input_allowed() \
		and world.game_progress.is_companion_unlocked("herta") \
		and duel.anchor.global_transform.is_equal_approx(original)
	return "" if restored else "Stage exit did not restore exploration"

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	get_tree().root.push_input(event)

func _check_local_airp() -> bool:
	var client_script: GDScript = load("res://scripts/ai/local_airp/local_airp_client.gd") as GDScript
	if client_script == null:
		_missing.append("res://scripts/ai/local_airp/local_airp_client.gd")
		return false
	var client: Node = client_script.new()
	client.load_resources()
	if client.templates.is_empty() or client.reference_embeddings.is_empty():
		_missing.append("res://assets/ai/local_airp/templates.json or embeddings")
		return false
	if not client.ensure_probe():
		_missing.append("Local AIRP BGE probe native sidecar executable")
		return false
	var res: Dictionary = client.retrieve_and_compose("花火早上好呀", "sparkle", "home_chat", {}, 42)
	client.close_probe()
	if res.get("content_tag", "") != "greet":
		return false
	var text: String = str(res.get("text", ""))
	if text.is_empty() or text.contains("\u2026") or text.contains("." + "." + "."):
		return false
	return true
