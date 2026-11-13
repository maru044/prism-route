class_name TurnCombatManager
extends Node
## Turn-based RPG combat state machine for sensual pleasure duals.

signal combat_started()
signal phase_changed(new_phase: int)
signal log_message_emitted(message: String)
signal mid_battle_dialogue_requested(reason: String)
signal combat_ended(winner: String, loser: String, reason: String)
signal koujou_triggered(speaker: String, text: String, emotion: String)

const SparkleDialogueClass := preload("res://scripts/narrative/sparkle_tutorial_dialogue.gd")

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

var current_phase: Phase = Phase.INACTIVE
var round_count: int = 1
var is_tutorial_round: bool = true # Round 1 is teaching kill

var round_action_defense: float = 0.0
var temporary_defense_modifier: float = 0.0 # From mid-battle dialogue (e.g. 咬牙坚持)
var has_triggered_mid_edging_talk: bool = false
var is_resolved: bool = false

func setup(player_comp: Node, npc_comp: Node) -> void:
	player_pleasure = player_comp
	npc_pleasure = npc_comp

func start_combat(tutorial_mode: bool = true, meta_settings: Dictionary = {}) -> void:
	is_tutorial_round = tutorial_mode
	round_count = 1
	round_action_defense = 0.0
	temporary_defense_modifier = 0.0
	has_triggered_mid_edging_talk = false
	is_resolved = false
	
	player_pleasure.reset()
	npc_pleasure.reset()
	
	# Apply meta cheat settings if provided
	var cheat_mode: String = meta_settings.get("meta_cheat_mode", "none")
	if cheat_mode == "distracted":
		npc_pleasure.damage_taken_multiplier = 2.5
		log_message_emitted.emit("【识趣生效】花火故意走神了！受到的快感大幅增加！")
	elif cheat_mode == "lock_master_pleasure":
		player_pleasure.pleasure_locked = true
		player_pleasure.pleasure_cap = 90.0
		log_message_emitted.emit("【识趣生效】花火施加了保护！主人的快感被锁定在90%！")
	elif cheat_mode == "instant_surrender":
		log_message_emitted.emit("【识趣特权】花火顺从主人的指令，准备直接走流程认输！")
		
	current_phase = Phase.ROUND_START
	combat_started.emit()
	phase_changed.emit(current_phase)
	
	log_message_emitted.emit("=== 回合制 Battle Fuck 开始！第 %d 回合 ===" % round_count)
	
	if cheat_mode == "instant_surrender":
		npc_pleasure.add_pleasure(100.0)
		_check_battle_state()
		return
		
	_advance_to_player_turn()

func execute_player_action(action: Resource) -> void:
	if current_phase != Phase.PLAYER_INPUT or is_resolved:
		return
		
	current_phase = Phase.PLAYER_ACTION
	phase_changed.emit(current_phase)
	
	round_action_defense = action.self_pleasure_defense
	
	if action.base_pleasure > 0.0:
		var gained: float = npc_pleasure.add_pleasure(action.base_pleasure, action.target_zone)
		var zone_desc := "敏感部位"
		match action.target_zone:
			"mouth": zone_desc = "柔嫩口腔"
			"nipples": zone_desc = "敏感双乳"
			"anal": zone_desc = "紧致菊部"
			"clitoris": zone_desc = "私密花核"
		var extra_badge := "（造成 +%.1f%% 快感 · %s）" % [gained, zone_desc]
		log_message_emitted.emit("主人施展【%s】，刺激了花火的%s，造成了 +%.1f%% 快感！" % [action.action_name, zone_desc, gained])
		var koujou: Dictionary = SparkleDialogueClass.get_zone_reaction(action.target_zone, npc_pleasure.current_pleasure)
		koujou_triggered.emit(koujou.get("speaker", "花火"), koujou.get("text", ""), extra_badge)
	else:
		log_message_emitted.emit("主人采取了【%s】姿态，本回合快感减免 50%%！" % action.action_name)
		koujou_triggered.emit("状态", "采取了防守姿态，本回合受到的快感减免 50%！", "")
		
	await get_tree().create_timer(1.8).timeout
	
	if _check_battle_state():
		return
		
	_advance_to_npc_turn()

func request_in_battle_negotiation() -> void:
	if current_phase != Phase.PLAYER_INPUT or is_resolved:
		return
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
	log_message_emitted.emit("【花火回合】轮到花火行动了！")
	
	await get_tree().create_timer(0.6).timeout
	
	# NPC AI Decision
	if is_tutorial_round and round_count == 1:
		# Teaching Kill: Overwhelming unblockable blow
		var attack_koujou: Dictionary = SparkleDialogueClass.get_npc_attack_line("teaching_kill")
		var raw_dmg := 150.0
		player_pleasure.add_pleasure(raw_dmg, "mouth")
		koujou_triggered.emit(attack_koujou.get("speaker", "花火"), attack_koujou.get("text", ""), "（受到极强烈的绝顶侍奉，快感 +100%！）")
		log_message_emitted.emit("花火娇笑着伏下身，使出了新手导师绝技【神级深喉绝顶侍奉】！")
		log_message_emitted.emit("极致温热的包裹无视防御，让主人受到极度强烈的快感冲击（+100.0%）！")
		await get_tree().create_timer(2.2).timeout
	else:
		# Regular round: Smooth balanced damage (15% to 18%)
		var choices := ["tongue", "deep_throat", "eye_contact"]
		var chosen: String = choices[randi() % choices.size()]
		var raw_dmg := 16.0
		var skill_name := ""
		match chosen:
			"tongue":
				skill_name = "灵巧舌尖缠绕"
				raw_dmg = 15.0
			"deep_throat":
				skill_name = "柔情深喉吞吐"
				raw_dmg = 18.0
			"eye_contact":
				skill_name = "媚眼凝视与娇吟"
				raw_dmg = 16.0
				
		var total_defense: float = clampf(round_action_defense + temporary_defense_modifier, 0.0, 0.95)
		var actual_dmg: float = raw_dmg * (1.0 - total_defense)
		var gained: float = player_pleasure.add_pleasure(actual_dmg)
		var attack_koujou: Dictionary = SparkleDialogueClass.get_npc_attack_line(chosen)
		koujou_triggered.emit(attack_koujou.get("speaker", "花火"), attack_koujou.get("text", ""), "（主人受到 +%.1f%% 快感）" % gained)
		log_message_emitted.emit("花火施展了【%s】，对主人造成了 +%.1f%% 快感！" % [skill_name, gained])
		await get_tree().create_timer(1.8).timeout
		
	# Reset round defense & consume temporary defense
	round_action_defense = 0.0
	temporary_defense_modifier = 0.0
	
	await get_tree().create_timer(0.5).timeout
	
	if _check_battle_state():
		return
		
	# Check for mid-battle edging dialogue (if master >= 90% and not yet defeated)
	if player_pleasure.current_pleasure >= 90.0 and not has_triggered_mid_edging_talk and not is_tutorial_round:
		has_triggered_mid_edging_talk = true
		current_phase = Phase.MID_BATTLE_DIALOGUE
		phase_changed.emit(current_phase)
		mid_battle_dialogue_requested.emit("edging_danger")
		return
		
	_advance_to_next_round()

func _advance_to_next_round() -> void:
	if is_resolved:
		return
	current_phase = Phase.ROUND_END
	round_count += 1
	phase_changed.emit(current_phase)
	log_message_emitted.emit("--- 第 %d 回合开始 ---" % round_count)
	_advance_to_player_turn()

func _check_battle_state() -> bool:
	if is_resolved:
		return true
		
	if npc_pleasure.has_reached_climax:
		is_resolved = true
		current_phase = Phase.VICTORY
		phase_changed.emit(current_phase)
		log_message_emitted.emit("【花火绝顶败北】花火娇喘连连，全身痉挛绝顶，主人赢得了回合对战！")
		combat_ended.emit("Master", "Sparkle", "npc_climax")
		return true
		
	if player_pleasure.has_reached_climax:
		is_resolved = true
		current_phase = Phase.DEFEAT
		phase_changed.emit(current_phase)
		log_message_emitted.emit("【主人射精败北】主人的忍耐突破极限，败北射精虚脱！")
		combat_ended.emit("Sparkle", "Master", "player_climax")
		return true
		
	return false
