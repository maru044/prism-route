extends SceneTree

const Transport := preload("res://scripts/ai/chat_transport.gd")
const Client := preload("res://scripts/ai/game_llm_client.gd")
const ChatPanel := preload("res://scripts/ai/llm_panel.gd")
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
	var client := Client.new()
	root.add_child(client)
	client.profiles[Client.DIALOGUE] = {
		"url": "http://%s:%d/v1" % [LOCALHOST, server.get_local_port()], "model": "fixture", "key": "",
	}
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
		{"name": "HTML instead of SSE", "body": "<html></html>", "mime": "text/html", "text": "", "error": "返回了网页"},
		{"name": "rate limit", "body": "{}", "code": 429, "mime": "application/json", "text": "", "error": "429"},
		{"name": "cancel before text", "body": "", "text": "", "status": "已停止", "cancel": true},
		{"name": "stalled before text", "body": ": keepalive\r\n\r\n", "text": "", "error": "第一段", "held": true, "timeout": true},
		{"name": "stalled after text", "body": text + ": keepalive\r\n\r\n", "text": "你好", "error": "中途", "held": true, "timeout": true},
	]
	for fixture: Dictionary in cases:
		await _run_case(server, client, fixture)
	await _verify_report_panel()
	_verify_model_routes()
	client.free()
	server.stop()
	print("LLM_STREAM cases=", cases.size(), " report_panel=1 model_routes=1 failures=", _failures)
	quit(0 if _failures == 0 else 1)

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
	capture.delta_received.emit("ort_nya~>REPORT 内容 <game>标签示例</game></report_nya~><game>正文")
	var visible_text := panel._transcript.get_parsed_text()
	if not visible_text.contains("正文") or visible_text.contains("REPORT 内容") or visible_text.contains("标签示例") or not visible_text.contains("查看报告"):
		_fail("report panel", "body or collapsed report state is wrong")
	panel._transcript.meta_clicked.emit(Vector2i(0, 0))
	if not panel._transcript.get_parsed_text().contains("REPORT 内容"):
		_fail("report panel", "report did not expand")
	capture.delta_received.emit("</game>")
	capture.finished.emit({}, "")
	if not panel._transcript.get_parsed_text().contains("REPORT 内容"):
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
	client.send("follow up")
	if not {"role": "assistant", "content": "正文继续"} in capture.request.messages:
		_fail("report panel", "follow-up history included formatting")
	capture.delta_received.emit("<think_nya~>STOP REPORT")
	client.stop()
	if panel._transcript.get_parsed_text().contains("STOP REPORT") or not panel._continue.disabled:
		_fail("report panel", "stopped report leaked")
	panel._transcript.meta_clicked.emit(Vector2i(1, 0))
	if not panel._transcript.get_parsed_text().contains("STOP REPORT"):
		_fail("report panel", "stopped report not inspectable")
	panel.close_panel()
	panel.free()

func _run_case(server: TCPServer, client: Node, fixture: Dictionary) -> void:
	var title: String = fixture.name
	client.open(Client.DIALOGUE, title, {"user": "FixturePlayer", "description": "FixtureCharacter"})
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
	if messages.size() != 3 or not messages[0].content.contains("[Game rules]") or not messages[0].content.contains("核心设定集") or not messages[0].content.contains("FixtureCharacter") \
			or messages[1] != {"role": "user", "content": "stream fixture"} \
			or messages[2].role != "system" or not messages[2].content.contains("FixturePlayer") \
			or not messages[2].content.contains("活人感") or messages[2].content.contains("{{user}}") \
			or not payload.stream or payload.has("tools") or payload.has("tool_choice"):
		_fail(title, "unexpected dialogue prompt composition")
	if fixture.get("cancel", false):
		client.stop()
		peer.disconnect_from_host()
	else:
		var body: String = fixture.body
		var first: String = fixture.get("first", "")
		var bytes := (first + body).to_utf8_buffer()
		var mime: String = fixture.get("mime", "text/event-stream")
		var code: int = fixture.get("code", 200)
		var held: bool = fixture.get("held", false)
		var length_header := "" if held else "Content-Length: %d\r\n" % bytes.size()
		var headers := "HTTP/1.1 %d Test\r\nContent-Type: %s\r\n%sConnection: close\r\n\r\n" % [code, mime, length_header]
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
	if fixture.has("error"):
		if not client.status.contains(fixture.error):
			_fail(title, "unexpected error: " + client.status)
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
	if not header.begins_with("POST /v1/chat/completions "):
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
