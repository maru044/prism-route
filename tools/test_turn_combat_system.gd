extends SceneTree
## Comprehensive automated test suite for the Refactored Turn-Based Sensual Combat and Narrative Engine.
## Validates Action Registry, DialogueContext, TemporaryCombatModifiers, Reset Isolation, and Session Idempotency.

const PleasureComponent := preload("res://scripts/combat/pleasure_component.gd")
const TurnActionResource := preload("res://scripts/combat/turn_action_resource.gd")
const TurnCombatManager := preload("res://scripts/combat/turn_combat_manager.gd")
const DialogueManager := preload("res://scripts/narrative/dialogue_manager.gd")
const SparkleTutorialDialogue := preload("res://scripts/narrative/sparkle_tutorial_dialogue.gd")

func _init() -> void:
	call_deferred("_run_full_test_suite")

func _run_full_test_suite() -> void:
	print("=== STARTING FULL REFACTORED COMBAT & NARRATIVE TEST SUITE ===")
	
	# Test 1: PleasureComponent Complete Reset and Edging Thresholds
	print("[Test 1] Testing PleasureComponent complete reset and thresholds:")
	var player_pleasure = PleasureComponent.new()
	player_pleasure.character_name = "Player"
	root.add_child(player_pleasure)
	
	player_pleasure.pleasure_locked = true
	player_pleasure.pleasure_cap = 90.0
	player_pleasure.damage_taken_multiplier = 2.5
	player_pleasure.add_pleasure(50.0, "mouth")
	assert(player_pleasure.current_pleasure > 0.0, "Pleasure should be greater than 0")
	
	player_pleasure.reset()
	assert(player_pleasure.current_pleasure == 0.0, "Pleasure must be reset to 0")
	assert(player_pleasure.pleasure_locked == false, "pleasure_locked must be reset to false")
	assert(player_pleasure.pleasure_cap == 100.0, "pleasure_cap must be reset to 100.0")
	assert(player_pleasure.damage_taken_multiplier == 1.0, "damage_taken_multiplier must be reset to 1.0")
	assert(player_pleasure.edging_threshold == PleasureComponent.EDGING_PREVIEW_THRESHOLD, "Threshold must match constant")
	print("[Test 1 PASSED] PleasureComponent reset and threshold isolation verified!")
	
	# Test 2: DialogueManager Action Registry, Aliases, and Context
	print("[Test 2] Testing DialogueManager Action Registry and Session Context:")
	var d_mgr = DialogueManager.new()
	root.add_child(d_mgr)
	
	var graph: Dictionary = SparkleTutorialDialogue.get_dialogue_graph()
	var payload_box := [{}]
	d_mgr.dialogue_ended.connect(func(payload: Dictionary):
		payload_box[0] = payload
	)
	
	# Start in-battle edging dialogue with NEXT_TURN policy
	d_mgr.start_dialogue(
		graph,
		"mid_battle_edging",
		DialogueManager.DialogueSource.MID_BATTLE_EDGING,
		DialogueManager.ResumePolicy.NEXT_TURN
	)
	assert(d_mgr.session_active, "Session must be active")
	assert(d_mgr.session_id == 1, "Session ID should be 1")
	assert(d_mgr.current_source == DialogueManager.DialogueSource.MID_BATTLE_EDGING, "Source must match")
	assert(d_mgr.current_resume_policy == DialogueManager.ResumePolicy.NEXT_TURN, "Policy must match NEXT_TURN")
	
	# Advance text to choice
	d_mgr.advance_text()
	# Choose option 0: 咬牙坚持
	d_mgr.choose_option(0)
	# Choose option 0: 重返战场
	d_mgr.choose_option(0)
	
	assert(not d_mgr.session_active, "Session must be closed after action")
	assert(payload_box[0].get("action") == DialogueManager.ACTION_RESUME_COMBAT, "Action must be resume_combat")
	assert(payload_box[0].get("resume_policy") == DialogueManager.ResumePolicy.NEXT_TURN, "Payload must retain NEXT_TURN policy")
	assert(payload_box[0].get("session_id") == 1, "Payload must have correct session_id")
	print("[Test 2 PASSED] DialogueManager context tracking and action dispatch verified!")
	
	# Test 3: Action Aliases (choose_kill -> kill, choose_spare -> spare)
	print("[Test 3] Testing Action Alias Normalization:")
	d_mgr.start_dialogue(graph, "start")
	d_mgr._finish_with_action("choose_kill")
	assert(payload_box[0].get("action") == "kill", "choose_kill must normalize to kill")
	d_mgr.start_dialogue(graph, "start")
	d_mgr._finish_with_action("choose_spare")
	assert(payload_box[0].get("action") == "spare", "choose_spare must normalize to spare")
	print("[Test 3 PASSED] Action alias normalization verified!")
	
	# Test 4: Temporary Defense Modifier vs Action Defense (P0-3)
	print("[Test 4] Testing Temporary Defense Modifier non-overwriting:")
	var npc_pleasure = PleasureComponent.new()
	npc_pleasure.character_name = "NPC"
	root.add_child(npc_pleasure)
	
	var combat_mgr = TurnCombatManager.new()
	root.add_child(combat_mgr)
	combat_mgr.setup(player_pleasure, npc_pleasure)
	
	combat_mgr.start_combat(false, {})
	
	# Apply temporary defense from mid-battle dialogue (e.g. 咬牙坚持 50%)
	combat_mgr.temporary_defense_modifier = 0.5
	
	# Player uses an aggressive action with 0 self-defense (e.g. caress)
	var caress_action = load("res://assets/combat/actions/action_caress.tres")
	combat_mgr.execute_player_action(caress_action)
	
	# Temporary defense MUST survive player action execution
	assert(combat_mgr.temporary_defense_modifier == 0.5, "Temporary defense must NOT be wiped by player action")
	
	# Allow NPC turn to execute and consume defense
	for i in range(75):
		await process_frame
		
	# After NPC turn, temporary modifier is consumed
	assert(combat_mgr.temporary_defense_modifier == 0.0, "Temporary defense must be consumed after NPC turn")
	assert(combat_mgr.round_action_defense == 0.0, "Round action defense must be reset after NPC turn")
	print("[Test 4 PASSED] Temporary combat modifier non-overwriting verified!")
	
	# Test 5: Consecutive Battles Reset (P0-4)
	print("[Test 5] Testing consecutive battles state isolation:")
	# Battle 1: Distracted cheat (multiplier 2.5) + lock pleasure
	combat_mgr.start_combat(false, {"meta_cheat_mode": "distracted"})
	assert(npc_pleasure.damage_taken_multiplier == 2.5, "NPC should take 2.5x damage in Battle 1")
	
	# Battle 2: Fair duel with no cheats
	combat_mgr.start_combat(false, {})
	assert(npc_pleasure.damage_taken_multiplier == 1.0, "NPC damage multiplier must be reset to 1.0 in Battle 2")
	assert(player_pleasure.pleasure_locked == false, "Player pleasure lock must be false in Battle 2")
	print("[Test 5 PASSED] Consecutive battle state isolation verified!")
	
	# Test 6: Idempotent Combat Ending (P0-5)
	print("[Test 6] Testing Idempotent Combat Ending:")
	var end_event_box := [0]
	combat_mgr.combat_ended.connect(func(_w: String, _l: String, _r: String):
		end_event_box[0] += 1
	)
	
	combat_mgr.start_combat(false, {})
	player_pleasure.add_pleasure(150.0) # Defeat master
	combat_mgr._check_battle_state()
	
	assert(combat_mgr.is_resolved == true, "Combat must be resolved")
	assert(end_event_box[0] == 1, "Combat ended event must be emitted exactly once")
	
	# Attempt illegal second resolution
	combat_mgr._check_battle_state()
	assert(end_event_box[0] == 1, "Combat ended event must not be emitted again")
	
	# Attempt illegal resume after resolved
	combat_mgr.resume_combat_after_dialogue(false, false)
	assert(combat_mgr.current_phase == TurnCombatManager.Phase.DEFEAT, "Phase must not change after resolution")
	print("[Test 6 PASSED] Idempotent combat resolution verified!")
	
	# Clean up test nodes
	player_pleasure.queue_free()
	npc_pleasure.queue_free()
	combat_mgr.queue_free()
	d_mgr.queue_free()
	
	print("=== ALL REFACTORED UNIT TESTS PASSED 100%! ===")
	quit(0)
