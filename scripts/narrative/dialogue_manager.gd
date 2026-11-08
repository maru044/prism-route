class_name DialogueManager
extends Node
## Core manager for multi-choice, branch-rich narrative dialogues and meta-interactions.

signal dialogue_started(graph_id: String)
signal text_updated(speaker: String, text: String, emotion: String)
signal choices_presented(choices: Array)
signal dialogue_ended(finish_payload: Dictionary)
signal meta_rule_changed(rule_key: String, rule_value: Variant)

var current_graph: Dictionary = {}
var current_node_id: String = ""
var blackboard: Dictionary = {
	"master_name": "主人",
	"defeat_count": 0,
	"meta_cheat_enabled": false,
	"meta_cheat_mode": "none",
	"mercy_choice": "undecided"
}

func start_dialogue(graph_data: Dictionary, start_node: String = "start") -> void:
	current_graph = graph_data
	current_node_id = start_node
	dialogue_started.emit(current_graph.get("id", "unnamed_graph"))
	_process_current_node()

func choose_option(option_index: int) -> void:
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
		var act: String = selected_choice["action"]
		if act == "choose_kill":
			blackboard["mercy_choice"] = "kill"
		elif act == "choose_spare":
			blackboard["mercy_choice"] = "spare"
		dialogue_ended.emit({"action": act})
		return
			
	var next_node_id: String = selected_choice.get("target", "")
	if next_node_id.is_empty():
		dialogue_ended.emit({"action": "close"})
	else:
		current_node_id = next_node_id
		_process_current_node()

func advance_text() -> void:
	var node: Dictionary = current_graph.get("nodes", {}).get(current_node_id, {})
	if node.get("type", "text") == "choice":
		return # Cannot advance text while choices are active
		
	var next_id: String = node.get("next", "")
	if next_id.is_empty():
		var act: String = node.get("action", "close")
		dialogue_ended.emit({"action": act})
	else:
		current_node_id = next_id
		_process_current_node()

func _process_current_node() -> void:
	var nodes: Dictionary = current_graph.get("nodes", {})
	if not nodes.has(current_node_id):
		dialogue_ended.emit({"action": "close"})
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
