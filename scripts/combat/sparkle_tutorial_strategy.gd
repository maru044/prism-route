class_name SparkleTutorialStrategy
extends "res://scripts/combat/combat_strategy.gd"
## Tutorial strategy for Sparkle in Initial Temple:
## Round 1 executes the unblockable teaching kill; subsequent rounds use standard balanced combat.

var is_tutorial_round: bool = true

func _init(p_tutorial_mode: bool = true) -> void:
	is_tutorial_round = p_tutorial_mode

func decide_npc_action(round_count: int, player_pleasure: Node, npc_pleasure: Node, reaction_resolver: RefCounted = null) -> Dictionary:
	if is_tutorial_round and round_count == 1:
		return {
			"skill_id": "teaching_kill",
			"skill_name": "神级深喉绝顶侍奉",
			"raw_damage": 150.0,
			"target_zone": "mouth",
			"is_teaching_kill": true,
			"custom_log": "花火娇笑着伏下身，使出了新手导师绝技【神级深喉绝顶侍奉】！"
		}
	# Subsequent rounds use balanced combat
	return super.decide_npc_action(round_count, player_pleasure, npc_pleasure, reaction_resolver)
