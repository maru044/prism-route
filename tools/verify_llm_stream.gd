extends SceneTree

const Transport := preload("res://scripts/ai/chat_transport.gd")
const Client := preload("res://scripts/ai/game_llm_client.gd")
const ChatPanel := preload("res://scripts/ai/llm_panel.gd")
const TitleSettings := preload("res://scripts/ui/title_api_settings.gd")
const LOCALHOST := "127.0.0.1"
const CASE_TIMEOUT_MS := 5000

var _failures := 0

class CaptureTransport extends Transport:
	var request: Dictionary
	var url := ""
	var key := ""
	var sends := 0

	func start(target: String, credential: String, body: Dictionary) -> String:
		url = target
		key = credential
		request = body.duplicate(true)
		sends += 1
		return ""

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var server := TCPServer.new()
	var bind_error := server.listen(0, LOCALHOST)
	if bind_error != OK:
		printerr("Cannot listen on loopback: ", error_string(bind_error))
		quit(1)
		return
	_verify_endpoint_paths()
	await _verify_title_model_list(server)
	var client := Client.new()
	root.add_child(client)
	client.profiles[Client.DIALOGUE] = {
		"url": "http://%s:%d" % [LOCALHOST, server.get_local_port()], "model": "fixture", "key": "fixture-private-key",
	}
	client.profiles[Client.ASSISTANT] = client.profiles[Client.DIALOGUE].duplicate()
	var text := _sse({"choices": [{"delta": {"content": "你好"}}]})
	var stop := _sse({"choices": [{"delta": {}, "finish_reason": "stop"}]})
	var escaped_first := _text_event("已收到" + r"\u4f")
	var escaped_final := _text_event("60" + r"\u{1F") + _text_event("642}" + r"\uD83D")
	escaped_final += _text_event(r"\uD") + _text_event("E42") + stop
	var cases := [
		{"name": "split UTF-8", "body": text + stop + "data: [DONE]\r\n\r\n", "text": "你好", "status": ""},
		{"name": "split literal Unicode", "body": escaped_final, "first": escaped_first, "visible": "已收到", "text": "已收到你🙂🙂", "status": ""},
		{"name": "invalid or escaped Unicode", "body": _text_event(r"\\u4f60 \u{110000} \uD83D\\u4f60 \u4f") + stop, "text": r"\\u4f60 \u{110000} \uD83D\\u4f60 \u4f", "status": ""},
		{"name": "cancel with incomplete Unicode", "body": "", "first": escaped_first, "visible": "已收到", "text": "已收到" + r"\u4f", "status": "已停止", "cancel_after_text": true},
		{"name": "finish reason and open connection", "body": text + stop, "text": "你好", "status": "", "held": true},
		{"name": "truncated stream", "body": text + "data: {", "text": "你好", "error": "中断"},
		{"name": "server event error", "body": text + _sse({"error": {"message": "fixture"}}), "text": "你好", "error": "错误事件"},
		{"name": "invalid choices after text", "body": text + _sse({"choices": {}}), "text": "你好", "error": "无效的流式选项"},
		{"name": "output token limit", "body": text + _sse({"choices": [{"finish_reason": "length"}]}), "text": "你好", "error": "输出上限"},
		{"name": "unexpected tool turn", "body": _sse({"choices": [{"finish_reason": "tool_calls"}]}), "text": "", "error": "只接收文本"},
		{"name": "unexpected tool delta", "body": text + _sse({"choices": [{"delta": {"tool_calls": [{"index": 0}]}}]}), "text": "你好", "error": "只接收文本"},
		{"name": "JSON instead of SSE", "body": "{}", "mime": "application/json", "text": "", "error": "普通 JSON"},
		{"name": "mislabeled JSON", "body": '{"choices":[]}', "mime": "text/plain", "text": "", "held": true, "error": "普通 JSON", "diagnostic": ["检查响应格式"]},
		{"name": "plain text instead of SSE", "body": "Plain proxy reply\r\n", "mime": "text/plain", "text": "", "held": true, "error": "未返回 SSE", "diagnostic": ["检查响应格式"]},
		{"name": "one-word plain proxy reply", "body": "Forbidden\r\n", "mime": "text/plain", "text": "", "error": "未返回 SSE"},
		{"name": "SSE without MIME", "body": text + stop, "mime": "", "text": "你好", "status": ""},
		{"name": "SSE under generic MIME", "body": "\ufeff:keepalive\r\n\r\nid: 5\r\n" + text + stop, "mime": "text/plain", "text": "你好", "status": ""},
		{"name": "invalid delta content", "body": text + _sse({"choices": [{"delta": {"content": ["not text"]}}]}), "text": "你好", "error": "格式无效的流式正文"},
		{"name": "stream refusal", "body": _sse({"choices": [{"delta": {"refusal": "server refusal"}}]}), "text": "", "error": "明确拒绝"},
		{"name": "HTML instead of SSE", "body": "<html></html>", "mime": "text/html", "text": "", "error": "返回了网页"},
		{"name": "rate limit", "body": "{}", "code": 429, "mime": "application/json", "text": "", "error": "429"},
		{"name": "HTTP error detail redaction", "body": JSON.stringify({"error": {"message": "invalid model; API key: fixture-private-key; Authorization: Bearer other-private-key; https://fixture.invalid; stream fixture"}}), "code": 400, "mime": "application/json", "response_headers": "X-Request-ID: fixture-private-key\r\n", "text": "", "error": "invalid model", "diagnostic": ["HTTP 400", "模型 · fixture", "invalid model"], "redacted": true},
		{"name": "FastAPI field detail", "body": '{"detail":[{"msg":"Field required"},{"msg":"Input should be a string"}]}', "code": 422, "text": "", "error": "Field required / Input should be a string", "diagnostic": ["HTTP 422"]},
		{"name": "cancel before text", "body": "", "text": "", "status": "已停止", "cancel": true},
		{"name": "stalled before text", "body": ": keepalive\r\n\r\n", "text": "", "error": "第一段", "held": true, "timeout": true},
		{"name": "stalled after text", "body": text + ": keepalive\r\n\r\n", "text": "你好", "error": "中途", "held": true, "timeout": true},
		{"name": "report without body", "body": _text_event("<report_nya~>report</report_nya~><game>  </game>") + stop, "text": "<report_nya~>report</report_nya~><game>  </game>", "error": "未返回正文"},
		{"name": "retry after", "body": "{}", "code": 429, "response_headers": "Retry-After: 30\r\nX-Request-ID: req-test\r\n", "text": "", "error": "30 秒", "diagnostic": ["HTTP 429", "req-test", "30 秒"], "retryable": true},
		{"name": "quota exhausted", "body": '{"error":{"code":"insufficient_quota"}}', "code": 429, "response_headers": "Retry-After: 30\r\n", "text": "", "error": "额度不足", "retryable": false},
		{"name": "proxy balance exhausted", "body": '{"detail":"Insufficient balance"}', "code": 429, "response_headers": "Retry-After: 1\r\n", "text": "", "error": "额度不足", "retryable": false},
		{"name": "plain proxy balance exhausted", "body": "Insufficient balance", "mime": "text/plain", "code": 429, "text": "", "error": "额度不足", "retryable": false},
		{"name": "context too large", "body": '{"error":{"code":"context_length_exceeded"}}', "code": 400, "text": "", "error": "上下文上限"},
		{"name": "payload too large", "body": "{}", "code": 413, "text": "", "error": "大小上限"},
		{"name": "proxy unavailable", "body": "{}", "code": 503, "text": "", "error": "稍后重新生成", "retryable": true},
	]
	for fixture: Dictionary in cases:
		await _run_case(server, client, fixture)
	var assistant_tool_reads := []
	client.world_status = func():
		assistant_tool_reads.append(true)
		return {}
	var assistant_cases := [
		{"name": "assistant text", "body": '{"choices":[{"message":{"content":"OK"}}]}', "text": "OK", "status": ""},
		{"name": "assistant JSON without MIME", "body": '{"choices":[{"message":{"content":"OK"}}]}', "mime": "", "text": "OK", "status": ""},
		{"name": "assistant received SSE", "body": text + stop, "mime": "text/event-stream", "text": "", "error": "返回了 SSE"},
		{"name": "assistant received mislabeled SSE", "body": text + stop, "mime": "text/plain", "text": "", "error": "返回了 SSE"},
		{"name": "assistant refusal", "body": '{"choices":[{"message":{"content":null,"refusal":"server refusal"}}]}', "text": "", "error": "明确拒绝"},
		{"name": "assistant invalid JSON", "body": "{", "text": "", "error": "无效的 JSON"},
		{"name": "assistant empty body", "body": '{"choices":[{"message":{"content":"  "}}]}', "text": "  ", "status": "游戏助手没有返回文字。"},
		{"name": "assistant invalid tool array", "body": '{"choices":[{"message":{"content":"unexpected","tool_calls":{}}}]}', "text": "", "error": "无效或不支持的工具调用"},
		{"name": "assistant absent tool call", "body": '{"choices":[{"finish_reason":"tool_calls","message":{"content":null}}]}', "text": "", "error": "未返回调用内容"},
	]
	for fixture: Dictionary in assistant_cases:
		fixture.route = Client.ASSISTANT
		await _run_case(server, client, fixture)
	if not assistant_tool_reads.is_empty():
		_fail("assistant HTTP", "invalid replies executed a game tool")
	await _verify_report_panel()
	_verify_model_routes()
	_verify_assistant_retry()
	_verify_context_budget()
	_verify_tool_context_budget()
	_verify_blank_player_profile(client)
	_verify_teleport_lifecycle()
	if not Transport.connection_error("http://127.0.0.1:8080", "").is_empty() \
			or not Transport.connection_error("https://fixture.invalid", "bad\nkey").contains("密钥") \
			or not Transport.connection_error("http://fixture.invalid", "").contains("地址"):
		_fail("connection settings", "validation failed to distinguish URL and key")
	client.free()
	server.stop()
	print("LLM_STREAM cases=", cases.size(), " assistant_http=", assistant_cases.size(), " report_panel=1 model_routes=1 context_budget=1 tool_context=1 player_profile=1 teleport_lifecycle=1 title_model_list=1 failures=", _failures)
	quit(0 if _failures == 0 else 1)

func _verify_endpoint_paths() -> void:
	var fixtures := {
		"https://gcli.ggchan.dev": "",
		"https://fixture.invalid/": "",
		"https://fixture.invalid/v1": "/v1",
		"https://fixture.invalid/v1beta/openai/": "/v1beta/openai",
		"https://fixture.invalid/proxy/v1/chat/completions/": "/proxy/v1",
		"https://fixture.invalid/proxy/models": "/proxy",
	}
	for address: String in fixtures:
		for resource: String in ["/models", "/chat/completions"]:
			if Transport.endpoint(address, resource).get("path") != fixtures[address] + resource:
				_fail("API base address", "path did not match the configured base: " + address + " " + resource)

func _verify_title_model_list(server: TCPServer) -> void:
	var settings := TitleSettings.new()
	root.add_child(settings)
	settings.open()
	await process_frame
	_verify_title_address_drag(settings._url)
	await process_frame
	settings._url.text = "http://%s:%d" % [LOCALHOST, server.get_local_port()]
	settings._key.text = "fixture-model-list-key"
	settings._fetch_button.pressed.emit()
	var deadline := Time.get_ticks_msec() + CASE_TIMEOUT_MS
	var peer := server.take_connection()
	while peer == null and Time.get_ticks_msec() < deadline:
		await process_frame
		peer = server.take_connection()
	if peer == null:
		_fail("title model list", "button did not connect to the configured endpoint")
		settings.free()
		return
	var request := PackedByteArray()
	while not request.get_string_from_ascii().contains("\r\n\r\n") and Time.get_ticks_msec() < deadline:
		await process_frame
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			break
		var available := peer.get_available_bytes()
		if available > 0:
			request.append_array(peer.get_data(available)[1])
	var header := request.get_string_from_ascii()
	if not header.begins_with("GET /models HTTP/1.1\r\n") \
			or not header.contains("Authorization: Bearer fixture-model-list-key\r\n") \
			or not header.ends_with("\r\n\r\n"):
		_fail("title model list", "request did not use the matching API base path and current key")
		peer.disconnect_from_host()
		settings.free()
		return
	var body := '{"data":[{"id":"vendor/model:latest","name":"Display name"},{"id":"vendor/model:latest"},{"id":null}]}'
	peer.put_data(("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s" % [body.length(), body]).to_utf8_buffer())
	while settings._fetch_button.disabled and Time.get_ticks_msec() < deadline:
		await process_frame
	peer.disconnect_from_host()
	if settings._model_menu.item_count != 1:
		_fail("title model list", "client did not receive exactly one valid model ID")
	else:
		settings._model_menu.index_pressed.emit(0)
		if settings._model.text != "vendor/model:latest":
			_fail("title model list", "selection did not use the provider's exact model ID")
		settings._load_route(Client.ASSISTANT)
		if settings._model_menu.item_count != 0 or settings._model_menu.visible:
			_fail("title model list", "switching routes retained the old provider's items")
	settings.free()

func _verify_title_address_drag(field: LineEdit) -> void:
	var url := "https://gateway.example.test/teams/prism/openai/v1"
	field.text = url
	field.select_all()
	var start := field.get_global_transform_with_canvas() * Vector2(89, field.size.y / 2.0)
	var end := start + Vector2(80, 0)
	var click := InputEventMouseButton.new()
	click.position = start
	click.global_position = start
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	click.pressed = true
	root.push_input(click, true)
	var motion := InputEventMouseMotion.new()
	motion.position = end
	motion.global_position = end
	motion.relative = end - start
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	click = click.duplicate()
	click.position = end
	click.global_position = end
	click.button_mask = 0
	click.pressed = false
	root.push_input(click, true)
	var first := field.get_selection_from_column()
	var last := field.get_selection_to_column()
	if not field.has_selection() or first <= 0 or last >= url.length():
		_fail("title address drag", "dragging from selected text did not select a partial range")
		return
	var letter := InputEventKey.new()
	letter.keycode = KEY_X
	letter.unicode = "x".unicode_at(0)
	letter.pressed = true
	root.push_input(letter, true)
	if field.text != url.left(first) + "x" + url.substr(last):
		_fail("title address drag", "typing did not replace the selected range")

func _verify_model_routes() -> void:
	var client := Client.new()
	var capture := CaptureTransport.new()
	client._transport.free()
	client._transport = capture
	root.add_child(client)
	client.profiles[Client.ASSISTANT] = {"url": "https://assistant.invalid", "model": "flash-fixture", "key": "assistant-fixture"}
	client.profiles[Client.DIALOGUE] = {"url": "https://dialogue.invalid", "model": "argon-fixture", "key": "dialogue-fixture"}
	var reads: Array[bool] = []
	client.world_status = func():
		reads.append(true)
		return {"location": "world fixture"}
	var tool_message := {"tool_calls": [{"id": "route-test", "function": {"name": "get_world_status", "arguments": "{}"}}]}

	client.open(Client.ASSISTANT, "same-scope", {})
	client.send("assistant question")
	if capture.request.model != "flash-fixture" or capture.request.stream or not capture.request.has("tools"):
		_fail("model routes", "assistant request used the wrong model or tool mode")
	client.profiles[Client.ASSISTANT] = {"url": "https://updated.invalid", "model": "updated-fixture", "key": "updated-fixture"}
	for offset in client.MAX_TOOL_ROUNDS:
		capture.finished.emit(tool_message, "")
		if capture.request.model != "flash-fixture" or capture.url != "https://assistant.invalid" or capture.key != "assistant-fixture":
			_fail("model routes", "assistant tool round changed its connection profile")
		if capture.request.has("tools") != (offset + 1 < client.MAX_TOOL_ROUNDS):
			_fail("model routes", "assistant tool budget was not enforced")
	var sends := capture.sends
	capture.finished.emit(tool_message, "")
	if capture.sends != sends or reads.size() != client.MAX_TOOL_ROUNDS or client.pending:
		_fail("model routes", "tool call executed after reaching the limit")
	client.retry()
	if not capture.request.has("tools") or capture.request.model != "updated-fixture":
		_fail("model routes", "retry lost read-only tool access or updated profile")
	capture.finished.emit({"content": "retry answer"}, "")

	client.open(Client.DIALOGUE, "same-scope", {})
	client.send("dialogue question")
	if capture.request.model != "argon-fixture" or capture.url != "https://dialogue.invalid" or capture.key != "dialogue-fixture" \
			or not capture.request.stream or capture.request.has("tools") or capture.request.has("tool_choice") \
			or capture.request.has("functions") or capture.request.has("function_call") \
			or JSON.stringify(capture.request.messages).contains("assistant question"):
		_fail("model routes", "assistant settings, history, or tools entered the dialogue request")
	sends = capture.sends
	capture.finished.emit(tool_message, "")
	if capture.sends != sends or reads.size() != client.MAX_TOOL_ROUNDS:
		_fail("model routes", "dialogue response executed a tool")

	client.send("dialogue cancellation")
	client.open(Client.ASSISTANT, "same-scope", {})
	if client.pending or client.history.size() != 1 or client.history[0].user != "assistant question":
		_fail("model routes", "entry switch did not cancel or restore the separate history")
	client.send("another assistant question")
	if capture.request.model != "updated-fixture" or JSON.stringify(capture.request.messages).contains("dialogue question"):
		_fail("model routes", "assistant request reused old settings or dialogue history")
	capture.finished.emit({"content": "assistant answer"}, "")
	client.free()

func _verify_assistant_retry() -> void:
	var client := Client.new()
	var capture := CaptureTransport.new()
	client._transport.free()
	client._transport = capture
	root.add_child(client)
	client.profiles[Client.ASSISTANT] = {"url": "https://fixture.invalid", "model": "flash-fixture", "key": ""}
	client.profiles[Client.DIALOGUE] = {"url": "https://fixture.invalid", "model": "dialogue-fixture", "key": ""}
	client.world_status = func(): return {}
	var temporary_failure := {"retryable": true, "retry_after_seconds": 3}
	client.open(Client.ASSISTANT, "retry", {})
	client.send("assistant question")
	var initial := capture.request.duplicate(true)
	var sends := capture.sends
	for attempt in Client.MAX_ASSISTANT_RETRIES:
		capture.failure_details = temporary_failure
		capture.finished.emit({}, "temporary error")
		if not client.pending or client._assistant_retry_timer.wait_time < 3 or capture.sends != sends + attempt:
			_fail("assistant retry", "temporary error skipped backoff or changed turn state")
		client._assistant_retry_timer.stop()
		client._assistant_retry_timer.timeout.emit()
		if capture.request != initial or client.history.size() != 1:
			_fail("assistant retry", "retry changed payload or duplicated history")
	capture.finished.emit({}, "temporary error")
	if client.pending or capture.sends != sends + Client.MAX_ASSISTANT_RETRIES:
		_fail("assistant retry", "retry count exceeded limit")
	client.send("cancel while waiting")
	capture.finished.emit({}, "temporary error")
	client.stop()
	sends = capture.sends
	client._assistant_retry_timer.timeout.emit()
	if not client._assistant_retry_timer.is_stopped() or capture.sends != sends:
		_fail("assistant retry", "stopped retry sent another request")
	client.send("run tool")
	capture.finished.emit({"tool_calls": [{"id": "retry-tool", "function": {"name": "get_world_status", "arguments": "{}"}}]}, "")
	sends = capture.sends
	capture.failure_details = temporary_failure
	capture.finished.emit({}, "temporary error")
	if client.pending or not client._assistant_retry_timer.is_stopped() or capture.sends != sends:
		_fail("assistant retry", "automatic retry ran after tools")
	client.send("tool without final text")
	capture.finished.emit({"content": "让我查一下", "tool_calls": [{"id": "empty-tool", "function": {"name": "get_world_status", "arguments": "{}"}}]}, "")
	sends = capture.sends
	if capture.request.messages[-2].content != "让我查一下":
		_fail("assistant tools", "tool-call commentary was lost from the tool request")
	capture.finished.emit({"content": null}, "")
	if client.pending or capture.sends != sends or client.status != "已查询游戏状态，模型未返回说明。" or not client.active_reply().is_empty():
		_fail("assistant retry", "tool-only success was treated as a failure")
	client.send("long retry after")
	sends = capture.sends
	capture.failure_details = {"retryable": true, "retry_after_seconds": 30}
	capture.finished.emit({}, "long retry after")
	if client.pending or capture.sends != sends:
		_fail("assistant retry", "long Retry-After triggered an automatic retry")
	client.open(Client.DIALOGUE, "manual retry", {})
	client.send("dialogue question")
	sends = capture.sends
	capture.failure_details = temporary_failure
	capture.finished.emit({}, "temporary error")
	if client.pending or not client._assistant_retry_timer.is_stopped() or capture.sends != sends:
		_fail("dialogue retry", "free dialogue retried automatically")
	client.retry()
	if capture.sends != sends + 1 or client.history.size() != 1:
		_fail("dialogue retry", "manual retry did not reuse the user turn")
	client.free()

func _verify_context_budget() -> void:
	var client := Client.new()
	var capture := CaptureTransport.new()
	client._transport.free()
	client._transport = capture
	root.add_child(client)
	client.profiles[Client.DIALOGUE] = {"url": "https://fixture.invalid", "model": "fixture", "key": ""}
	client.open(Client.DIALOGUE, "budget", {
		"npc_name": "FixtureNPC", "dialogue_location": "FixtureLocation",
	})
	var prompt := "开始{{// 第一行\n{{unknown {{npc_name}}}} 注释尾}}保留{{npc_name}}{{// 另一段}}于{{dialogue_location}}"
	if client._expand_dialogue_prompt(prompt) != "开始保留FixtureNPC于FixtureLocation":
		_fail("prompt macros", "nested or consecutive comments changed visible prompt text")
	if client._expand_dialogue_prompt("保留{{// 未闭合，内含 {{npc_name}}") != "保留":
		_fail("prompt macros", "unclosed comment text entered the visible prompt")
	for i in range(6):
		client.send("问题%d" % i)
		capture.delta_received.emit("回复%d" % i)
		capture.finished.emit({}, "")
	var full_messages: Array = capture.request.messages
	# Before the final four chat messages: reply 3, question 4, reply 4, question 5.
	if full_messages.size() != 14 or full_messages[7].content != "问题3" \
			or full_messages[8].role != "system" or not full_messages[8].content.contains("[Game rules]") \
			or full_messages[9].content != "回复3" or full_messages[12].content != "问题5" \
			or JSON.stringify(full_messages).count("[Game rules]") != 1:
		_fail("worldbook depth", "world rules must be inserted before the final four chat messages")
	var budget := Client.OUTPUT_TOKEN_RESERVE + Client._message_tokens(Client.DIALOGUE_SYSTEM)
	for row: Dictionary in client._dialogue_entries:
		budget += Client._message_tokens({"content": client._expand_dialogue_prompt(row.content)})
	for content: String in ["问题5", "回复5", "最后的问题"]:
		budget += Client._message_tokens({"content": content})
	client._context_limit_tokens = budget + 3
	client.send("最后的问题")
	var messages: Array = capture.request.messages
	if _role_contents(messages, "user") != ["问题5", "最后的问题"] or _role_contents(messages, "assistant") != ["回复5"]:
		_fail("context budget", "history did not preserve the newest complete turns")
	if client.history.size() != 7 or client.omitted_turns != 5 or capture.request.max_tokens != 8000:
		_fail("context budget", "request budget changed local history")
	var before: String = messages.front().content
	var after: String = messages.back().content
	if messages.size() != 5 \
			or not _ordered_text(before, ["[game Materials]", "玩家称呼：", "核心设定集", "当前对话对象：FixtureNPC", "当前对话地点：FixtureLocation", "[Game rules]"]) \
			or after.contains("[Game rules]") or after.contains("核心设定集"):
		_fail("context budget", "worldbook placement or dynamic marker order is incorrect")
	if not _has_final_dialogue_format(messages) or after.contains("img-prompt") or before.contains("{{//") or after.contains("{{//"):
		_fail("context budget", "shared prompt or prompt cleanup is incorrect")
	client.stop()
	var sends := capture.sends
	if client.send("长".repeat(budget)) or client.history.size() != 7 or capture.sends != sends \
			or not client.status.contains("上下文预算") or client.pending:
		_fail("context budget", "oversize current turn was sent or left pending")
	client.free()

func _verify_tool_context_budget() -> void:
	var client := Client.new()
	var capture := CaptureTransport.new()
	client._transport.free()
	client._transport = capture
	root.add_child(client)
	client.profiles[Client.ASSISTANT] = {"url": "https://fixture.invalid", "model": "fixture", "key": ""}
	client.world_status = func(): return {"location": "地".repeat(180)}
	client.open(Client.ASSISTANT, "tool context", {})
	client.send("older " + "字".repeat(240))
	capture.finished.emit({"content": "old answer"}, "")
	client.send("newer")
	capture.finished.emit({"content": "new answer"}, "")
	client.send("current query")
	var budget := Client.OUTPUT_TOKEN_RESERVE + Client._text_tokens(JSON.stringify(Client.TOOLS))
	for row: Dictionary in capture.request.messages:
		budget += Client._message_tokens(row)
	client.stop()
	client._context_limit_tokens = budget + 5
	client.retry()
	var tool_message := {"tool_calls": [{"id": "budget-check", "function": {"name": "get_world_status", "arguments": "{}"}}]}
	capture.finished.emit(tool_message, "")
	if _role_contents(capture.request.messages, "user") != ["newer", "current query"] \
			or capture.request.messages.back().role != "tool" or client.omitted_turns != 1:
		_fail("tool context", "tool output budget split a round or dropped the current query")
	var sends := capture.sends
	client.world_status = func(): return {"location": "地".repeat(500)}
	capture.finished.emit(tool_message, "")
	if capture.sends != sends or client.pending or not client.status.contains("上下文预算"):
		_fail("tool context", "oversize tool output was dispatched")
	client.free()

func _verify_blank_player_profile(client: Node) -> void:
	var path := "user://llm_profile_fixture_%d.md" % Time.get_ticks_usec()
	for contents: String in ["", '{"depth": 978, "name": "玩家人设"}\n---']:
		var fixture := FileAccess.open(path, FileAccess.WRITE)
		if fixture == null:
			_fail("player profile", "could not write temporary player profile")
			return
		fixture.store_string(contents)
		fixture.close()
		var error: String = client._load_dialogue_markdown(path)
		if not error.is_empty() or client._dialogue_entries.any(func(row: Dictionary): return row.depth == 978):
			_fail("player profile", "empty player profile blocked dialogue or was included")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _verify_teleport_lifecycle() -> void:
	var client := Client.new()
	var capture := CaptureTransport.new()
	client._transport.free()
	client._transport = capture
	root.add_child(client)
	client.profiles[Client.ASSISTANT] = {"url": "https://fixture.invalid", "model": "fixture", "key": ""}
	client.world_status = func(): return {"destinations": [{"id": "one"}, {"id": "two"}]}
	var attempts: Array[String] = []
	client.world_teleport = func(destination: String):
		attempts.append(destination)
		return {"ok": attempts.size() > 1, "message": "fixture result"}
	client.open(Client.ASSISTANT, "offer", {})
	client.send("propose")
	capture.finished.emit({"tool_calls": [
		{"id": "first", "function": {"name": "propose_teleport", "arguments": JSON.stringify({"destination_id": "one"})}},
		{"id": "second", "function": {"name": "propose_teleport", "arguments": JSON.stringify({"destination_id": "two"})}},
	]}, "")
	if not capture.request.messages.back().content.contains("one_teleport_proposal_per_turn"):
		_fail("teleport lifecycle", "a duplicate proposal was accepted")
	if client.teleport_offer() != "" or not attempts.is_empty():
		_fail("teleport lifecycle", "proposal was presented or executed before the tool request ended")
	capture.finished.emit({}, "follow-up failed")
	if client.teleport_offer() != "one" or not client.status.contains("传送提议仍可确认"):
		_fail("teleport lifecycle", "failed follow-up lost the pending proposal")
	client.confirm_teleport()
	if attempts != ["one"] or client.teleport_offer() != "one":
		_fail("teleport lifecycle", "failed confirmation consumed the offer")
	client.send("unrelated")
	client.confirm_teleport()
	capture.finished.emit({"content": "answer"}, "")
	if attempts != ["one"] or client.teleport_offer() != "one":
		_fail("teleport lifecycle", "new or pending turn invalidated or executed the offer")
	client.confirm_teleport()
	client.confirm_teleport()
	if attempts != ["one", "one"] or not client.teleport_offer().is_empty():
		_fail("teleport lifecycle", "success did not consume exactly one offer")
	client.undo()
	if client.can_retry():
		_fail("teleport lifecycle", "tool turn containing a committed action was retryable")
	client.free()

func _ordered_text(text: String, tokens: Array) -> bool:
	var cursor := 0
	for token: String in tokens:
		var position := text.find(token, cursor)
		if position < 0:
			return false
		cursor = position + token.length()
	return true

func _role_contents(messages: Array, role: String) -> Array:
	var contents := []
	for message: Dictionary in messages:
		if message.role == role:
			contents.append(message.content)
	return contents

func _has_final_dialogue_format(messages: Array) -> bool:
	var final_system: Dictionary = messages.back()
	return final_system.role == "system" \
		and _ordered_text(final_system.content, ["<game></game>", "【当前回复的结束边界】", "<censorship_bypass>"]) \
		and final_system.content.ends_with("</censorship_bypass>") \
		and JSON.stringify(messages).count("<censorship_bypass>") == 1

func _verify_report_panel() -> void:
	var panel := ChatPanel.new()
	var capture := CaptureTransport.new()
	panel.client._transport.free()
	panel.client._transport = capture
	root.add_child(panel)
	var client = panel.client
	client.profiles[Client.DIALOGUE] = {"url": "https://fixture.invalid", "model": "fixture", "key": ""}
	panel.open_panel(Client.DIALOGUE, "report", {})
	await process_frame
	client.send("question")
	capture.delta_received.emit("<rep")
	if panel._transcript.get_parsed_text().contains("<rep"):
		_fail("report panel", "partial tag was displayed")
	capture.delta_received.emit("ort_nya~>REPORT 内容 <game>标签示例</game></report_nya~>前置杂文<game>正文")
	var visible_text := panel._transcript.get_parsed_text()
	if not visible_text.contains("正文") or visible_text.contains("REPORT 内容") or visible_text.contains("标签示例") \
			or visible_text.contains("前置杂文") or not visible_text.contains("查看报告"):
		_fail("report panel", "body or collapsed report state is wrong")
	panel._transcript.meta_clicked.emit(Vector2i(0, 0))
	if not panel._transcript.get_parsed_text().contains("REPORT 内容"):
		_fail("report panel", "report did not expand")
	capture.delta_received.emit("</game>尾部杂文")
	capture.finished.emit({}, "")
	if not panel._transcript.get_parsed_text().contains("REPORT 内容") or panel._transcript.get_parsed_text().contains("尾部杂文"):
		_fail("report panel", "expansion lost on completion")
	panel._transcript.meta_clicked.emit(Vector2i(0, 0))
	if panel._transcript.get_parsed_text().contains("REPORT 内容"):
		_fail("report panel", "report did not collapse")
	client.continue_reply()
	if not {"role": "assistant", "content": "正文"} in capture.request.messages:
		_fail("report panel", "history did not preserve clean body")
	capture.delta_received.emit("继续")
	capture.finished.emit({}, "")
	if not panel._transcript.get_parsed_text().contains("正文继续"):
		_fail("report panel", "plain continuation lost")
	client.continue_reply()
	capture.delta_received.emit("续写杂文<game>下一段</game>尾部杂文")
	capture.finished.emit({}, "")
	client.continue_reply()
	capture.delta_received.emit("不完整的续写")
	capture.finished.emit({}, "续写失败样例")
	if not panel._transcript.get_parsed_text().contains("不完整的续写") or not panel._transcript.get_parsed_text().contains("续写失败样例"):
		_fail("failed continuation", "partial continuation or its error was hidden")
	client.send("follow up")
	if not {"role": "assistant", "content": "正文继续下一段"} in capture.request.messages or JSON.stringify(capture.request.messages).contains("不完整的续写"):
		_fail("failed continuation", "follow-up lost the successful reply or included the failed fragment")
	capture.delta_received.emit("<think_nya~>STOP REPORT")
	if panel._send.text != "停止":
		_fail("report panel", "send button did not change to stop during streaming")
	var shortcut := InputEventKey.new()
	shortcut.keycode = KEY_ENTER
	shortcut.ctrl_pressed = true
	shortcut.pressed = true
	panel._input(shortcut)
	if not client.pending or not panel._draft.placeholder_text.contains("生成中"):
		_fail("pending shortcut", "Ctrl+Enter stopped generation or showed a send hint")
	panel._send.pressed.emit()
	if client.pending or panel._send.text != "发送":
		_fail("report panel", "stop button did not cancel and restore send")
	if panel._transcript.get_parsed_text().contains("STOP REPORT") or not panel._continue.disabled:
		_fail("report panel", "stopped report leaked")
	panel._transcript.meta_clicked.emit(Vector2i(1, 0))
	if not panel._transcript.get_parsed_text().contains("STOP REPORT"):
		_fail("report panel", "stopped report not inspectable")
	client.send("failed HTTP turn")
	capture.finished.emit({}, "test HTTP failure")
	if not panel._copy_diagnostic.visible or not client.can_retry():
		_fail("failed turns", "failure diagnostics or manual retry unavailable")
	panel.close_panel()
	panel.open_panel(Client.DIALOGUE, "report", {})
	if not panel._copy_diagnostic.visible or not panel._transcript.get_parsed_text().contains("test HTTP failure"):
		_fail("failed turns", "closing the panel lost the error and diagnostic")
	client.send("new turn")
	if _role_contents(capture.request.messages, "user") != ["question", "new turn"] or not panel._status.text.contains("2 个未完成回合"):
		_fail("failed turns", "failed user messages entered the new request")
	capture.delta_received.emit("new answer")
	capture.finished.emit({}, "")
	var budget := Client.OUTPUT_TOKEN_RESERVE + Client._message_tokens(Client.DIALOGUE_SYSTEM)
	for row: Dictionary in client._dialogue_entries:
		budget += Client._message_tokens({"content": client._expand_dialogue_prompt(row.content)})
	for content: String in ["new turn", "new answer", "trimmed"]:
		budget += Client._message_tokens({"content": content})
	client._context_limit_tokens = budget + 3
	client.send("trimmed")
	if not panel._status.text.contains("省略了 1 个较早回合"):
		_fail("context budget", "panel did not show truncation")
	panel.close_panel()
	panel.free()

func _run_case(server: TCPServer, client: Node, fixture: Dictionary) -> void:
	var title: String = fixture.name
	var route: String = fixture.get("route", Client.DIALOGUE)
	client.open(route, title, {"npc_name": "FixtureNPC", "dialogue_location": "FixtureLocation"})
	if not client.send("stream fixture"):
		_fail(title, "could not send request")
		return
	var deadline := Time.get_ticks_msec() + CASE_TIMEOUT_MS
	var peer := server.take_connection()
	while peer == null and Time.get_ticks_msec() < deadline:
		await process_frame
		peer = server.take_connection()
	if peer == null:
		_fail(title, "no loopback connection")
		client.stop()
		return
	var request := PackedByteArray()
	var payload: Variant
	while payload == null and Time.get_ticks_msec() < deadline:
		await process_frame
		peer.poll()
		var available := peer.get_available_bytes()
		if available > 0:
			request.append_array(peer.get_data(available)[1])
			payload = _request_payload(request)
	if not payload is Dictionary:
		_fail(title, "missing or malformed request")
		peer.disconnect_from_host()
		client.stop()
		return
	var messages: Array = payload.messages
	if payload.has("temperature") or payload.has("top_p"):
		_fail(title, "request still sends obsolete sampling parameters")
	var before: String = messages.front().content
	var after: String = messages.back().content
	if route == Client.ASSISTANT:
		if payload.stream or not payload.has("tools") or _role_contents(messages, "user") != ["stream fixture"] \
				or before.contains("[Game rules]"):
			_fail(title, "unexpected assistant request composition")
	elif messages.size() != 3 or _role_contents(messages, "user") != ["stream fixture"] \
			or not _ordered_text(before, ["[game Materials]", "玩家称呼：", "核心设定集", "当前对话对象：FixtureNPC", "当前对话地点：FixtureLocation", "[Game rules]", "故事的整体氛围应始终保持"]) \
			or after.contains("核心设定集") \
			or JSON.stringify(messages).count("[Game rules]") != 1 or JSON.stringify(messages).count("[game Materials]") != 1 \
			or before.contains("{{") or after.contains("{{") \
			or not _has_final_dialogue_format(messages) or after.contains("img-prompt") \
			or not payload.stream or payload.has("tools") or payload.has("tool_choice"):
		_fail(title, "unexpected dialogue prompt composition")
	if fixture.get("cancel", false):
		client.stop()
		peer.disconnect_from_host()
	else:
		var body: String = fixture.body
		var first: String = fixture.get("first", "")
		var bytes := (first + body).to_utf8_buffer()
		var mime: String = fixture.get("mime", "text/event-stream" if route == Client.DIALOGUE else "application/json")
		var code: int = fixture.get("code", 200)
		var held: bool = fixture.get("held", false)
		var length_header := "" if held else "Content-Length: %d\r\n" % bytes.size()
		var content_type := "" if mime.is_empty() else "Content-Type: %s\r\n" % mime
		var headers := "HTTP/1.1 %d Test\r\n%s%s%sConnection: close\r\n\r\n" % [code, content_type, length_header, fixture.get("response_headers", "")]
		if not first.is_empty():
			peer.put_data((headers + first).to_utf8_buffer())
			while client.partial.is_empty() and client.pending and Time.get_ticks_msec() < deadline:
				await process_frame
			if client.partial != fixture.visible or not client.pending:
				_fail(title, "incomplete escape was displayed or preceding text was delayed")
			if fixture.get("cancel_after_text", false):
				client.stop()
			else:
				peer.put_data(body.to_utf8_buffer())
		elif title == "split UTF-8":
			var split_at := bytes.find(0xe4) + 1
			peer.put_data(headers.to_utf8_buffer() + bytes.slice(0, split_at))
			await create_timer(0.06).timeout
			var first_event_end := _sse({"choices": [{"delta": {"content": "你好"}}]}).to_utf8_buffer().size()
			peer.put_data(bytes.slice(split_at, first_event_end))
			while client.partial.is_empty() and client.pending and Time.get_ticks_msec() < deadline:
				await process_frame
			if client.partial != "你好" or not client.pending:
				_fail(title, "text was not displayed before the terminal event")
			peer.put_data(bytes.slice(first_event_end))
		else:
			peer.put_data(headers.to_utf8_buffer() + bytes)
		if fixture.get("timeout", false):
			while client._transport._received_bytes < bytes.size() and client.pending and Time.get_ticks_msec() < deadline:
				await process_frame
			client._transport._deadline = Time.get_ticks_msec() - 1
		while client.pending and Time.get_ticks_msec() < deadline:
			await process_frame
		peer.disconnect_from_host()
	if client.pending:
		_fail(title, "client stayed pending")
		client.stop()
	var actual_text: String = client.active_reply().get("text", "")
	if actual_text != fixture.text:
		_fail(title, "wrong saved text: " + actual_text)
	if fixture.has("retryable") and client._transport.failure_details.get("retryable") != fixture.retryable:
		_fail(title, "incorrect retry classification")
	if fixture.has("error"):
		if not client.status.contains(fixture.error):
			_fail(title, "unexpected error: " + client.status)
		if fixture.get("redacted", false) and ((client.status + client.diagnostic).contains("fixture-private-key") \
				or (client.status + client.diagnostic).contains("other-private-key") or client.diagnostic.contains("stream fixture") \
				or (client.status + client.diagnostic).contains("https://fixture.invalid")):
			_fail(title, "HTTP details disclosed a credential")
		for expected: String in fixture.get("diagnostic", []):
			if not client.diagnostic.contains(expected):
				_fail(title, "missing diagnostic field: " + expected)
	elif client.status != fixture.status:
		_fail(title, "unexpected status: " + client.status)

func _request_payload(bytes: PackedByteArray) -> Variant:
	var boundary := bytes.find(13)
	while boundary >= 0 and boundary + 3 < bytes.size():
		if bytes[boundary + 1] == 10 and bytes[boundary + 2] == 13 and bytes[boundary + 3] == 10:
			break
		boundary = bytes.find(13, boundary + 1)
	if boundary < 0 or boundary + 3 >= bytes.size():
		return null
	var header := bytes.slice(0, boundary).get_string_from_utf8()
	if not header.begins_with("POST /chat/completions "):
		return null
	var body_start := boundary + 4
	for line in header.split("\r\n"):
		if line.to_lower().begins_with("content-length:"):
			var size := int(line.get_slice(":", 1).strip_edges())
			if bytes.size() - body_start >= size:
				return JSON.parse_string(bytes.slice(body_start, body_start + size).get_string_from_utf8())
	return null

func _fail(title: String, detail: String) -> void:
	printerr(title, " — ", detail)
	_failures += 1

func _sse(data: Dictionary) -> String:
	return "data: " + JSON.stringify(data) + "\r\n\r\n"

func _text_event(text: String) -> String:
	return _sse({"choices": [{"delta": {"content": text}}]})
