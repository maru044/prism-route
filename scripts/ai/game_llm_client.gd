extends Node

signal changed

const Transport := preload("res://scripts/ai/chat_transport.gd")
const SETTINGS_PATH := "user://llm_client.cfg"
const DIALOGUE_CONFIG_PATH := "res://assets/ai/reborn.json"
const DIALOGUE := "dialogue"
const ASSISTANT := "assistant"
const MAX_TOOL_ROUNDS := 3
const DEFAULT_HISTORY_BUDGET := {DIALOGUE: 65536, ASSISTANT: 32768}
const DIALOGUE_MARKERS := [
	"worldInfoBefore", "charDescription", "charPersonality", "scenario", "worldInfoAfter",
	"personaDescription", "dialogueExamples", "chatHistory",
]
const RETRYABLE_TOOLS := ["get_world_status", "propose_teleport"]
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

static var _dialogue_tag := RegEx.create_from_string(r"(?i)<(/?)(game|report_nya~?|think_nya~?)>")
static var _prompt_macro := RegEx.create_from_string(r"(?s)\{\{(?://.*?|user|char|roll 1d100)\}\}")
static var _dialogue_tag_prefixes := [
	"<game>", "</game>", "<report_nya>", "</report_nya>", "<think_nya>", "</think_nya>",
	"<report_nya~>", "</report_nya~>", "<think_nya~>", "</think_nya~>",
]

var profiles := {
	DIALOGUE: {"url": "", "model": "gemini-4-argon", "key": ""},
	ASSISTANT: {"url": "", "model": "gemini-3.8-flash", "key": ""},
}
var route: String:
	get:
		return _route
var context: Dictionary
var history: Array
var pending := false
var partial := ""
var status := ""
var world_status: Callable
var world_teleport: Callable

var _transport = Transport.new()
var _route := ASSISTANT
var _thread_id := ""
var _threads := {}
var _teleport_offers := {}
var _request_messages: Array
var _request_profile: Dictionary
var _operation := ""
var _tool_rounds := 0
var _proposed_destination := ""
var _dialogue_generation: Dictionary
var _dialogue_merge := true
var _history_budget := DEFAULT_HISTORY_BUDGET.duplicate()
var _dialogue_worldbook := ""
var _dialogue_entries: Array[Dictionary] = []
var _dialogue_config_error := ""
var _dialogue_escape_tail := ""
var _unicode_escape := RegEx.create_from_string(
	r"\\\\|\\u([dD][89a-bA-B][0-9a-fA-F]{2})\\u([dD][c-fC-F][0-9a-fA-F]{2})|\\u\{([0-9a-fA-F]{1,6})\}|\\u([0-9a-fA-F]{4})|(\\(?:u(?:\{[0-9a-fA-F]{0,6}|[0-9a-fA-F]{0,3})?)?)\z"
)

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
	if not preset is Dictionary or not preset.get("generation") is Dictionary or not preset.get("game_dialogue") is Dictionary:
		_dialogue_config_error = "无法读取自由对话配置 reborn.json。"
		return
	var budgets: Dictionary = preset.get("request_history_budget_bytes", {})
	for channel: String in DEFAULT_HISTORY_BUDGET:
		_history_budget[channel] = maxi(1, int(budgets.get(channel, DEFAULT_HISTORY_BUDGET[channel])))
	var generation: Dictionary = preset.generation
	for field in ["temperature", "top_p", "max_tokens"]:
		var value: Variant = generation.get(field)
		if value is float or value is int:
			_dialogue_generation[field] = int(value) if field == "max_tokens" else value
	var processing: Dictionary = preset.get("spreset", {}).get("message_processing", {})
	_dialogue_merge = bool(processing.get("enabled", true)) and processing.get("mode", "merge") == "merge"
	_dialogue_config_error = _load_dialogue_markdown(preset)

func _load_dialogue_markdown(preset: Dictionary) -> String:
	var runtime: Dictionary = preset.game_dialogue
	if not runtime.get("worldbook") is Array or not runtime.get("prompt_ids") is Array or not preset.get("prompt_order") is Array:
		return "自由对话配置缺少世界书或正文顺序。"
	var world_entries: Array[Dictionary] = []
	for file: String in runtime.worldbook:
		var raw := _read_dialogue_markdown(file)
		var separator := raw.find("\n---\n")
		if separator < 0:
			return "世界书缺少文件或条目头 · " + file
		var header: Variant = JSON.parse_string(raw.left(separator))
		if not header is Dictionary or not (header.get("depth") is float or header.get("depth") is int):
			return "世界书的条目头无效 · " + file
		if header.get("enabled", true) and header.get("role", "system") == "system":
			world_entries.append({"depth": int(header.depth), "index": world_entries.size(), "body": raw.substr(separator + 5).strip_edges()})
	world_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.index < b.index if a.depth == b.depth else a.depth > b.depth
	)
	var bodies := PackedStringArray()
	for entry: Dictionary in world_entries:
		bodies.append(entry.body)
	_dialogue_worldbook = "\n\n".join(bodies)
	var pending_ids: Array = runtime.prompt_ids.duplicate()
	var markdown_files := {}
	var model_conditions: Dictionary = runtime.get("model_contains", {})
	var history_marker_found := false
	for row: Dictionary in preset.prompt_order:
		var id: String = row.identifier
		if row.enabled and row.marker and id in DIALOGUE_MARKERS:
			_dialogue_entries.append({"marker": id})
			history_marker_found = history_marker_found or id == "chatHistory"
		if not pending_ids.has(id):
			continue
		pending_ids.erase(id)
		if not row.enabled:
			continue
		var model_filter := str(model_conditions.get(id, "")).to_lower()
		if row.get("spreset_condition_enabled", false) and model_filter.is_empty():
			return "自由对话正文缺少模型条件 · " + id
		var file: String = row.get("markdown", "")
		if row.marker or row.role != "system" or row.injection_position != 0 or file.is_empty():
			return "自由对话正文配置无效 · " + id
		if not markdown_files.has(file):
			markdown_files[file] = _read_dialogue_markdown(file)
		var text: String = markdown_files[file]
		var opening := "<!-- prompt:%s -->\n" % id
		var start := text.find(opening)
		var end := text.find("\n<!-- /prompt -->", start + opening.length()) if start >= 0 else -1
		if end < 0:
			return "找不到自由对话正文 · " + file + " · " + id
		start += opening.length()
		_dialogue_entries.append({"content": text.substr(start, end - start), "model_filter": model_filter})
	if not history_marker_found:
		return "自由对话配置缺少聊天历史标记。"
	return "" if pending_ids.is_empty() else "自由对话配置引用了未知正文。"

static func _read_dialogue_markdown(file: String) -> String:
	return FileAccess.get_file_as_string(DIALOGUE_CONFIG_PATH.get_base_dir().path_join(file)).trim_prefix("\ufeff").replace("\r\n", "\n")

func save_profile(channel: String, url: String, model: String, key: String, remember_key: bool) -> String:
	if not profiles.has(channel):
		return "未知的模型入口。"
	var connection_error := Transport.connection_error(url, key)
	if not connection_error.is_empty():
		return connection_error
	if model.strip_edges().is_empty():
		return "请填写模型 ID。"
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
	if not profiles.has(channel):
		return
	stop()
	_route = channel
	context = speaker_context
	_thread_id = channel + "/" + scope
	if not _threads.has(_thread_id):
		_threads[_thread_id] = []
	history = _threads[_thread_id]
	status = ""
	changed.emit()

func configured() -> bool:
	return not profiles[route].url.is_empty() and not profiles[route].model.is_empty()

func send(text: String) -> bool:
	if pending or text.strip_edges().is_empty() or not _can_start():
		return false
	if _message_bytes([{"role": "user", "content": text}]) > _history_budget[route]:
		status = "当前回合超过发送历史预算，请缩短输入或调整配置。"
		changed.emit()
		return false
	history.append({
		"user": text, "replies": [], "active": -1, "action_committed": false,
	})
	_start("send")
	return true

func retry() -> void:
	if not can_retry() or not _can_start():
		return
	_start("retry")

func can_retry() -> bool:
	return not pending and not history.is_empty() and not history.back().action_committed

func continue_reply() -> void:
	if not can_continue_reply() or not _can_start():
		return
	_start("continue")

func can_continue_reply() -> bool:
	if route != DIALOGUE or pending:
		return false
	var body: String = dialogue_sections(active_reply().get("text", "")).body
	return not body.strip_edges().is_empty()

func undo() -> Variant:
	if pending or history.is_empty():
		return null
	var removed: Dictionary = history.pop_back()
	if _teleport_offers.get(_thread_id, {}).get("turn", -1) == history.size():
		_teleport_offers.erase(_thread_id)
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
	elif route == DIALOGUE and not _dialogue_config_error.is_empty():
		status = _dialogue_config_error
	else:
		return true
	changed.emit()
	return false

func _start(operation: String) -> void:
	_operation = operation
	_request_profile = profiles[route].duplicate()
	partial = ""
	_dialogue_escape_tail = ""
	status = "等待模型。"
	_tool_rounds = 0
	_proposed_destination = ""
	var messages := _build_request_history(operation)
	if messages.is_empty():
		_complete("当前回合超过发送历史预算，请缩短输入或调整配置。")
		return
	if route == DIALOGUE:
		_request_messages = _build_dialogue_messages(messages)
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

func _build_request_history(operation: String) -> Array:
	var turns: Array[Array] = []
	var remaining: int = _history_budget[route]
	for i in range(history.size() - 1, -1, -1):
		var turn: Dictionary = history[i]
		var rows := [{"role": "user", "content": turn.user}]
		if turn.active >= 0 and (i < history.size() - 1 or operation == "continue"):
			var content: String = turn.replies[turn.active].text
			if route == DIALOGUE:
				content = dialogue_sections(content).body
			if not content.is_empty():
				rows.append({"role": "assistant", "content": content})
		var bytes := _message_bytes(rows)
		if bytes > remaining:
			break
		remaining -= bytes
		turns.append(rows)
	var messages: Array = []
	for i in range(turns.size() - 1, -1, -1):
		messages.append_array(turns[i])
	return messages

static func _message_bytes(messages: Array) -> int:
	return JSON.stringify(messages).to_utf8_buffer().size()

func _build_dialogue_messages(history_messages: Array) -> Array:
	var messages: Array = [{"role": "system", "content": "保持当前角色语气和场景。"}]
	var model: String = _request_profile.model.to_lower()
	var dynamic := {
		"worldInfoBefore": _dialogue_worldbook,
		"charDescription": context.get("description", ""),
		"charPersonality": context.get("personality", ""),
		"scenario": context.get("scenario", ""),
		"worldInfoAfter": context.get("world_after", ""),
		"personaDescription": context.get("persona", ""),
		"dialogueExamples": context.get("dialogue_examples", ""),
	}
	for row: Dictionary in _dialogue_entries:
		var marker: String = row.get("marker", "")
		if marker == "chatHistory":
			messages.append_array(history_messages)
			continue
		var model_filter: String = row.get("model_filter", "")
		if not model_filter.is_empty() and not model.contains(model_filter):
			continue
		var content: String = dynamic.get(marker, "") if not marker.is_empty() else row.content
		if not content.is_empty():
			messages.append({"role": "system", "content": _expand_dialogue_prompt(content)})
	return messages

static func dialogue_sections(raw: String, streaming := false) -> Dictionary:
	var body := PackedStringArray()
	var reports := PackedStringArray()
	var in_report := false
	var cursor := 0
	for matched in _dialogue_tag.search_all(raw):
		var tag := matched.get_string(2).to_lower()
		if in_report and tag == "game":
			continue
		var segment := raw.substr(cursor, matched.get_start() - cursor)
		if in_report:
			reports.append(segment)
		else:
			body.append(segment)
		if tag != "game":
			in_report = matched.get_string(1).is_empty()
		cursor = matched.get_end()
	var tail := raw.substr(cursor)
	var start := tail.rfind("<")
	if start >= 0 and (streaming or in_report or tail.length() - start >= 3):
		var suffix := tail.substr(start).to_lower()
		for tag: String in _dialogue_tag_prefixes:
			if tag.begins_with(suffix):
				tail = tail.left(start)
				break
	if in_report:
		reports.append(tail)
	else:
		body.append(tail)
	return {"body": "".join(body), "report": "\n\n".join(reports).strip_edges()}

func _expand_dialogue_prompt(text: String) -> String:
	var parts := PackedStringArray()
	var cursor := 0
	for matched in _prompt_macro.search_all(text):
		parts.append(text.substr(cursor, matched.get_start() - cursor))
		match matched.get_string():
			"{{user}}":
				parts.append(str(context.get("user", "玩家")))
			"{{char}}":
				parts.append(str(context.get("char", "")))
			"{{roll 1d100}}":
				parts.append(str(randi_range(1, 100)))
		cursor = matched.get_end()
	parts.append(text.substr(cursor))
	return "".join(parts)

static func _merge_dialogue_messages(messages: Array) -> Array[Dictionary]:
	var merged: Array[Dictionary] = []
	for message: Dictionary in messages:
		if not merged.is_empty() and merged.back().role == message.role and not message.content.is_empty():
			merged.back().content += "\n\n" + message.content
		else:
			merged.append({"role": message.role, "content": message.content})
	return merged

func payload() -> Dictionary:
	var body := {"model": _request_profile.get("model", ""), "messages": _request_messages, "stream": route == DIALOGUE}
	if route == DIALOGUE:
		body.merge(_dialogue_generation)
	elif _allows_tools():
		body["tools"] = TOOLS
	return body

func _dispatch() -> void:
	if not pending:
		return
	var error: String = _transport.start(_request_profile.url, _request_profile.key, payload())
	if not error.is_empty():
		_complete(error)

func _receive_delta(text: String) -> void:
	if pending and route == DIALOGUE:
		partial += _decode_dialogue_fragment(text)
		status = "生成中。"
		changed.emit()

func _decode_dialogue_fragment(fragment: String, final := false) -> String:
	var incoming := _dialogue_escape_tail + fragment
	_dialogue_escape_tail = ""
	var output := PackedStringArray()
	var cursor := 0
	var matches := _unicode_escape.search_all(incoming)
	for index in matches.size():
		var match_result := matches[index]
		var start := match_result.get_start()
		var end := match_result.get_end()
		output.append(incoming.substr(cursor, start - cursor))
		var token := match_result.get_string()
		var point := -1
		if not match_result.get_string(1).is_empty():
			var high := match_result.get_string(1).hex_to_int()
			var low := match_result.get_string(2).hex_to_int()
			point = 0x10000 + ((high - 0xd800) << 10) + low - 0xdc00
		elif not match_result.get_string(3).is_empty():
			point = match_result.get_string(3).hex_to_int()
		elif not match_result.get_string(4).is_empty():
			point = match_result.get_string(4).hex_to_int()
		var high_surrogate := point >= 0xd800 and point <= 0xdbff and not match_result.get_string(4).is_empty()
		if not final and high_surrogate:
			var rest := incoming.substr(end).to_lower()
			if rest.is_empty() or (
				index + 1 == matches.size() - 1 and matches[index + 1].get_start() == end
				and not matches[index + 1].get_string(5).is_empty()
				and rest.length() < 6 and (r"\ud".begins_with(rest) or rest.begins_with(r"\ud"))
			):
				_dialogue_escape_tail = incoming.substr(start)
				return "".join(output)
		if not final and not match_result.get_string(5).is_empty():
			_dialogue_escape_tail = token
			return "".join(output)
		if point > 0 and point <= 0x10ffff and not (point >= 0xd800 and point <= 0xdfff):
			output.append(String.chr(point))
		else:
			output.append(token)
		cursor = end
	output.append(incoming.substr(cursor))
	return "".join(output)

func _receive_result(message: Dictionary, error: String) -> void:
	if not pending:
		return
	if route == ASSISTANT:
		if message.get("content") is String:
			partial = message.content
		var calls: Variant = message.get("tool_calls", [])
		if error.is_empty() and calls is Array and not calls.is_empty():
			if not _allows_tools() or calls.size() > 8:
				_complete("此请求未开放工具调用或调用次数已达上限。")
				return
			_follow_tools(calls, message.get("content"))
			return
	_complete(error)

func _allows_tools() -> bool:
	return route == ASSISTANT and world_status.is_valid() and _tool_rounds < MAX_TOOL_ROUNDS

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
		var result := _call_tool(call.function)
		_request_messages.append({"role": "tool", "tool_call_id": call.id, "content": JSON.stringify(result)})
	_tool_rounds += 1
	status = "正在根据游戏状态组织回复。"
	changed.emit()
	_dispatch()

func _call_tool(function: Dictionary) -> Dictionary:
	if function.name not in RETRYABLE_TOOLS:
		return {"error": "tool_or_destination_unavailable"}
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
				if not _proposed_destination.is_empty():
					return {"error": "one_teleport_proposal_per_turn", "destination_id": _proposed_destination}
				for destination: Dictionary in state.get("destinations", []):
					if destination.id == args.destination_id:
						_proposed_destination = destination.id
						return {"status": "awaiting_player_confirmation", "destination": destination}
	return {"error": "tool_or_destination_unavailable"}

func teleport_offer() -> String:
	if route != ASSISTANT:
		return ""
	return _teleport_offers.get(_thread_id, {}).get("destination", "")

func confirm_teleport() -> void:
	var destination := teleport_offer()
	if pending or destination.is_empty() or not world_teleport.is_valid():
		return
	var result: Dictionary = world_teleport.call(destination)
	if result.get("ok", false):
		var offer: Dictionary = _teleport_offers[_thread_id]
		history[offer.turn].action_committed = true
		_teleport_offers.erase(_thread_id)
	status = str(result.get("message", "当前状态无法传送。"))
	changed.emit()

func _complete(error: String) -> void:
	if route == DIALOGUE:
		partial += _decode_dialogue_fragment("", true)
	var turn: Dictionary = history.back()
	if not partial.is_empty():
		if _operation == "continue":
			var reply: Dictionary = turn.replies[turn.active]
			reply.text += partial
			reply.note = error
		else:
			turn.replies.append({"text": partial, "note": error})
			turn.active = turn.replies.size() - 1
	status = error
	if error.is_empty() and not _proposed_destination.is_empty():
		if not teleport_offer().is_empty() and teleport_offer() != _proposed_destination:
			status = "已替换上一条待确认的传送提议。"
		_teleport_offers[_thread_id] = {"destination": _proposed_destination, "turn": history.size() - 1}
	elif status.is_empty() and partial.is_empty():
		status = "模型没有返回文本。"
	pending = false
	partial = ""
	_request_messages = []
	_request_profile = {}
	_proposed_destination = ""
	changed.emit()
