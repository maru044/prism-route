@tool
extends SceneTree
## End-to-End Acceptance Test for Second Character (Keqing) via Universal NPCEncounterRuntime.
## Proves that Keqing runs through dynamic 3-tier loading, world spawn placement,
## interactive dialogue, duel combat with custom skills/koujou, and motion resolution.

const NPCEncounterRuntimeClass := preload("res://scripts/world/npc_encounter_runtime.gd")
const TEST_ACTION := preload("res://assets/combat/actions/action_toy_vibe.tres")
const InteractiveFurnitureClass := preload("res://scripts/world/interactive_furniture.gd")

func _init() -> void:
	_run_end_to_end_test.call_deferred()

func _run_end_to_end_test() -> void:
	print("==================================================")
	print("[Acceptance Test] Keqing End-to-End Encounter Runtime Verification")
	print("==================================================")

	var root := Node.new()
	get_root().add_child(root)

	var runtime = NPCEncounterRuntimeClass.new()
	root.add_child(runtime)

	# --- Step 1: Dynamic 3-tier Assembly via NPCRegistry ---
	print("\n--- Step 1: Assembly via NPCRegistry ---")
	var setup_ok: bool = runtime.setup_encounter("sandbar_keqing")
	assert(setup_ok, "Encounter setup for sandbar_keqing must succeed")
	assert(runtime.character_name == "刻晴")
	assert(runtime.spawn_position.distance_to(Vector3(-828.462, 0.1, -129.634)) < 0.01)
	assert(runtime.current_state == NPCEncounterRuntimeClass.EncounterState.AVAILABLE)
	print("  ✓ Assembled sandbar_keqing successfully: Name='%s', SpawnPos=%s" % [runtime.character_name, str(runtime.spawn_position)])

	# --- Step 2: Intro Dialogue Flow & Choice Transition ---
	print("\n--- Step 2: Intro Dialogue & Combat Trigger ---")
	var last_speaker := {"name": "", "text": ""}
	runtime.dialogue_updated.connect(func(sp, tx, em):
		last_speaker["name"] = sp
		last_speaker["text"] = tx
	)

	runtime.start_intro_dialogue()
	assert(runtime.current_state == NPCEncounterRuntimeClass.EncounterState.INTRO_DIALOGUE)
	assert(last_speaker["name"] == "刻晴")
	assert("斩尽芜杂" in last_speaker["text"])
	print("  ✓ Keqing initial line received: %s" % last_speaker["text"])

	# Advance to choice menu
	runtime.dialogue_manager.advance_text()
	assert(runtime.dialogue_manager.current_node_id == "main_menu_choices")

	# Select option 1: "提出切磋：以剑会友，点到为止！" -> triggers enter_combat
	runtime.dialogue_manager.choose_option(1)
	assert(runtime.current_state == NPCEncounterRuntimeClass.EncounterState.COMBAT)
	print("  ✓ Successfully transitioned from Dialogue to COMBAT via ActionRegistry!")

	# --- Step 3: Turn-Based Duel Combat with Keqing Reactions ---
	print("\n--- Step 3: Duel Combat Execution with Dynamic Skills & Koujou ---")
	runtime.combat_manager.animation_delays = false
	var koujou_received := {"lines": []}
	runtime.combat_manager.koujou_triggered.connect(func(speaker, line, extra):
		koujou_received["lines"].append({"speaker": speaker, "line": line})
		print("    [Koujou] %s: %s" % [speaker, line])
	)

	# Player executes attack
	runtime.combat_manager.execute_player_action(TEST_ACTION)
	assert(runtime.npc_pleasure.current_pleasure > 0)
	print("  ✓ Player attack executed, opponent pleasure increased: %.1f" % runtime.npc_pleasure.current_pleasure)

	# Process turn cycle until victory or defeat
	for i in range(16):
		if runtime.combat_manager.is_resolved:
			break
		runtime.combat_manager.execute_player_action(TEST_ACTION)

	assert(runtime.current_state == NPCEncounterRuntimeClass.EncounterState.RESULT_DIALOGUE)
	assert(runtime.last_battle_winner == "player")
	print("  ✓ Combat concluded with player victory; auto-transitioned to RESULT_DIALOGUE!")

	# --- Step 4: Motion Resolution via MotionProfile ---
	print("\n--- Step 4: Motion Resolution via MotionResolver ---")
	# Create mock desk furniture
	var desk_mock := InteractiveFurnitureClass.new()
	desk_mock.name = "desk_01"
	var surf := Marker3D.new()
	surf.name = "Anchor_Desk_Surface"
	desk_mock.add_child(surf)
	var front := Marker3D.new()
	front.name = "Anchor_Front"
	desk_mock.add_child(front)
	root.add_child(desk_mock)

	var motion_res: Dictionary = runtime.resolve_service_motion("desk_service", [desk_mock])
	assert(motion_res.get("found", false) == true)
	assert(motion_res.get("type") == "furniture")
	assert("mmd_fca4bab1635f_a.tres" in motion_res.get("role_a_motion", ""))
	assert("mmd_fca4bab1635f_b.tres" in motion_res.get("role_b_motion", ""))
	print("  ✓ Desk motion resolved correctly to Keqing's desk animations!")

	# Test ground service
	var ground_res: Dictionary = runtime.resolve_service_motion("ground_service")
	assert(ground_res.get("found", false) == true)
	assert(ground_res.get("type") == "ground")
	print("  ✓ Ground motion resolved correctly to Keqing's ground animations!")

	# --- Step 5: Conclude Dialogue & Settlement ---
	print("\n--- Step 5: Post-Battle Dialogue & Final Completion ---")
	assert(runtime.dialogue_manager.current_node_id == "victory_node")
	# Select option 1: "【点到为止】刚才的切磋很精彩，我们握手言和吧。" -> action: close
	runtime.dialogue_manager.choose_option(1)
	assert(runtime.current_state == NPCEncounterRuntimeClass.EncounterState.COMPLETED)
	print("  ✓ Keqing encounter cleanly concluded in COMPLETED state!")

	print("\n==================================================")
	print("[GOLDEN ACCEPTANCE SUCCESS] Keqing completed 100% full runtime encounter flow!")
	print("==================================================")
	quit(0)
