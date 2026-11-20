extends SceneTree
## Automated test suite for Home Housing and Multi-Dimensional Resident Interaction System.

const DATA := preload("res://scripts/construction/building_data.gd")
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

	test_resident_manager()
	test_housing_panel_ui()
	test_interaction_panel_and_tiers()
	await test_construction_world_housing_integration()

	print("\n==================================================")
	print("ALL HOME HOUSING & INTERACTION TESTS PASSED!")
	print("==================================================\n")
	quit(0)

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

	# Test 1: Chat interaction
	panel._on_chat_pressed()
	assert("好感度与信任度提升" in panel._feedback_label.text, "Chat feedback must show affection gain")

	# Test 2: Follow mode toggle
	panel._on_follow_toggle_pressed(true)
	assert(actor.state == RESIDENT_ACTOR.State.FOLLOWING, "Actor must enter FOLLOWING state")
	assert(follow_log.size() == 1 and follow_log[0] == true, "Follow toggled signal must be emitted")

	panel._on_follow_toggle_pressed(false)
	assert(actor.state == RESIDENT_ACTOR.State.IDLE, "Actor must return to IDLE state")

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

	panel.queue_free()
	actor.queue_free()
	root_ctrl.queue_free()
	print("  [Pass] Interaction panel chat, companion follow and dual intimacy tiers verified")

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
	char_mock.global_position = Vector3(25.0, 0.25, 25.0)
	var char_shape := CollisionShape3D.new()
	char_shape.shape = CapsuleShape3D.new()
	char_mock.add_child(char_shape)
	world_mock.add_child(char_mock)
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

	cw.queue_free()
	world_mock.queue_free()
	print("  [Pass] ConstructionWorld room detection, resident spawning, and snapshot persistence verified")
