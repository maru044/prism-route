class_name TurnCombatManager
extends Node
## Turn-based RPG combat state machine for sensual pleasure duals.
## Decoupled from specific character scripts via CombatStrategy and ReactionResolver.

signal combat_started()
signal phase_changed(new_phase: int)
signal log_message_emitted(message: String)
signal mid_battle_dialogue_requested(reason: String)
signal combat_ended(winner: String, loser: String, reason: String)
signal koujou_triggered(speaker: String, text: String, emotion: String)

const ReactionResolverClass := preload("res://scripts/combat/reaction_resolver.gd")
const CombatStrategyClass := preload("res://scripts/combat/combat_strategy.gd")

enum Phase {
	INACTIVE,
	ROUND_START,
	PLAYER_INPUT,
	PLAYER_ACTION,
	NPC_ACTION,
	MID_BATTLE_DIALOGUE,
	ROUND_END,
	VICTORY,
	DEFEAT
}

var player_pleasure: Node
var npc_pleasure: Node
var npc_name: String = "NPC"
var reaction_resolver: RefCounted
var combat_strategy: RefCounted

var current_phase: Phase = Phase.INACTIVE
var round_count: int = 1
var is_tutorial_round: bool = false

var round_action_defense: float = 0.0
var temporary_defense_modifier: float = 0.0 # From mid-battle dialogue (e.g. 咬牙坚持)
var has_triggered_mid_edging_talk: bool = false
var is_resolved: bool = false
var animation_delays: bool = true

var active_meta_settings: Dictionary = {}
var last_player_action_name: String = ""
var last_player_target_zone: String = ""
var last_npc_skill_name: String = ""
var last_npc_koujou_text: String = ""
var last_mid_battle_reason: String = ""

func setup(player_comp: Node, npc_comp: Node) -> void:
	player_pleasure = player_comp
	npc_pleasure = npc_comp
	if reaction_resolver == null:
		reaction_resolver = ReactionResolverClass.new({"speaker": npc_name})
	if combat_strategy == null:
		combat_strategy = CombatStrategyClass.new()

func configure_npc(p_npc_name: String, p_reactions: Dictionary = {}, p_strategy: RefCounted = null) -> void:
	npc_name = p_npc_name
	if not p_reactions.is_empty():
		reaction_resolver = ReactionResolverClass.new(p_reactions)
	elif reaction_resolver == null:
		reaction_resolver = ReactionResolverClass.new({"speaker": npc_name})
		
	if p_strategy != null:
		combat_strategy = p_strategy
	elif combat_strategy == null:
		combat_strategy = CombatStrategyClass.new()

func start_combat(tutorial_mode: bool = false, meta_settings: Dictionary = {}) -> void:
	is_tutorial_round = tutorial_mode
	round_count = 1
	round_action_defense = 0.0
	temporary_defense_modifier = 0.0
	has_triggered_mid_edging_talk = false
	is_resolved = false
	active_meta_settings = meta_settings.duplicate()
	last_player_action_name = ""
	last_player_target_zone = ""
	last_npc_skill_name = ""
	last_npc_koujou_text = ""
	last_mid_battle_reason = ""
	
	if combat_strategy == null:
		combat_strategy = CombatStrategyClass.new()
	elif "is_tutorial_round" in combat_strategy:
		combat_strategy.is_tutorial_round = is_tutorial_round
		
	player_pleasure.reset()
	npc_pleasure.reset()
	player_pleasure.damage_taken_multiplier = float(meta_settings.get("player_damage_taken_multiplier", 1.0))
	npc_pleasure.damage_taken_multiplier = float(meta_settings.get("npc_damage_taken_multiplier", 1.0))
	
	# Apply meta cheat settings if provided
	var cheat_mode: String = meta_settings.get("meta_cheat_mode", "none")
	if cheat_mode == "distracted":
		npc_pleasure.damage_taken_multiplier = 2.5
		log_message_emitted.emit("【识趣生效】%s故意走神了！受到的快感大幅增加！" % npc_name)
	elif cheat_mode == "lock_master_pleasure":
		player_pleasure.pleasure_locked = true
		player_pleasure.pleasure_cap = 90.0
		log_message_emitted.emit("【识趣生效】锁精结界生效！主人的快感被限制在 90% 以下！")
	elif cheat_mode == "reduce_damage":
		player_pleasure.damage_taken_multiplier = 0.4
		log_message_emitted.emit("【识趣生效】防线强化！主人受到的快感大幅降低！")
		
	if meta_settings.get("edging_endure", false):
		temporary_defense_modifier = 0.6
		log_message_emitted.emit("【战术增益】心神合一生效，下一轮受到的快感减免 60%！")
		
	current_phase = Phase.ROUND_START
	phase_changed.emit(current_phase)
	combat_started.emit()
	
	log_message_emitted.emit("【身心对决开始】与%s的身心快感对决正式打响！" % npc_name)
	_advance_to_player_turn()

func execute_player_action(command: Variant) -> void:
	var action: Dictionary
	if command is TurnActionResource:
		action = {
			"action_name": command.action_name,
			"base_pleasure": command.base_pleasure,
			"target_zone": command.target_zone,
			"self_pleasure_defense": command.self_pleasure_defense,
		}
	elif command is Dictionary:
		action = command
	else:
		return
	if current_phase != Phase.PLAYER_INPUT or is_resolved:
		return
		
	current_phase = Phase.PLAYER_ACTION
	phase_changed.emit(current_phase)
	
	round_action_defense = action.self_pleasure_defense
	var act_name: String = action.get("action_name", action.get("name", "未知招式"))
	last_player_action_name = act_name
	
	if action.base_pleasure > 0.0:
		last_player_target_zone = str(action.target_zone)
		var gained: float = npc_pleasure.add_pleasure(action.base_pleasure, action.target_zone)
		var zone_desc := "敏感部位"
		match action.target_zone:
			"mouth": zone_desc = "柔嫩口腔"
			"nipples": zone_desc = "敏感双乳"
			"anal": zone_desc = "紧致菊部"
			"clitoris": zone_desc = "私密花核"
			"thighs": zone_desc = "娇嫩大腿"
		var extra_badge := "（造成 +%.1f%% 快感 · %s）" % [gained, zone_desc]
		log_message_emitted.emit("主人施展【%s】，刺激了%s的%s，造成了 +%.1f%% 快感！" % [act_name, npc_name, zone_desc, gained])
		var koujou: Dictionary = reaction_resolver.get_zone_reaction(action.target_zone, npc_pleasure.current_pleasure) if reaction_resolver else {"speaker": npc_name, "text": "哈啊"}
		last_npc_koujou_text = str(koujou.get("text", ""))
		koujou_triggered.emit(koujou.get("speaker", npc_name), koujou.get("text", ""), extra_badge)
	else:
		last_player_target_zone = ""
		last_npc_koujou_text = ""
		log_message_emitted.emit("主人采取了【%s】姿态，本回合快感减免 50%%！" % act_name)
		koujou_triggered.emit("状态", "采取了防守姿态，本回合受到的快感减免 50%！", "")
		
	if animation_delays and is_inside_tree() and get_tree():
		await get_tree().create_timer(1.8).timeout
	
	if _check_battle_state():
		return
		
	_advance_to_npc_turn()

func request_in_battle_negotiation() -> void:
	if current_phase != Phase.PLAYER_INPUT or is_resolved:
		return
	last_mid_battle_reason = "player_manual_call"
	current_phase = Phase.MID_BATTLE_DIALOGUE
	phase_changed.emit(current_phase)
	mid_battle_dialogue_requested.emit("player_manual_call")

func resume_combat_after_dialogue(surrender_requested: bool = false, from_edging_danger: bool = false) -> void:
	if current_phase != Phase.MID_BATTLE_DIALOGUE or is_resolved:
		return
		
	if surrender_requested:
		npc_pleasure.add_pleasure(100.0)
		_check_battle_state()
		return
		
	if from_edging_danger:
		log_message_emitted.emit("主人咬牙忍耐成功，化解了本轮危机！进入下一回合！")
		_advance_to_next_round()
	else:
		current_phase = Phase.PLAYER_INPUT
		phase_changed.emit(current_phase)
		log_message_emitted.emit("战中交涉结束，对决继续！请主人选择行动。")

func _advance_to_player_turn() -> void:
	if is_resolved:
		return
	current_phase = Phase.PLAYER_INPUT
	phase_changed.emit(current_phase)
	log_message_emitted.emit("【玩家回合】请主人选择行动指令。")

func _advance_to_npc_turn() -> void:
	if is_resolved:
		return
	current_phase = Phase.NPC_ACTION
	phase_changed.emit(current_phase)
	log_message_emitted.emit("【%s回合】轮到%s行动了！" % [npc_name, npc_name])
	
	if animation_delays and is_inside_tree() and get_tree():
		await get_tree().create_timer(0.6).timeout
	
	# Execute NPC decision via CombatStrategy
	if combat_strategy == null:
		combat_strategy = CombatStrategyClass.new()
		
	var decision: Dictionary = combat_strategy.decide_npc_action(round_count, player_pleasure, npc_pleasure, reaction_resolver)
	var skill_id: String = decision.get("skill_id", "tongue")
	var skill_name: String = decision.get("skill_name", "灵巧舌尖缠绕")
	last_npc_skill_name = skill_name
	var raw_dmg: float = decision.get("raw_damage", 16.0)
	var target_zone: String = decision.get("target_zone", "mouth")
	var is_teaching: bool = decision.get("is_teaching_kill", false)
	
	var attack_koujou: Dictionary = reaction_resolver.get_attack_line(skill_id) if reaction_resolver else {"speaker": npc_name, "text": "看招！"}
	
	if is_teaching:
		player_pleasure.add_pleasure(raw_dmg, target_zone)
		koujou_triggered.emit(attack_koujou.get("speaker", npc_name), attack_koujou.get("text", ""), "（受到极强烈的绝顶侍奉，快感 +100%！）")
		var custom_log: String = decision.get("custom_log", "%s使出了绝招！" % npc_name)
		log_message_emitted.emit(custom_log)
		log_message_emitted.emit("极致温热的包裹无视防御，让主人受到极度强烈的快感冲击（+100.0%）！")
		if animation_delays and is_inside_tree() and get_tree():
			await get_tree().create_timer(2.2).timeout
	else:
		var total_defense: float = clampf(round_action_defense + temporary_defense_modifier, 0.0, 0.95)
		var actual_dmg: float = raw_dmg * (1.0 - total_defense)
		var gained: float = player_pleasure.add_pleasure(actual_dmg, target_zone)
		koujou_triggered.emit(attack_koujou.get("speaker", npc_name), attack_koujou.get("text", ""), "（主人受到 +%.1f%% 快感）" % gained)
		log_message_emitted.emit("%s施展了【%s】，对主人造成了 +%.1f%% 快感！" % [npc_name, skill_name, gained])
		if animation_delays and is_inside_tree() and get_tree():
			await get_tree().create_timer(1.8).timeout
		
	# Reset round defense & consume temporary defense
	round_action_defense = 0.0
	temporary_defense_modifier = 0.0
	
	if _check_battle_state():
		return
		
	_advance_to_next_round()

func _advance_to_next_round() -> void:
	if is_resolved:
		return
	round_count += 1
	current_phase = Phase.ROUND_START
	phase_changed.emit(current_phase)
	log_message_emitted.emit("———————— 第 %d 回合开始 ————————" % round_count)
	_advance_to_player_turn()

func _check_battle_state() -> bool:
	if is_resolved:
		return true
		
	# Check Player Defeat (100% Pleasure)
	if player_pleasure.has_reached_climax:
		is_resolved = true
		current_phase = Phase.DEFEAT
		phase_changed.emit(current_phase)
		log_message_emitted.emit("【对决结束】主人承受不住强烈刺激，达到了绝顶高潮！对决落败！")
		combat_ended.emit(npc_name, "player", "player_climax")
		return true
		
	# Check NPC Defeat (100% Pleasure)
	if npc_pleasure.has_reached_climax:
		is_resolved = true
		current_phase = Phase.VICTORY
		phase_changed.emit(current_phase)
		log_message_emitted.emit("【对决结束】%s娇喘连连彻底失守，陷入了剧烈绝顶！主人获得了胜利！" % npc_name)
		combat_ended.emit("player", npc_name, "npc_climax")
		return true
		
	# Check Edging Threshold Interruption (Only trigger once per battle unless reset)
	if not has_triggered_mid_edging_talk and player_pleasure.is_edging:
		has_triggered_mid_edging_talk = true
		last_mid_battle_reason = "player_edging_critical"
		current_phase = Phase.MID_BATTLE_DIALOGUE
		phase_changed.emit(current_phase)
		log_message_emitted.emit("【濒危警告】主人的快感已突破 90%% 绝顶临界点！触发紧急战中交涉！")
		mid_battle_dialogue_requested.emit("player_edging_critical")
		return true
		
	return false

func get_combat_llm_context(mid_reason: String = "") -> Dictionary:
	if current_phase == Phase.INACTIVE:
		return {}
	var reason_text := ""
	var r := mid_reason if not mid_reason.is_empty() else last_mid_battle_reason
	if r == "player_manual_call":
		reason_text = "Master主动战中搭话"
	elif r == "player_edging_critical":
		reason_text = "Master快感突破90%濒临绝顶危机"
	elif not r.is_empty():
		reason_text = r
	
	var phase_text := "对决对峙中"
	match current_phase:
		Phase.PLAYER_INPUT, Phase.PLAYER_ACTION:
			phase_text = "Master行动回合"
		Phase.NPC_ACTION:
			phase_text = "%s反击回合" % npc_name
		Phase.MID_BATTLE_DIALOGUE:
			phase_text = "战中交涉阶段"
		Phase.VICTORY:
			phase_text = "战胜结算"
		Phase.DEFEAT:
			phase_text = "战败受惩"

	var p_zone_zh := ""
	match last_player_target_zone:
		"mouth": p_zone_zh = "柔嫩口腔"
		"nipples": p_zone_zh = "敏感双乳"
		"anal": p_zone_zh = "紧致菊部"
		"clitoris": p_zone_zh = "私密花核"
		"thighs": p_zone_zh = "娇嫩大腿"
		_: p_zone_zh = last_player_target_zone

	var player_p: float = player_pleasure.current_pleasure if player_pleasure else 0.0
	var npc_p: float = npc_pleasure.current_pleasure if npc_pleasure else 0.0

	var p_danger := "从容自若"
	if player_p >= 90.0:
		p_danger = "濒临绝顶危机 (Edging Danger)"
	elif player_p >= 75.0:
		p_danger = "心神动摇 / 快感激烈"
	elif player_p >= 40.0:
		p_danger = "渐入佳境"

	var npc_stage := "从容微喘"
	if npc_p >= 90.0:
		npc_stage = "身心沦陷濒临绝顶"
	elif npc_p >= 75.0:
		npc_stage = "意乱情迷 / 娇喘连连"
	elif npc_p >= 40.0:
		npc_stage = "动情微润"

	var buffs: Array[String] = []
	var cheat: String = str(active_meta_settings.get("meta_cheat_mode", "none"))
	if cheat == "distracted":
		buffs.append("识趣生效（故意走神放水，受快感大幅增加）")
	elif cheat == "lock_master_pleasure":
		buffs.append("锁精结界（Master快感限制在90%以下）")
	elif cheat == "reduce_damage":
		buffs.append("防线强化（Master受快感大幅降低）")
	if active_meta_settings.get("edging_endure", false):
		buffs.append("心神合一（快感减免60%）")
	var buffs_str := "、".join(buffs)

	var last_act_desc := ""
	if not last_player_action_name.is_empty():
		if not p_zone_zh.is_empty():
			last_act_desc = "Master 针对 %s 施展了【%s】" % [p_zone_zh, last_player_action_name]
		else:
			last_act_desc = "Master 采取了【%s】姿态" % last_player_action_name

	return {
		"combat_round": "第 %d 回合" % round_count,
		"combat_phase": phase_text,
		"mid_battle_reason": reason_text,
		"last_player_action": last_player_action_name,
		"last_target_zone": p_zone_zh,
		"last_combat_exchange": last_act_desc,
		"last_npc_skill": last_npc_skill_name,
		"last_npc_koujou": last_npc_koujou_text,
		"player_danger_level": p_danger,
		"npc_pleasure_stage": npc_stage,
		"combat_buffs": buffs_str,
	}
