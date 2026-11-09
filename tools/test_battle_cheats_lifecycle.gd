extends SceneTree
## Automated test suite for Battle Cheat Lifecycle and State Isolation.
## Verifies that temporary cheat options are consumed and do not leak across battles.

const PleasureComponent := preload("res://scripts/combat/pleasure_component.gd")
const TurnCombatManager := preload("res://scripts/combat/turn_combat_manager.gd")
const DialogueManager := preload("res://scripts/narrative/dialogue_manager.gd")
const SparkleTutorialDialogue := preload("res://scripts/narrative/sparkle_tutorial_dialogue.gd")

func _init() -> void:
	call_deferred("_run_cheat_lifecycle_tests")

func _run_cheat_lifecycle_tests() -> void:
	print("=== STARTING BATTLE CHEAT LIFECYCLE AND ISOLATION TESTS ===")

	var player_pleasure = PleasureComponent.new()
	player_pleasure.character_name = "Master"
	root.add_child(player_pleasure)

	var npc_pleasure = PleasureComponent.new()
	npc_pleasure.character_name = "Sparkle"
	root.add_child(npc_pleasure)

	var combat_mgr = TurnCombatManager.new()
	root.add_child(combat_mgr)
	combat_mgr.setup(player_pleasure, npc_pleasure)

	var dialogue_mgr = DialogueManager.new()
	root.add_child(dialogue_mgr)

	var graph: Dictionary = SparkleTutorialDialogue.get_dialogue_graph()

	# -------------------------------------------------------------
	# Test 1: Pre-battle Cheat Option Consumption and Isolation
	# -------------------------------------------------------------
	print("[Test 1] Testing Pre-battle Cheat Option Consumption and Isolation:")
	dialogue_mgr.start_dialogue(
		graph,
		"respawn_dialogue",
		DialogueManager.DialogueSource.WORLD_INTERACTION,
		DialogueManager.ResumePolicy.RETURN_TO_WORLD
	)
	# Advance text to respawn_choices
	dialogue_mgr.advance_text()
	# Choose option 1: 【识趣放水】(distracted)
	dialogue_mgr.choose_option(1)
	assert(dialogue_mgr.blackboard.get("meta_cheat_mode") == "distracted", "Blackboard must stage distracted cheat")
	assert(dialogue_mgr.blackboard.get("meta_cheat_enabled") == true, "meta_cheat_enabled must be true")

	# Advance text through confirm to enter combat choice
	dialogue_mgr.advance_text()
	dialogue_mgr.choose_option(0) # Action: enter_combat

	# Simulate staging: consume cheats from dialogue_mgr
	var staging_cheats: Dictionary = dialogue_mgr.consume_battle_cheats()
	assert(staging_cheats.get("meta_cheat_mode") == "distracted", "Consumed cheats must contain distracted")
	assert(dialogue_mgr.blackboard.get("meta_cheat_mode") == "none", "Blackboard must be reset to none immediately after consumption")
	assert(dialogue_mgr.blackboard.get("meta_cheat_enabled") == false, "meta_cheat_enabled must be reset to false")

	# Start Battle 1 with consumed cheat
	combat_mgr.start_combat(false, {"meta_cheat_mode": staging_cheats.get("meta_cheat_mode")})
	assert(npc_pleasure.damage_taken_multiplier == 2.5, "Battle 1 NPC pleasure multiplier must be 2.5")

	# Simulate Battle 1 ends (Master defeats Sparkle)
	npc_pleasure.add_pleasure(100.0)
	combat_mgr._check_battle_state()
	assert(combat_mgr.is_resolved == true, "Battle 1 must be resolved")

	# Simulate _on_combat_ended clean-up
	dialogue_mgr.reset_battle_cheats()
	player_pleasure.reset()
	npc_pleasure.reset()

	# Now simulate entering Battle 2 (e.g. from post_spare_choices 【再次对决】)
	# There was no cheat chosen for Battle 2.
	var battle2_cheats: Dictionary = dialogue_mgr.consume_battle_cheats()
	assert(battle2_cheats.get("meta_cheat_mode") == "none", "Battle 2 must have no cheat mode staged")
	combat_mgr.start_combat(false, {"meta_cheat_mode": battle2_cheats.get("meta_cheat_mode")})

	assert(npc_pleasure.damage_taken_multiplier == 1.0, "Battle 2 NPC pleasure multiplier must be normal 1.0")
	assert(player_pleasure.pleasure_locked == false, "Battle 2 Player pleasure must not be locked")
	print("[Test 1 PASSED] Pre-battle cheat consumed immediately and Battle 2 clean!")

	# -------------------------------------------------------------
	# Test 2: Mid-battle Negotiation Cheat Consumption and Clean-up
	# -------------------------------------------------------------
	print("[Test 2] Testing Mid-battle Negotiation Cheat Consumption:")
	# Start Battle with normal rules
	combat_mgr.start_combat(false, {"meta_cheat_mode": "none"})
	assert(player_pleasure.pleasure_locked == false, "Player must not be locked initially")

	# Master requests mid-battle negotiation
	combat_mgr.request_in_battle_negotiation()
	assert(combat_mgr.current_phase == TurnCombatManager.Phase.MID_BATTLE_DIALOGUE, "Phase must be MID_BATTLE_DIALOGUE")

	# Dialogue launches mid_battle_manual
	dialogue_mgr.start_dialogue(
		graph,
		"mid_battle_manual",
		DialogueManager.DialogueSource.MID_BATTLE_MANUAL,
		DialogueManager.ResumePolicy.SAME_TURN
	)
	dialogue_mgr.advance_text()
	# Choose option 1: 【识趣保护】(lock_master_pleasure)
	dialogue_mgr.choose_option(1)
	assert(dialogue_mgr.blackboard.get("meta_cheat_mode") == "lock_master_pleasure", "Blackboard must stage lock cheat")

	# Advance to back_to_fight and choose resume
	dialogue_mgr.advance_text()
	dialogue_mgr.choose_option(0) # Action: resume_combat

	# Controller consumes battle cheat on dialogue ended
	var mid_cheats: Dictionary = dialogue_mgr.consume_battle_cheats()
	assert(mid_cheats.get("meta_cheat_mode") == "lock_master_pleasure", "Consumed cheat must be lock_master_pleasure")
	assert(dialogue_mgr.blackboard.get("meta_cheat_mode") == "none", "Blackboard must be reset immediately")

	# Apply mid-battle effect
	if mid_cheats.get("meta_cheat_mode") == "lock_master_pleasure":
		player_pleasure.pleasure_locked = true
		player_pleasure.pleasure_cap = 90.0
	combat_mgr.resume_combat_after_dialogue(false, false)

	# Verify pleasure lock is active in current battle
	player_pleasure.add_pleasure(150.0)
	assert(player_pleasure.current_pleasure == 90.0, "Player pleasure must be clamped at 90.0")
	assert(player_pleasure.has_reached_climax == false, "Player must not climax due to lock")

	# End combat
	dialogue_mgr.reset_battle_cheats()
	player_pleasure.reset()
	npc_pleasure.reset()

	# Start Battle 3 to ensure lock does not persist
	var battle3_cheats: Dictionary = dialogue_mgr.consume_battle_cheats()
	combat_mgr.start_combat(false, {"meta_cheat_mode": battle3_cheats.get("meta_cheat_mode")})
	assert(player_pleasure.pleasure_locked == false, "Battle 3 Player pleasure must not be locked")
	assert(player_pleasure.pleasure_cap == 100.0, "Battle 3 Player cap must be 100.0")

	player_pleasure.add_pleasure(100.0)
	assert(player_pleasure.current_pleasure == 100.0, "Battle 3 Player must be able to reach 100.0")
	assert(player_pleasure.has_reached_climax == true, "Battle 3 Player must reach climax normally")
	print("[Test 2 PASSED] Mid-battle lock consumed and cleared cleanly!")

	# -------------------------------------------------------------
	# Test 3: Edging Endure Modifier Consumption
	# -------------------------------------------------------------
	print("[Test 3] Testing Edging Endure Modifier Consumption:")
	dialogue_mgr.start_dialogue(
		graph,
		"mid_battle_edging",
		DialogueManager.DialogueSource.MID_BATTLE_EDGING,
		DialogueManager.ResumePolicy.NEXT_TURN
	)
	dialogue_mgr.advance_text()
	# Choose option 0: 【咬牙坚持】(edging_endure = true)
	dialogue_mgr.choose_option(0)
	assert(dialogue_mgr.blackboard.get("edging_endure") == true, "Blackboard must have edging_endure true")

	var endure_cheats: Dictionary = dialogue_mgr.consume_battle_cheats()
	assert(endure_cheats.get("edging_endure") == true, "Consumed cheats must have edging_endure true")
	assert(dialogue_mgr.blackboard.get("edging_endure") == false, "Blackboard edging_endure must be reset to false")
	print("[Test 3 PASSED] Edging endure modifier consumed and isolated!")

	# Clean up test nodes
	player_pleasure.queue_free()
	npc_pleasure.queue_free()
	combat_mgr.queue_free()
	dialogue_mgr.queue_free()

	print("=== ALL BATTLE CHEAT LIFECYCLE TESTS PASSED 100%! ===")
	quit(0)
