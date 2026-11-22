extends SceneTree

const Client := preload("res://scripts/ai/game_llm_client.gd")
const CombatManagerClass := preload("res://scripts/combat/turn_combat_manager.gd")
const PleasureCompClass := preload("res://scripts/combat/pleasure_component.gd")

func _init() -> void:
	print("==================================================")
	print("[Test] Verifying Dynamic Dialogue Prompt Variables")
	print("==================================================")
	
	_test_home_dialogue_expansion()
	_test_combat_dialogue_expansion()
	_test_combat_manager_context_lifecycle()
	_test_prompt_depth_900_placement()
	
	print("==================================================")
	print("[SUCCESS] All Dynamic Prompt Variable Tests Passed 100%!")
	print("==================================================")
	quit(0)

func _test_home_dialogue_expansion() -> void:
	print("\n--- Test 1: Home / Non-Combat Prompt Expansion ---")
	var client := Client.new()
	client.context = {
		"npc_name": "花火",
		"character_title": "假面愚者",
		"dialogue_location": "家园 · plot_01 (家园房间 · bed_01)",
		"current_interaction_state": "家园闲聊",
		"bound_furniture_info": "双人软床",
		"companion_status": "已缔结契约（识趣玩伴）",
		"pleasure_npc": "0.0%",
		"pleasure_player": "0.0%",
	}
	
	var err := client._load_dialogue_markdown()
	if not err.is_empty():
		push_error("Failed to load dialogue markdown: " + err)
		quit(1)
		return
		
	var parsed := client._parsed_dialogue_prompts()
	var scene_prompt := ""
	for mid: Dictionary in parsed.get("mid", []):
		if mid.get("depth") == 900 and mid.get("name") == "角色与场景":
			scene_prompt = mid.get("content", "")
			break
			
	assert(not scene_prompt.is_empty(), "角色与场景 tag must be found at depth 900")
	assert(scene_prompt.contains("当前对话对象：花火（假面愚者）"), "Must contain npc_name and title")
	assert(scene_prompt.contains("当前对话地点：家园 · plot_01 (家园房间 · bed_01)"), "Must contain location")
	assert(scene_prompt.contains("场景家具绑定：双人软床"), "Must contain bound furniture")
	assert(scene_prompt.contains("当前互动阶段：家园闲聊"), "Must contain interaction state")
	
	# Verify that ALL combat lines are absent
	assert(not scene_prompt.contains("战斗回合"), "Combat round must be absent in home dialogue")
	assert(not scene_prompt.contains("战斗阶段"), "Combat phase must be absent in home dialogue")
	assert(not scene_prompt.contains("交涉起因"), "Negotiation reason must be absent in home dialogue")
	assert(not scene_prompt.contains("上一轮攻防"), "Last combat exchange must be absent in home dialogue")
	assert(not scene_prompt.contains("Master危险度"), "Player danger level must be absent in home dialogue")
	assert(not scene_prompt.contains("受访者动情状态"), "NPC pleasure stage must be absent in home dialogue")
	assert(not scene_prompt.contains("当前对决增益"), "Combat buffs must be absent in home dialogue")
	assert(not scene_prompt.contains("未指定"), "No '未指定' placeholder must exist")
	
	print("  [Pass] Home prompt expansion pure and free of combat tags!")

func _test_combat_dialogue_expansion() -> void:
	print("\n--- Test 2: Combat Prompt Expansion ---")
	var client := Client.new()
	client.context = {
		"npc_name": "花火",
		"character_title": "假面愚者",
		"dialogue_location": "初始神殿",
		"current_interaction_state": "对决对峙中",
		"bound_furniture_info": "神殿御座 / 石座",
		"companion_status": "已缔结契约（识趣玩伴）",
		"pleasure_npc": "75.0%",
		"pleasure_player": "45.0%",
		"combat_round": "第 2 回合",
		"combat_phase": "战中交涉阶段",
		"mid_battle_reason": "Master主动战中搭话",
		"last_combat_exchange": "Master 针对 敏感双乳 施展了【指尖轻抚】",
		"player_danger_level": "渐入佳境",
		"npc_pleasure_stage": "意乱情迷 / 娇喘连连",
		"combat_buffs": "识趣生效（走神放水）",
	}
	
	var err := client._load_dialogue_markdown()
	if not err.is_empty():
		push_error("Failed to load dialogue markdown: " + err)
		quit(1)
		return
		
	var parsed := client._parsed_dialogue_prompts()
	var scene_prompt := ""
	for mid: Dictionary in parsed.get("mid", []):
		if mid.get("depth") == 900 and mid.get("name") == "角色与场景":
			scene_prompt = mid.get("content", "")
			break
			
	assert(not scene_prompt.is_empty(), "角色与场景 tag must be found at depth 900")
	assert(scene_prompt.contains("战斗回合：第 2 回合"), "Combat round must be present")
	assert(scene_prompt.contains("战斗阶段：战中交涉阶段"), "Combat phase must be present")
	assert(scene_prompt.contains("交涉起因：Master主动战中搭话"), "Negotiation reason must be present")
	assert(scene_prompt.contains("上一轮攻防：Master 针对 敏感双乳 施展了【指尖轻抚】"), "Last action exchange must be present")
	assert(scene_prompt.contains("Master危险度：渐入佳境"), "Player danger level must be present")
	assert(scene_prompt.contains("受访者动情状态：意乱情迷 / 娇喘连连"), "NPC pleasure stage must be present")
	assert(scene_prompt.contains("当前对决增益：识趣生效（走神放水）"), "Combat buffs must be present")
	assert(not scene_prompt.contains("未指定"), "No '未指定' placeholder must exist")
	
	print("  [Pass] Combat prompt expansion correctly injected all combat variables!")

func _test_combat_manager_context_lifecycle() -> void:
	print("\n--- Test 3: TurnCombatManager Context Extraction ---")
	var mgr := CombatManagerClass.new()
	var p_pleasure := PleasureCompClass.new()
	var n_pleasure := PleasureCompClass.new()
	p_pleasure.max_pleasure = 100.0
	n_pleasure.max_pleasure = 100.0
	
	mgr.setup(p_pleasure, n_pleasure)
	mgr.configure_npc("花火")
	
	# Before combat starts, context is empty
	assert(mgr.get_combat_llm_context().is_empty(), "Inactive combat context must be empty")
	
	# Start combat
	mgr.start_combat(false, {"meta_cheat_mode": "distracted", "edging_endure": true})
	assert(mgr.current_phase == CombatManagerClass.Phase.PLAYER_INPUT, "Phase must be player input")
	
	var ctx1 := mgr.get_combat_llm_context()
	assert(ctx1.get("combat_round") == "第 1 回合", "Round count must be 1")
	assert(ctx1.get("combat_phase") == "Master行动回合", "Phase must be Master行动回合")
	assert(ctx1.get("combat_buffs").contains("识趣生效"), "Buffs must contain 识趣生效")
	assert(ctx1.get("combat_buffs").contains("心神合一"), "Buffs must contain 心神合一")
	
	# Execute player action
	mgr.animation_delays = false
	mgr.execute_player_action({
		"action_name": "揉捏敏感",
		"base_pleasure": 10.0,
		"target_zone": "nipples",
		"self_pleasure_defense": 0.0,
	})
	
	var ctx2 := mgr.get_combat_llm_context()
	assert(ctx2.get("last_player_action") == "揉捏敏感", "Last action name must be recorded")
	assert(ctx2.get("last_target_zone") == "敏感双乳", "Target zone must be mapped to Chinese")
	assert(ctx2.get("last_combat_exchange").contains("敏感双乳"), "Combat exchange must describe zone")
	
	# Trigger mid battle dialogue
	mgr.request_in_battle_negotiation()
	var ctx3 := mgr.get_combat_llm_context()
	assert(ctx3.get("mid_battle_reason") == "Master主动战中搭话", "Mid battle reason must be recorded")
	assert(ctx3.get("combat_phase") == "战中交涉阶段", "Phase must be 战中交涉阶段")
	
	print("  [Pass] TurnCombatManager context lifecycle verified cleanly!")

func _test_prompt_depth_900_placement() -> void:
	print("\n--- Test 4: Prompt Depth 900 Placement Hierarchy ---")
	var client := Client.new()
	client.context = {
		"npc_name": "花火",
		"character_id": "sparkle",
		"dialogue_location": "初始神殿",
	}
	var err := client._load_dialogue_markdown()
	assert(err.is_empty(), "Markdown files must load without error")
	var parsed := client._parsed_dialogue_prompts()
	
	var mid_list: Array = parsed.get("mid", [])
	var scene_index := -1
	for i in range(mid_list.size()):
		var item: Dictionary = mid_list[i]
		if item.get("name") == "角色与场景":
			scene_index = i
			assert(item.get("depth") == 900, "Depth of 角色与场景 must be exactly 900")
			break
			
	assert(scene_index >= 0, "角色与场景 must be present in mid prompts")
	# System prompt sort order: mid_prompts sorted descending by depth (highest depth first)
	# Depth 978 (玩家人设) -> Depth 900 (角色与场景) -> Depth 850 (角色设定)
	for i in range(scene_index):
		var prev_depth: int = mid_list[i].get("depth", 0)
		assert(prev_depth >= 900, "Entries before scene tag must have depth >= 900")
	for i in range(scene_index + 1, mid_list.size()):
		var next_depth: int = mid_list[i].get("depth", 0)
		assert(next_depth <= 900, "Entries after scene tag must have depth <= 900")
		
	print("  [Pass] Depth 900 placement verified at exact hierarchy location!")
