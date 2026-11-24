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
	_test_edge_cases_and_clean_pruning()
	
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
	
	# Verify that ALL combat and pleasure lines are absent
	assert(not scene_prompt.contains("双方快感状态"), "Pleasure status line must be absent in home dialogue")
	assert(not scene_prompt.contains("0.0%"), "Misleading 0.0% pleasure must be absent in home dialogue")
	assert(not scene_prompt.contains("战斗回合"), "Combat round must be absent in home dialogue")
	assert(not scene_prompt.contains("战斗阶段"), "Combat phase must be absent in home dialogue")
	assert(not scene_prompt.contains("交涉起因"), "Negotiation reason must be absent in home dialogue")
	assert(not scene_prompt.contains("上一轮攻防"), "Last combat exchange must be absent in home dialogue")
	assert(not scene_prompt.contains("Master危险度"), "Player danger level must be absent in home dialogue")
	assert(not scene_prompt.contains("受访者动情状态"), "NPC pleasure stage must be absent in home dialogue")
	assert(not scene_prompt.contains("当前对决增益"), "Combat buffs must be absent in home dialogue")
	assert(not scene_prompt.contains("受访者上一招"), "Last NPC skill must be absent in home dialogue")
	assert(not scene_prompt.contains("受访者反应台词"), "Last NPC reaction must be absent in home dialogue")
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
		"last_npc_skill": "灵巧舌尖缠绕",
		"last_npc_koujou": "哈啊，Master好用力",
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
	assert(scene_prompt.contains("双方快感状态：受访者 75.0% / Master 45.0%"), "Combat pleasure state must be injected")
	assert(scene_prompt.contains("战斗回合：第 2 回合"), "Combat round must be present")
	assert(scene_prompt.contains("战斗阶段：战中交涉阶段"), "Combat phase must be present")
	assert(scene_prompt.contains("交涉起因：Master主动战中搭话"), "Negotiation reason must be present")
	assert(scene_prompt.contains("上一轮攻防：Master 针对 敏感双乳 施展了【指尖轻抚】"), "Last action exchange must be present")
	assert(scene_prompt.contains("Master危险度：渐入佳境"), "Player danger level must be present")
	assert(scene_prompt.contains("受访者动情状态：意乱情迷 / 娇喘连连"), "NPC pleasure stage must be present")
	assert(scene_prompt.contains("当前对决增益：识趣生效（走神放水）"), "Combat buffs must be present")
	assert(scene_prompt.contains("受访者上一招：灵巧舌尖缠绕"), "NPC last skill must be present")
	assert(scene_prompt.contains("受访者反应台词：哈啊，Master好用力"), "NPC reaction koujou must be present")
	assert(not scene_prompt.contains("未指定"), "No '未指定' placeholder must exist")
	
	print("  [Pass] Combat prompt expansion correctly injected all combat variables!")

func _test_combat_manager_context_lifecycle() -> void:
	print("\n--- Test 3: TurnCombatManager Context Extraction & Buff Sync ---")
	var mgr := CombatManagerClass.new()
	var p_pleasure := PleasureCompClass.new()
	var n_pleasure := PleasureCompClass.new()
	p_pleasure.max_pleasure = 100.0
	n_pleasure.max_pleasure = 100.0
	
	mgr.setup(p_pleasure, n_pleasure)
	mgr.configure_npc("花火")
	
	# Before combat starts, context is empty
	assert(mgr.get_combat_llm_context().is_empty(), "Inactive combat context must be empty")
	
	# Start combat with meta cheat settings
	mgr.start_combat(false, {"meta_cheat_mode": "distracted", "edging_endure": true})
	assert(mgr.current_phase == CombatManagerClass.Phase.PLAYER_INPUT, "Phase must be player input")
	
	var ctx1 := mgr.get_combat_llm_context()
	assert(ctx1.get("combat_round") == "第 1 回合", "Round count must be 1")
	assert(ctx1.get("combat_phase") == "Master行动回合", "Phase must be Master行动回合")
	# In player turn before mid-battle talk, mid_battle_reason MUST be empty!
	assert(ctx1.get("mid_battle_reason").is_empty(), "Mid battle reason must be empty in player turn")
	assert(ctx1.get("combat_buffs").contains("识趣生效"), "Buffs must contain 识趣生效")
	assert(ctx1.get("combat_buffs").contains("战意增益"), "Buffs must contain 战意增益 from temporary modifier")
	
	# Trigger mid battle dialogue
	mgr.request_in_battle_negotiation()
	var ctx_mid := mgr.get_combat_llm_context()
	assert(ctx_mid.get("mid_battle_reason") == "Master主动战中搭话", "Mid battle reason must be recorded in mid-battle phase")
	assert(ctx_mid.get("combat_phase") == "战中交涉阶段", "Phase must be 战中交涉阶段")
	
	# Resume combat after dialogue
	mgr.resume_combat_after_dialogue(false, false)
	var ctx_resumed := mgr.get_combat_llm_context()
	assert(mgr.current_phase == CombatManagerClass.Phase.PLAYER_INPUT, "Phase must return to PLAYER_INPUT")
	# After resuming, mid_battle_reason MUST be cleared back to empty!
	assert(ctx_resumed.get("mid_battle_reason").is_empty(), "Mid battle reason must be cleared upon resuming combat")
	
	# Execute player defense posture action
	mgr.animation_delays = false
	mgr.execute_player_action({
		"action_name": "坚守心神",
		"base_pleasure": 0.0,
		"target_zone": "",
		"self_pleasure_defense": 0.5,
	})
	
	var ctx_def := mgr.get_combat_llm_context()
	assert(ctx_def.get("last_player_action") == "坚守心神", "Last action name must be recorded")
	assert(ctx_def.get("last_combat_exchange").contains("姿态"), "Combat exchange must describe posture")
	
	# In-battle dynamic modification: test 50% temporary defense injection (from 咬牙忍耐)
	mgr.temporary_defense_modifier = 0.5
	var ctx_buff_sync := mgr.get_combat_llm_context()
	assert(ctx_buff_sync.get("combat_buffs").contains("50%"), "Combat buffs must reflect dynamic 50% defense modifier")
	
	# Check battle resolution: when battle is resolved, get_combat_llm_context must return empty!
	n_pleasure.add_pleasure(100.0)
	mgr._check_battle_state()
	assert(mgr.is_resolved, "Combat must be resolved")
	assert(mgr.get_combat_llm_context().is_empty(), "Resolved battle must return empty context so settlement dialogue is clean")
	
	print("  [Pass] TurnCombatManager context lifecycle and in-battle buff sync verified cleanly!")

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
	for i in range(scene_index):
		var prev_depth: int = mid_list[i].get("depth", 0)
		assert(prev_depth >= 900, "Entries before scene tag must have depth >= 900")
	for i in range(scene_index + 1, mid_list.size()):
		var next_depth: int = mid_list[i].get("depth", 0)
		assert(next_depth <= 900, "Entries after scene tag must have depth <= 900")
		
	print("  [Pass] Depth 900 placement verified at exact hierarchy location!")

func _test_edge_cases_and_clean_pruning() -> void:
	print("\n--- Test 5: Empty Line Pruning and Edge Cases ---")
	var client := Client.new()
	
	# Edge Case A: Variable containing newline must NOT break pruning of empty combat tags
	client.context = {
		"npc_name": "花火",
		"dialogue_location": "沙洲度假\n第二层遗址",
		"current_interaction_state": "家园闲聊",
		"bound_furniture_info": "双人软床",
		# combat tags empty
	}
	var template := "当前对话地点：{{dialogue_location}}\n当前互动阶段：{{current_interaction_state}}\n战斗回合：{{combat_round}}\n战斗阶段：{{combat_phase}}"
	var result_a := client._expand_dialogue_prompt(template)
	assert(result_a.contains("沙洲度假\n第二层遗址"), "Location with newline must be expanded")
	assert(not result_a.contains("战斗回合"), "Empty combat round tag must be pruned even if other variable has newline")
	assert(not result_a.contains("战斗阶段"), "Empty combat phase tag must be pruned even if other variable has newline")
	
	# Edge Case B: Legitimate header ending in colon must be preserved
	var template_b := "下一行介绍{{npc_name}}：\n花火是可爱的假面愚者。"
	var result_b := client._expand_dialogue_prompt(template_b)
	assert(result_b.contains("下一行介绍花火："), "Legitimate author header ending in colon must be preserved")
	
	print("  [Pass] Edge cases for newline variables and colon preservation verified!")
