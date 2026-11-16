class_name CombatStrategy
extends RefCounted
## Strategy interface for NPC turn decisions in turn-based sensual combat.
## Allows plugging different combat AI routines (standard, teaching kill, berserk, boss phases).

func decide_npc_action(round_count: int, player_pleasure: Node, npc_pleasure: Node) -> Dictionary:
	# Default standard strategy: randomly choose balanced skill
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
			
	return {
		"skill_id": chosen,
		"skill_name": skill_name,
		"raw_damage": raw_dmg,
		"target_zone": "mouth",
		"is_teaching_kill": false,
		"custom_log": ""
	}
