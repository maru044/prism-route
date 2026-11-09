class_name DialogueManager
extends Node
## Core manager for multi-choice, branch-rich narrative dialogues and meta-interactions.

signal dialogue_started(graph_id: String)
signal text_updated(speaker: String, text: String, emotion: String)
signal choices_presented(choices: Array)
signal dialogue_ended(finish_payload: Dictionary)
signal meta_rule_changed(rule_key: String, rule_value: Variant)

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
const ACTION_CLOSE: String = "close"

const REGISTERED_ACTIONS: Dictionary = {
	ACTION_ENTER_COMBAT: true,
	ACTION_RESUME_COMBAT: true,
	ACTION_KILL: true,
	ACTION_SPARE: true,
	ACTION_CLOSE: true
}

const ACTION_ALIASES: Dictionary = {
	"choose_kill": ACTION_KILL,
	"choose_spare": ACTION_SPARE
}

var current_graph: Dictionary = {}
var current_node_id: String = ""
var current_source: DialogueSource = DialogueSource.WORLD_INTERACTION
var current_resume_policy: ResumePolicy = ResumePolicy.RETURN_TO_WORLD

var session_active: bool = false
var session_id: int = 0

var blackboard: Dictionary = {
	"master_name": "主人",
	"defeat_count": 0,
	"meta_cheat_enabled": false,
	"meta_cheat_mode": "none",
	"mercy_choice": "undecided"
}

func start_dialogue(
	graph_data: Dictionary,
	start_node: String = "start",
	source: DialogueSource = DialogueSource.WORLD_INTERACTION,
	policy: ResumePolicy = ResumePolicy.RETURN_TO_WORLD
) -> void:
	session_id += 1
	session_active = true
	current_graph = graph_data
	current_node_id = start_node
	current_source = source
	current_resume_policy = policy
	dialogue_started.emit(current_graph.get("id", "unnamed_graph"))
	_process_current_node()

func choose_option(option_index: int) -> void:
	if not session_active:
		return
		
	var node: Dictionary = current_graph.get("nodes", {}).get(current_node_id, {})
	var choices: Array = node.get("choices", [])
	if option_index < 0 or option_index >= choices.size():
		push_error("Invalid choice index: " + str(option_index))
		return
		
	var selected_choice: Dictionary = choices[option_index]
	
	# Execute optional choice payload or meta modification
	if selected_choice.has("set_blackboard"):
		var modifications: Dictionary = selected_choice["set_blackboard"]
		for k: String in modifications:
			blackboard[k] = modifications[k]
			meta_rule_changed.emit(k, modifications[k])
			
	if selected_choice.has("action"):
		var raw_act: String = selected_choice["action"]
		_finish_with_action(raw_act)
		return
			
	var next_node_id: String = selected_choice.get("target", "")
	if next_node_id.is_empty():
		_finish_with_action(ACTION_CLOSE)
	else:
		current_node_id = next_node_id
		_process_current_node()

func advance_text() -> void:
	if not session_active:
		return
		
	var node: Dictionary = current_graph.get("nodes", {}).get(current_node_id, {})
	if node.get("type", "text") == "choice":
		return # Cannot advance text while choices are active
		
	var next_id: String = node.get("next", "")
	if next_id.is_empty():
		var raw_act: String = node.get("action", ACTION_CLOSE)
		_finish_with_action(raw_act)
	else:
		current_node_id = next_id
		_process_current_node()

func _normalize_action(raw_act: String) -> String:
	if ACTION_ALIASES.has(raw_act):
		return ACTION_ALIASES[raw_act]
	return raw_act

func _finish_with_action(raw_act: String) -> void:
	if not session_active:
		return
	session_active = false
	
	var act: String = _normalize_action(raw_act)
	if not REGISTERED_ACTIONS.has(act):
		push_error("Dialogue action not registered: " + raw_act)
		
	if act == ACTION_KILL:
		blackboard["mercy_choice"] = "kill"
	elif act == ACTION_SPARE:
		blackboard["mercy_choice"] = "spare"
		
	var payload := {
		"action": act,
		"raw_action": raw_act,
		"source": current_source,
		"resume_policy": current_resume_policy,
		"session_id": session_id
	}
	dialogue_ended.emit(payload)

func _process_current_node() -> void:
	var nodes: Dictionary = current_graph.get("nodes", {})
	if not nodes.has(current_node_id):
		_finish_with_action(ACTION_CLOSE)
		return
		
	var node: Dictionary = nodes[current_node_id]
	var node_type: String = node.get("type", "text")
	
	var speaker: String = node.get("speaker", "旁白")
	var raw_text: String = node.get("text", "")
	var emotion: String = node.get("emotion", "default")
	var interpolated_text: String = _interpolate_variables(raw_text)
	
	if node_type == "text":
		text_updated.emit(speaker, interpolated_text, emotion)
	elif node_type == "choice":
		text_updated.emit(speaker, interpolated_text, emotion)
		var choices: Array = node.get("choices", [])
		choices_presented.emit(choices)

func _interpolate_variables(text: String) -> String:
	var result: String = text
	for k: String in blackboard:
		var tag: String = "{" + k + "}"
		if tag in result:
			result = result.replace(tag, str(blackboard[k]))
	return result
