extends RefCounted
class_name LocalAirpComposer

const HISTORY_CAPACITY := 4

var sparkle_wildcards: Dictionary = {}
var keqing_wildcards: Dictionary = {}
var scenes_wildcards: Dictionary = {}
var character_wildcards: Dictionary = {}
var data_directory: String = "res://assets/ai/local_airp"
var slot_history: Dictionary = {}
var _slot_regex := RegEx.create_from_string(r"\{([a-zA-Z0-9_]+)\}")
var _double_punct_regex := RegEx.create_from_string(r"([，。！？~])\1+")
var _space_punct_regex := RegEx.create_from_string(r"\s+([，。！？~♡])")

func load_data(data_dir: String = "res://assets/ai/local_airp") -> void:
	data_directory = data_dir
	sparkle_wildcards = _load_json(data_dir.path_join("wildcards_sparkle.json"))
	keqing_wildcards = _load_json(data_dir.path_join("wildcards_keqing.json"))
	scenes_wildcards = _load_json(data_dir.path_join("wildcards_scenes.json"))
	character_wildcards["sparkle"] = sparkle_wildcards
	character_wildcards["keqing"] = keqing_wildcards

func get_character_data(character_id: String) -> Dictionary:
	if character_wildcards.has(character_id):
		return character_wildcards[character_id]
	var path := data_directory.path_join("wildcards_%s.json" % character_id)
	if FileAccess.file_exists(path):
		var custom_data := _load_json(path)
		if not custom_data.is_empty():
			character_wildcards[character_id] = custom_data
			return custom_data
	if character_id == "sparkle":
		return sparkle_wildcards
	elif character_id == "keqing":
		return keqing_wildcards
	return sparkle_wildcards

func _resolve_pool(character_id: String, pool_path: String) -> Array:
	var parts := pool_path.split(".")
	if parts.is_empty():
		return []
	var root := parts[0]
	var current: Variant
	if root == "character":
		current = get_character_data(character_id)
	elif root == "scene":
		current = scenes_wildcards
	else:
		return []
		
	for i in range(1, parts.size()):
		var key := parts[i]
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return []
			
	if current is Array:
		return current
	return []

func _pick_with_anti_repetition(pool_key: String, candidate_list: Array, rng: RandomNumberGenerator) -> String:
	if candidate_list.is_empty():
		return ""
	if candidate_list.size() == 1:
		return str(candidate_list[0])
		
	if not slot_history.has(pool_key):
		slot_history[pool_key] = []
	var recent: Array = slot_history[pool_key]
	
	var available: Array = []
	for item in candidate_list:
		if not recent.has(item):
			available.append(item)
			
	if available.is_empty():
		if not recent.is_empty():
			recent.pop_front()
		for item in candidate_list:
			if not recent.has(item):
				available.append(item)
		if available.is_empty():
			available = candidate_list
			
	var chosen_index := rng.randi_range(0, available.size() - 1)
	var chosen_val: String = str(available[chosen_index])
	
	recent.append(chosen_val)
	while recent.size() > HISTORY_CAPACITY:
		recent.pop_front()
		
	return chosen_val

func compose(template_obj: Dictionary, character_id: String, scene_id: String, context: Dictionary = {}, seed_val: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed_val >= 0:
		rng.seed = seed_val
	else:
		rng.randomize()
		
	var templates: Array = template_obj.get("templates", [])
	if templates.is_empty():
		return {"text": "", "reply_id": template_obj.get("reply_id", "")}
		
	var reply_id: String = template_obj.get("reply_id", "")
	var skeleton_key := "%s_%s_skeletons" % [character_id, reply_id]
	var template_str := _pick_with_anti_repetition(skeleton_key, templates, rng)
	
	var wildcard_slots: Dictionary = template_obj.get("wildcard_slots", {})
	var filled_slots: Dictionary = {}
	
	var matches := _slot_regex.search_all(template_str)
	for m in matches:
		var slot := m.get_string(1)
		if context.has(slot):
			filled_slots[slot] = str(context[slot])
			continue
			
		var pool_path: String = wildcard_slots.get(slot, "")
		if pool_path.is_empty():
			if slot == "address":
				pool_path = "character.addresses"
			elif slot == "dialogue_core":
				var content_tag: String = template_obj.get("content_tag", "greet")
				pool_path = "character.dialogues." + content_tag
			elif slot == "reaction":
				pool_path = "character.reactions_intimate" if scene_id == "intimate" else "character.reactions_home"
			elif slot == "body_action":
				pool_path = "character.actions_intimate" if scene_id == "intimate" else "character.actions_home"
			elif slot == "followup":
				pool_path = "character.followups_intimate" if scene_id == "intimate" else "character.followups_home"
			elif slot == "atmosphere":
				pool_path = "scene.intimate_atmosphere" if scene_id == "intimate" else "scene.home_atmosphere"
			else:
				pool_path = "character." + slot
				
		var pool := _resolve_pool(character_id, pool_path)
		var history_key := "%s_%s" % [character_id, pool_path]
		var chosen_val := _pick_with_anti_repetition(history_key, pool, rng)
		filled_slots[slot] = chosen_val
		
	var composed := template_str
	for k in filled_slots.keys():
		composed = composed.replace("{" + k + "}", filled_slots[k])
		
	composed = _sanitize_text(composed)
	
	return {
		"text": composed,
		"reply_id": reply_id,
		"character_id": character_id,
		"scene_id": scene_id,
		"template_skeleton": template_str,
		"slots_filled": filled_slots
	}

func _sanitize_text(text: String) -> String:
	var clean := text.strip_edges()
	clean = _double_punct_regex.sub(clean, "$1", true)
	clean = clean.replace("！~", "！").replace("~！", "！")
	clean = clean.replace("，！", "！").replace("，。", "。")
	clean = clean.replace("！，", "！").replace("？，", "？").replace("~，", "~ ")
	clean = clean.replace("  ", " ")
	clean = _space_punct_regex.sub(clean, "$1", true)
	if not clean.is_empty() and not clean[-1] in "。！？~♡":
		clean += "。"
	# Zero ellipses normalization
	clean = clean.replace("\u2026\u2026", "~ ")
	clean = clean.replace("\u2026", "~ ")
	clean = clean.replace("." + "." + ".", "~ ")
	return clean

func reset_history() -> void:
	slot_history.clear()

func _load_json(file_path: String) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_warning("Failed to open local AIRP file: " + file_path)
		return {}
	var text := file.get_as_text()
	var json_res: Variant = JSON.parse_string(text)
	if json_res is Dictionary:
		return json_res
	return {}
