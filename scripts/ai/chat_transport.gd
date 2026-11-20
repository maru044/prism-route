extends Node

signal delta_received(text: String)
signal finished(message: Dictionary, error: String)

const CONNECT_TIMEOUT_MS := 30000
const RESPONSE_TIMEOUT_MS := 120000
const STREAM_END_GRACE_MS := 2000
const MAX_RESPONSE_BYTES := 4 * 1024 * 1024
const MAX_ERROR_BYTES := 8192
const RESPONSE_PROBE_BYTES := 256
const ERROR_BODY_TIMEOUT_MS := 2000
const OUTPUT_LIMIT_ERROR := "回复达到模型的输出上限。"
const RETRYABLE_HTTP_CODES := [408, 429, 500, 502, 503, 504]
const STREAM_FINISH_REASONS := ["stop", "length", "content_filter", "safety", "tool_calls", "function_call"]
const STREAM_USAGE_FIELDS := {
	"usage": ["prompt_tokens", "completion_tokens", "total_tokens"],
	"usageMetadata": ["promptTokenCount", "candidatesTokenCount", "thoughtsTokenCount", "totalTokenCount"],
}
static var _sensitive_error := RegEx.create_from_string(
	r"""(?i)\b(?:authorization|api[-_ ]?key|access[-_ ]?token|proxy[-_ ]?password|password|secret)["']?[ \t]*[:=][ \t]*(?:bearer[ \t]+)?(?:"[^"]*"|'[^']*'|[^,\s;]+)|\bbearer[ \t]+[^,\s;]+|\b(?:sk-|AIza)[A-Za-z0-9_-]{8,}"""
)
static var _request_id_format := RegEx.create_from_string(r"^[A-Za-z0-9._:-]{1,128}$")
static var _model_id_format := RegEx.create_from_string(r"^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$")
static var _url_in_error := RegEx.create_from_string(r"(?i)https?://[^\s<>]+")
static var _retry_date_format := RegEx.create_from_string(r"^[A-Za-z]{3}, [0-9]{2} [A-Za-z]{3} [0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2} GMT$")

var failure_details := {}

var _client: HTTPClient
var _target: Dictionary
var _headers: PackedStringArray
var _request_body: String
var _fetching_models := false
var _stream := false
var _sent := false
var _code := -1
var _deadline: int
var _received_bytes := 0
var _buffer := PackedByteArray()
var _data := PackedStringArray()
var _after_cr := false
var _stream_finish := ""
var _request_sent_ms := -1
var _first_content_ms := -1
var _last_content_ms := -1
var _content_events := 0
var _stream_usage := {}
var _response_key := ""
var _request_id := ""
var _retry_after := ""
var _retry_after_seconds := -1
var _quota_exhausted := false
var _saw_sse := false
var _saw_non_sse_line := false
var _error_summary := ""

func _ready() -> void:
	set_process(false)

static func endpoint(raw: String, resource := "/chat/completions") -> Dictionary:
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
	if path.ends_with("/chat/completions"):
		path = path.trim_suffix("/chat/completions")
	else:
		path = path.trim_suffix("/models")
	return {"host": host, "port": port, "path": path + resource, "secure": secure}

func start(url: String, key: String, payload: Dictionary) -> String:
	return _start_request(url, key, payload, false)

func fetch_models(url: String, key: String) -> String:
	return _start_request(url, key, {}, true)

func _start_request(url: String, key: String, payload: Dictionary, fetching_models: bool) -> String:
	cancel()
	failure_details = {"stage": "连接接口"}
	var validation := connection_error(url, key)
	if not validation.is_empty():
		failure_details.summary = validation
		failure_details.detail = validation
		return validation
	_fetching_models = fetching_models
	_target = endpoint(url, "/models" if _fetching_models else "/chat/completions")
	_response_key = key
	_client = HTTPClient.new()
	_stream = not _fetching_models and bool(payload.get("stream", false))
	_headers = PackedStringArray([
		"Accept: " + ("text/event-stream" if _stream else "application/json"),
		"Accept-Encoding: identity",
	])
	if not key.is_empty():
		_headers.append("Authorization: Bearer " + key)
	if not _fetching_models:
		_headers.append("Content-Type: application/json")
		_request_body = JSON.stringify(payload)
	var tls := TLSOptions.client() if _target.secure else null
	var error := _client.connect_to_host(_target.host, _target.port, tls)
	if error != OK:
		cancel()
		failure_details.retryable = error in [ERR_CANT_CONNECT, ERR_CONNECTION_ERROR, ERR_TIMEOUT]
		failure_details.summary = "连接失败 · " + error_string(error)
		failure_details.detail = failure_details.summary
		return failure_details.summary
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
	_fetching_models = false
	_buffer.clear()
	_data.clear()
	_sent = false
	_code = -1
	_received_bytes = 0
	_after_cr = false
	_stream_finish = ""
	_request_sent_ms = -1
	_first_content_ms = -1
	_last_content_ms = -1
	_content_events = 0
	_stream_usage = {}
	_response_key = ""
	_request_id = ""
	_retry_after = ""
	_retry_after_seconds = -1
	_quota_exhausted = false
	_saw_sse = false
	_saw_non_sse_line = false
	_error_summary = ""

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
			_finish({}, _timeout_error(), true)
		return
	_client.poll()
	var state := _client.get_status()
	if state == HTTPClient.STATUS_CONNECTED and not _sent:
		_sent = true
		_request_sent_ms = Time.get_ticks_msec()
		_deadline = _request_sent_ms + RESPONSE_TIMEOUT_MS
		var method := HTTPClient.METHOD_GET if _fetching_models else HTTPClient.METHOD_POST
		var error := _client.request(method, _target.path, _headers, _request_body)
		_headers.clear()
		_request_body = ""
		if error != OK:
			_finish({}, "发送失败 · " + error_string(error), error == ERR_CONNECTION_ERROR)
		return
	if _client.has_response() and _code < 0:
		_code = _client.get_response_code()
		var headers := _client.get_response_headers_as_dictionary()
		_read_diagnostic_headers(headers)
		_deadline = Time.get_ticks_msec() + RESPONSE_TIMEOUT_MS
		if _is_http_error():
			_deadline = Time.get_ticks_msec() + ERROR_BODY_TIMEOUT_MS
		else:
			var format_error := _response_format_error(headers)
			if not format_error.is_empty():
				_finish({}, format_error, false, "检查响应格式")
				return
	if _is_http_error():
		if state != HTTPClient.STATUS_BODY:
			_finish_http_error()
			return
		var chunk := _client.read_response_body_chunk()
		var remaining := MAX_ERROR_BYTES - _buffer.size()
		_buffer.append_array(chunk.slice(0, remaining))
		if _buffer.size() >= MAX_ERROR_BYTES:
			_finish_http_error()
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
				if _buffer.size() - chunk.size() < RESPONSE_PROBE_BYTES:
					var prefix := _response_prefix(_buffer)
					if _is_sse_line(prefix):
						_finish({}, _unexpected_sse_error(), false, "检查响应格式")
					elif _is_html_prefix(prefix):
						_finish({}, "接口返回了网页。请检查接口路径和反向代理。", false, "检查响应格式")
		return
	if state == HTTPClient.STATUS_CONNECTED and _sent and _code >= 0:
		if _stream:
			_finish_stream()
		else:
			_read_json()
	elif state == HTTPClient.STATUS_DISCONNECTED:
		if _stream and _code >= 200 and _received_bytes > 0:
			_finish_stream()
		elif not _stream and _code >= 200 and not _buffer.is_empty():
			_read_json()
		else:
			_finish({}, "连接在回复完成前中断。", true, "连接中断")
	elif state == HTTPClient.STATUS_CONNECTION_ERROR:
		if _stream and not _stream_finish.is_empty():
			_finish_stream()
		else:
			_finish({}, "连接在回复完成前中断。" if _sent else "无法连接到接口。", true, "连接中断" if _sent else "")
	elif state == HTTPClient.STATUS_CANT_RESOLVE:
		_finish({}, "无法解析接口域名。请检查地址和 DNS。")
	elif state == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
		_finish({}, "HTTPS 握手失败。请检查证书和系统时间。")
	elif state == HTTPClient.STATUS_CANT_CONNECT:
		_finish({}, "无法连接到接口。请检查服务地址和网络。", true)

func _timeout_error() -> String:
	if not _sent:
		return "连接接口超时。"
	if _code < 0:
		return "请求已发送，等待 HTTP 响应超时。"
	if not _stream:
		return "读取模型列表超时。" if _fetching_models else "等待完整的 JSON 回复超时。"
	return "流式回复中途长时间没有新增文本。" if _content_events > 0 else "接口已响应，但等待第一段流式文本超时。"

func _response_format_error(headers: Dictionary) -> String:
	for key: String in headers:
		if key.nocasecmp_to("Content-Type") != 0:
			continue
		var kind := str(headers[key]).get_slice(";", 0).strip_edges().to_lower()
		if kind == "text/html":
			return "接口返回了网页。请检查接口路径和反向代理。"
		if _stream and (kind == "application/json" or kind.ends_with("+json")):
			return "接口返回了普通 JSON。请检查该接口或模型是否支持流式回复。"
		if not _stream and kind == "text/event-stream":
			return _unexpected_sse_error()
	return ""

func _unexpected_sse_error() -> String:
	return "模型列表接口返回了 SSE，需要 JSON 响应。" if _fetching_models \
		else "游戏助手接口返回了 SSE。请检查非流式回复设置。"

static func _is_sse_line(line: String) -> bool:
	return line.begins_with(":") or line.begins_with("data:") or line.begins_with("event:") \
		or line.begins_with("id:") or line.begins_with("retry:")

static func _response_prefix(bytes: PackedByteArray) -> String:
	var start := 3 if bytes.size() >= 3 and bytes[0] == 0xef and bytes[1] == 0xbb and bytes[2] == 0xbf else 0
	return bytes.slice(start, RESPONSE_PROBE_BYTES).get_string_from_ascii().strip_edges()

static func _is_html_prefix(text: String) -> bool:
	var prefix := text.to_lower()
	return prefix.begins_with("<html") or prefix.begins_with("<!doctype")

static func _non_sse_error(text: String) -> String:
	var prefix := text.strip_edges()
	if prefix.begins_with("{") or prefix.begins_with("["):
		return "接口返回了普通 JSON。请检查该接口或模型是否支持流式回复。"
	if _is_html_prefix(prefix):
		return "接口返回了网页。请检查接口路径和反向代理。"
	return "接口未返回 SSE 流式数据。请检查接口或代理的流式设置。"

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
			if not _saw_sse and not line.strip_edges().is_empty():
				_saw_sse = _is_sse_line(line) or line in ["data", "event", "id", "retry"]
				_saw_non_sse_line = not _saw_sse
				if not _saw_sse and (line.strip_edges().left(1) in ["{", "[", "<"] or (
					not line.contains(":") and line.strip_edges().contains(" ")
				)):
					_finish_stream_error(chunk_text, _non_sse_error(line), "检查响应格式")
					return
			if line.is_empty() and not _data.is_empty():
				var raw := "\n".join(_data)
				_data.clear()
				if raw.strip_edges() == "[DONE]":
					if not chunk_text.is_empty():
						delta_received.emit(chunk_text)
					_finish_stream(true)
					return
				var event: Variant = _parse_json(raw)
				if not event is Dictionary:
					_finish_stream_error(chunk_text, "模型返回了无效的流式 JSON。")
					return
				if event.has("error"):
					_finish_stream_error(chunk_text, _append_error_detail("接口在流式回复中返回了错误事件。", event))
					return
				_capture_stream_usage(event)
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
				if choice.get("finish_reason") is String and not choice.finish_reason.is_empty():
					_stream_finish = choice.finish_reason
					_deadline = Time.get_ticks_msec() + STREAM_END_GRACE_MS
				var delta: Dictionary = choice.get("delta", {})
				var content: Variant = delta.get("content")
				if content != null and not content is String:
					_finish_stream_error(chunk_text, "模型返回了格式无效的流式正文。")
					return
				if _has_refusal(delta):
					_finish_stream_error(chunk_text, "模型明确拒绝了该请求。")
					return
				if content is String and not content.is_empty():
					chunk_text += content
					_last_content_ms = Time.get_ticks_msec()
					if _content_events == 0:
						_first_content_ms = _last_content_ms
					_content_events += 1
					if _stream_finish.is_empty():
						_deadline = _last_content_ms + RESPONSE_TIMEOUT_MS
				if delta.get("tool_calls") or delta.get("function_call"):
					_finish_stream_error(chunk_text, "自由对话入口只接收文本回复。")
					return
			elif line.begins_with("data:"):
				_data.append(line.substr(5).trim_prefix(" "))
		else:
			_buffer.append(byte)
	if not _saw_sse and not _buffer.is_empty():
		var prefix := _response_prefix(_buffer)
		if prefix.left(1) in ["{", "["] or _is_html_prefix(prefix) \
				or (_buffer.size() >= RESPONSE_PROBE_BYTES and not prefix.is_empty() and not _is_sse_line(prefix)):
			_finish_stream_error(chunk_text, _non_sse_error(prefix), "检查响应格式")
			return
	if not chunk_text.is_empty():
		delta_received.emit(chunk_text)

func _capture_stream_usage(event: Dictionary) -> void:
	for field: String in STREAM_USAGE_FIELDS:
		var usage: Variant = event.get(field)
		if not usage is Dictionary:
			continue
		var counts: Dictionary = _stream_usage.get(field, {})
		for name: String in STREAM_USAGE_FIELDS[field]:
			_capture_token_count(counts, name, usage.get(name))
		var details: Variant = usage.get("completion_tokens_details") if field == "usage" else null
		if details is Dictionary:
			_capture_token_count(counts, "reasoning_tokens", details.get("reasoning_tokens"))
		if not counts.is_empty():
			_stream_usage[field] = counts

static func _capture_token_count(counts: Dictionary, name: String, value: Variant) -> void:
	if (value is int or value is float) and value >= 0 and value <= 2147483647 and value == int(value):
		counts[name] = int(value)

func _finish_stream_error(visible_text: String, error: String, stage := "解析流式事件") -> void:
	if not visible_text.is_empty():
		delta_received.emit(visible_text)
	_finish({}, error, false, stage)

func _read_json() -> void:
	var result: Variant = _parse_json(_buffer.get_string_from_utf8())
	if _fetching_models:
		_read_models(result)
		return
	if not result is Dictionary:
		_finish({}, "游戏助手接口返回了无效的 JSON。", false, "解析 JSON")
		return
	if result.has("error"):
		_finish({}, _append_error_detail("接口在 JSON 回复中返回了错误。", result))
		return
	var choices: Variant = result.get("choices")
	if not choices is Array or choices.is_empty() or not choices[0] is Dictionary:
		_finish({}, "模型接口没有返回回复。", false, "检查回复结构")
		return
	var choice: Dictionary = choices[0]
	var message: Variant = choice.get("message")
	if not message is Dictionary:
		_finish({}, "模型接口未返回有效消息。", false, "检查回复结构")
		return
	if choice.get("finish_reason") in ["content_filter", "safety"]:
		_finish({}, "模型未继续生成。")
		return
	if _has_refusal(message):
		_finish({}, "模型明确拒绝了该请求。")
		return
	var format_error := assistant_format_error(message)
	if not format_error.is_empty():
		_finish({}, format_error, false, "检查回复结构")
		return
	var calls: Variant = message.get("tool_calls")
	if choice.get("finish_reason") == "tool_calls" and (calls == null or calls.is_empty()):
		_finish({}, "模型声明了工具调用，但未返回调用内容。", false, "检查回复结构")
		return
	if choice.get("finish_reason") == "length":
		_finish(message, OUTPUT_LIMIT_ERROR)
		return
	_finish(message, "")

func _read_models(result: Variant) -> void:
	if result is Dictionary and result.has("error"):
		_finish({}, _append_error_detail("接口未能提供模型列表。", result))
		return
	if not result is Dictionary or not result.get("data") is Array:
		_finish({}, "模型列表响应无效，预期返回包含 data 数组的 JSON。", false, "检查模型列表")
		return
	var models := {}
	for entry: Variant in result.data:
		if entry is Dictionary and entry.get("id") is String:
			var id: String = entry.id
			if not id.is_empty() and id == id.strip_edges() and not "\n" in id and not "\r" in id and not "\t" in id:
				models[id] = true
	if models.is_empty():
		_finish({}, "接口未返回可选模型。请检查密钥的模型权限，或手动填写模型 ID。")
		return
	var ids := PackedStringArray(models.keys())
	ids.sort()
	_finish({"models": ids}, "")

static func assistant_format_error(message: Dictionary) -> String:
	var content: Variant = message.get("content")
	if content != null and not content is String:
		return "游戏助手返回了格式无效的正文。"
	var calls: Variant = message.get("tool_calls")
	if (calls != null and not calls is Array) or message.get("function_call") != null:
		return "游戏助手返回了格式无效或不支持的工具调用。"
	return ""

static func _has_refusal(message: Dictionary) -> bool:
	var refusal: Variant = message.get("refusal")
	return refusal is String and not refusal.strip_edges().is_empty()

func _finish_stream(done := false) -> void:
	if not done and not _saw_sse:
		var prefix := _response_prefix(_buffer)
		if _saw_non_sse_line or (not prefix.is_empty() and not _is_sse_line(prefix) and not "data:".begins_with(prefix)):
			_finish({}, _non_sse_error(prefix), false, "检查响应格式")
			return
	match _stream_finish:
		"stop":
			_finish({}, "")
		"length":
			_finish({}, OUTPUT_LIMIT_ERROR)
		"content_filter", "safety":
			_finish({}, "模型未继续生成。")
		"tool_calls", "function_call":
			_finish({}, "自由对话入口只接收文本回复。")
		_:
			_finish({}, "" if done else "连接在回复完成前中断。", false, "" if done else "连接中断")

func _finish(message: Dictionary, error: String, network_failure := false, stage_override := "") -> void:
	var stage := "连接接口"
	if _sent:
		stage = "等待 HTTP 响应" if _code < 0 else "读取回复"
	if _is_http_error():
		stage = "接口拒绝请求"
	elif _stream and _code >= 0:
		stage = "读取流式正文" if _content_events > 0 else "等待流式正文"
	if not stage_override.is_empty():
		stage = stage_override
	failure_details = {
		"stage": stage, "http_code": _code, "request_id": _request_id, "retry_after": _retry_after,
		"retry_after_seconds": _retry_after_seconds,
		"retryable": network_failure or (_code in RETRYABLE_HTTP_CODES and not _quota_exhausted),
		"summary": error if _error_summary.is_empty() else _error_summary,
		"detail": error,
	}
	if _stream and _request_sent_ms >= 0:
		var finish_reason := _stream_finish if _stream_finish in STREAM_FINISH_REASONS else (
			"未收到" if _stream_finish.is_empty() else "其他")
		failure_details["stream"] = {
			"finish_reason": finish_reason, "usage": _stream_usage,
			"content_events": _content_events,
			"elapsed_ms": Time.get_ticks_msec() - _request_sent_ms,
			"first_content_ms": _first_content_ms - _request_sent_ms,
			"last_content_ms": _last_content_ms - _request_sent_ms,
		}
	cancel()
	finished.emit(message, error)

static func _http_error(code: int) -> String:
	match code:
		400, 422:
			return "接口拒绝请求参数 · HTTP %d。请核对模型 ID、接口兼容性与上下文限额。" % code
		402:
			return "接口要求付费或余额不足 · HTTP 402。请检查账户或代理额度。"
		401, 403:
			return "接口拒绝了请求 · HTTP %d。请检查 API 密钥与模型权限。" % code
		429:
			return "接口限制了请求 · HTTP 429。请检查速率限制和账户额度。"
		404:
			return "找不到接口或模型 · HTTP 404。"
		413:
			return "请求超过接口大小上限 · HTTP 413。请缩短输入，或减少历史和提示词。"
	if code >= 500 and code < 600:
		return "接口或代理暂时无法处理请求 · HTTP %d。可稍后重新生成。" % code
	if code >= 300 and code < 400:
		return "接口返回了重定向 · HTTP %d。请填写最终的 API 地址。" % code
	return "模型接口返回 HTTP %d。" % code

func _is_http_error() -> bool:
	return _code >= 0 and (_code < 200 or _code >= 300)

func _finish_http_error() -> void:
	var raw := _buffer.get_string_from_utf8()
	var payload: Variant = _parse_json(raw) if not raw.is_empty() else null
	var fields: Dictionary = payload if payload is Dictionary else {}
	var hint := _status_hint(fields, raw if fields.is_empty() else "")
	var full_error := _append_error_detail(hint, fields)
	if fields.is_empty() and not raw.strip_edges().is_empty() and full_error == hint:
		var snippet := raw.strip_edges().replace("\r", " ").replace("\n", " ").replace("\t", " ")
		snippet = _sensitive_error.sub(snippet, "[已隐藏]", true)
		snippet = _url_in_error.sub(snippet, "[已隐藏]", true).strip_edges().left(200)
		if not snippet.is_empty():
			full_error = hint + " " + snippet
	_finish({}, full_error)

static func _parse_json(text: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(text) == OK else null

func _status_hint(payload: Dictionary, raw: String) -> String:
	if _fetching_models and _code in [404, 405, 501]:
		return "无法获取模型列表 · HTTP %d。请检查 API 基础路径，或手动填写模型 ID。" % _code
	var error: Variant = payload.get("error")
	var fields: Dictionary = error if error is Dictionary else payload
	var kind := str(fields.get("type", "")).to_lower()
	var code := str(fields.get("code", "")).to_lower()
	if code == "context_length_exceeded":
		return "请求超过模型上下文上限 · HTTP %d。请缩短输入或减少历史。" % _code
	var quota_codes := ["insufficient_quota", "billing_hard_limit_reached", "insufficient_balance"]
	var detail := (_error_detail(payload) + " " + raw).to_lower()
	if _code == 429 and (code in quota_codes or kind in quota_codes or detail.contains("insufficient balance") \
			or detail.contains("insufficient quota") or detail.contains("billing hard limit")):
		_quota_exhausted = true
		_retry_after = ""
		_retry_after_seconds = -1
		return "账户或代理额度不足 · HTTP 429。请检查额度或余额。"
	var hint := _http_error(_code)
	if not _retry_after.is_empty():
		hint += " 建议等待 · " + _retry_after
	return hint

static func _error_detail(payload: Dictionary) -> String:
	var error: Variant = payload.get("error")
	var detail: Variant = error.get("message", "") if error is Dictionary else payload.get("message", error)
	if detail is String and not detail.strip_edges().is_empty():
		return detail
	detail = payload.get("detail")
	if detail is String:
		return detail
	if detail is Array:
		var messages := PackedStringArray()
		for entry: Variant in detail.slice(0, 3):
			if entry is Dictionary and entry.get("msg") is String:
				messages.append(entry.msg)
		return " / ".join(messages)
	return ""

func _append_error_detail(summary: String, payload: Dictionary) -> String:
	_error_summary = summary
	var detail := _error_detail(payload)
	if not detail.is_empty():
		var normalized := detail.to_lower()
		for known: String in ["invalid model", "model not found", "unknown model", "invalid api key"]:
			if normalized.begins_with(known):
				_error_summary += " " + known
				break
		if not _response_key.is_empty():
			detail = detail.replace(_response_key, "[已隐藏]")
		detail = detail.replace("\r", " ").replace("\n", " ").replace("\t", " ")
		detail = _sensitive_error.sub(detail, "[已隐藏]", true)
		detail = _url_in_error.sub(detail, "[已隐藏]", true).strip_edges().left(240)
		if not detail.is_empty():
			return summary + " " + detail
	return summary

static func safe_diagnostic_model(model: String, key: String) -> String:
	if _model_id_format.search(model) == null or "://" in model or _sensitive_error.search(model) != null:
		return ""
	return model if key.is_empty() or not model.contains(key) else ""

func _read_diagnostic_headers(headers: Dictionary) -> void:
	for key: String in headers:
		var name := key.to_lower()
		var value := str(headers[key]).strip_edges()
		if name in ["x-request-id", "request-id", "x-goog-request-id"] and _request_id.is_empty():
			if _request_id_format.search(value) != null and (_response_key.is_empty() or not value.contains(_response_key)) \
					and _sensitive_error.search(value) == null:
				_request_id = value
		elif name == "retry-after" and _code in RETRYABLE_HTTP_CODES:
			if value.is_valid_int() and value.length() <= 9 and int(value) >= 0:
				_retry_after_seconds = int(value)
				_retry_after = "%d 秒" % _retry_after_seconds
			elif _retry_date_format.search(value) != null:
				_retry_after = "至 " + value
