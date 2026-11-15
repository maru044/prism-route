extends Node

signal changed

const Transport := preload("res://scripts/ai/chat_transport.gd")
const SETTINGS_PATH := "user://llm_client.cfg"
const DIALOGUE_PROMPT_DIR := "res://assets/ai/worldbook"
const PLAYER_PROFILE_FILE := "玩家人设.md"
const LOCAL_PLAYER_PROFILE := "user://" + PLAYER_PROFILE_FILE
const OUTPUT_TOKEN_RESERVE := 8000
const DIALOGUE := "dialogue"
const ASSISTANT := "assistant"
const MAX_TOOL_ROUNDS := 3
const MAX_ASSISTANT_RETRIES := 2
const MAX_ASSISTANT_RETRY_WAIT := 10
const CONTEXT_TOKEN_LIMIT := 1_000_000
const DIALOGUE_SYSTEM := {"role": "system", "content": "保持当前角色语气和场景。"}
const ASSISTANT_SYSTEM := {
	"role": "system",
	"content": "你是 Prism Route 的游戏助手。用中文回答。用游戏工具读取实际状态。传送由玩家在游戏界面确认。不要声称执行了没有成功的操作。",
}
const CONTINUE_MESSAGE := {"role": "user", "content": "接着上一条回复继续，只写新增内容。"}
const CONTEXT_OVERFLOW := "当前请求超过约 100 万 token 的上下文预算。请缩短输入或提示词。"
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
static var _prompt_token := RegEx.create_from_string(r"\{\{//|\{\{(?:roll 1d100|npc_name|dialogue_location)\}\}|\{\{|\}\}")
static var _dialogue_role_marker := RegEx.create_from_string(r"\|(用户|小猫之神)\|")
static var _dialogue_tag_prefixes := [
	"<game>", "</game>", "<report_nya>", "</report_nya>", "<think_nya>", "</think_nya>",
	"<report_nya~>", "</report_nya~>", "<think_nya~>", "</think_nya~>",
]

var profiles := {
	DIALOGUE: {"url": "", "model": "", "key": ""},
	ASSISTANT: {"url": "", "model": "", "key": ""},
}
var route: String:
	get:
		return _route
var context: Dictionary
var history: Array
var pending := false
var partial := ""
var status := ""
var diagnostic := ""
var omitted_turns := 0
var incomplete_turns := 0
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
var _assistant_retries := 0
var _assistant_retry_timer: Timer
var _proposed_destination := ""
var _world_status_read := false
var _context_limit_tokens := CONTEXT_TOKEN_LIMIT
var _retained_turns := 0
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
	_assistant_retry_timer = Timer.new()
	_assistant_retry_timer.one_shot = true
	_assistant_retry_timer.timeout.connect(_retry_assistant_request)
	add_child(_assistant_retry_timer)
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		for channel: String in profiles:
			for field in ["url", "model", "key"]:
				profiles[channel][field] = str(config.get_value(channel, field, profiles[channel][field]))

func _load_dialogue_markdown(local_profile_path := LOCAL_PLAYER_PROFILE) -> String:
	_dialogue_entries.clear()
	var files_by_depth := {}
	for file: String in DirAccess.get_files_at(DIALOGUE_PROMPT_DIR):
		if file.get_extension() != "md":
			continue
		var path := DIALOGUE_PROMPT_DIR.path_join(file)
		if file == PLAYER_PROFILE_FILE:
			if OS.has_feature("template") and not FileAccess.file_exists(local_profile_path):
				var profile := FileAccess.open(local_profile_path, FileAccess.WRITE)
				if profile != null:
					profile.store_buffer(FileAccess.get_file_as_bytes(path))
					profile.close()
			if FileAccess.file_exists(local_profile_path):
				path = local_profile_path
		var raw := FileAccess.get_file_as_string(path).trim_prefix("\ufeff").replace("\r\n", "\n")
		if file == PLAYER_PROFILE_FILE and raw.strip_edges().is_empty():
			continue
		var separator := raw.find("\n---")
		var body_start := separator + 4
		if separator < 0 or (body_start < raw.length() and raw[body_start] != "\n"):
			return "提示词缺少文件或条目头 · " + path
		var parser := JSON.new()
		var header: Variant = parser.data if parser.parse(raw.left(separator)) == OK else null
		if not header is Dictionary:
			return "提示词的条目头无效 · " + path
		var value: Variant = header.get("depth")
		if not _is_nonnegative_integer(value):
			return "提示词的 depth 必须为非负整数 · " + path
		var depth := int(value)
		var content := raw.substr(body_start).strip_edges()
		if content.is_empty():
			if file == PLAYER_PROFILE_FILE:
				continue
			return "提示词正文为空 · " + path
		if files_by_depth.has(depth):
			return "提示词的 depth 重复，请把同深度正文合入同一文件 · " + files_by_depth[depth] + " / " + path
		files_by_depth[depth] = path
		_dialogue_entries.append({"depth": depth, "content": content})
	if _dialogue_entries.is_empty():
		return "世界书目录里没有自由对话提示词。"
	_dialogue_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.depth > b.depth)
	return ""

static func _is_nonnegative_integer(value: Variant) -> bool:
	return (value is int or value is float) and value >= 0 and value <= 2147483647 and value == int(value)

func save_profile(channel: String, url: String, model: String, key: String) -> String:
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
	config.set_value(channel, "key", key.strip_edges())
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
	if channel == DIALOGUE:
		_dialogue_config_error = _load_dialogue_markdown()
	_thread_id = channel + "/" + scope
	if not _threads.has(_thread_id):
		_threads[_thread_id] = []
	history = _threads[_thread_id]
	_restore_last_status()
	changed.emit()

func configured() -> bool:
	return not profiles[route].url.is_empty() and not profiles[route].model.is_empty()

func send(text: String) -> bool:
	if pending or text.strip_edges().is_empty() or not _can_start():
		return false
	return _start("send", {
		"user": text, "replies": [], "active": -1, "action_committed": false,
	})

func retry() -> void:
	if not can_retry() or not _can_start():
		return
	_start("retry", history.back())

func can_retry() -> bool:
	return not pending and not history.is_empty() and not history.back().action_committed

func continue_reply() -> void:
	if not can_continue_reply() or not _can_start():
		return
	_start("continue", history.back())

func can_continue_reply() -> bool:
	if route != DIALOGUE or pending:
		return false
	var body: String = reply_sections(active_reply(), "", false, true).body
	return not body.strip_edges().is_empty()

func undo() -> Variant:
	if pending or history.is_empty():
		return null
	var removed: Dictionary = history.pop_back()
	if _teleport_offers.get(_thread_id, {}).get("turn", -1) == history.size():
		_teleport_offers.erase(_thread_id)
	_restore_last_status()
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
		_assistant_retry_timer.stop()
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

func _restore_last_status() -> void:
	var result: Dictionary = {} if history.is_empty() else history.back().get("result", {})
	status = result.get("status", "")
	diagnostic = result.get("diagnostic", "")
	omitted_turns = result.get("omitted_turns", 0)
	incomplete_turns = result.get("incomplete_turns", 0)

func _start(operation: String, turn: Dictionary) -> bool:
	_operation = operation
	_request_profile = profiles[route].duplicate()
	partial = ""
	_dialogue_escape_tail = ""
	status = "等待模型。"
	diagnostic = ""
	_transport.failure_details = {}
	_tool_rounds = 0
	_assistant_retries = 0
	_proposed_destination = ""
	_world_status_read = false
	var fixed := fixed_dialogue_tokens(operation) if route == DIALOGUE else _message_tokens(ASSISTANT_SYSTEM)
	if route == ASSISTANT and _allows_tools():
		fixed += _text_tokens(JSON.stringify(TOOLS))
	var messages := _build_request_history(operation, turn, _context_limit_tokens - OUTPUT_TOKEN_RESERVE - fixed)
	if messages.is_empty():
		status = CONTEXT_OVERFLOW
		changed.emit()
		return false
	if operation == "send":
		history.append(turn)
	if route == DIALOGUE:
		_request_messages = _build_dialogue_messages(messages, operation)
		_request_messages = _merge_dialogue_messages(_request_messages)
	else:
		_request_messages = [ASSISTANT_SYSTEM]
		_request_messages.append_array(messages)
	pending = true
	changed.emit()
	_dispatch()
	return true

func _build_request_history(operation: String, turn: Dictionary, remaining: int) -> Array:
	omitted_turns = 0
	incomplete_turns = 0
	_retained_turns = 0
	var current := [{"role": "user", "content": turn.user}]
	if operation == "continue":
		current.append({"role": "assistant", "content": reply_sections(active_reply(), "", false, true).body})
	for row: Dictionary in current:
		remaining -= _message_tokens(row)
	if remaining < 0:
		return []
	var turns: Array[Array] = [current]
	var latest := history.size() - (1 if operation == "send" else 2)
	for i in range(latest, -1, -1):
		var previous: Dictionary = history[i]
		if previous.active < 0:
			if previous.get("result", {}).get("incomplete", false):
				incomplete_turns += 1
			continue
		var reply: Dictionary = previous.replies[previous.active]
		if not reply.note.is_empty():
			incomplete_turns += 1
			continue
		var content: String = reply_sections(reply, "", false, true).body if route == DIALOGUE else reply.text
		if content.strip_edges().is_empty():
			if previous.get("result", {}).get("incomplete", false):
				incomplete_turns += 1
			continue
		var user_row := {"role": "user", "content": previous.user}
		var reply_row := {"role": "assistant", "content": content}
		if omitted_turns > 0:
			omitted_turns += 1
			continue
		var cost := _message_tokens(user_row) + _message_tokens(reply_row)
		if cost > remaining:
			omitted_turns += 1
			continue
		remaining -= cost
		turns.append([user_row, reply_row])
		_retained_turns += 1
	var messages: Array = []
	for i in range(turns.size() - 1, -1, -1):
		messages.append_array(turns[i])
	return messages

static func _text_tokens(content: String) -> int:
	var non_ascii := 0
	for i in content.length():
		if content.unicode_at(i) > 127:
			non_ascii += 1
	return non_ascii + ceili((content.length() - non_ascii) / 4.0)

static func _message_tokens(message: Dictionary) -> int:
	var cost := 6 + _text_tokens(str(message.get("content", "")))
	if message.has("tool_calls"):
		cost += _text_tokens(JSON.stringify(message.tool_calls))
	if message.has("tool_call_id"):
		cost += _text_tokens(message.tool_call_id)
	return cost

static func _extract_dialogue_examples(text: String) -> Dictionary:
	var matches := _dialogue_role_marker.search_all(text)
	if matches.is_empty():
		return {"head": text, "examples": []}
	var head := text.substr(0, matches[0].get_start()).strip_edges()
	var examples: Array[Dictionary] = []
	for i in matches.size():
		var matched := matches[i]
		var role := "user" if matched.get_string(1) == "用户" else "assistant"
		var start := matched.get_end()
		var end := matches[i + 1].get_start() if i + 1 < matches.size() else text.length()
		var segment := text.substr(start, end - start).strip_edges()
		if not segment.is_empty():
			examples.append({"role": role, "content": segment})
	return {"head": head, "examples": examples}

func _parsed_dialogue_prompts(entries: Array = []) -> Dictionary:
	var list: Array = entries if not entries.is_empty() else _dialogue_entries
	var head_prompt := DIALOGUE_SYSTEM.content
	var examples: Array[Dictionary] = []
	var mid_prompts: Array[Dictionary] = []
	var format_content := ""
	for row: Dictionary in list:
		var raw_content: String = row.get("content", "")
		var content := _expand_dialogue_prompt(raw_content)
		if content.is_empty():
			continue
		var depth: int = int(row.get("depth", 0))
		if depth == 999:
			var extracted := _extract_dialogue_examples(content)
			if not extracted.head.is_empty():
				head_prompt += "\n\n" + extracted.head
			examples = extracted.examples
		elif depth == 0:
			format_content = content
		else:
			mid_prompts.append({"depth": depth, "content": content})
	mid_prompts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.depth > b.depth)
	return {
		"head": head_prompt,
		"examples": examples,
		"mid": mid_prompts,
		"format": format_content,
	}

func fixed_dialogue_tokens(operation := "send") -> int:
	var parsed := _parsed_dialogue_prompts()
	var fixed := _message_tokens({"role": "system", "content": parsed.head})
	for ex: Dictionary in parsed.examples:
		fixed += _message_tokens(ex)
	for mid: Dictionary in parsed.mid:
		fixed += _message_tokens({"role": "system", "content": mid.content})
	if not parsed.format.is_empty():
		fixed += _message_tokens({"role": "assistant", "content": parsed.format})
	if operation == "continue":
		fixed += _message_tokens(CONTINUE_MESSAGE)
	return fixed

func _build_dialogue_messages(history_messages: Array, operation := "send", entries: Array = []) -> Array:
	var parsed := _parsed_dialogue_prompts(entries)
	var request_messages: Array = [{"role": "system", "content": parsed.head}]
	request_messages.append_array(parsed.examples)

	var slotted_history: Array = []
	var history_index := 0
	var mid_prompts: Array[Dictionary] = parsed.mid
	for row: Dictionary in mid_prompts:
		var insert_at := maxi(0, history_messages.size() - row.depth)
		while history_index < insert_at:
			slotted_history.append(history_messages[history_index].duplicate())
			history_index += 1
		slotted_history.append({"role": "system", "content": row.content})
	while history_index < history_messages.size():
		slotted_history.append(history_messages[history_index].duplicate())
		history_index += 1

	var format_content: String = parsed.format
	if operation == "continue":
		if not format_content.is_empty():
			if slotted_history.is_empty() or slotted_history.back().role != "assistant":
				slotted_history.append({"role": "assistant", "content": format_content})
			else:
				slotted_history.back().content += "\n\n" + format_content
		slotted_history.append(CONTINUE_MESSAGE)
	else:
		var current_user: Dictionary = slotted_history.pop_back() if not slotted_history.is_empty() else {}
		if not format_content.is_empty():
			if slotted_history.is_empty() or slotted_history.back().role != "assistant":
				slotted_history.append({"role": "assistant", "content": format_content})
			else:
				slotted_history.back().content += "\n\n" + format_content
		if not current_user.is_empty():
			slotted_history.append(current_user)

	request_messages.append_array(slotted_history)
	return request_messages

static func dialogue_sections(raw: String, streaming := false) -> Dictionary:
	var plain := PackedStringArray()
	var game := PackedStringArray()
	var reports := PackedStringArray()
	var in_report := false
	var in_game := false
	var has_game := false
	var cursor := 0
	for matched in _dialogue_tag.search_all(raw):
		var tag := matched.get_string(2).to_lower()
		if in_report and tag == "game":
			continue
		var segment := raw.substr(cursor, matched.get_start() - cursor)
		if in_report:
			reports.append(segment)
		elif in_game:
			game.append(segment)
		else:
			plain.append(segment)
		if tag == "game":
			in_game = matched.get_string(1).is_empty()
			has_game = has_game or in_game
		else:
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
	elif in_game:
		game.append(tail)
	else:
		plain.append(tail)
	return {"body": "".join(game if has_game else plain), "report": "\n\n".join(reports).strip_edges()}

static func reply_sections(reply: Dictionary, partial_text := "", streaming := false, for_context := false) -> Dictionary:
	var sections := dialogue_sections(reply.get("text", ""))
	var fragments: Array = reply.get("continuations", [])
	if streaming:
		fragments = fragments + [{"text": partial_text, "note": ""}]
	for index in fragments.size():
		var fragment: Dictionary = fragments[index]
		var note: String = fragment.note
		if for_context and not note.is_empty():
			continue
		var part := dialogue_sections(fragment.text, streaming and index == fragments.size() - 1)
		sections.body += part.body
		if not note.is_empty():
			sections.body += "〔续写 · %s〕" % note
		if not part.report.is_empty():
			sections.report += ("\n\n" if not sections.report.is_empty() else "") + part.report
	return sections

func _expand_dialogue_prompt(text: String) -> String:
	var parts := PackedStringArray()
	var cursor := 0
	var comment_depth := 0
	for matched in _prompt_token.search_all(text):
		var token := matched.get_string()
		if comment_depth > 0:
			match token:
				"{{//", "{{":
					comment_depth += 1
				"}}":
					comment_depth -= 1
					if comment_depth == 0:
						cursor = matched.get_end()
			continue
		if token in ["{{", "}}"]:
			continue
		parts.append(text.substr(cursor, matched.get_start() - cursor))
		match token:
			"{{//":
				comment_depth = 1
			"{{roll 1d100}}":
				parts.append(str(randi_range(1, 100)))
			_:
				var key := token.trim_prefix("{{").trim_suffix("}}")
				parts.append(str(context.get(key, "未指定")))
		cursor = matched.get_end()
	if comment_depth == 0:
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
		body["max_tokens"] = OUTPUT_TOKEN_RESERVE
	elif _allows_tools():
		body["tools"] = TOOLS
	return body

func _dispatch() -> void:
	if not pending:
		return
	var error: String = _transport.start(_request_profile.url, _request_profile.key, payload())
	if not error.is_empty() and not _schedule_assistant_retry(error):
		_complete(error)

func _schedule_assistant_retry(error: String) -> bool:
	if route != ASSISTANT or _tool_rounds > 0 or _assistant_retries >= MAX_ASSISTANT_RETRIES or not partial.is_empty():
		return false
	var details: Dictionary = _transport.failure_details
	if not details.get("retryable", false):
		return false
	var seconds: int = details.get("retry_after_seconds", -1)
	if seconds > MAX_ASSISTANT_RETRY_WAIT or (seconds < 0 and not str(details.get("retry_after", "")).is_empty()):
		return false
	var wait_seconds := maxi(1 << _assistant_retries, seconds)
	_assistant_retries += 1
	status = "%s %d 秒后重试（%d/%d）。" % [error, wait_seconds, _assistant_retries, MAX_ASSISTANT_RETRIES]
	_assistant_retry_timer.start(wait_seconds)
	changed.emit()
	return true

func _retry_assistant_request() -> void:
	if pending and route == ASSISTANT:
		status = "正在重试游戏助手请求。"
		changed.emit()
		_dispatch()

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
	var calls: Variant = message.get("tool_calls", [])
	if not error.is_empty():
		if route == ASSISTANT and message.get("content") is String and (calls == null or calls == []):
			partial = message.content
		if not _schedule_assistant_retry(error):
			_complete(error)
		return
	if route == ASSISTANT:
		var format_error := Transport.assistant_format_error(message)
		if not format_error.is_empty():
			partial = ""
			_complete(format_error)
			return
	if calls is Array and not calls.is_empty():
		if not _allows_tools() or calls.size() > 8:
			_complete("此请求未开放工具调用或调用次数已达上限。")
			return
		_follow_tools(calls, message.get("content"))
		return
	if route == ASSISTANT and message.get("content") is String:
		partial = message.content
	_complete("")

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
		if id.strip_edges().is_empty() or ids.has(id) or not function.get("name") is String \
				or function.name.strip_edges().is_empty() or not function.get("arguments") is String \
				or call.get("type", "function") != "function":
			_complete("模型返回了格式无效的工具调用。")
			return
		ids[id] = true
		accepted.append({"id": id, "type": "function", "function": {"name": function.name, "arguments": function.arguments}})
	_request_messages.append({"role": "assistant", "content": text, "tool_calls": accepted})
	for call: Dictionary in accepted:
		var result := _call_tool(call.function)
		_request_messages.append({"role": "tool", "tool_call_id": call.id, "content": JSON.stringify(result)})
	_tool_rounds += 1
	if not _fit_tool_context():
		_complete(CONTEXT_OVERFLOW)
		return
	status = "正在根据游戏状态组织回复。"
	changed.emit()
	_dispatch()

func _fit_tool_context() -> bool:
	var cost := OUTPUT_TOKEN_RESERVE
	if _allows_tools():
		cost += _text_tokens(JSON.stringify(TOOLS))
	for row: Dictionary in _request_messages:
		cost += _message_tokens(row)
	var first := 1
	while cost > _context_limit_tokens and _retained_turns > 0:
		cost -= _message_tokens(_request_messages[first]) + _message_tokens(_request_messages[first + 1])
		first += 2
		_retained_turns -= 1
		omitted_turns += 1
	if first > 1:
		_request_messages = [_request_messages.front()] + _request_messages.slice(first)
	return cost <= _context_limit_tokens

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
				_world_status_read = _world_status_read or not state.has("error")
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
		var turn: Dictionary = history[offer.turn]
		turn.action_committed = true
		var saved: Dictionary = turn.result
		saved.status = saved.status.trim_suffix(" · 传送提议仍可确认。")
		saved.notice = saved.notice.trim_suffix(" · 传送提议仍可确认。")
		if not saved.incomplete:
			saved.status = ""
			saved.notice = ""
		_teleport_offers.erase(_thread_id)
	status = str(result.get("message", "当前状态无法传送。"))
	changed.emit()

func _complete(error: String) -> void:
	if route == DIALOGUE:
		partial += _decode_dialogue_fragment("", true)
	var final_error := error
	var body: String = dialogue_sections(partial).body if route == DIALOGUE else partial
	if route == DIALOGUE and final_error.is_empty() and body.strip_edges().is_empty():
		final_error = "模型未返回正文，可以重新生成。"
	var turn: Dictionary = history.back()
	if not partial.is_empty():
		if _operation == "continue":
			var reply: Dictionary = turn.replies[turn.active]
			if not reply.has("continuations"):
				reply.continuations = []
			reply.continuations.append({"text": partial, "note": final_error})
			if final_error.is_empty():
				reply.note = ""
		else:
			turn.replies.append({"text": partial, "note": final_error})
			turn.active = turn.replies.size() - 1
	status = final_error
	var notice := ""
	if not final_error.is_empty() and partial.is_empty():
		notice = ("续写 · " if _operation == "continue" else "") + final_error
	if route == ASSISTANT and final_error.is_empty() and body.strip_edges().is_empty() and _proposed_destination.is_empty():
		status = "已查询游戏状态，模型未返回说明。" if _world_status_read else "游戏助手没有返回文字。"
		notice = status
	if not _proposed_destination.is_empty():
		if not final_error.is_empty():
			status += " · 传送提议仍可确认。"
		elif not teleport_offer().is_empty() and teleport_offer() != _proposed_destination:
			status = "已替换上一条待确认的传送提议。"
		elif body.strip_edges().is_empty():
			status = "已有待确认的传送提议。"
		_teleport_offers[_thread_id] = {"destination": _proposed_destination, "turn": history.size() - 1}
		if body.strip_edges().is_empty():
			notice = status
	if not final_error.is_empty() and final_error != "已停止":
		var details: Dictionary = _transport.failure_details
		var stage := "整理上下文" if final_error == CONTEXT_OVERFLOW else str(details.get("stage", "处理回复"))
		var lines := PackedStringArray(["入口 · " + ("自由对话" if route == DIALOGUE else "游戏助手"),
			"阶段 · " + stage])
		var model := Transport.safe_diagnostic_model(_request_profile.model, _request_profile.key)
		if not model.is_empty():
			lines.append("模型 · " + model)
		# Use the client-generated summary only. Provider details can echo request data.
		var summary := str(details.get("summary", ""))
		if final_error == CONTEXT_OVERFLOW:
			summary = final_error
		lines.append("错误 · " + (summary if not summary.is_empty() else "模型回复未能完成。"))
		if details.get("http_code", 0) > 0:
			lines.append("HTTP %d" % details.http_code)
		if not str(details.get("request_id", "")).is_empty():
			lines.append("请求 ID · " + details.request_id)
		if not str(details.get("retry_after", "")).is_empty():
			lines.append("建议等待 · " + details.retry_after)
		diagnostic = "\n".join(lines)
	turn.result = {
		"status": status, "diagnostic": diagnostic, "notice": notice, "incomplete": not final_error.is_empty(),
		"omitted_turns": omitted_turns, "incomplete_turns": incomplete_turns,
	}
	pending = false
	partial = ""
	_request_messages = []
	_request_profile = {}
	_proposed_destination = ""
	changed.emit()
