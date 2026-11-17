class_name DialogueSession
extends RefCounted
## Isolated runtime session for an active dialogue instance.
## Encapsulates session-local variables, graph state, and execution tokens to prevent state leakage.

var session_id: int = 0
var character_id: String = ""
var encounter_id: String = ""
var graph: Dictionary = {}
var current_node_id: String = ""
var source: int = 0
var resume_policy: int = 0
var is_active: bool = false
var is_waiting_action: bool = false

## 4-Tier variable scopes:
## 1. session_variables: strictly ephemeral to this specific dialogue execution
var session_variables: Dictionary = {}
## 2. encounter_context: reference to current encounter state (read/write delegated)
var encounter_context: Dictionary = {}
## 3. character_context: reference to character relationships/unlocks
var character_context: Dictionary = {}
## 4. world_context: global world flags (isolated snapshot / read-through)
var world_context: Dictionary = {}

func _init(
	p_id: int,
	p_graph: Dictionary,
	p_start: String,
	p_source: int = 0,
	p_policy: int = 0,
	p_character_id: String = "",
	p_encounter_id: String = "",
	p_encounter_context: Dictionary = {},
	p_character_context: Dictionary = {},
	p_world_context: Dictionary = {}
) -> void:
	session_id = p_id
	graph = p_graph
	current_node_id = p_start
	source = p_source
	resume_policy = p_policy
	character_id = p_character_id
	encounter_id = p_encounter_id
	encounter_context = p_encounter_context.duplicate(true)
	character_context = p_character_context.duplicate(true)
	world_context = p_world_context.duplicate(true)
	is_active = true
	is_waiting_action = false

func has_variable(key: String) -> bool:
	if key.begins_with("session."):
		return session_variables.has(key.substr(8))
	elif key.begins_with("encounter."):
		return encounter_context.has(key.substr(10))
	elif key.begins_with("character."):
		return character_context.has(key.substr(10))
	elif key.begins_with("world."):
		return world_context.has(key.substr(6))
	return session_variables.has(key) or encounter_context.has(key) or character_context.has(key) or world_context.has(key)

func get_variable(key: String, default_val: Variant = null) -> Variant:
	# 1. Prefix checking
	if key.begins_with("session."):
		return session_variables.get(key.substr(8), default_val)
	elif key.begins_with("encounter."):
		return encounter_context.get(key.substr(10), default_val)
	elif key.begins_with("character."):
		return character_context.get(key.substr(10), default_val)
	elif key.begins_with("world."):
		return world_context.get(key.substr(6), default_val)
		
	# 2. Scope hierarchy: session -> encounter -> character -> world
	if session_variables.has(key):
		return session_variables[key]
	if encounter_context.has(key):
		return encounter_context[key]
	if character_context.has(key):
		return character_context[key]
	if world_context.has(key):
		return world_context[key]
	return default_val

func set_variable(key: String, value: Variant, scope: String = "") -> void:
	# 1. Explicit scope parameter
	if scope == "session":
		session_variables[key] = value
		return
	elif scope == "encounter":
		encounter_context[key] = value
		return
	elif scope == "character":
		character_context[key] = value
		return
	elif scope == "world":
		world_context[key] = value
		return

	# 2. Scope prefix in key (e.g. "session.foo", "world.bar")
	if key.begins_with("session."):
		session_variables[key.substr(8)] = value
		return
	elif key.begins_with("encounter."):
		encounter_context[key.substr(10)] = value
		return
	elif key.begins_with("character."):
		character_context[key.substr(10)] = value
		return
	elif key.begins_with("world."):
		world_context[key.substr(6)] = value
		return

	# 3. Default resolution: session -> encounter -> character
	# CRITICAL: Never write to world_context unless explicitly requested!
	if session_variables.has(key):
		session_variables[key] = value
	elif encounter_context.has(key):
		encounter_context[key] = value
	elif character_context.has(key):
		character_context[key] = value
	else:
		if not encounter_id.is_empty():
			encounter_context[key] = value
		else:
			session_variables[key] = value

func set_session_variable(key: String, value: Variant) -> void:
	session_variables[key] = value

func interpolate(text: String) -> String:
	var result: String = text
	# Interpolate session variables first, then encounter, character, world
	for k: String in session_variables:
		var tag := "{" + k + "}"
		if tag in result:
			result = result.replace(tag, str(session_variables[k]))
	for k: String in encounter_context:
		var tag := "{" + k + "}"
		if tag in result:
			result = result.replace(tag, str(encounter_context[k]))
	for k: String in character_context:
		var tag := "{" + k + "}"
		if tag in result:
			result = result.replace(tag, str(character_context[k]))
	for k: String in world_context:
		var tag := "{" + k + "}"
		if tag in result:
			result = result.replace(tag, str(world_context[k]))
	return result
