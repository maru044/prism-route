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

func get_available_attack_skills() -> Array:
	return attack_lines.keys()

func get_attack_skill_data(action_id: String) -> Dictionary:
	return attack_lines.get(action_id, {})

func get_attack_line(action_id: String) -> Dictionary:
	var line_data: Dictionary = {}
	if attack_lines.has(action_id):
		line_data = attack_lines[action_id]
	elif not attack_lines.is_empty():
		var first_key: String = str(attack_lines.keys()[0])
		line_data = attack_lines[first_key]
	return {
		"speaker": speaker_name,
		"text": line_data.get("text", "看招！"),
		"emotion": line_data.get("emotion", "default"),
		"name": line_data.get("name", "灵巧攻势"),
		"damage": float(line_data.get("damage", 16.0))
	}
