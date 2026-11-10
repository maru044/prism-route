extends SceneTree

const ENCOUNTER_CLASS := preload("res://scripts/world/initial_temple_encounter_controller.gd")
const WORLD_CHAR_SCENE := preload("res://scenes/characters/world_ganyu.tscn")
const FURNITURE_CLASS := preload("res://scripts/world/interactive_furniture.gd")
const PROGRESS_CLASS := preload("res://scripts/progress/game_progress.gd")

func _init() -> void:
	call_deferred("_run_phase3_tests")

func _run_phase3_tests() -> void:
	print("=== STARTING PHASE 3 & 4 AUDIT FIXES TEST ===")

	var root_node := Node3D.new()
	root_node.name = "Phase3Root"
	get_root().add_child(root_node)

	# 1. Test InteractiveFurniture Anchor API
	print("Step 1: Testing InteractiveFurniture Anchor API")
	var furn: Node3D = FURNITURE_CLASS.new()
	furn.name = "seat_01"
	furn.set("furniture_id", "temple_seat")
	furn.position = Vector3(10.0, 2.0, 5.0)

	var anchor_seat := Marker3D.new()
	anchor_seat.name = "Anchor_Seat"
	anchor_seat.position = Vector3(0.0, 0.45, 0.1)
	furn.add_child(anchor_seat)

	var anchor_front := Marker3D.new()
	anchor_front.name = "Anchor_Front"
	anchor_front.position = Vector3(0.0, 0.0, 1.2)
	furn.add_child(anchor_front)

	root_node.add_child(furn)

	for f in 2:
		await process_frame

	assert(furn.has_motion_anchor("Anchor_Seat") == true, "Must have Anchor_Seat")
	assert(furn.has_motion_anchor("seat") == true, "Must find short name seat")
	assert(furn.has_motion_anchor("Anchor_Front") == true, "Must have Anchor_Front")
	assert(furn.has_motion_anchor("non_existent") == false, "Must return false for non-existent anchor")

	var seat_local: Transform3D = furn.get_motion_anchor("Anchor_Seat", false)
	assert(absf(seat_local.origin.y - 0.45) < 0.01, "Local anchor height must be 0.45")

	var seat_global: Transform3D = furn.get_motion_anchor("Anchor_Seat", true)
	assert(absf(seat_global.origin.y - 2.45) < 0.01, "Global anchor height must be 2.45")

	var missing_tf: Transform3D = furn.get_motion_anchor("non_existent", true)
	assert(missing_tf == Transform3D.IDENTITY, "Missing anchor must return Transform3D.IDENTITY")
	print("PASS: InteractiveFurniture Anchor API verified")

	# 2. Test GameProgress Data Boundary
	print("Step 2: Testing GameProgress boundary and serialization")
	var prog = PROGRESS_CLASS.new()
	assert(prog.tutorial_completed == false, "Initial tutorial_completed must be false")
	assert(prog.initial_temple_defeat_count == 0, "Initial defeat count must be 0")
	assert(prog.is_companion_unlocked("sparkle") == false, "Sparkle initially locked")

	prog.record_defeat()
	assert(prog.initial_temple_defeat_count == 1, "Defeat count should increment to 1")

	prog.mark_tutorial_completed()
	assert(prog.tutorial_completed == true, "Tutorial completed must be true")

	prog.unlock_companion("sparkle")
	assert(prog.is_companion_unlocked("sparkle") == true, "Sparkle should be unlocked")

	prog.set_settlement_outcome("spare_virgin")
	assert(prog.settlement_outcome == "spare_virgin", "Settlement outcome should be spare_virgin")

	var serialized: Dictionary = prog.to_dict()
	assert(serialized.get("tutorial_completed") == true, "Serialized must have tutorial_completed")
	assert(serialized.get("initial_temple_defeat_count") == 1, "Serialized defeat count must be 1")

	var prog_restored = PROGRESS_CLASS.new()
	prog_restored.from_dict(serialized)
	assert(prog_restored.tutorial_completed == true, "Restored tutorial completed")
	assert(prog_restored.is_companion_unlocked("sparkle") == true, "Restored companion unlock")
	assert(prog_restored.settlement_outcome == "spare_virgin", "Restored settlement outcome")
	print("PASS: GameProgress operations and serialization verified")

	# 3. Test Controller Anchor Discovery and Missing Rejection
	print("Step 3: Testing Controller Furniture Anchor Resolution")
	var temple := Node3D.new()
	temple.name = "TempleNode"
	temple.set_meta("furniture_instances", { "seat_01": furn })
	root_node.add_child(temple)

	var npc_anchor := Marker3D.new()
	npc_anchor.name = "NPCAnchor"
	temple.add_child(npc_anchor)

	var npc_avatar := Node3D.new()
	npc_avatar.name = "NPCAvatar"
	npc_anchor.add_child(npc_avatar)

	var npc_body := StaticBody3D.new()
	npc_body.name = "NPCBody"
	npc_anchor.add_child(npc_body)

	var world := Node3D.new()
	world.name = "MockWorld"
	world.set("automation_enabled", true)
	world.set("character_mode", true)
	world.set("free_mode", false)
	world.set("game_progress", prog)
	root_node.add_child(world)

	var char_node: CharacterBody3D = WORLD_CHAR_SCENE.instantiate()
	char_node.name = "Character"
	char_node.position = Vector3(10.0, 2.0, 7.0)
	world.add_child(char_node)
	world.set_meta("character", char_node)

	var encounter: ENCOUNTER_CLASS = ENCOUNTER_CLASS.new()
	encounter.name = "EncounterController"
	temple.add_child(encounter)
	encounter.initialize(temple, world, npc_anchor, npc_avatar, npc_body)

	for f in 2:
		await process_frame

	# Must resolve anchor from real InteractiveFurniture
	var resolved_seat: Transform3D = encounter.get_furniture_anchor("seat_01", "Anchor_Seat")
	assert(absf(resolved_seat.origin.y - 2.45) < 0.01, "Controller must resolve seat_01 Anchor_Seat from furniture instance")

	# Real temple with furniture_instances must reject missing anchors without silent fallback
	var missing_anchor: Transform3D = encounter.get_furniture_anchor("seat_01", "Anchor_NonExistent")
	assert(missing_anchor == Transform3D.IDENTITY, "Missing anchor must return Transform3D.IDENTITY")

	var missing_furn: Transform3D = encounter.get_furniture_anchor("unknown_furniture", "Anchor_Front")
	assert(missing_furn == Transform3D.IDENTITY, "Unknown furniture must return Transform3D.IDENTITY")
	print("PASS: Controller Anchor Resolution and Missing Anchor Rejection verified")

	# 4. Test World Mode Constraints on Character Interaction
	print("Step 4: Testing World Mode Boundaries (Character vs Camper vs FreeCam)")
	assert(encounter._get_world_character() == char_node, "Character mode must return character node")

	world.set_meta("free_mode", true)
	assert(encounter._get_world_character() == null, "Free camera mode must return null character to block temple interaction")
	world.set_meta("free_mode", false)

	world.set_meta("character_mode", false)
	assert(encounter._get_world_character() == null, "Camper mode (character_mode=false) must return null character")
	world.set_meta("character_mode", true)

	var mock_planting := { "active": true }
	world.set_meta("planting", mock_planting)
	assert(encounter._get_world_character() == null, "Active planting mode must return null character")
	world.set_meta("planting", null)

	assert(encounter._get_world_character() == char_node, "Character mode restored successfully")
	print("PASS: World Mode Boundaries verified")

	# 5. Test Staging Safety and Abort on Missing Anchor
	print("Step 5: Testing Furniture Staging with Missing Anchor")
	encounter.allow_test_fixture_fallback = false
	encounter._begin_furniture_service_staging("honban") # rest_01 does not exist in this test temple!
	for f in 3:
		await process_frame
	assert(encounter.current_state == encounter.EncounterState.AVAILABLE, "Staging must abort to AVAILABLE when furniture anchor is missing")
	print("PASS: Staging cleanly aborted on missing anchor")

	# 6. Test Local Exit Positioning and InputMap Action Dismissal
	print("Step 6: Testing Local Exit Positioning & InputMap Dismissal")
	encounter.allow_test_fixture_fallback = true # Allow fallback to rest_01 for staging test
	encounter._begin_furniture_service_staging("virgin")
	assert(encounter.current_state == encounter.EncounterState.FURNITURE_SERVICE_STAGING, "Staging entered")

	var start_time := Time.get_ticks_msec()
	while encounter.current_state == encounter.EncounterState.FURNITURE_SERVICE_STAGING:
		await process_frame
		if Time.get_ticks_msec() - start_time > 6000:
			push_error("Staging timed out")
			quit(1)
			return

	assert(encounter.current_state == encounter.EncounterState.FURNITURE_SERVICE_ACTIVE, "Active service entered")

	var settlement_signals: Array[String] = []
	encounter.settlement_completed.connect(func(outcome: String):
		settlement_signals.append(outcome)
	)

	# Dismiss using InputMap Action 'ui_accept'
	var ev_action := InputEventAction.new()
	ev_action.action = "ui_accept"
	ev_action.pressed = true
	encounter._unhandled_input(ev_action)

	for f in 3:
		await process_frame

	assert(encounter.current_state == encounter.EncounterState.COMPLETED, "Encounter should be COMPLETED")
	assert(settlement_signals.size() == 1, "settlement_completed must be emitted exactly ONCE")
	assert(settlement_signals[0] == "spare_virgin", "Emitted outcome must match spare_virgin")

	# Verify NPC exit position was calculated from local basis, not arbitrary world offset
	var expected_local_offset: Vector3 = encounter.last_service_approach_basis.x.normalized() * 0.7
	var expected_npc_exit: Vector3 = encounter.last_service_approach_pos + expected_local_offset
	assert(npc_avatar.global_position.distance_to(expected_npc_exit) < 0.05, "NPC exit position must align with local furniture side vector")

	# Verify GameProgress received updates
	assert(prog.tutorial_completed == true, "GameProgress tutorial completed")
	assert(prog.is_companion_unlocked("sparkle") == true, "GameProgress companion unlocked")
	assert(prog.settlement_outcome == "spare_virgin", "GameProgress outcome updated")
	print("PASS: Local exit positioning, single settlement signal and GameProgress verified")

	print("=== ALL PHASE 3 & 4 AUDIT FIXES PASSED 100%! ===")
	quit(0)
