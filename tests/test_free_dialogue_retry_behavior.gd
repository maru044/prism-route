@tool
extends SceneTree
## Verifies that Free Dialogue never automatically retries on errors,
## requiring manual user retry, while Assistant (auxiliary model) automatically retries.

const GameLLMClientClass := preload("res://scripts/ai/game_llm_client.gd")
const LLMPanelClass := preload("res://scripts/ai/llm_panel.gd")
const TransportClass := preload("res://scripts/ai/chat_transport.gd")

class MockTransport extends TransportClass:
	var sends: int = 0
	var last_body: Dictionary = {}
	var force_start_error: String = ""

	func start(target: String, credential: String, body: Dictionary) -> String:
		sends += 1
		last_body = body.duplicate(true)
		if not force_start_error.is_empty():
			return force_start_error
		return ""

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("==================================================")
	print("[Test] Verifying Free Dialogue and Assistant Retry Architecture")
	print("==================================================")

	# -----------------------------------------------------------------
	# Test 1: Free Dialogue NEVER automatically retries on network/HTTP errors
	# -----------------------------------------------------------------
	print("\n--- Test 1: Free Dialogue (route == DIALOGUE) Zero Automatic Retry ---")
	var client := GameLLMClientClass.new()
	var mock_transport := MockTransport.new()
	client._transport.free()
	client._transport = mock_transport
	root.add_child(client)

	client.profiles[GameLLMClientClass.DIALOGUE] = {
		"url": "https://fixture.invalid",
		"model": "test-dialogue-model",
		"key": "test-key"
	}
	client.profiles[GameLLMClientClass.ASSISTANT] = {
		"url": "https://fixture.invalid",
		"model": "test-assistant-model",
		"key": "test-key"
	}

	client.set_dialogue_source(GameLLMClientClass.SOURCE_CLOUD_API)
	client.open(GameLLMClientClass.DIALOGUE, "sparkle_test", {
		"npc_name": "花火",
		"dialogue_location": "初始神殿"
	})

	var send_ok := client.send("你好，花火！")
	assert(send_ok, "client.send should succeed")
	assert(mock_transport.sends == 1, "Expected exactly 1 request sent")
	assert(client.pending, "Client should be in pending state")

	# Simulate a retryable HTTP 429 rate-limit error with Retry-After header
	mock_transport.failure_details = {
		"retryable": true,
		"http_code": 429,
		"retry_after_seconds": 2,
		"stage": "等待响应",
		"summary": "请求过于频繁"
	}
	mock_transport.finished.emit({}, "HTTP 429 请求过于频繁")

	# Assert that Free Dialogue did NOT schedule any automatic retry
	assert(not client.pending, "Free dialogue must NOT be pending after error")
	assert(client._assistant_retry_timer.is_stopped(), "Retry timer must remain stopped for Free Dialogue")
	assert(mock_transport.sends == 1, "Transport must not have received any automatic retry send")
	assert(client._assistant_retries == 0, "Assistant retry count must remain 0 for dialogue")
	print("  [Pass] Free Dialogue did not trigger automatic retry on retryable HTTP 429")

	# Assert that manual retry is enabled and ready for the user
	assert(client.can_retry(), "client.can_retry() must be true for manual user retry")
	print("  [Pass] client.can_retry() is true for user-initiated manual retry")

	# Simulate user manual retry
	var initial_sends: int = mock_transport.sends
	client.retry()
	assert(mock_transport.sends == initial_sends + 1, "Manual retry must trigger exactly 1 new request")
	assert(client.pending, "Client should be pending after manual retry")
	assert(client.history.size() == 1, "Manual retry must reuse the same history turn instead of creating a new one")
	print("  [Pass] Manual client.retry() successfully resubmitted the turn without duplicating history")

	# Complete the retry cleanly via stream deltas
	mock_transport.delta_received.emit("我是花火！")
	mock_transport.finished.emit({}, "")
	assert(not client.pending, "Client should be done")
	assert(client.history[0].replies.size() == 1, "Reply recorded")
	print("  [Pass] Free dialogue successfully completed upon manual retry")

	# -----------------------------------------------------------------
	# Test 2: Assistant (Auxiliary Model) DOES automatically retry
	# -----------------------------------------------------------------
	print("\n--- Test 2: Assistant (route == ASSISTANT) Automatic Retry Support ---")
	client.open(GameLLMClientClass.ASSISTANT, "assistant_test", {})
	client.send("请问初始神殿在哪里？")
	assert(mock_transport.sends == 3, "Sent assistant request")
	assert(client.pending, "Assistant pending")

	# Simulate temporary retryable failure
	mock_transport.failure_details = {
		"retryable": true,
		"http_code": 503,
		"retry_after_seconds": 1,
		"stage": "连接接口",
		"summary": "服务暂时不可用"
	}
	mock_transport.finished.emit({}, "HTTP 503 服务暂时不可用")

	# Assert that Assistant scheduled an automatic retry
	assert(client.pending, "Assistant should remain pending during automatic retry backoff")
	assert(not client._assistant_retry_timer.is_stopped(), "Assistant retry timer must be running")
	assert(client._assistant_retries == 1, "Assistant retry counter incremented to 1")
	print("  [Pass] Assistant scheduled automatic retry 1/2 with timer running")

	# Trigger timer timeout
	client._assistant_retry_timer.stop()
	client._assistant_retry_timer.timeout.emit()
	assert(mock_transport.sends == 4, "Assistant automatically resent request on timer timeout")
	print("  [Pass] Assistant automatically resent request upon backoff timeout")

	# -----------------------------------------------------------------
	# Test 3: LLMPanel UI Binding
	# -----------------------------------------------------------------
	print("\n--- Test 3: LLMPanel UI Manual Retry Button Binding ---")
	var panel := LLMPanelClass.new()
	root.add_child(panel)

	# Free dialogue open: retry button is manual
	panel.open_panel(GameLLMClientClass.DIALOGUE, "sparkle_scope", {"npc_name": "花火"})
	assert(panel._retry.text == "重新生成", "Retry button text should be 重新生成")
	assert(panel._retry.pressed.is_connected(panel.client.retry), "Retry button must connect directly to client.retry")
	print("  [Pass] LLMPanel retry button is dedicated manual 重新生成 connected to client.retry")

	panel.close_panel()
	panel.queue_free()
	client.queue_free()

	print("\n==================================================")
	print("[SUCCESS] All Free Dialogue manual retry and Assistant auto retry assertions verified")
	print("==================================================")
	quit(0)
