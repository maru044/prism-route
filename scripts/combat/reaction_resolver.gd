class_name ReactionResolver
extends RefCounted
## Event-driven resolver for in-combat NPC koujou, zone reactions, and skill lines.
## Decouples combat engine from character-specific text.

var speaker_name: String = "NPC"
var zones: Dictionary = {}
var attack_lines: Dictionary = {}

func _init(p_profile: Dictionary = {}) -> void:
	load_profile(p_profile)

func load_profile(profile: Dictionary) -> void:
	if profile.is_empty():
		return
	speaker_name = profile.get("speaker", "NPC")
	zones = profile.get("zones", {})
	attack_lines = profile.get("attack_lines", {})

func get_zone_reaction(zone: String, pleasure_pct: float) -> Dictionary:
	var tier := "low"
	if pleasure_pct >= 75.0:
		tier = "high"
	elif pleasure_pct >= 40.0:
		tier = "mid"
		
	var zone_dict: Dictionary = zones.get(zone, zones.get("clitoris", {}))
	var line_data: Dictionary = zone_dict.get(tier, zone_dict.get("low", {}))
	
	return {
		"speaker": speaker_name,
		"text": line_data.get("text", "哈啊……好舒服……"),
		"emotion": line_data.get("emotion", "default")
	}

func get_attack_line(action_id: String) -> Dictionary:
	var line_data: Dictionary = attack_lines.get(action_id, attack_lines.get("tongue", {}))
	return {
		"speaker": speaker_name,
		"text": line_data.get("text", "嘻嘻，轮到我进攻咯！"),
		"emotion": line_data.get("emotion", "smirk")
	}
