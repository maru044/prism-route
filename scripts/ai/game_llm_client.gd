extends Node

signal changed

const Transport := preload("res://scripts/ai/chat_transport.gd")
const SETTINGS_PATH := "user://llm_client.cfg"
const DIALOGUE_CONFIG_PATH := "res://assets/ai/reborn.json"
const DIALOGUE := "dialogue"
const ASSISTANT := "assistant"
const MAX_TOOL_ROUNDS := 3
const TOOLS := [
	{
		"type": "function",
		"function": {
			"name": "get_world_status",
			"description": "Read the current actor, location and preview destinations.",
			"parameters": {"type": "object", "properties": {}, "additionalProperties": false},
		},
	},
	{
		"type": "function",
		"function": {
			"name": "propose_teleport",
			"description": "Offer a preview destination for the player to confirm. Use its exact ID from get_world_status.",
			"parameters": {
				"type": "object", "properties": {"destination_id": {"type": "string"}},
				"required": ["destination_id"], "additionalProperties": false,
			},
		},
	},
]

var profiles := {
	DIALOGUE: {"url": "", "model": "gemini-4-argon", "key": ""},
	ASSISTANT: {"url": "", "model": "gemini-3.8-flash", "key": ""},
}
var route := ASSISTANT
var context: Dictionary
var history: Array
var pending := false
var partial := ""
var status := ""
var world_status: Callable
var world_teleport: Callable

var _transport = Transport.new()
var _threads := {}
var _request_messages: Array
var _operation := ""
var _tool_rounds := 0
var _proposed_destination := ""
var _dialogue_generation: Dictionary
var _dialogue_merge := true

func _ready() -> void:
	add_child(_transport)
	_transport.delta_received.connect(_receive_delta)
	_transport.finished.connect(_receive_result)
	_load_dialogue_config()
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		for channel: String in profiles:
			for field in ["url", "model", "key"]:
				profiles[channel][field] = str(config.get_value(channel, field, profiles[channel][field]))

func _load_dialogue_config() -> void:
	var preset: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIALOGUE_CONFIG_PATH))
	if not preset is Dictionary or not preset.get("generation") is Dictionary:
		return
	var generation: Dictionary = preset.generation
	for field in ["temperature", "top_p", "max_tokens"]:
		var value: Variant = generation.get(field)
		if value is float or value is int:
			_dialogue_generation[field] = int(value) if field == "max_tokens" else value
	var processing: Dictionary = preset.get("spreset", {}).get("message_processing", {})
	_dialogue_merge = bool(processing.get("enabled", true)) and processing.get("mode", "merge") == "merge"

func save_profile(channel: String, url: String, model: String, key: String, remember_key: bool) -> String:
	if Transport.endpoint(url).is_empty() or model.strip_edges().is_empty():
		return "请填写有效的接口地址和模型 ID。"
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(channel, "url", url.strip_edges())
	config.set_value(channel, "model", model.strip_edges())
	config.set_value(channel, "key", key.strip_edges() if remember_key else "")
	if config.save(SETTINGS_PATH) != OK:
		return "无法写入本机连接设置。"
	profiles[channel] = {"url": url.strip_edges(), "model": model.strip_edges(), "key": key.strip_edges()}
	return ""

func open(channel: String, scope: String, speaker_context: Dictionary) -> void:
	stop()
	route = channel
	context = speaker_context
	var thread_id := channel + "/" + scope
	if not _threads.has(thread_id):
		_threads[thread_id] = []
	history = _threads[thread_id]
	status = ""
	changed.emit()

func configured() -> bool:
	return not profiles[route].url.is_empty() and not profiles[route].model.is_empty()

func send(text: String) -> bool:
	if pending or text.strip_edges().is_empty() or not _can_start():
		return false
	history.append({
		"user": text, "replies": [], "active": -1, "offer": "", "tool_used": false,
	})
	_start("send")
	return true

func retry() -> void:
	if pending or history.is_empty() or history.back().tool_used or not _can_start():
		return
	_start("retry")

func continue_reply() -> void:
	if route != DIALOGUE or pending or active_reply().is_empty() or not _can_start():
		return
	_start("continue")

func undo() -> Variant:
	if pending or history.is_empty():
		return null
	var removed: Dictionary = history.pop_back()
	status = ""
	changed.emit()
	return removed.user

func swipe(step: int) -> void:
	if pending or history.is_empty():
		return
	var turn: Dictionary = history.back()
	if turn.replies.size() < 2:
		return
	turn.active = wrapi(turn.active + step, 0, turn.replies.size())
	changed.emit()

func active_reply() -> Dictionary:
	if history.is_empty():
		return {}
	var turn: Dictionary = history.back()
	return turn.replies[turn.active] if turn.active >= 0 else {}

func is_continuing() -> bool:
	return pending and _operation == "continue"

func stop() -> void:
	if pending:
		_transport.cancel()
		_complete("已停止")

func _can_start() -> bool:
	if not configured():
		status = "请先配置这个入口的模型。"
	else:
		return true
	changed.emit()
	return false

func _start(operation: String) -> void:
	_operation = operation
	partial = ""
	status = "等待模型。"
	_tool_rounds = 0
	_proposed_destination = ""
	var messages: Array = []
	for i in history.size():
		var turn: Dictionary = history[i]
		messages.append({"role": "user", "content": turn.user})
		var include_reply := i < history.size() - 1 or operation == "continue"
		if include_reply and turn.active >= 0:
			var content: String = turn.replies[turn.active].text
			if not content.is_empty():
				messages.append({"role": "assistant", "content": content})
	if route == DIALOGUE:
		_request_messages = [{
			"role": "system",
			"content": "%s\n%s\n使用中文回应玩家，保持角色语气，只输出对话或简短动作。" % [
				context.get("description", ""), context.get("scenario", ""),
			],
		}]
		_request_messages.append_array(messages)
		if operation == "continue":
			_request_messages.append({"role": "user", "content": "接着上一条回复继续，只写新增内容。"})
		if _dialogue_merge:
			_request_messages = _merge_dialogue_messages(_request_messages)
	else:
		_request_messages = [{
			"role": "system",
			"content": "你是 Prism Route 的游戏助手。用中文回答。用游戏工具读取实际状态。传送由玩家在游戏界面确认。不要声称执行了没有成功的操作。",
		}]
		_request_messages.append_array(messages)
	pending = true
	changed.emit()
	_dispatch()

static func _merge_dialogue_messages(messages: Array) -> Array[Dictionary]:
	var merged: Array[Dictionary] = []
	for message: Dictionary in messages:
		if not merged.is_empty() and merged.back().role == message.role and not message.content.is_empty():
			merged.back().content += "\n\n" + message.content
		else:
			merged.append({"role": message.role, "content": message.content})
	return merged

func payload() -> Dictionary:
	var body := {"model": profiles[route].model, "messages": _request_messages, "stream": route == DIALOGUE}
	if route == DIALOGUE:
		body.merge(_dialogue_generation)
	elif world_status.is_valid() and _operation == "send" and _tool_rounds < MAX_TOOL_ROUNDS:
		body["tools"] = TOOLS
	return body

func _dispatch() -> void:
	var profile: Dictionary = profiles[route]
	var error: String = _transport.start(profile.url, profile.key, payload())
	if not error.is_empty():
		_complete(error)

func _receive_delta(text: String) -> void:
	if pending and route == DIALOGUE:
		partial += text
		status = "生成中。"
		changed.emit()

func _receive_result(message: Dictionary, error: String) -> void:
	if not pending:
		return
	if route == ASSISTANT:
		if message.get("content") is String:
			partial = message.content
		var calls: Variant = message.get("tool_calls", [])
		if error.is_empty() and calls is Array and not calls.is_empty():
			if not payload().has("tools") or calls.size() > 8:
				_complete("此请求未开放工具调用或调用次数已达上限。")
				return
			_follow_tools(calls, message.get("content"))
			return
	_complete(error)

func _follow_tools(calls: Array, text: Variant) -> void:
	var accepted: Array = []
	var ids := {}
	for call: Variant in calls:
		if not call is Dictionary or not call.get("id") is String or not call.get("function") is Dictionary:
			_complete("模型返回了格式无效的工具调用。")
			return
		var id: String = call.id
		var function: Dictionary = call.function
		if id.is_empty() or ids.has(id) or not function.get("name") is String or not function.get("arguments") is String:
			_complete("模型返回了格式无效的工具调用。")
			return
		ids[id] = true
		accepted.append({"id": id, "type": "function", "function": {"name": function.name, "arguments": function.arguments}})
	_request_messages.append({"role": "assistant", "content": text, "tool_calls": accepted})
	for call: Dictionary in accepted:
		_request_messages.append({"role": "tool", "tool_call_id": call.id, "content": JSON.stringify(_call_tool(call.function))})
	history.back().tool_used = true
	_tool_rounds += 1
	status = "正在根据游戏状态组织回复。"
	changed.emit()
	_dispatch()

func _call_tool(function: Dictionary) -> Dictionary:
	var args: Variant = JSON.parse_string(function.arguments)
	if not args is Dictionary:
		return {"error": "invalid_arguments"}
	var state: Dictionary = world_status.call()
	match function.name:
		"get_world_status":
			if args.is_empty():
				return state
		"propose_teleport":
			if args.size() == 1 and args.get("destination_id") is String:
				for destination: Dictionary in state.get("destinations", []):
					if destination.id == args.destination_id:
						_proposed_destination = destination.id
						return {"status": "awaiting_player_confirmation", "destination": destination}
	return {"error": "tool_or_destination_unavailable"}

func teleport_offer() -> String:
	if route != ASSISTANT or history.is_empty() or pending:
		return ""
	return history.back().offer

func confirm_teleport() -> void:
	var destination := teleport_offer()
	if destination.is_empty() or not world_teleport.is_valid():
		return
	history.back().offer = ""
	status = str(world_teleport.call(destination))
	changed.emit()

func _complete(error: String) -> void:
	var turn: Dictionary = history.back()
	if not partial.is_empty():
		if _operation == "continue":
			var reply: Dictionary = turn.replies[turn.active]
			reply.text += partial
			reply.note = error
		else:
			turn.replies.append({"text": partial, "note": error})
			turn.active = turn.replies.size() - 1
	if error.is_empty():
		turn.offer = _proposed_destination
	status = error
	if status.is_empty() and partial.is_empty() and turn.offer.is_empty():
		status = "模型没有返回文本。"
	pending = false
	partial = ""
	_request_messages = []
	_proposed_destination = ""
	changed.emit()
