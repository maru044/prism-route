extends SceneTree

const Transport := preload("res://scripts/ai/chat_transport.gd")
const Client := preload("res://scripts/ai/game_llm_client.gd")
const LOCALHOST := "127.0.0.1"
const CASE_TIMEOUT_MS := 5000

var _failures := 0

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
	var cases := [
		{"name": "split UTF-8", "body": text + stop + "data: [DONE]\r\n\r\n", "text": "你好", "status": ""},
		{"name": "finish reason and open connection", "body": text + stop, "text": "你好", "status": "", "held": true},
		{"name": "truncated stream", "body": text + "data: {", "text": "你好", "error": "中断"},
		{"name": "server event error", "body": text + _sse({"error": {"message": "fixture"}}), "text": "你好", "error": "错误事件"},
		{"name": "invalid choices after text", "body": text + _sse({"choices": {}}), "text": "你好", "error": "无效的流式选项"},
		{"name": "output token limit", "body": text + _sse({"choices": [{"finish_reason": "length"}]}), "text": "你好", "error": "输出上限"},
		{"name": "unexpected tool turn", "body": _sse({"choices": [{"finish_reason": "tool_calls"}]}), "text": "", "error": "只接收文本"},
		{"name": "JSON instead of SSE", "body": "{}", "mime": "application/json", "text": "", "error": "普通 JSON"},
		{"name": "HTML instead of SSE", "body": "<html></html>", "mime": "text/html", "text": "", "error": "返回了网页"},
		{"name": "rate limit", "body": "{}", "code": 429, "mime": "application/json", "text": "", "error": "429"},
		{"name": "cancel before text", "body": "", "text": "", "status": "已停止", "cancel": true},
		{"name": "stalled before text", "body": ": keepalive\r\n\r\n", "text": "", "error": "第一段", "held": true, "timeout": true},
		{"name": "stalled after text", "body": text + ": keepalive\r\n\r\n", "text": "你好", "error": "中途", "held": true, "timeout": true},
	]
	for fixture: Dictionary in cases:
		await _run_case(server, client, fixture)
	client.free()
	server.stop()
	print("LLM_STREAM cases=", cases.size(), " failures=", _failures)
	quit(0 if _failures == 0 else 1)

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
		var bytes := body.to_utf8_buffer()
		var mime: String = fixture.get("mime", "text/event-stream")
		var code: int = fixture.get("code", 200)
		var held: bool = fixture.get("held", false)
		var length_header := "" if held else "Content-Length: %d\r\n" % bytes.size()
		var headers := "HTTP/1.1 %d Test\r\nContent-Type: %s\r\n%sConnection: close\r\n\r\n" % [code, mime, length_header]
		if title == "split UTF-8":
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
