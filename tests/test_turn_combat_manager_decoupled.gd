@tool
extends SceneTree
## Phase 3 Verification: TurnCombatManager decoupled with Strategy & ReactionResolver.
## Verifies that TurnCombatManager can seamlessly run with Sparkle AND a second character (Keqing).

const TurnCombatManagerClass := preload("res://scripts/combat/turn_combat_manager.gd")
const PleasureComponentClass := preload("res://scripts/combat/pleasure_component.gd")
const CombatStrategyClass := preload("res://scripts/combat/combat_strategy.gd")
const SparkleTutorialStrategyClass := preload("res://scripts/combat/sparkle_tutorial_strategy.gd")

func _init() -> void:
	_run_test.call_deferred()

func _run_test() -> void:
	print("==================================================")
	print("[Phase 3] Testing Decoupled TurnCombatManager...")
	
	var root := Node.new()
	get_root().add_child(root)
	var combat_mgr := TurnCombatManagerClass.new()
	var player_pleasure := PleasureComponentClass.new()
	var npc_pleasure := PleasureComponentClass.new()
	
	root.add_child(combat_mgr)
	root.add_child(player_pleasure)
	root.add_child(npc_pleasure)
	
	# Test 1: Sparkle Tutorial Combat Flow
	print("\n--- Test 1: Sparkle Tutorial Combat Flow ---")
	combat_mgr.setup(player_pleasure, npc_pleasure)
	var sparkle_strategy := SparkleTutorialStrategyClass.new(true)
	var sparkle_reactions_path := "res://assets/npc/reactions/sparkle_temple.json"
	var sparkle_reactions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sparkle_reactions_path))
	combat_mgr.configure_npc("花火", sparkle_reactions, sparkle_strategy)
	assert(combat_mgr.npc_name == "花火")
	
	var last_log := ""
	var last_koujou := {}
	combat_mgr.log_message_emitted.connect(func(msg):
		last_log = msg
	)
	combat_mgr.koujou_triggered.connect(func(sp, tx, badge):
		last_koujou["speaker"] = sp
		last_koujou["text"] = tx
	)
	
	combat_mgr.start_combat(true)
	assert(combat_mgr.current_phase == combat_mgr.Phase.PLAYER_INPUT)
	assert(combat_mgr.round_count == 1)
	print("  ✓ Sparkle combat started cleanly")
	
	# Player action: Stimulate mouth
	var mock_player_act := {
		"action_name": "轻触唇瓣",
		"base_pleasure": 15.0,
		"target_zone": "mouth",
		"self_pleasure_defense": 0.0
	}
	
	# In headless mode without awaiting real wallclock timers, we can test state transitions
	print("  Executing player action...")
	combat_mgr.execute_player_action(mock_player_act)
	assert(npc_pleasure.current_pleasure > 0.0)
	assert(last_koujou.get("speaker") == "花火")
	print("  ✓ Player action triggered Sparkle reaction: '%s'" % last_koujou.get("text"))
	
	# Test 2: Decoupled Second Character (Keqing) Flow
	print("\n--- Test 2: Decoupled Second Character (Keqing) Flow ---")
	var keqing_reactions := {
		"speaker": "刻晴",
		"zones": {
			"mouth": {
				"low": {"text": "唔……别小看我！", "emotion": "blush"},
				"mid": {"text": "哈啊……指尖好烫……", "emotion": "shy"},
				"high": {"text": "停下……快停下……！", "emotion": "climax"}
			}
		},
		"attack_lines": {
			"tongue": {"text": "本小姐才不会输给你！看招！", "emotion": "serious"}
		}
	}
	var keqing_strategy := CombatStrategyClass.new()
	combat_mgr.configure_npc("刻晴", keqing_reactions, keqing_strategy)
	combat_mgr.start_combat(false)
	
	assert(combat_mgr.npc_name == "刻晴")
	assert(combat_mgr.is_tutorial_round == false)
	
	combat_mgr.execute_player_action(mock_player_act)
	assert(last_koujou.get("speaker") == "刻晴")
	assert(last_koujou.get("text") == "唔……别小看我！")
	print("  ✓ Keqing custom reactions triggered cleanly without modifying manager!")
	
	print("\n[Phase 3 SUCCESS] Decoupled TurnCombatManager fully validated!")
	print("==================================================")
	quit(0)
