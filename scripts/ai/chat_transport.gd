extends Node

signal delta_received(text: String)
signal finished(message: Dictionary, error: String)

const CONNECT_TIMEOUT_MS := 30000
const RESPONSE_TIMEOUT_MS := 120000
const STREAM_END_GRACE_MS := 2000
const MAX_RESPONSE_BYTES := 4 * 1024 * 1024
const MAX_ERROR_BYTES := 8192
const ERROR_BODY_TIMEOUT_MS := 2000
static var _sensitive_error := RegEx.create_from_string(
	r"""(?i)\b(?:authorization|api[-_ ]?key|access[-_ ]?token|proxy[-_ ]?password|password|secret)["']?[ \t]*[:=][ \t]*(?:bearer[ \t]+)?(?:"[^"]*"|'[^']*'|[^,\s;]+)|\bbearer[ \t]+[^,\s;]+|\b(?:sk-|AIza)[A-Za-z0-9_-]{8,}"""
)

var _client: HTTPClient
var _target: Dictionary
var _headers: PackedStringArray
var _request_body: String
var _stream := false
var _sent := false
var _code := -1
var _deadline: int
var _received_bytes := 0
var _buffer := PackedByteArray()
var _data := PackedStringArray()
var _after_cr := false
var _stream_finish := ""
var _has_stream_text := false
var _response_key := ""

func _ready() -> void:
	set_process(false)

static func endpoint(raw: String) -> Dictionary:
	var matcher := RegEx.create_from_string("^(https?)://(\\[[0-9a-fA-F:]+\\]|[a-zA-Z0-9.-]+)(?::([0-9]+))?(/[^\\s?#]*)?$")
	var parts := matcher.search(raw.strip_edges())
	if parts == null:
		return {}
	var secure := parts.get_string(1) == "https"
	var host := parts.get_string(2).trim_prefix("[").trim_suffix("]")
	if not secure and host not in ["localhost", "127.0.0.1", "::1"]:
		return {}
	var port_string := parts.get_string(3)
	var port := int(port_string) if not port_string.is_empty() else (443 if secure else 80)
	if port < 1 or port > 65535:
		return {}
	var path := parts.get_string(4).rstrip("/")
	if not path.ends_with("/chat/completions"):
		path = ("/v1" if path.is_empty() else path) + "/chat/completions"
	return {"host": host, "port": port, "path": path, "secure": secure}

func start(url: String, key: String, payload: Dictionary) -> String:
	cancel()
	var validation := connection_error(url, key)
	if not validation.is_empty():
		return validation
	_target = endpoint(url)
	_response_key = key
	_client = HTTPClient.new()
	_stream = bool(payload.get("stream", false))
	_headers = PackedStringArray([
		"Content-Type: application/json",
		"Accept: " + ("text/event-stream" if _stream else "application/json"),
		"Accept-Encoding: identity",
	])
	if not key.is_empty():
		_headers.append("Authorization: Bearer " + key)
	_request_body = JSON.stringify(payload)
	var tls := TLSOptions.client() if _target.secure else null
	var error := _client.connect_to_host(_target.host, _target.port, tls)
	if error != OK:
		cancel()
		return "连接失败 · " + error_string(error)
	_deadline = Time.get_ticks_msec() + CONNECT_TIMEOUT_MS
	set_process(true)
	return ""

func cancel() -> void:
	if _client != null:
		_client.close()
	_client = null
	set_process(false)
	_headers.clear()
	_request_body = ""
	_buffer.clear()
	_data.clear()
	_sent = false
	_code = -1
	_received_bytes = 0
	_after_cr = false
	_stream_finish = ""
	_has_stream_text = false
	_response_key = ""

static func connection_error(url: String, key: String) -> String:
	if endpoint(url).is_empty():
		return "接口地址无效。请填写 HTTPS 地址和有效端口，本机回环地址也可使用 HTTP。"
	for index in key.length():
		var code := key.unicode_at(index)
		if code < 32 or code == 127:
			return "API 密钥含有换行、制表符或其他控制字符。"
	return ""

func _process(_delta: float) -> void:
	if Time.get_ticks_msec() > _deadline:
		if _is_http_error():
			_finish_http_error()
		elif _stream and not _stream_finish.is_empty():
			_finish_stream()
		else:
			_finish({}, _timeout_error())
		return
	_client.poll()
	var state := _client.get_status()
	if state == HTTPClient.STATUS_CONNECTED and not _sent:
		_sent = true
		_deadline = Time.get_ticks_msec() + RESPONSE_TIMEOUT_MS
		var error := _client.request(HTTPClient.METHOD_POST, _target.path, _headers, _request_body)
		_headers.clear()
		_request_body = ""
		if error != OK:
			_finish({}, "发送失败 · " + error_string(error))
		return
	if _client.has_response() and _code < 0:
		_code = _client.get_response_code()
		_deadline = Time.get_ticks_msec() + RESPONSE_TIMEOUT_MS
		if _is_http_error():
			_deadline = Time.get_ticks_msec() + ERROR_BODY_TIMEOUT_MS
		else:
			var format_error := _response_format_error(_client.get_response_headers_as_dictionary())
			if not format_error.is_empty():
				_finish({}, format_error)
				return
	if _is_http_error():
		if state != HTTPClient.STATUS_BODY:
			_finish_http_error()
			return
		var chunk := _client.read_response_body_chunk()
		var remaining := MAX_ERROR_BYTES - _buffer.size()
		if chunk.size() > remaining:
			_finish({}, _http_error(_code))
		else:
			_buffer.append_array(chunk)
		return
	if state == HTTPClient.STATUS_BODY:
		var chunk := _client.read_response_body_chunk()
		if not chunk.is_empty():
			_received_bytes += chunk.size()
			if _received_bytes > MAX_RESPONSE_BYTES:
				_finish({}, "回复超过客户端的大小限制。")
			elif _stream:
				_read_stream(chunk)
			else:
				_deadline = Time.get_ticks_msec() + RESPONSE_TIMEOUT_MS
				_buffer.append_array(chunk)
		return
	if state == HTTPClient.STATUS_CONNECTED and _sent and _code >= 0:
		if _stream:
			_finish_stream()
		else:
			_read_json()
	elif state == HTTPClient.STATUS_DISCONNECTED:
		if _stream and not _stream_finish.is_empty():
			_finish_stream()
		elif not _stream and _code >= 200 and not _buffer.is_empty():
			_read_json()
		else:
			_finish({}, "连接在回复完成前中断。")
	elif state == HTTPClient.STATUS_CONNECTION_ERROR:
		if _stream and not _stream_finish.is_empty():
			_finish_stream()
		else:
			_finish({}, "连接在回复完成前中断。" if _sent else "无法连接到接口。")
	elif state == HTTPClient.STATUS_CANT_RESOLVE:
		_finish({}, "无法解析接口域名。请检查地址和 DNS。")
	elif state == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
		_finish({}, "HTTPS 握手失败。请检查证书和系统时间。")
	elif state == HTTPClient.STATUS_CANT_CONNECT:
		_finish({}, "无法连接到接口。请检查服务地址和网络。")

func _timeout_error() -> String:
	if not _sent:
		return "连接接口超时。"
	if _code < 0:
		return "请求已发送，等待 HTTP 响应超时。"
	if not _stream:
		return "等待完整的 JSON 回复超时。"
	return "流式回复中途长时间没有新增文本。" if _has_stream_text else "接口已响应，但等待第一段流式文本超时。"

func _response_format_error(headers: Dictionary) -> String:
	for key: String in headers:
		if key.nocasecmp_to("Content-Type") != 0:
			continue
		var kind := str(headers[key]).get_slice(";", 0).strip_edges().to_lower()
		if kind == "text/html":
			return "接口返回了网页。请检查接口路径和反向代理。"
		if _stream and (kind == "application/json" or kind.ends_with("+json")):
			return "接口返回了普通 JSON。请检查该接口或模型是否支持流式回复。"
	return ""

func _read_stream(chunk: PackedByteArray) -> void:
	var chunk_text := ""
	for byte in chunk:
		if _after_cr:
			_after_cr = false
			if byte == 10:
				continue
		if byte == 10 or byte == 13:
			_after_cr = byte == 13
			var line := _buffer.get_string_from_utf8().trim_prefix("\ufeff")
			_buffer.clear()
			if line.is_empty() and not _data.is_empty():
				var raw := "\n".join(_data)
				_data.clear()
				if raw.strip_edges() == "[DONE]":
					if not chunk_text.is_empty():
						delta_received.emit(chunk_text)
					_finish_stream(true)
					return
				var event: Variant = JSON.parse_string(raw)
				if not event is Dictionary:
					_finish_stream_error(chunk_text, "模型返回了无效的流式 JSON。")
					return
				if event.has("error"):
					_finish_stream_error(chunk_text, "接口在流式回复中返回了错误事件。")
					return
				var choices: Variant = event.get("choices", [])
				if not choices is Array:
					_finish_stream_error(chunk_text, "模型返回了无效的流式选项。")
					return
				if choices.is_empty():
					continue
				if not choices[0] is Dictionary or not choices[0].get("delta", {}) is Dictionary:
					_finish_stream_error(chunk_text, "模型返回了无效的流式选项。")
					return
				var choice: Dictionary = choices[0]
				if choice.get("finish_reason") is String:
					_stream_finish = choice.finish_reason
					if not _stream_finish.is_empty():
						_deadline = Time.get_ticks_msec() + STREAM_END_GRACE_MS
				var delta: Dictionary = choice.get("delta", {})
				var content: Variant = delta.get("content")
				if content is String and not content.is_empty():
					chunk_text += content
					_has_stream_text = true
					if _stream_finish.is_empty():
						_deadline = Time.get_ticks_msec() + RESPONSE_TIMEOUT_MS
				if delta.get("tool_calls") or delta.get("function_call"):
					_finish_stream_error(chunk_text, "自由对话入口只接收文本回复。")
					return
			elif line.begins_with("data:"):
				_data.append(line.substr(5).trim_prefix(" "))
		else:
			_buffer.append(byte)
	if not chunk_text.is_empty():
		delta_received.emit(chunk_text)

func _finish_stream_error(visible_text: String, error: String) -> void:
	if not visible_text.is_empty():
		delta_received.emit(visible_text)
	_finish({}, error)

func _read_json() -> void:
	var result: Variant = JSON.parse_string(_buffer.get_string_from_utf8())
	if not result is Dictionary or result.has("error"):
		_finish({}, "模型接口返回了无效的 JSON 或错误信息。")
		return
	var choices: Variant = result.get("choices")
	if not choices is Array or choices.is_empty() or not choices[0] is Dictionary:
		_finish({}, "模型接口没有返回回复。")
		return
	var choice: Dictionary = choices[0]
	var message: Variant = choice.get("message")
	if not message is Dictionary:
		_finish({}, "模型接口未返回有效消息。")
		return
	if choice.get("finish_reason") in ["content_filter", "safety"]:
		_finish({}, "模型未继续生成。")
		return
	if choice.get("finish_reason") == "length":
		_finish(message, "回复达到模型的输出上限。")
		return
	_finish(message, "")

func _finish_stream(done := false) -> void:
	match _stream_finish:
		"stop":
			_finish({}, "")
		"length":
			_finish({}, "回复达到模型的输出上限。")
		"content_filter", "safety":
			_finish({}, "模型未继续生成。")
		"tool_calls", "function_call":
			_finish({}, "自由对话入口只接收文本回复。")
		_:
			_finish({}, "" if done else "连接在回复完成前中断。")

func _finish(message: Dictionary, error: String) -> void:
	cancel()
	finished.emit(message, error)

static func _http_error(code: int) -> String:
	match code:
		401, 403:
			return "接口拒绝了请求 · HTTP %d。请检查 API 密钥与模型权限。" % code
		429:
			return "接口额度不足或请求过于频繁 · HTTP 429。"
		404:
			return "找不到接口或模型 · HTTP 404。"
	return "模型接口返回 HTTP %d。" % code

func _is_http_error() -> bool:
	return _code >= 0 and (_code < 200 or _code >= 300)

func _finish_http_error() -> void:
	var summary := _http_error(_code)
	var payload: Variant = JSON.parse_string(_buffer.get_string_from_utf8()) if not _buffer.is_empty() else null
	if payload is Dictionary:
		var error: Variant = payload.get("error")
		var detail: Variant = error.get("message", "") if error is Dictionary else payload.get("message", error)
		if detail is String and not detail.is_empty():
			if not _response_key.is_empty():
				detail = detail.replace(_response_key, "[已隐藏]")
			detail = detail.replace("\r", " ").replace("\n", " ").replace("\t", " ")
			detail = _sensitive_error.sub(detail, "[已隐藏]", true).strip_edges().left(240)
			if not detail.is_empty():
				summary += " " + detail
	_finish({}, summary)
