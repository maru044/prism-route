class_name CombatStrategy
extends RefCounted
## Strategy interface for NPC turn decisions in turn-based sensual combat.
## Allows plugging different combat AI routines (standard, teaching kill, berserk, boss phases).

func decide_npc_action(round_count: int, player_pleasure: Node, npc_pleasure: Node, reaction_resolver: RefCounted = null) -> Dictionary:
	var available_skills: Array = []
	if reaction_resolver != null and reaction_resolver.has_method("get_available_attack_skills"):
		available_skills = reaction_resolver.get_available_attack_skills()
		available_skills = available_skills.filter(func(s): return s != "teaching_kill")
		
	if available_skills.is_empty():
		available_skills = ["tongue", "deep_throat", "eye_contact"]
		
	var chosen: String = str(available_skills[randi() % available_skills.size()])
	var skill_data: Dictionary = {}
	if reaction_resolver != null and reaction_resolver.has_method("get_attack_skill_data"):
		skill_data = reaction_resolver.get_attack_skill_data(chosen)
		
	var fallback_names := {
		"tongue": "灵巧舌尖缠绕",
		"deep_throat": "柔情深喉吞吐",
		"eye_contact": "媚眼凝视与娇吟"
	}
	var fallback_damages := {
		"tongue": 15.0,
		"deep_throat": 18.0,
		"eye_contact": 16.0
	}
	var skill_name: String = str(skill_data.get("name", fallback_names.get(chosen, "灵动攻势")))
	var raw_dmg: float = float(skill_data.get("damage", fallback_damages.get(chosen, 16.0)))
	var target_zone: String = str(skill_data.get("target_zone", "mouth"))
	
	return {
		"skill_id": chosen,
		"skill_name": skill_name,
		"raw_damage": raw_dmg,
		"target_zone": target_zone,
		"is_teaching_kill": false,
		"custom_log": ""
	}
