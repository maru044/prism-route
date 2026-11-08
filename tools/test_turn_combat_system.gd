extends SceneTree
## Automated headless verification test for the updated Turn-Based Sensual Combat without endurance and with mid-battle negotiation.

const PleasureComponent := preload("res://scripts/combat/pleasure_component.gd")
const TurnActionResource := preload("res://scripts/combat/turn_action_resource.gd")
const TurnCombatManager := preload("res://scripts/combat/turn_combat_manager.gd")
const DialogueManager := preload("res://scripts/narrative/dialogue_manager.gd")
const SparkleTutorialDialogue := preload("res://scripts/narrative/sparkle_tutorial_dialogue.gd")

func _init() -> void:
	call_deferred("_run_full_test")

func _run_full_test() -> void:
	print("--- STARTING UPDATED TURN COMBAT & NARRATIVE TEST ---")
	
	# 1. PleasureComponent Tests (No Endurance)
	print("[Step 1] Verifying PleasureComponent without endurance")
	var p_comp = PleasureComponent.new()
	p_comp.character_name = "TestPlayer"
	root.add_child(p_comp)
	
	assert(p_comp.current_pleasure == 0.0, "Initial pleasure should be 0")
	var gained: float = p_comp.add_pleasure(15.0, "mouth")
	assert(gained == 15.0, "Mouth zone default sensitivity should be 1.0")
	
	p_comp.pleasure_locked = true
	p_comp.pleasure_cap = 90.0
	p_comp.add_pleasure(100.0)
	assert(p_comp.current_pleasure == 90.0, "Pleasure cap should clamp at 90.0")
	assert(not p_comp.has_reached_climax, "Capped pleasure should not climax")
	
	p_comp.queue_free()
	print("[Step 1 PASSED] PleasureComponent verified.")
	
	# 2. DialogueManager Tests
	print("[Step 2] Verifying DialogueManager and Graph")
	var d_mgr = DialogueManager.new()
	root.add_child(d_mgr)
	
	var graph: Dictionary = SparkleTutorialDialogue.get_dialogue_graph()
	var text_box := [""]
	var choices_box := [[]]
	
	d_mgr.text_updated.connect(func(speaker: String, text: String, emotion: String):
		text_box[0] = text
	)
	d_mgr.choices_presented.connect(func(choices: Array):
		choices_box[0] = choices
	)
	
	d_mgr.start_dialogue(graph, "start")
	assert("欢迎来到我们的游�? in text_box[0], "Start text mismatch")
	
	d_mgr.queue_free()
	print("[Step 2 PASSED] DialogueManager verified.")
	
	# 3. TurnCombatManager: Mid-battle dialogue resumption test
	print("[Step 3] Verifying in-battle negotiation resumption")
	var player_pleasure = PleasureComponent.new()
	root.add_child(player_pleasure)
	var npc_pleasure = PleasureComponent.new()
	root.add_child(npc_pleasure)
	
	var combat_mgr = TurnCombatManager.new()
	root.add_child(combat_mgr)
	combat_mgr.setup(player_pleasure, npc_pleasure)
	
	combat_mgr.start_combat(false, {})
	assert(combat_mgr.current_phase == TurnCombatManager.Phase.PLAYER_INPUT, "Should start in player input phase")
	
	# Trigger in-battle negotiation
	combat_mgr.request_in_battle_negotiation()
	assert(combat_mgr.current_phase == TurnCombatManager.Phase.MID_BATTLE_DIALOGUE, "Phase should be mid-battle dialogue")
	
	# Resume combat without exiting
	combat_mgr.resume_combat_after_dialogue(false)
	assert(combat_mgr.current_phase == TurnCombatManager.Phase.PLAYER_INPUT, "Combat should resume to player input without exiting")
	print("In-battle negotiation resumption verified: combat remains active!")
	
	# 4. Teaching kill & Surrender test
	print("[Step 4] Verifying Teaching Kill and Surrender")
	var combat_record := {"winner": "", "ended": false}
	combat_mgr.combat_ended.connect(func(winner: String, loser: String, reason: String):
		combat_record["winner"] = winner
		combat_record["ended"] = true
	)
	
	combat_mgr.start_combat(true, {})
	var endure_action = load("res://assets/combat/actions/action_endure.tres")
	combat_mgr.execute_player_action(endure_action)
	
	for i in range(120):
		await process_frame
		if combat_record["ended"]:
			break
			
	assert(combat_record["winner"] == "Sparkle", "Teaching kill should defeat master")
	assert(player_pleasure.has_reached_climax, "Master should climax in teaching kill")
	print("Teaching kill confirmed.")
	
	# Surrender cheat
	combat_record["ended"] = false
	combat_record["winner"] = ""
	combat_mgr.start_combat(false, {"meta_cheat_mode": "instant_surrender"})
	for i in range(60):
		await process_frame
		if combat_record["ended"]:
			break
	assert(combat_record["winner"] == "Master", "Surrender should defeat Sparkle")
	print("Instant surrender confirmed.")
	
	player_pleasure.queue_free()
	npc_pleasure.queue_free()
	combat_mgr.queue_free()
	
	print("--- ALL UPDATED TURN COMBAT TESTS PASSED! ---")
	quit(0)
