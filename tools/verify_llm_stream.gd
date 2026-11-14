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
	client.open(Client.DIALOGUE, title, {})
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
	var request := ""
	while not request.contains("\r\n\r\n") and Time.get_ticks_msec() < deadline:
		await process_frame
		peer.poll()
		var available := peer.get_available_bytes()
		if available > 0:
			request += peer.get_utf8_string(available)
	if not request.begins_with("POST /v1/chat/completions "):
		_fail(title, "unexpected request path")
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

func _fail(title: String, detail: String) -> void:
	printerr(title, " — ", detail)
	_failures += 1

func _sse(data: Dictionary) -> String:
	return "data: " + JSON.stringify(data) + "\r\n\r\n"
