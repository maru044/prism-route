extends SceneTree
## Automated test suite for Home Housing and Multi-Dimensional Resident Interaction System.

const DATA := preload("res://scripts/construction/building_data.gd")
const CATALOG := preload("res://scripts/construction/home_intimacy_catalog.gd")
const RESIDENT_MANAGER := preload("res://scripts/construction/home_resident_manager.gd")
const RESIDENT_ACTOR := preload("res://scripts/construction/home_resident_actor.gd")
const ROOM_ASSIGNMENT_PANEL := preload("res://scripts/ui/home_room_assignment_panel.gd")
const HOME_INTERACTION_PANEL := preload("res://scripts/narrative/home_interaction_panel.gd")
const CONSTRUCTION_WORLD := preload("res://scripts/construction/construction_world.gd")
const GAME_PROGRESS := preload("res://scripts/progress/game_progress.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("\n==================================================")
	print("[Test] Verifying Home Housing & Resident Interaction System")
	print("==================================================\n")

	test_intimacy_catalog()
	test_resident_manager()
	test_resident_actor_state_management()
	test_resident_navigation_and_corner_avoidance()
	test_housing_panel_ui()
	test_interaction_panel_and_tiers()
	await test_construction_world_housing_integration()

	print("\n==================================================")
	print("ALL HOME HOUSING & INTERACTION TESTS PASSED!")
	print("==================================================\n")
	quit(0)

func test_intimacy_catalog() -> void:
	print("--- Test 0: HomeIntimacyCatalog Definitions & Furniture Locking Logic ---")
	var services: Array[Dictionary] = CATALOG.get_motions("service")
	var honbans: Array[Dictionary] = CATALOG.get_motions("honban")
	assert(services.size() == 16, "Must catalog 16 service motions, got %d" % services.size())
	assert(honbans.size() == 17, "Must catalog 17 honban motions, got %d" % honbans.size())

	# Ground motion always available even with empty room furniture
	var ground_motion: Dictionary = {}
	for m in services:
		if m.get("furniture") == "ground":
			ground_motion = m
			break
	assert(not ground_motion.is_empty(), "Must find a ground service motion")
	assert(CATALOG.can_play_in_room(ground_motion, []), "Ground motion must be playable without furniture")

	# Bed motion requires bed
	var bed_motion: Dictionary = {}
	for m in services:
		if m.get("furniture") == "bed":
			bed_motion = m
			break
	assert(not bed_motion.is_empty(), "Must find a bed service motion")
	assert(not CATALOG.can_play_in_room(bed_motion, []), "Bed motion cannot play in room without bed")
	assert(not CATALOG.can_play_in_room(bed_motion, ["chair", "desk"]), "Bed motion cannot play without bed")
	assert(CATALOG.can_play_in_room(bed_motion, ["bed"]), "Bed motion must play when bed is present")

	# Chair motion requires chair or bench
	var chair_motion: Dictionary = {}
	for m in services:
		if m.get("furniture") == "chair":
			chair_motion = m
			break
	assert(not chair_motion.is_empty(), "Must find a chair service motion")
	assert(not CATALOG.can_play_in_room(chair_motion, ["bed", "desk"]), "Chair motion cannot play without chair/bench")
	assert(CATALOG.can_play_in_room(chair_motion, ["chair"]), "Chair motion must play when chair is present")
	assert(CATALOG.can_play_in_room(chair_motion, ["bench"]), "Chair motion must play when bench is present")

	# Desk motion requires desk
	var desk_motion: Dictionary = {}
	for m in honbans:
		if m.get("furniture") == "desk":
			desk_motion = m
			break
	assert(not desk_motion.is_empty(), "Must find a desk honban motion")
	assert(not CATALOG.can_play_in_room(desk_motion, ["bed", "chair"]), "Desk motion cannot play without desk")
	assert(CATALOG.can_play_in_room(desk_motion, ["desk"]), "Desk motion must play when desk is present")

	# Verify 2-role mutual service motion kk_tagai_ijiri replaces 3-track mmd_7869c66910b9
	var found_kk_tagai: bool = false
	for m in services:
		assert(m.get("id") != "mmd_7869c66910b9", "Three-track mmd_7869c66910b9 must be removed from catalog")
		if m.get("id") == "kk_tagai_ijiri":
			found_kk_tagai = true
	assert(found_kk_tagai, "kk_tagai_ijiri must be cataloged in services")
	for m in honbans:
		assert(m.get("id") != "mmd_7869c66910b9", "Three-track mmd_7869c66910b9 must not exist in honbans")

	# Verify placement calculation with desk offsets (-0.838m role_a, -0.822m role_b)
	var placements: Dictionary = CATALOG.get_role_placements(desk_motion)
	assert(placements.has("role_a_placement") and placements.has("role_b_placement"), "Desk motion must have role_a and role_b placements")
	var role_targets: Dictionary = CATALOG.calculate_role_targets(Transform3D.IDENTITY, desk_motion)
	assert(abs(role_targets["role_a_target"].origin.y - (-0.838)) < 0.001, "Role A desk target offset must be -0.838m")
	assert(abs(role_targets["role_b_target"].origin.y - (-0.822)) < 0.001, "Role B desk target offset must be -0.822m")

	print("  [Pass] HomeIntimacyCatalog 16 service & 17 honban motions, dual role offsets and furniture locks verified")

func test_resident_manager() -> void:
	print("--- Test 1: HomeResidentManager 1-to-1 Logic & Serialization ---")
	var mgr := RESIDENT_MANAGER.new()
	var signal_log: Array[Dictionary] = []
	mgr.assignment_changed.connect(func(r_id: String, c_id: String):
		signal_log.append({"room": r_id, "char": c_id})
	)

	# 1. Basic assignment
	var ok: bool = mgr.assign_resident("room_01", "ganyu")
	assert(ok, "Assignment of ganyu to room_01 must succeed")
	assert(mgr.get_resident("room_01") == "ganyu", "room_01 resident must be ganyu")
	assert(mgr.get_room_for_character("ganyu") == "room_01", "ganyu must be housed in room_01")
	assert(mgr.is_room_occupied("room_01"), "room_01 must be occupied")
	assert(mgr.is_character_housed("ganyu"), "ganyu must be housed")

	# 2. Moving character to another room auto-vacates previous room
	ok = mgr.assign_resident("room_02", "ganyu")
	assert(ok, "Moving ganyu to room_02 must succeed")
	assert(mgr.get_resident("room_01") == "", "room_01 must now be empty")
	assert(mgr.get_resident("room_02") == "ganyu", "room_02 must now house ganyu")
	assert(mgr.get_room_for_character("ganyu") == "room_02", "ganyu must be in room_02")

	# 3. Vacating room
	mgr.unassign_room("room_02")
	assert(mgr.get_resident("room_02") == "", "room_02 must be vacant after unassign")
	assert(not mgr.is_character_housed("ganyu"), "ganyu must not be housed")

	# 4. Serialization roundtrip
	mgr.assign_resident("room_A", "keqing")
	mgr.assign_resident("room_B", "sparkle")
	var snapshot: Dictionary = mgr.to_dict()
	assert(snapshot.get("version") == 1, "Snapshot version must be 1")

	var mgr_restored := RESIDENT_MANAGER.new()
	mgr_restored.from_dict(snapshot)
	assert(mgr_restored.get_resident("room_A") == "keqing", "Restored room_A must be keqing")
	assert(mgr_restored.get_resident("room_B") == "sparkle", "Restored room_B must be sparkle")
	assert(mgr_restored.get_all_assignments().size() == 2, "Restored total assignments must be 2")

	print("  [Pass] HomeResidentManager 1-to-1 uniqueness and serialization verified")

func test_resident_actor_state_management() -> void:
	print("--- Test 1.5: HomeResidentActor State Preservation & Room Updates ---")
	var root_node := Node3D.new()
	root.add_child(root_node)

	var actor := RESIDENT_ACTOR.new()
	actor.character_id = "ganyu"
	actor.plot_id = "coastal"
	actor.room_id = "coastal_room_0001"
	actor.room_data = {
		"id": "coastal_room_0001",
		"story": 0,
		"cells": ["0:10:10", "0:10:11"],
		"furniture": ["desk_01"]
	}
	root_node.add_child(actor)

	assert(actor.state == RESIDENT_ACTOR.State.IDLE, "Initial actor state must be IDLE")
	assert(not actor.is_following(), "Actor should not be following initially")

	# 1. Enter and exit interaction from IDLE
	actor.enter_interaction()
	assert(actor.state == RESIDENT_ACTOR.State.INTERACTING, "Actor must enter INTERACTING state")
	assert(actor.previous_state == RESIDENT_ACTOR.State.IDLE, "Previous state must be IDLE")
	actor.exit_interaction()
	assert(actor.state == RESIDENT_ACTOR.State.IDLE, "Actor must restore IDLE state")

	# 2. Enter follow mode
	actor.set_following(true)
	assert(actor.state == RESIDENT_ACTOR.State.FOLLOWING, "Actor state must be FOLLOWING")
	assert(actor.is_following(), "Actor must report is_following() == true")

	# 3. Enter and exit interaction from FOLLOWING (e.g. pressing E while following)
	actor.enter_interaction()
	assert(actor.state == RESIDENT_ACTOR.State.INTERACTING, "Actor must enter INTERACTING state")
	assert(actor.previous_state == RESIDENT_ACTOR.State.FOLLOWING, "Previous state must be FOLLOWING")
	actor.exit_interaction()
	assert(actor.state == RESIDENT_ACTOR.State.FOLLOWING, "Actor must restore FOLLOWING state after interaction")
	assert(actor.is_following(), "Actor must still be following")

	# 4. Stop following
	actor.set_following(false)
	assert(actor.state == RESIDENT_ACTOR.State.IDLE, "Actor must return to IDLE")
	assert(not actor.is_following(), "Actor must not report is_following()")

	# 5. Live room data update (e.g. user placed new furniture in building mode)
	var new_room_data: Dictionary = {
		"id": "coastal_room_0001",
		"story": 0,
		"cells": ["0:10:10", "0:10:11", "0:11:10"],
		"furniture": ["desk_01", "bed_01"]
	}
	actor.update_room_data(new_room_data)
	assert(actor.room_data.furniture.size() == 2, "Room data furniture must be updated to 2 items")
	assert(actor._room_cells.size() == 3, "Parsed room cells must update to 3")

	actor.queue_free()
	root_node.queue_free()
	print("  [Pass] Resident actor state preservation, follow toggling and room data updates verified")

func test_resident_navigation_and_corner_avoidance() -> void:
	print("--- Test 1.6: HomeResidentActor Pathfinding & Corner Avoidance ---")
	var root_node := Node3D.new()
	root.add_child(root_node)

	var actor := RESIDENT_ACTOR.new()
	actor.character_id = "ganyu"
	actor.plot_id = "coastal"
	actor.room_id = "coastal_room_0001"
	actor.room_data = {"id": "coastal_room_0001", "story": 0, "cells": ["0:10:10"]}
	root_node.add_child(actor)

	# 1. Test Line of sight helper
	assert(actor._has_line_of_sight(Vector3.ZERO, Vector3(5, 0, 5), null), "Without space, line of sight should be true")

	# 2. Test Whisker steering calculation
	var steer_straight: Vector3 = actor._calculate_steer_direction(Vector3(0, 0, 10), null)
	assert(steer_straight.is_equal_approx(Vector3(0, 0, 1)), "Steering without obstacles should point towards target")

	# 3. Test breadcrumb trail accumulation during follow mode
	var mock_player := Node3D.new()
	root_node.add_child(mock_player)
	mock_player.global_position = Vector3(0, 0, 0)
	actor.global_position = Vector3(0, 0, -3)

	actor.set_following(true)
	assert(actor.state == RESIDENT_ACTOR.State.FOLLOWING, "Actor must be in FOLLOWING state")
	assert(actor._player_trail.is_empty(), "Trail starts empty")

	# Simulate player moving to multiple waypoints around a corner
	# Point 1: Move forward 1.0m
	mock_player.global_position = Vector3(0, 0, 1.0)
	actor._process_following(0.016, mock_player, actor.global_position.distance_to(mock_player.global_position))
	assert(actor._player_trail.size() == 1, "First player breadcrumb must be recorded")
	assert(actor._player_trail[0].is_equal_approx(Vector3(0, 0, 1.0)), "Waypoint must match player position")

	# Point 2: Move further forward (corner turn point)
	mock_player.global_position = Vector3(0, 0, 3.0)
	actor._process_following(0.016, mock_player, actor.global_position.distance_to(mock_player.global_position))

	# Point 3: Turn 90 degrees right around corner
	mock_player.global_position = Vector3(3.0, 0, 3.0)
	actor._process_following(0.016, mock_player, actor.global_position.distance_to(mock_player.global_position))
	assert(actor._player_trail.size() >= 2, "Trail must accumulate corner waypoints")

	# 4. Test teleport catch up when far away
	mock_player.global_position = Vector3(100.0, 0, 100.0)
	actor.global_position = Vector3(0, 0, 0)
	actor._process_following(0.016, mock_player, 141.4)
	assert(actor.global_position.distance_to(mock_player.global_position) < 3.0, "Actor must teleport catch up when far away")
	assert(actor._player_trail.is_empty(), "Trail must reset after catch up")

	mock_player.queue_free()
	actor.queue_free()
	root_node.queue_free()
	print("  [Pass] Resident actor breadcrumb pathfinding, whisker steering and corner catch-up verified")

func test_housing_panel_ui() -> void:
	print("--- Test 2: HomeRoomAssignmentPanel UI & Actions ---")
	var root_ctrl := Control.new()
	root.add_child(root_ctrl)

	var mgr := RESIDENT_MANAGER.new()
	var progress := GAME_PROGRESS.new()
	progress.unlock_companion("ganyu")
	progress.unlock_companion("keqing")

	var panel := ROOM_ASSIGNMENT_PANEL.new()
	panel.resident_manager = mgr
	panel.game_progress = progress
	root_ctrl.add_child(panel)

	var test_room: Dictionary = {
		"id": "coastal_room_0001",
		"story": 0,
		"kind": "indoor",
		"function": "bedroom",
		"area": 24.0,
		"cells": ["0:10:10", "0:10:11", "0:11:10", "0:11:11"]
	}

	var assigned_received := []
	panel.resident_assigned.connect(func(r_id: String, c_id: String):
		assigned_received.append({"room": r_id, "char": c_id})
	)

	panel.open("coastal", test_room)
	assert(panel.visible, "Panel must be visible after open()")
	assert(panel.target_room_id == "coastal_room_0001", "Target room id must match")

	# Simulate assigning ganyu
	panel._on_assign_pressed("coastal_room_0001", "ganyu")
	assert(mgr.get_resident("coastal_room_0001") == "ganyu", "Resident manager must record ganyu")
	assert(assigned_received.size() == 1, "resident_assigned signal must be emitted")
	assert(assigned_received[0].char == "ganyu", "Assigned char must be ganyu")

	# Close panel
	panel.close()
	assert(not panel.visible, "Panel must hide on close()")

	panel.queue_free()
	root_ctrl.queue_free()
	print("  [Pass] HomeRoomAssignmentPanel opened, assigned resident and closed successfully")

func test_interaction_panel_and_tiers() -> void:
	print("--- Test 3: HomeInteractionPanel Chat, Follow & Dual Intimacy Tiers ---")
	var root_ctrl := Control.new()
	root.add_child(root_ctrl)

	var panel := HOME_INTERACTION_PANEL.new()
	root_ctrl.add_child(panel)

	var actor := RESIDENT_ACTOR.new()
	actor.character_id = "keqing"
	actor.plot_id = "coastal"
	actor.room_id = "coastal_room_0001"
	actor.room_data = {"id": "coastal_room_0001", "story": 0, "cells": ["0:10:10"]}
	root_ctrl.add_child(actor)

	var intimacy_log: Array[Dictionary] = []
	panel.intimacy_requested.connect(func(tier: String, act: RESIDENT_ACTOR):
		intimacy_log.append({"tier": tier, "actor": act})
	)

	var follow_log: Array[bool] = []
	panel.follow_mode_toggled.connect(func(f: bool, act: RESIDENT_ACTOR):
		follow_log.append(f)
	)

	# Open interaction
	panel.open(actor)
	assert(panel.visible, "Interaction panel must be visible")
	assert(panel._name_label.text == "刻晴", "Character name must be 刻晴")

	# Test 1: Chat interaction fallback (offline / without world)
	panel._on_chat_pressed()
	assert(panel._dialogue_label.text.length() > 0, "Chat dialogue label must have content")
	assert(not "好感度与信任度提升" in panel._feedback_label.text, "Fake affection gain text must not be present")

	# Test 1.2: Chat interaction delegation to LLM free dialogue when world is connected
	var mock_world := Node.new()
	var mock_world_script := GDScript.new()
	mock_world_script.source_code = """
extends Node
var character: Node3D = null
var last_dialogue_call: Dictionary = {}
func show_free_dialogue(parent_panel: Node, display_name: String, character_id: String, custom_ctx: Dictionary) -> void:
	last_dialogue_call = {
		"parent_panel": parent_panel,
		"display_name": display_name,
		"character_id": character_id,
		"custom_ctx": custom_ctx
	}
"""
	mock_world_script.reload()
	mock_world.set_script(mock_world_script)
	root_ctrl.add_child(mock_world)

	var mock_home := Node3D.new()
	var mock_home_script := GDScript.new()
	mock_home_script.source_code = """
extends Node3D
var world: Node = null
var plots: Dictionary = {}
func _get_room_spawn_position(plot_id: String, room_data: Dictionary) -> Vector3:
	return Vector3(12.0, 0.5, 14.0)
"""
	mock_home_script.reload()
	mock_home.set_script(mock_home_script)
	mock_home.set("world", mock_world)
	root_ctrl.add_child(mock_home)

	actor.home = mock_home
	panel.open(actor)
	panel._on_chat_pressed()
	assert(not panel.visible, "Panel must hide when opening free dialogue")
	var call_info: Dictionary = mock_world.get("last_dialogue_call")
	assert(call_info.get("character_id") == "keqing", "Free dialogue character_id must be keqing")
	assert(call_info.get("parent_panel") == panel, "Parent panel must be passed")
	assert(call_info.get("custom_ctx", {}).has("on_closed"), "Custom ctx must contain on_closed callback")
	assert("家园" in call_info.get("custom_ctx", {}).get("dialogue_location", ""), "Location must mention home")

	# Simulating closing free dialogue via callback
	call_info["custom_ctx"]["on_closed"].call()
	assert(panel.visible, "Panel must restore visibility when free dialogue closes")

	# Test 2: Follow mode toggle and dynamic button text
	var follow_btn: Button = panel._options_container.get_child(2) as Button
	assert(follow_btn != null, "Follow button must exist")
	assert("要求跟我走" in follow_btn.text, "Initial button text must offer companion mode")
	panel._on_follow_toggle_pressed(true)
	assert(actor.state == RESIDENT_ACTOR.State.FOLLOWING, "Actor must enter FOLLOWING state")
	assert(actor.is_following(), "Actor must report following")
	follow_btn = panel._options_container.get_child(2) as Button
	assert("返回房间休息" in follow_btn.text, "Button text must now offer ending companion mode")
	assert(follow_log.size() == 1 and follow_log[0] == true, "Follow toggled signal must be emitted")

	panel._on_follow_toggle_pressed(false)
	assert(actor.state == RESIDENT_ACTOR.State.IDLE, "Actor must return to IDLE state")
	assert(not actor.is_following(), "Actor must not report following")
	follow_btn = panel._options_container.get_child(2) as Button
	assert("要求跟我走" in follow_btn.text, "Button text must revert to companion mode")
	assert(actor.global_position == Vector3(12.0, 0.5, 14.0), "Actor must return to room spawn position on stop follow")

	# Test 3: Intimacy selection - Normal Service (普通侍奉)
	panel._on_intimacy_menu_pressed()
	assert(panel._intimacy_options_container.visible, "Intimacy options container must show")
	panel._on_intimacy_selected("service")
	assert(intimacy_log.size() == 1, "Intimacy signal must fire for service")
	assert(intimacy_log[0].tier == "service", "Tier must be service")

	# Test 4: Intimacy selection - Honban (本番侍奉)
	panel.open(actor)
	panel._on_intimacy_menu_pressed()
	panel._on_intimacy_selected("honban")
	assert(intimacy_log.size() == 2, "Intimacy signal must fire for honban")
	assert(intimacy_log[1].tier == "honban", "Tier must be honban")

	# Test 5: In-room motion list scroll view with disabled furniture buttons
	panel.open(actor)
	panel._on_intimacy_menu_pressed()
	panel._show_motion_list("service")
	assert(panel._motion_scroll.visible, "Motion scroll container must be visible")
	var btns := panel._motion_list_container.get_children()
	assert(btns.size() == 17, "Must contain 16 motions plus back button, got %d" % btns.size())

	# Since actor room has no furniture, bed and chair buttons must be disabled
	var disabled_count := 0
	var enabled_count := 0
	for b in btns:
		if b is Button and b.text != "◀ 返回选择侍奉类别":
			if b.disabled:
				disabled_count += 1
				assert("缺少家具" in b.text, "Disabled button must show missing furniture notice")
			else:
				enabled_count += 1
	assert(disabled_count == 4, "Must have 4 furniture-locked service motions (1 bed + 3 chair), got %d" % disabled_count)
	assert(enabled_count == 12, "Must have 12 enabled ground service motions, got %d" % enabled_count)

	# Click an enabled motion button
	var selected_motion_log: Array[Dictionary] = []
	panel.intimacy_motion_selected.connect(func(m: Dictionary, act: RESIDENT_ACTOR):
		selected_motion_log.append(m)
	)
	var intimacy_log_count_before: int = intimacy_log.size()
	var first_active_btn: Button = null
	for b in btns:
		if b is Button and not b.disabled and b.text.begins_with("▶"):
			first_active_btn = b
			break
	assert(first_active_btn != null, "Must find an active motion button")
	first_active_btn.pressed.emit()
	assert(selected_motion_log.size() == 1, "intimacy_motion_selected must emit when clicked")
	assert(intimacy_log.size() == intimacy_log_count_before, "Legacy intimacy_requested must not be emitted when motion is selected")
	assert(not panel.visible, "Panel must close when motion is selected")

	mock_home.queue_free()
	mock_world.queue_free()
	panel.queue_free()
	actor.queue_free()
	root_ctrl.queue_free()
	print("  [Pass] Interaction panel chat, companion follow, scrollable motions and furniture locks verified")

func test_construction_world_housing_integration() -> void:
	print("--- Test 4: ConstructionWorld Full Housing Integration & Snapshot Persistence ---")
	var world_mock := Node3D.new()
	var w_script := GDScript.new()
	w_script.source_code = """
extends Node3D
var test_ready: bool = true
var character_mode: bool = true
var free_mode: bool = false
var review_ui_visible: bool = false
var encounter_ui_active: bool = false
var automation_enabled: bool = true
var metadata: Dictionary = {"spawns": []}
var character: Node3D = null
var resolved_spawns: Array = []
var switching_actor: bool = false
func is_world_input_allowed() -> bool:
	return true
func active_actor() -> Node3D:
	return character
"""
	w_script.reload()
	world_mock.set_script(w_script)
	root.add_child(world_mock)

	var char_mock := CharacterBody3D.new()
	var char_shape := CollisionShape3D.new()
	char_shape.shape = CapsuleShape3D.new()
	char_mock.add_child(char_shape)
	world_mock.add_child(char_mock)
	char_mock.global_position = Vector3(25.0, 0.25, 25.0)
	world_mock.character = char_mock

	var cw: Node3D = CONSTRUCTION_WORLD.new()
	cw.world = world_mock
	root.add_child(cw)
	cw.set_process(false)

	await process_frame
	await process_frame

	assert(cw.resident_manager != null, "Resident manager must be instantiated")
	assert(cw.room_assignment_panel != null, "Room assignment panel must be instantiated")
	assert(cw.home_interaction_panel != null, "Home interaction panel must be instantiated")

	# Check coastal example rooms exist
	var coastal_plot: Dictionary = cw.plots.get("coastal", {})
	assert(not coastal_plot.is_empty(), "Coastal plot must exist")
	assert(not coastal_plot.data.rooms.is_empty(), "Coastal plot must have analyzed rooms")

	var first_room: Dictionary = coastal_plot.data.rooms[0]
	var test_room_id: String = str(first_room.get("id"))
	assert(not test_room_id.is_empty(), "Room id must not be empty")

	# Assign ganyu to first room
	cw.resident_manager.assign_resident(test_room_id, "ganyu")
	cw.refresh_residents()
	assert(cw.resident_actors.has(test_room_id), "Resident actor must be spawned for assigned room")

	var actor_instance = cw.resident_actors[test_room_id]
	assert(actor_instance.character_id == "ganyu", "Actor character_id must be ganyu")

	# Test room detection with get_current_room()
	var first_cell_str: String = str(first_room.cells[0])
	var cell_parts := first_cell_str.split(":")
	var cx := cell_parts[1].to_int()
	var cz := cell_parts[2].to_int()
	var local_in_room := Vector3(cx * 2.0 + 1.0, 0.25, cz * 2.0 + 1.0)
	var global_in_room: Vector3 = coastal_plot.root.to_global(local_in_room)
	char_mock.global_position = global_in_room

	var detected_room: Dictionary = cw.get_current_room()
	assert(not detected_room.is_empty(), "Room must be detected when player stands inside")
	assert(detected_room.get("id") == test_room_id, "Detected room ID must match first room")

	# Test player outside plots -> empty room
	char_mock.global_position = Vector3(9999.0, 0.0, 9999.0)
	assert(cw.get_current_room().is_empty(), "Outside position must return empty room")

	# Test Snapshot serialization including housing data
	var snap: Dictionary = cw.save_snapshot()
	assert(snap.has("housing"), "Save snapshot must contain housing section")
	var snap_housing: Dictionary = snap.get("housing", {})
	var snap_assignments: Dictionary = snap_housing.get("assignments", {})
	assert(snap_assignments.get(test_room_id) == "ganyu", "Housing snapshot must store ganyu")

	# Test Snapshot restoration
	cw.resident_manager.clear_all()
	cw.refresh_residents()
	assert(cw.resident_actors.is_empty(), "Resident actors must be cleared after clear_all()")

	var restored_ok: bool = cw.restore_snapshot(snap, true)
	assert(restored_ok, "Snapshot restoration must succeed")
	assert(cw.resident_manager.get_resident(test_room_id) == "ganyu", "Resident assignment must be restored")
	assert(cw.resident_actors.has(test_room_id), "Resident actor must be restored and spawned")

	# Test Intimacy dispatch with furniture routing
	cw._on_home_intimacy_requested("service", actor_instance)
	cw._on_home_intimacy_requested("honban", actor_instance)

	# Test in-room paired animation playback staging and camera control
	assert(not cw.is_service_staging_active(), "is_service_staging_active must be false before staging")
	assert(cw.get_active_custom_camera() == null, "get_active_custom_camera must be null before staging")

	var test_motion: Dictionary = CATALOG.get_motions("service")[0]
	cw._on_home_intimacy_motion_selected(test_motion, actor_instance)
	assert(cw.is_intimacy_active, "is_intimacy_active must be true during staging")
	assert(cw.is_service_staging_active(), "is_service_staging_active must report true during staging")
	assert(cw.get_active_custom_camera() == cw.intimacy_camera, "get_active_custom_camera must return intimacy_camera")
	assert(cw.is_world_input_locked(), "Input must be locked during staging")
	assert(is_instance_valid(cw.intimacy_staging_root), "intimacy_staging_root must be created")
	assert(is_instance_valid(cw.intimacy_camera), "intimacy_camera must be created")
	assert(not char_mock.visible, "Player character must be hidden during intimacy")
	assert(not actor_instance.visible, "Resident actor must be hidden during intimacy")

	# Test camera orbit zoom
	var initial_dist: float = cw.intimacy_cam_dist
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	cw._input(wheel_up)
	assert(cw.intimacy_cam_dist < initial_dist, "Wheel up must zoom in camera")

	# Test finishing intimacy staging
	cw.finish_intimacy_staging()
	assert(not cw.is_intimacy_active, "is_intimacy_active must be false after finish")
	assert(not cw.is_service_staging_active(), "is_service_staging_active must report false after finish")
	assert(cw.get_active_custom_camera() == null, "get_active_custom_camera must be null after finish")
	assert(cw.intimacy_staging_root == null, "Staging root must be cleaned up")
	assert(cw.intimacy_camera == null, "Staging camera must be cleaned up")
	assert(char_mock.visible, "Player character must be restored")
	assert(actor_instance.visible, "Resident actor must be restored")
	assert(actor_instance.state == RESIDENT_ACTOR.State.IDLE, "Resident actor state must be IDLE")

	cw.queue_free()
	world_mock.queue_free()
	print("  [Pass] ConstructionWorld room detection, resident spawning, in-room intimacy playback staging and persistence verified")
