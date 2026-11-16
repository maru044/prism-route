@tool
extends SceneTree
## Phase 5 Verification: Golden Acceptance Test for Second Character (Keqing).
## Proves that without modifying a single line of DialogueManager or TurnCombatManager,
## Keqing completes her complete dialogue, combat duel, and furniture/ground motion resolution flow!

const DialogueManagerClass := preload("res://scripts/narrative/dialogue_manager.gd")
const TurnCombatManagerClass := preload("res://scripts/combat/turn_combat_manager.gd")
const PleasureComponentClass := preload("res://scripts/combat/pleasure_component.gd")
const MotionResolverClass := preload("res://scripts/world/motion_resolver.gd")
const InteractiveFurnitureClass := preload("res://scripts/world/interactive_furniture.gd")

func _init() -> void:
	_run_acceptance_test.call_deferred()

func _run_acceptance_test() -> void:
	print("==================================================")
	print("[Phase 5] Golden Acceptance Test: Pilot Character (Keqing)")
	print("==================================================")
	
	var root := Node.new()
	get_root().add_child(root)
	
	# Load Keqing Data
	var char_json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/npc/characters/keqing.json"))
	var dialogue_json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/npc/dialogue/keqing/sandbar_dialogue.json"))
	var reactions_json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/npc/reactions/keqing_reactions.json"))
	var motions_json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/npc/motions/keqing_motions.json"))
	
	print("\n--- Step 1: Dialogue Flow with Generic DialogueManager ---")
	var dia_mgr := DialogueManagerClass.new()
	root.add_child(dia_mgr)
	
	var received := {"speaker": "", "text": "", "choices": [], "action": ""}
	dia_mgr.text_updated.connect(func(sp, tx, em):
		received["speaker"] = sp
		received["text"] = tx
	)
	dia_mgr.choices_presented.connect(func(ch):
		received["choices"] = ch
	)
	dia_mgr.dialogue_ended.connect(func(payload):
		received["action"] = payload.get("action", "")
	)
	
	# Start dialogue
	dia_mgr.start_dialogue(dialogue_json, "start")
	assert(received["speaker"] == "刻晴")
	assert("斩尽芜杂" in received["text"])
	print("  ✓ Keqing initial dialogue received: %s" % received["text"])
	
	# Advance to choices
	dia_mgr.advance_text()
	assert(received["choices"].size() == 3)
	assert("提出切磋" in received["choices"][1]["text"])
	print("  ✓ Keqing choices presented successfully (Count: %d)" % received["choices"].size())
	
	# Select combat option
	dia_mgr.choose_option(1)
	assert(received["action"] == "enter_combat")
	print("  ✓ Action 'enter_combat' dispatched successfully from generic DialogueManager!")
	
	print("\n--- Step 2: Sensual Duel with Generic TurnCombatManager ---")
	var combat_mgr := TurnCombatManagerClass.new()
	var player_pleasure := PleasureComponentClass.new()
	var npc_pleasure := PleasureComponentClass.new()
	root.add_child(combat_mgr)
	root.add_child(player_pleasure)
	root.add_child(npc_pleasure)
	
	# Configure combat specifically for Keqing
	combat_mgr.setup(player_pleasure, npc_pleasure)
	combat_mgr.configure_npc(char_json["display_name"], reactions_json)
	combat_mgr.start_combat(false) # Non-tutorial combat
	
	assert(combat_mgr.npc_name == "刻晴")
	assert(combat_mgr.is_tutorial_round == false)
	assert(combat_mgr.current_phase == combat_mgr.Phase.PLAYER_INPUT)
	print("  ✓ TurnCombatManager configured with NPC '%s', regular balanced strategy" % combat_mgr.npc_name)
	
	var combat_log := ""
	var combat_koujou := {}
	combat_mgr.log_message_emitted.connect(func(msg):
		combat_log = msg
	)
	combat_mgr.koujou_triggered.connect(func(sp, tx, badge):
		combat_koujou["speaker"] = sp
		combat_koujou["text"] = tx
	)
	
	# Player action: Stimulate thighs (Keqing sensitive zone)
	var player_act := {
		"action_name": "抚摸黑丝大腿",
		"base_pleasure": 20.0,
		"target_zone": "thighs",
		"self_pleasure_defense": 0.0
	}
	combat_mgr.execute_player_action(player_act)
	assert(combat_koujou.get("speaker") == "刻晴")
	assert("黑丝" in combat_koujou.get("text") or "大腿" in combat_koujou.get("text"))
	print("  ✓ Player stimulated thighs -> Keqing custom koujou: '%s'" % combat_koujou.get("text"))
	
	# NPC action: Keqing turn action decision & custom attack koujou
	var npc_decision: Dictionary = combat_mgr.combat_strategy.decide_npc_action(1, player_pleasure, npc_pleasure, combat_mgr.reaction_resolver)
	assert(npc_decision["skill_id"] in ["yunlai_sword", "starward_sword", "sensual_feint"])
	assert(npc_decision["skill_name"] in ["云来剑势·灵动突袭", "天街巡游·柔情攻势", "假动作·贴面娇吟"])
	var attack_koujou: Dictionary = combat_mgr.reaction_resolver.get_attack_line(npc_decision["skill_id"])
	assert(attack_koujou.get("speaker") == "刻晴")
	assert(attack_koujou.get("text") in [
		"看招！以迅雷不及掩耳之势贴身进攻，可别眨眼哦！",
		"剑影纷飞！用最细腻温柔的手法抚过你的敏感点，认输吧！",
		"以为我要出剑？这可是贴身佯攻！耳边的娇喘，你能抵挡得住吗？"
	])
	print("  ✓ Keqing custom attack skill '%s' and koujou '%s' triggered cleanly!" % [npc_decision["skill_name"], attack_koujou["text"]])
	
	print("\n--- Step 3: Motion & Furniture Adaptive Resolution ---")
	# Mock desk furniture in Sandbar
	var desk := InteractiveFurnitureClass.new()
	desk.name = "desk_01"
	var anchor_surf := Marker3D.new()
	anchor_surf.name = "Anchor_Desk_Surface"
	anchor_surf.position = Vector3(0, 0.838, 0)
	desk.add_child(anchor_surf)
	var anchor_front := Marker3D.new()
	anchor_front.name = "Anchor_Front"
	desk.add_child(anchor_front)
	root.add_child(desk)
	
	# Test 3.1: Resolve with desk furniture available
	var res_desk: Dictionary = MotionResolverClass.resolve_motion(motions_json, "desk_service", [desk])
	assert(res_desk["found"] == true)
	assert(res_desk["type"] == "furniture")
	assert(res_desk["contact_anchor"].name == "Anchor_Desk_Surface")
	assert("mmd_fca4bab1635f" in res_desk["binding"]["role_a_motion"])
	print("  ✓ Desk furniture present -> Accurately resolved to table motion 'mmd_fca4bab1635f'!")
	
	# Test 3.2: Resolve when furniture is NOT available (fallback to ground)
	var res_ground: Dictionary = MotionResolverClass.resolve_motion(motions_json, "desk_service", [])
	assert(res_ground["found"] == true)
	assert(res_ground["type"] == "ground")
	assert(res_ground["binding_key"] == "ground_service")
	assert("mmd_fcc0340f8227" in res_ground["binding"]["role_a_motion"])
	print("  ✓ Furniture absent -> Seamlessly and gracefully fell back to ground motion 'mmd_fcc0340f8227'!")
	
	print("\n==================================================")
	print("[Phase 5 ACCEPTANCE PASSED] Golden standard achieved!")
	print("Generic architecture successfully powers Keqing with 100% data injection!")
	print("==================================================")
	quit(0)
