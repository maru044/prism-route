extends SceneTree
## Automated test suite for Phase 1 Audit Fixes (Issue #24).
## Verifies WorldControlContext, state transition constraints, decoupled branches, and pleasure math.

const WorldControlContext := preload("res://scripts/world/world_control_context.gd")
const InitialTempleEncounterController := preload("res://scripts/world/initial_temple_encounter_controller.gd")
const PleasureComponent := preload("res://scripts/combat/pleasure_component.gd")
const DialogueManager := preload("res://scripts/narrative/dialogue_manager.gd")
const SparkleTutorialDialogue := preload("res://scripts/narrative/sparkle_tutorial_dialogue.gd")

func _init() -> void:
	call_deferred("_run_phase1_tests")

func _run_phase1_tests() -> void:
	print("=== STARTING PHASE 1 AUDIT FIXES VERIFICATION ===")

	# -------------------------------------------------------------
	# Test 1: WorldControlContext Input Blocking
	# -------------------------------------------------------------
	print("[Test 1] Testing WorldControlContext input blocking:")
	var temple_mock = Node3D.new()
	root.add_child(temple_mock)

	var controller = InitialTempleEncounterController.new()
	temple_mock.add_child(controller)

	var dummy_anchor = Marker3D.new()
	temple_mock.add_child(dummy_anchor)
	var dummy_avatar = Node3D.new()
	temple_mock.add_child(dummy_avatar)
	var dummy_body = StaticBody3D.new()
	temple_mock.add_child(dummy_body)

	controller.initialize(temple_mock, null, dummy_anchor, dummy_avatar, dummy_body)

	assert(WorldControlContext.is_world_input_blocked(self) == false, "Input must not be blocked initially in AVAILABLE state")

	# Enter combat staging
	var ok_intro = controller._set_encounter_state(InitialTempleEncounterController.EncounterState.INTRO_DIALOGUE)
	assert(ok_intro == true, "Transition to INTRO_DIALOGUE must succeed")
	assert(WorldControlContext.is_world_input_blocked(self) == true, "Input must be blocked during INTRO_DIALOGUE")

	var ok_staging = controller._set_encounter_state(InitialTempleEncounterController.EncounterState.STAGING_TRANSITION)
	assert(ok_staging == true, "Transition to STAGING_TRANSITION must succeed")
	assert(WorldControlContext.is_world_input_blocked(self) == true, "Input must be blocked during STAGING_TRANSITION even if dialogue panel is hidden")

	var ok_combat = controller._set_encounter_state(InitialTempleEncounterController.EncounterState.COMBAT)
	assert(ok_combat == true, "Transition to COMBAT must succeed")
	assert(WorldControlContext.is_world_input_blocked(self) == true, "Input must be blocked during COMBAT")

	# Revert to AVAILABLE
	controller._set_encounter_state(InitialTempleEncounterController.EncounterState.AVAILABLE)
	assert(WorldControlContext.is_world_input_blocked(self) == false, "Input must be unblocked when back to AVAILABLE")
	print("[Test 1 PASSED] WorldControlContext properly blocks input during all encounter stages!")

	# -------------------------------------------------------------
	# Test 2: EncounterState Illegal Transition Interception
	# -------------------------------------------------------------
	print("[Test 2] Testing illegal state transition interception:")
	assert(controller.current_state == InitialTempleEncounterController.EncounterState.AVAILABLE, "Must start at AVAILABLE")

	# Attempt illegal jump directly to COMBAT from AVAILABLE
	var illegal_jump = controller._set_encounter_state(InitialTempleEncounterController.EncounterState.COMBAT)
	assert(illegal_jump == false, "Direct jump from AVAILABLE to COMBAT must be rejected")
	assert(controller.current_state == InitialTempleEncounterController.EncounterState.AVAILABLE, "State must remain AVAILABLE")

	# Attempt illegal jump to FURNITURE_SERVICE_ACTIVE from AVAILABLE
	var illegal_furn = controller._set_encounter_state(InitialTempleEncounterController.EncounterState.FURNITURE_SERVICE_ACTIVE)
	assert(illegal_furn == false, "Direct jump to FURNITURE_SERVICE_ACTIVE must be rejected")
	assert(controller.current_state == InitialTempleEncounterController.EncounterState.AVAILABLE, "State must remain AVAILABLE")
	print("[Test 2 PASSED] Illegal state transitions correctly intercepted by state machine!")

	# -------------------------------------------------------------
	# Test 3: Decoupled Narrative Branches and Priority Resolution
	# -------------------------------------------------------------
	print("[Test 3] Testing Decoupled Narrative Branches and Priority Resolution:")
	var graph: Dictionary = SparkleTutorialDialogue.get_dialogue_graph()
	assert("post_kill_greeting" in graph.get("nodes", {}), "Dialogue graph must have post_kill_greeting")
	assert("post_spare_greeting" in graph.get("nodes", {}), "Dialogue graph must have post_spare_greeting")
	assert("respawn_dialogue" in graph.get("nodes", {}), "Dialogue graph must have respawn_dialogue")

	# Case A: Defeat retry priority over previous outcome
	controller.settlement_outcome = "spare_virgin"
	controller.last_battle_result = "player_defeat"

	controller.start_encounter_dialogue()
	assert(controller.dialogue_manager.current_node_id == "respawn_dialogue", "Defeat retry must take priority even after spare")
	assert(controller.last_battle_result == "none", "last_battle_result must be consumed by opening dialogue")
	controller.dialogue_manager._finish_with_action("close")

	# Case B: Post-kill greeting when settlement_outcome is kill
	controller.settlement_outcome = "kill"
	controller.last_battle_result = "none"
	controller._set_encounter_state(InitialTempleEncounterController.EncounterState.AVAILABLE)

	controller.start_encounter_dialogue()
	assert(controller.dialogue_manager.current_node_id == "post_kill_greeting", "Must enter post_kill_greeting after kill settlement")
	controller.dialogue_manager._finish_with_action("close")

	# Case C: Post-spare greeting when settlement_outcome is spare
	controller.settlement_outcome = "spare_honban"
	controller.last_battle_result = "none"
	controller._set_encounter_state(InitialTempleEncounterController.EncounterState.AVAILABLE)

	controller.start_encounter_dialogue()
	assert(controller.dialogue_manager.current_node_id == "post_spare_greeting", "Must enter post_spare_greeting after spare settlement")
	controller.dialogue_manager._finish_with_action("close")
	print("[Test 3 PASSED] Narrative branch priorities decoupled and verified!")

	# -------------------------------------------------------------
	# Test 4: Accurate PleasureComponent Increment Return Value
	# -------------------------------------------------------------
	print("[Test 4] Testing PleasureComponent accurate delta calculation:")
	var pleasure = PleasureComponent.new()
	root.add_child(pleasure)

	pleasure.current_pleasure = 89.0
	pleasure.pleasure_locked = true
	pleasure.pleasure_cap = 90.0

	var gained: float = pleasure.add_pleasure(20.0)
	assert(pleasure.current_pleasure == 90.0, "Current pleasure must be clamped to cap 90.0")
	assert(absf(gained - 1.0) < 0.001, "Returned gain must be exact delta (1.0), not requested 20.0")

	# Climax clamping exact delta
	pleasure.pleasure_locked = false
	pleasure.current_pleasure = 95.0
	var climax_gain: float = pleasure.add_pleasure(15.0)
	assert(pleasure.current_pleasure == 100.0, "Current pleasure must reach max 100.0")
	assert(absf(climax_gain - 5.0) < 0.001, "Returned climax gain must be exact delta (5.0)")
	print("[Test 4 PASSED] PleasureComponent delta returns accurate change!")

	# -------------------------------------------------------------
	# Test 5: Clean up
	# -------------------------------------------------------------
	pleasure.queue_free()
	temple_mock.queue_free()

	print("=== ALL PHASE 1 AUDIT FIXES TESTS PASSED 100%! ===")
	quit(0)
