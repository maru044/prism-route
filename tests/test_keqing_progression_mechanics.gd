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
	print("--- Running test_keqing_progression_mechanics ---")
	
	var runtime := RuntimeClass.new()
	var progress := GameProgressClass.new()
	
	var ok := runtime.setup_encounter("sandbar_keqing", false)
	if not _expect(ok, "Failed to setup sandbar_keqing encounter"):
		return
	
	runtime.game_progress = progress
	if not _expect(runtime.character_id == "keqing", "Runtime should identify character_id as keqing"):
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
	if not _expect(is_equal_approx(runtime.npc_pleasure.damage_taken_multiplier, 1.0), "Locked Keqing NPC pleasure mult should be 1.0"):
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
	# Test 2: Stage 2 (Unlocked / Tamed Playmate)
	# ----------------------------------------------------
	print("[Test 2] Testing Tamed Playmate Encounter (Unlocked)")
	progress.unlock_companion("keqing")
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
	runtime.start_combat()
	if not _expect(runtime.current_state == RuntimeClass.EncounterState.COMBAT, "Runtime should be in COMBAT"):
		return
	if not _expect(is_equal_approx(runtime.npc_pleasure.damage_taken_multiplier, 1.8), "Unlocked Keqing NPC pleasure mult should be 1.8 (sensitve)"):
		return
	if not _expect(is_equal_approx(runtime.player_pleasure.damage_taken_multiplier, 0.7), "Unlocked Player pleasure mult should be 0.7 (softened damage)"):
		return
		
	# Test in-battle negotiation routing when unlocked
	runtime.combat_manager.request_in_battle_negotiation()
	var unlocked_mid_node: String = runtime.dialogue_manager.current_session.current_node_id
	if not _expect(unlocked_mid_node == "mid_battle_manual_unlocked", "Unlocked in-battle negotiation should route to 'mid_battle_manual_unlocked', got: " + unlocked_mid_node):
		return
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
	# Now at mid_battle_resume, choose resume
	runtime.dialogue_manager.choose_option(0)
	if not _expect(is_equal_approx(runtime.combat_manager.npc_pleasure.damage_taken_multiplier, 2.5), "Distracted cheat should increase NPC pleasure multiplier to 2.5, got: " + str(runtime.combat_manager.npc_pleasure.damage_taken_multiplier)):
		return
	print("  ✓ Distracted cheat correctly applied 2.5x pleasure multiplier")
	
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
	
	# Choice 3: Instant Surrender
	runtime.combat_manager.request_in_battle_negotiation()
	runtime.dialogue_manager.choose_option(2)
	runtime.dialogue_manager.advance_text()
	runtime.dialogue_manager.choose_option(0)
	if not _expect(runtime.combat_manager.is_resolved and runtime.last_battle_winner == "player" and runtime.current_state == RuntimeClass.EncounterState.RESULT_DIALOGUE, "Instant surrender cheat should resolve combat with player victory"):
		return
	print("  ✓ Instant surrender cheat correctly resolved combat with player victory")
	runtime.dialogue_manager.cancel_session()
	
	# ----------------------------------------------------
	# Test 4: Post-Settlement Greetings
	# ----------------------------------------------------
	print("[Test 4] Testing Post-Settlement Greetings")
	# Post desk service
	runtime.settlement_outcome = "spare_desk"
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
	
	print("\n--- ALL KEQING PROGRESSION TESTS PASSED ---")
	runtime.queue_free()
	quit(0)
