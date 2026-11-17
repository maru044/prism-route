class_name DialogueManager
extends Node
## Core manager for multi-choice, branch-rich narrative dialogues and meta-interactions.
## Supports isolated DialogueSessions, Choice Providers, and Action Handlers via ActionRegistry.

signal dialogue_started(graph_id: String)
signal text_updated(speaker: String, text: String, emotion: String)
signal choices_presented(choices: Array)
signal dialogue_ended(finish_payload: Dictionary)
signal meta_rule_changed(rule_key: String, rule_value: Variant)
signal action_failed(action_id: String, result: Dictionary)

enum DialogueSource {
	WORLD_INTERACTION,
	MID_BATTLE_MANUAL,
	MID_BATTLE_EDGING,
	POST_BATTLE_RESULT
}

enum ResumePolicy {
	SAME_TURN,      # Return to current player turn
	NEXT_TURN,      # Advance to next round
	END_COMBAT,     # Conclude combat and transition to settlement
	RETURN_TO_WORLD # Free roaming in overworld
}

const ACTION_ENTER_COMBAT: String = "enter_combat"
const ACTION_RESUME_COMBAT: String = "resume_combat"
const ACTION_KILL: String = "kill"
const ACTION_SPARE: String = "spare"
const ACTION_SPARE_VIRGIN: String = "spare_virgin"
const ACTION_SPARE_HONBAN: String = "spare_honban"
const ACTION_FINISH_SERVICE: String = "finish_service"
const ACTION_CLOSE: String = "close"

const DialogueSessionClass := preload("res://scripts/narrative/dialogue_session.gd")
const ActionRegistryClass := preload("res://scripts/narrative/action_registry.gd")

var current_session: RefCounted
var current_graph: Dictionary:
	get: return current_session.graph if current_session else {}
	set(val):
		if current_session: current_session.graph = val
var current_node_id: String:
	get: return current_session.current_node_id if current_session else ""
	set(val):
		if current_session: current_session.current_node_id = val
var current_source: DialogueSource:
	get: return (current_session.source as DialogueSource) if current_session else DialogueSource.WORLD_INTERACTION
	set(val):
		if current_session: current_session.source = val
var current_resume_policy: ResumePolicy:
	get: return (current_session.resume_policy as ResumePolicy) if current_session else ResumePolicy.RETURN_TO_WORLD
	set(val):
		if current_session: current_session.resume_policy = val

var session_active: bool:
	get: return (current_session.is_active if current_session else false)
	set(val):
		if not val:
			cancel_session(false)
		elif current_session:
			current_session.is_active = val
var session_id: int = 0

## Extensible registries
var action_registry: ActionRegistryClass
var choice_providers: Dictionary = {}

## Blackboard: persistent global world state
var blackboard: Dictionary = {
	"master_name": "主人",
	"defeat_count": 0,
	"meta_cheat_enabled": false,
	"meta_cheat_mode": "none",
	"edging_endure": false,
	"mercy_choice": "undecided"
}

func _init() -> void:
	action_registry = ActionRegistryClass.new()

func register_action(
	action_id: String,
	handler: Callable = Callable(),
	is_async: bool = false,
	required_params: Array[String] = [],
	validator: Callable = Callable(),
	param_types: Dictionary = {},
	timeout_seconds: float = 30.0
) -> void:
	action_registry.register_action(action_id, handler, is_async, required_params, validator, param_types, timeout_seconds)

func register_choice_provider(provider_id: String, provider: Callable) -> void:
	choice_providers[provider_id] = provider

func consume_battle_cheats() -> Dictionary:
	var cheats := {
		"meta_cheat_enabled": current_session.get_variable("meta_cheat_enabled", false) if current_session else blackboard.get("meta_cheat_enabled", false),
		"meta_cheat_mode": current_session.get_variable("meta_cheat_mode", "none") if current_session else blackboard.get("meta_cheat_mode", "none"),
		"edging_endure": current_session.get_variable("edging_endure", false) if current_session else blackboard.get("edging_endure", false)
	}
	if current_session:
		current_session.set_variable("meta_cheat_enabled", false, "encounter")
		current_session.set_variable("meta_cheat_mode", "none", "encounter")
		current_session.set_variable("edging_endure", false, "encounter")
	return cheats

func reset_battle_cheats() -> void:
	if current_session:
		current_session.set_variable("meta_cheat_enabled", false, "encounter")
		current_session.set_variable("meta_cheat_mode", "none", "encounter")
		current_session.set_variable("edging_endure", false, "encounter")

func get_variable(key: String, default_val: Variant = null) -> Variant:
	if current_session:
		return current_session.get_variable(key, default_val)
	return blackboard.get(key, default_val)

func set_variable(key: String, value: Variant, scope: String = "") -> void:
	if current_session:
		current_session.set_variable(key, value, scope)
		# Only synchronize to global blackboard if explicitly marked as world scope
		if scope == "world" or key.begins_with("world."):
			blackboard[key.trim_prefix("world.")] = value
	else:
		blackboard[key] = value

func has_variable(key: String) -> bool:
	if current_session:
		return current_session.has_variable(key)
	return blackboard.has(key)

func interpolate(text: String) -> String:
	if current_session:
		return current_session.interpolate(text)
	var res := text
	for k: String in blackboard:
		res = res.replace("{" + k + "}", str(blackboard[k]))
	return res

func start_dialogue(
	graph_data: Dictionary,
	start_node: String = "start",
	source: DialogueSource = DialogueSource.WORLD_INTERACTION,
	policy: ResumePolicy = ResumePolicy.RETURN_TO_WORLD,
	p_encounter_context: Dictionary = {},
	p_character_context: Dictionary = {},
	p_world_context: Dictionary = {},
	identity: Dictionary = {}
) -> void:
	cancel_session(false)
	session_id += 1
	var char_id: String = identity.get("character_id", graph_data.get("character_id", ""))
	var enc_id: String = identity.get("encounter_id", graph_data.get("encounter_id", ""))

	var effective_world: Dictionary = blackboard.duplicate(true)
	if not p_world_context.is_empty():
		for k in p_world_context:
			effective_world[k] = p_world_context[k]

	current_session = DialogueSessionClass.new(
		session_id,
		graph_data,
		start_node,
		source,
		policy,
		char_id,
		enc_id,
		p_encounter_context,
		p_character_context,
		effective_world,
		identity.get("spawn_id", graph_data.get("spawn_id", ""))
	)

	var started := current_session
	var graph_id: String = current_graph.get("graph_id", current_graph.get("id", "unnamed_graph"))
	dialogue_started.emit(graph_id)
	if current_session == started and session_active:
		_process_current_node()

func cancel_session(notify := true) -> void:
	if current_session == null:
		return
	var session := current_session
	var was_active: bool = session.is_active
	session.is_active = false
	session.is_waiting_action = false
	session.session_variables.clear()
	action_registry.cancel_session(session.session_id)
	if notify and was_active and current_session == session:
		dialogue_ended.emit({
			"action": ACTION_CLOSE, "raw_action": ACTION_CLOSE, "source": session.source,
			"resume_policy": session.resume_policy, "session_id": session.session_id, "cancelled": true,
		})

func _exit_tree() -> void:
	cancel_session(false)

func choose_option(option_index: int) -> void:
	if not session_active or (current_session and current_session.is_waiting_action):
		return

	var node: Dictionary = current_graph.get("nodes", {}).get(current_node_id, {})
	var choices: Array = _get_processed_choices(node)
	if option_index < 0 or option_index >= choices.size():
		push_error("Invalid choice index: " + str(option_index))
		return

	var selected_choice: Dictionary = choices[option_index]

	# Execute optional choice payload or scoped variable modification
	if selected_choice.has("set_blackboard"):
		var modifications: Dictionary = selected_choice["set_blackboard"]
		for k: String in modifications:
			var val = modifications[k]
			set_variable(k, val)
			meta_rule_changed.emit(k, val)

	if selected_choice.has("action"):
		var raw_act: String = selected_choice["action"]
		var act_params: Dictionary = selected_choice.get("action_params", {})
		_execute_action(raw_act, act_params)
		return

	var next_node_id: String = selected_choice.get("target", "")
	if next_node_id.is_empty():
		_execute_action(ACTION_CLOSE)
	else:
		current_node_id = next_node_id
		_process_current_node()

func advance_text() -> void:
	if not session_active or (current_session and current_session.is_waiting_action):
		return

	var node: Dictionary = current_graph.get("nodes", {}).get(current_node_id, {})
	if node.get("type", "text") == "choice":
		return # Cannot advance text while choices are active

	var next_id: String = node.get("next", "")
	if next_id.is_empty():
		var raw_act: String = node.get("action", ACTION_CLOSE)
		var act_params: Dictionary = node.get("action_params", {})
		_execute_action(raw_act, act_params)
	else:
		current_node_id = next_id
		_process_current_node()

func _execute_action(raw_act: String, params: Dictionary = {}) -> void:
	if not session_active:
		return

	var owner := current_session
	owner.is_waiting_action = true

	var act_context := {
		"manager": self,
		"session": current_session,
		"session_id": owner.session_id,
		"spawn_id": owner.spawn_id,
		"tree": get_tree() if is_inside_tree() else null,
		"character_id": current_session.character_id if current_session else "",
		"encounter_id": current_session.encounter_id if current_session else "",
		"raw_action": raw_act,
		"source": current_source,
		"resume_policy": current_resume_policy
	}

	action_registry.execute_action(
		raw_act,
		params,
		act_context,
		_on_action_completed.bind(raw_act, owner.session_id)
	)

func _on_action_completed(status: int, result: Dictionary, raw_act: String, owner_id: int) -> void:
	if not session_active or current_session.session_id != owner_id or result.get("session_id") != owner_id:
		return
	var owner := current_session
	owner.is_waiting_action = false
	owner.is_active = false
	var canonical: String = action_registry.resolve_action_id(raw_act)

	if status == ActionRegistryClass.ActionStatus.SUCCEEDED:
		if canonical == ACTION_KILL:
			owner.set_variable("mercy_choice", "kill", "encounter")
		elif canonical in [ACTION_SPARE, ACTION_SPARE_VIRGIN, ACTION_SPARE_HONBAN]:
			owner.set_variable("mercy_choice", canonical, "encounter")

		var payload := {
			"action": canonical,
			"raw_action": raw_act,
			"source": current_source,
			"resume_policy": current_resume_policy,
			"session_id": session_id,
			"result": result
		}
		dialogue_ended.emit(payload)
	else:
		var payload := {
			"action": ACTION_CLOSE,
			"raw_action": raw_act,
			"source": current_source,
			"resume_policy": current_resume_policy,
			"session_id": session_id,
			"failed": true,
			"error": result.get("error", "action_failed")
		}
		action_failed.emit(raw_act, result)
		if current_session == owner:
			dialogue_ended.emit(payload)

func _get_processed_choices(node: Dictionary) -> Array:
	var base_choices: Array = node.get("choices", []).duplicate(true)
	var provider_id: String = node.get("choice_provider_id", "")
	if not provider_id.is_empty() and choice_providers.has(provider_id):
		var dynamic_choices: Array = choice_providers[provider_id].call(current_session)
		for c in dynamic_choices:
			base_choices.append(c)
	return base_choices

func _process_current_node() -> void:
	var nodes: Dictionary = current_graph.get("nodes", {})
	if not nodes.has(current_node_id):
		_execute_action(ACTION_CLOSE)
		return

	var node: Dictionary = nodes[current_node_id]
	var node_type: String = node.get("type", "text")

	var speaker: String = node.get("speaker", "旁白")
	var raw_text: String = node.get("text", "")
	var emotion: String = node.get("emotion", "default")
	var interpolated_text: String = current_session.interpolate(raw_text) if current_session else raw_text

	if node_type == "text":
		text_updated.emit(speaker, interpolated_text, emotion)
	elif node_type == "choice":
		text_updated.emit(speaker, interpolated_text, emotion)
		var choices: Array = _get_processed_choices(node)
		choices_presented.emit(choices)
	elif node_type == "command":
		if node.has("action"):
			var raw_act: String = node["action"]
			var act_params: Dictionary = node.get("action_params", {})
			_execute_action(raw_act, act_params)
		else:
			current_node_id = node.get("next", "")
			_process_current_node()
