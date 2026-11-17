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

const FLOW_ADAPTERS := {
	"sparkle_temple_flow": "res://scripts/world/initial_temple_encounter_controller.gd",
	"standard_duel": "res://scripts/world/npc_world_duel.gd",
}
const COMBAT_STRATEGIES := {
	"standard": preload("res://scripts/combat/combat_strategy.gd"),
	"sparkle_tutorial": preload("res://scripts/combat/sparkle_tutorial_strategy.gd"),
}

static var _combat: Dictionary = {}
static var _avatars: Dictionary = {}
static var _presentation: Dictionary = {}

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
	_combat.clear()
	_avatars.clear()
	_presentation.clear()

	_load_json_dir(CHARACTER_DIR, _characters, "character_id")
	_load_json_dir(SPAWN_DIR, _spawns, "spawn_id")
	_load_json_dir(ENCOUNTER_DIR, _encounters, "encounter_id")
	_load_dialogues_recursive(DIALOGUE_DIR)
	_load_json_dir(REACTION_DIR, _reactions, "reaction_profile_id")
	_load_json_dir(MOTION_DIR, _motions, "motion_profile_id")
	_load_json_dir("res://assets/npc/combat", _combat, "combat_profile_id")
	_load_json_dir("res://assets/npc/avatars", _avatars, "avatar_profile_id")
	_load_json_dir("res://assets/npc/presentation", _presentation, "presentation_profile_id")
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

static func get_combat_profile(profile_id: String) -> Dictionary:
	ensure_initialized()
	return _combat.get(profile_id, {})

static func get_persona(persona_id: String) -> Dictionary:
	ensure_initialized()
	return _personas.get(persona_id, {})

static func create_strategy(profile: Dictionary) -> RefCounted:
	var strategy_script: Script = COMBAT_STRATEGIES.get(profile.get("strategy_id", ""))
	if strategy_script == null:
		return null
	var strategy: RefCounted = strategy_script.new()
	strategy.configure(profile)
	return strategy

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

	if spawn_def.get("character_id") != char_id:
		return {"valid": false, "error": "Spawn character mismatch: " + spawn_id}
	var reaction_profile := get_reaction_profile(reaction_id)
	var motion_profile := get_motion_profile(motion_id)
	var combat_profile := get_combat_profile(encounter_def.get("combat_profile_id", ""))
	var avatar: Dictionary = _avatars.get(char_def.get("avatar_profile_id"), {})
	var presentation: Dictionary = _presentation.get(char_def.get("presentation_profile_id"), {})
	var flow_path: String = FLOW_ADAPTERS.get(encounter_def.get("flow_behavior_id"), "")
	var persona := get_persona(char_def.get("persona_id", ""))
	if reaction_profile.is_empty() or motion_profile.is_empty() or combat_profile.is_empty() or avatar.is_empty() or presentation.is_empty() or persona.is_empty() or flow_path.is_empty():
		return {"valid": false, "error": "Missing dependent profile or flow adapter: " + encounter_id}
	if not COMBAT_STRATEGIES.has(combat_profile.get("strategy_id")):
		return {"valid": false, "error": "Unknown combat strategy: " + encounter_id}

	return {
		"valid": true,
		"encounter_id": encounter_id,
		"identity": {"character_id": char_id, "spawn_id": spawn_id, "encounter_id": encounter_id},
		"combat": combat_profile,
		"avatar": avatar,
		"presentation": presentation,
		"flow_path": flow_path,
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
			var primary_id = data.get(id_key)
			if primary_id is String and not primary_id.is_empty():
				target_dict[primary_id] = data

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
				var graph_id = data.get("graph_id")
				if graph_id is String and not graph_id.is_empty():
					_dialogue_bundles[graph_id] = data
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
