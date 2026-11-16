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

## 4-Tier variable scopes:
## 1. session_variables: strictly ephemeral to this specific dialogue execution
var session_variables: Dictionary = {}
## 2. encounter_context: reference to current encounter state (read/write delegated)
var encounter_context: Dictionary = {}
## 3. character_context: reference to character relationships/unlocks
var character_context: Dictionary = {}
## 4. world_context: global world flags
var world_context: Dictionary = {}

func _init(p_id: int, p_graph: Dictionary, p_start: String, p_source: int = 0, p_policy: int = 0) -> void:
	session_id = p_id
	graph = p_graph
	current_node_id = p_start
	source = p_source
	resume_policy = p_policy
	is_active = true

func get_variable(key: String, default_val: Variant = null) -> Variant:
	if session_variables.has(key):
		return session_variables[key]
	if encounter_context.has(key):
		return encounter_context[key]
	if character_context.has(key):
		return character_context[key]
	if world_context.has(key):
		return world_context[key]
	return default_val

func set_session_variable(key: String, value: Variant) -> void:
	session_variables[key] = value

func interpolate(text: String) -> String:
	var result: String = text
	# Interpolate session variables first
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
