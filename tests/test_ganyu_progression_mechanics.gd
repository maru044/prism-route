extends SceneTree

const RuntimeClass := preload("res://scripts/world/npc_encounter_runtime.gd")
const GameProgressClass := preload("res://scripts/progress/game_progress.gd")
const DialogueManagerClass := preload("res://scripts/narrative/dialogue_manager.gd")
const TurnCombatManagerClass := preload("res://scripts/combat/turn_combat_manager.gd")

func _init() -> void:
	call_deferred("_run_tests")

func _expect(cond: bool, msg: String) -> bool:
	if not cond:
		push_error("[FAILED] " + msg)
		print("FAILED: " + msg)
		quit(1)
		return false
	return true

func _run_tests() -> void:
	print("--- Running test_ganyu_progression_mechanics ---")
	
	var runtime := RuntimeClass.new()
	root.add_child(runtime)
	var progress := GameProgressClass.new()
	
	var ok := runtime.setup_encounter("sandbar_ganyu", false)
	if not _expect(ok, "Failed to setup sandbar_ganyu encounter"):
		return
	
	runtime.game_progress = progress
	runtime.combat_manager.animation_delays = false
	if not _expect(runtime.character_id == "ganyu", "Runtime should identify character_id as ganyu"):
		return
	if not _expect(runtime.character_name == "甘雨", "Runtime should identify character_name as 甘雨"):
		return
		
	# ----------------------------------------------------
	# Test 1: Stage 1 (Locked / First Encounter)
	# ----------------------------------------------------
	print("[Test 1] Testing First Encounter (Locked)")
	progress.companion_unlocks.clear()
	runtime.settlement_outcome = ""
	runtime._set_state(RuntimeClass.EncounterState.AVAILABLE)
	
	runtime.start_intro_dialogue()
	if not _expect(runtime.dialogue_manager.session_active, "Dialogue session should be active"):
		return
	var node_id: String = runtime.dialogue_manager.current_session.current_node_id
	if not _expect(node_id == "start", "First encounter should start at 'start', got: " + node_id):
		return
	runtime.dialogue_manager.cancel_session()
	runtime._set_state(RuntimeClass.EncounterState.AVAILABLE)
	
	# Start combat in locked state
	runtime.start_combat()
	if not _expect(runtime.current_state == RuntimeClass.EncounterState.COMBAT, "Runtime should be in COMBAT"):
		return
	if not _expect(is_equal_approx(runtime.npc_pleasure.damage_taken_multiplier, 1.0), "Locked Ganyu NPC pleasure mult should be 1.0"):
		return
	if not _expect(is_equal_approx(runtime.player_pleasure.damage_taken_multiplier, 1.0), "Locked Player pleasure mult should be 1.0"):
		return
		
	# Test in-battle negotiation routing when locked
	runtime.combat_manager.request_in_battle_negotiation()
	var mid_node: String = runtime.dialogue_manager.current_session.current_node_id
	if not _expect(mid_node == "mid_battle_manual", "Locked in-battle negotiation should route to 'mid_battle_manual', got: " + mid_node):
		return
	runtime.dialogue_manager.cancel_session()
	runtime._set_state(RuntimeClass.EncounterState.AVAILABLE)
	print("  ✓ First encounter state and combat multipliers verified successfully")
	
	# ----------------------------------------------------
	# Test 2: Stage 2 (Unlocked / Tamed Companion)
	# ----------------------------------------------------
	print("[Test 2] Testing Tamed Companion Encounter (Unlocked)")
	progress.unlock_companion("ganyu")
	runtime.settlement_outcome = ""
	runtime._set_state(RuntimeClass.EncounterState.AVAILABLE)
	
	runtime.start_intro_dialogue()
	if not _expect(runtime.dialogue_manager.session_active, "Dialogue session should be active"):
		return
	var unlocked_node: String = runtime.dialogue_manager.current_session.current_node_id
	if not _expect(unlocked_node == "start_unlocked", "Unlocked encounter should start at 'start_unlocked', got: " + unlocked_node):
		return
	runtime.dialogue_manager.cancel_session()
	runtime._set_state(RuntimeClass.EncounterState.AVAILABLE)
	
	# Start combat in unlocked state
	var first_input: Array[Vector2] = []
	runtime.combat_manager.phase_changed.connect(func(phase: int) -> void:
		if phase == TurnCombatManagerClass.Phase.PLAYER_INPUT:
			first_input.append(Vector2(runtime.npc_pleasure.damage_taken_multiplier,
				runtime.player_pleasure.damage_taken_multiplier)))
	runtime.start_combat()
	if not _expect(runtime.current_state == RuntimeClass.EncounterState.COMBAT, "Runtime should be in COMBAT"):
		return
	if not _expect(is_equal_approx(runtime.npc_pleasure.damage_taken_multiplier, 1.8), "Unlocked Ganyu NPC pleasure mult should be 1.8 (sensitive)"):
		return
	if not _expect(is_equal_approx(runtime.player_pleasure.damage_taken_multiplier, 0.7), "Unlocked Player pleasure mult should be 0.7 (softened damage)"):
		return
	if not _expect(first_input[0].is_equal_approx(Vector2(1.8, 0.7)), "Rematch base must be set before the first input phase"):
		return
		
	# Test in-battle negotiation routing when unlocked
	runtime.combat_manager.request_in_battle_negotiation()
	var unlocked_mid_node: String = runtime.dialogue_manager.current_session.current_node_id
	if not _expect(unlocked_mid_node == "mid_battle_manual_unlocked", "Unlocked in-battle negotiation should route to 'mid_battle_manual_unlocked', got: " + unlocked_mid_node):
		return
	if not _expect(_surrender_choice(runtime) < 0, "Round 1 at zero meter must not offer surrender"):
		return
	runtime.dialogue_manager.choose_option(0)
	runtime.dialogue_manager.cancel_session()
	if not _expect(is_equal_approx(runtime.npc_pleasure.damage_taken_multiplier, 1.8)
			and runtime.combat_manager.current_phase == TurnCombatManagerClass.Phase.PLAYER_INPUT,
			"Cancelled negotiation must resume without applying the pending effect"):
		return
	runtime.combat_manager.request_in_battle_negotiation()
	print("  ✓ Unlocked tamed companion dialogue and weakened combat multipliers verified")
	
	# ----------------------------------------------------
	# Test 3: In-Battle Cheats & Negotiation Effects
	# ----------------------------------------------------
	print("[Test 3] Testing In-Battle Cheats Application")
	
	# Choice 1: Distracted (set_blackboard distracted)
	runtime.dialogue_manager.choose_option(0)
	var confirm_node: String = runtime.dialogue_manager.current_session.current_node_id
	if not _expect(confirm_node == "mid_battle_confirm_distracted", "Option 1 should target 'mid_battle_confirm_distracted'"):
		return
	runtime.dialogue_manager.advance_text()
	runtime.dialogue_manager.choose_option(0)
	if not _expect(is_equal_approx(runtime.combat_manager.npc_pleasure.damage_taken_multiplier, 2.5), "Distracted cheat should set NPC pleasure multiplier to 2.5"):
		return
	print("  ✓ Distracted cheat correctly applied 2.5x pleasure multiplier")
	_endure(runtime)
	if not _expect(runtime.combat_manager.round_count == 2
			and is_equal_approx(runtime.npc_pleasure.damage_taken_multiplier, 1.8),
			"Distracted must expire after one round and restore the rematch base"):
		return
		
	# Choice 2: Lock Master Pleasure
	runtime.combat_manager.request_in_battle_negotiation()
	runtime.dialogue_manager.choose_option(1)
	runtime.dialogue_manager.advance_text()
	runtime.dialogue_manager.choose_option(0)
	if not _expect(runtime.combat_manager.player_pleasure.pleasure_locked, "Lock cheat should lock player pleasure"):
		return
	if not _expect(is_equal_approx(runtime.combat_manager.player_pleasure.pleasure_cap, 90.0), "Lock cheat should cap pleasure at 90.0"):
		return
	print("  ✓ Lock master pleasure cheat correctly locked player cap at 90%")
	_endure(runtime)
	if not _expect(runtime.combat_manager.round_count == 3 and not runtime.player_pleasure.pleasure_locked
			and is_equal_approx(runtime.player_pleasure.pleasure_cap, 100.0),
			"Protection must expire at the next round"):
		return
		
	# Surrender Gate at Round 3
	runtime.combat_manager.request_in_battle_negotiation()
	if not _expect(_surrender_choice(runtime) >= 0, "Round 3 must offer surrender with a low meter"):
		return
	runtime.dialogue_manager.choose_option(_surrender_choice(runtime))
	runtime.dialogue_manager.advance_text()
	runtime.dialogue_manager.choose_option(0)
	if not _expect(runtime.combat_manager.is_resolved and runtime.last_battle_winner == "player" and runtime.current_state == RuntimeClass.EncounterState.RESULT_DIALOGUE, "Instant surrender cheat should resolve combat with player victory"):
		return
	print("  ✓ Instant surrender cheat correctly resolved combat with player victory")
	runtime.dialogue_manager.cancel_session()
	
	# Meter Gate test at Round 1
	runtime.start_combat()
	runtime.npc_pleasure.add_pleasure(59.0 / 1.8)
	runtime.combat_manager.request_in_battle_negotiation()
	if not _expect(_surrender_choice(runtime) < 0, "Round 1 just below 60 percent must hide surrender"):
		return
	runtime.dialogue_manager.cancel_session()
	runtime.npc_pleasure.add_pleasure(2.0 / 1.8)
	runtime.combat_manager.request_in_battle_negotiation()
	if not _expect(_surrender_choice(runtime) >= 0, "Round 1 above 60 percent must offer surrender"):
		return
	runtime.dialogue_manager.cancel_session()
	print("  ✓ Surrender threshold gates verified successfully")
	
	# ----------------------------------------------------
	# Test 4: Post-Settlement Greetings
	# ----------------------------------------------------
	print("[Test 4] Testing Post-Settlement Greetings")
	# Post seat service
	runtime.settlement_outcome = "spare_seat"
	runtime._set_state(RuntimeClass.EncounterState.COMPLETED)
	runtime.start_intro_dialogue()
	var spare_node: String = runtime.dialogue_manager.current_session.current_node_id
	if not _expect(spare_node == "post_spare_greeting", "Post spare should start at 'post_spare_greeting', got: " + spare_node):
		return
	runtime.dialogue_manager.cancel_session()
	
	# Post kill respawn
	runtime.settlement_outcome = "kill"
	runtime._set_state(RuntimeClass.EncounterState.COMPLETED)
	runtime.start_intro_dialogue()
	var kill_node: String = runtime.dialogue_manager.current_session.current_node_id
	if not _expect(kill_node == "post_kill_greeting", "Post kill should start at 'post_kill_greeting', got: " + kill_node):
		return
	runtime.dialogue_manager.cancel_session()
	print("  ✓ Post-settlement greeting routes verified")
	
	print("\nALL GANYU PROGRESSION TESTS PASSED!")
	runtime.queue_free()
	await process_frame
	quit(0)

func _surrender_choice(runtime: RuntimeClass) -> int:
	var dm := runtime.dialogue_manager
	var choices: Array = dm.current_graph["nodes"][dm.current_node_id]["choices"]
	return choices.find_custom(func(choice: Dictionary) -> bool:
		return choice.get("set_blackboard", {}).get("meta_cheat_mode") == "instant_surrender")

func _endure(runtime: RuntimeClass) -> void:
	runtime.combat_manager.execute_player_action({
		"action_name": "忍耐",
		"base_pleasure": 0.0,
		"target_zone": "",
		"self_pleasure_defense": 0.5,
	})
