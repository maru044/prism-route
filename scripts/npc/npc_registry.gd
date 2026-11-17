class_name NPCRegistry
extends RefCounted
## Universal registry and assembler for 3-tier NPC architecture:
## Character (Identity/Persona) + Spawn (World Placement/Furniture) + Encounter (Lifecycle/Dialogue/Combat/Motions).

const CHARACTER_DIR := "res://assets/npc/characters"
const SPAWN_DIR := "res://assets/npc/spawns"
const ENCOUNTER_DIR := "res://assets/npc/encounters"
const DIALOGUE_DIR := "res://assets/npc/dialogue"
const REACTION_DIR := "res://assets/npc/reactions"
const MOTION_DIR := "res://assets/npc/motions"
const PERSONA_DIR := "res://assets/ai/personas"

static var _characters: Dictionary = {}
static var _spawns: Dictionary = {}
static var _encounters: Dictionary = {}
static var _dialogue_bundles: Dictionary = {}
static var _reactions: Dictionary = {}
static var _motions: Dictionary = {}
static var _personas: Dictionary = {}
static var _is_initialized: bool = false

static func ensure_initialized() -> void:
	if not _is_initialized:
		reload_all()

static func reload_all() -> void:
	_characters.clear()
	_spawns.clear()
	_encounters.clear()
	_dialogue_bundles.clear()
	_reactions.clear()
	_motions.clear()
	_personas.clear()

	_load_json_dir(CHARACTER_DIR, _characters, "character_id")
	_load_json_dir(SPAWN_DIR, _spawns, "spawn_id")
	_load_json_dir(ENCOUNTER_DIR, _encounters, "encounter_id")
	_load_dialogues_recursive(DIALOGUE_DIR)
	_load_json_dir(REACTION_DIR, _reactions, "reaction_profile_id")
	_load_json_dir(MOTION_DIR, _motions, "motion_profile_id")
	_load_personas(PERSONA_DIR)

	_is_initialized = true

static func get_character(character_id: String) -> Dictionary:
	ensure_initialized()
	return _characters.get(character_id, {})

static func get_spawn(spawn_id: String) -> Dictionary:
	ensure_initialized()
	return _spawns.get(spawn_id, {})

static func get_encounter(encounter_id: String) -> Dictionary:
	ensure_initialized()
	return _encounters.get(encounter_id, {})

static func get_dialogue_bundle(bundle_id: String) -> Dictionary:
	ensure_initialized()
	return _dialogue_bundles.get(bundle_id, {})

static func get_reaction_profile(profile_id: String) -> Dictionary:
	ensure_initialized()
	return _reactions.get(profile_id, {})

static func get_motion_profile(profile_id: String) -> Dictionary:
	ensure_initialized()
	return _motions.get(profile_id, {})

static func get_persona(persona_id: String) -> Dictionary:
	ensure_initialized()
	return _personas.get(persona_id, {})

## Assembles a complete composite runtime bundle for an encounter by 3-tier IDs
static func assemble_encounter(encounter_id: String) -> Dictionary:
	ensure_initialized()

	var encounter_def := get_encounter(encounter_id)
	if encounter_def.is_empty():
		return {"valid": false, "error": "Encounter definition not found: " + encounter_id}

	var char_id: String = encounter_def.get("character_id", "")
	var spawn_id: String = encounter_def.get("spawn_id", "")
	var bundle_id: String = encounter_def.get("dialogue_bundle_id", "")
	var reaction_id: String = encounter_def.get("reaction_profile_id", "")
	var motion_id: String = encounter_def.get("motion_profile_id", "")

	var char_def := get_character(char_id)
	if char_def.is_empty():
		return {"valid": false, "error": "Character definition not found: " + char_id}

	var spawn_def := get_spawn(spawn_id)
	if spawn_def.is_empty():
		return {"valid": false, "error": "Spawn definition not found: " + spawn_id}

	var dialogue_bundle := get_dialogue_bundle(bundle_id)
	if dialogue_bundle.is_empty():
		return {"valid": false, "error": "Dialogue bundle not found: " + bundle_id}

	var reaction_profile := get_reaction_profile(reaction_id) if not reaction_id.is_empty() else {}
	var motion_profile := get_motion_profile(motion_id) if not motion_id.is_empty() else {}

	return {
		"valid": true,
		"encounter_id": encounter_id,
		"encounter": encounter_def,
		"character": char_def,
		"spawn": spawn_def,
		"dialogue": dialogue_bundle,
		"reactions": reaction_profile,
		"motions": motion_profile
	}

# Internal loaders
static func _load_json_dir(dir_path: String, target_dict: Dictionary, id_key: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var da := DirAccess.open(dir_path)
	if da == null:
		return
	for file in da.get_files():
		if not file.ends_with(".json"):
			continue
		var full_path := dir_path + "/" + file
		var text := FileAccess.get_file_as_string(full_path)
		var json := JSON.new()
		if json.parse(text) == OK and json.data is Dictionary:
			var data: Dictionary = json.data
			var primary_id: String = data.get(id_key, "")
			if primary_id.is_empty():
				primary_id = file.get_basename()
			target_dict[primary_id] = data
			var base_name := file.get_basename()
			if base_name != primary_id:
				target_dict[base_name] = data

static func _load_dialogues_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var da := DirAccess.open(path)
	if da == null:
		return
	for file in da.get_files():
		if file.ends_with(".json"):
			var full_path := path + "/" + file
			var text := FileAccess.get_file_as_string(full_path)
			var json := JSON.new()
			if json.parse(text) == OK and json.data is Dictionary:
				var data: Dictionary = json.data
				var graph_id: String = data.get("graph_id", data.get("id", file.get_basename()))
				_dialogue_bundles[graph_id] = data
				var base_name := file.get_basename()
				if base_name != graph_id:
					_dialogue_bundles[base_name] = data
	for sub in da.get_directories():
		_load_dialogues_recursive(path + "/" + sub)

static func _load_personas(dir_path: String) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var da := DirAccess.open(dir_path)
	if da == null:
		return
	for file in da.get_files():
		if not file.ends_with(".md"):
			continue
		var full_path := dir_path + "/" + file
		var raw := FileAccess.get_file_as_string(full_path).trim_prefix("\ufeff").replace("\r\n", "\n")
		var sep := raw.find("\n---")
		if sep >= 0:
			var json := JSON.new()
			if json.parse(raw.left(sep)) == OK and json.data is Dictionary:
				var header: Dictionary = json.data
				var persona_id: String = file.get_basename()
				_personas[persona_id] = {
					"header": header,
					"body": raw.substr(sep + 4).strip_edges(),
					"path": full_path
				}
				# Also map <character_id>_persona if name given
				_personas[persona_id + "_persona"] = _personas[persona_id]
