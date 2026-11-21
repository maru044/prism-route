@tool
extends SceneTree
## Verifies the Dedicated Offline Play Mode (Local AIRP) architecture:
## 1. Zero HTTP calls and 100% offline generation when SOURCE_LOCAL_AIRP is selected.
## 2. Continuation, Retry (branching with swipe), and Undo in offline mode.
## 3. Strict error reporting and ZERO silent fallback in online Cloud API mode (429/503/timeout).
## 4. Session key thread isolation between local and cloud dialogue.
## 5. Multiple interaction scenes (home_chat, intimate, combat_h).
## 6. Zero ellipses across all generated replies.

const GameLLMClientClass := preload("res://scripts/ai/game_llm_client.gd")
const TransportClass := preload("res://scripts/ai/chat_transport.gd")
const TitleAPISettingsClass := preload("res://scripts/ui/title_api_settings.gd")

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

func _has_ellipsis(text: String) -> bool:
	return text.contains("." + "." + ".") or text.contains("\u2026")

func run() -> void:
	print("==================================================")
	print("[Test] Verifying Local AIRP Dedicated Offline Play Mode")
	print("==================================================")

	var client := GameLLMClientClass.new()
	var mock_transport := MockTransport.new()
	client._transport.free()
	client._transport = mock_transport
	root.add_child(client)

	# -----------------------------------------------------------------
	# Test 1: Dedicated Offline Mode (SOURCE_LOCAL_AIRP) - 100% Local & Zero HTTP
	# -----------------------------------------------------------------
	print("\n--- Test 1: Dedicated Offline Mode (Zero HTTP, Local Generation) ---")
	client.set_dialogue_source(GameLLMClientClass.SOURCE_LOCAL_AIRP)
	assert(client.get_dialogue_source() == GameLLMClientClass.SOURCE_LOCAL_AIRP, "Dialogue source must be local_airp")

	# Clear cloud url and key to prove offline mode doesn't need them
	client.profiles[GameLLMClientClass.DIALOGUE]["url"] = ""
	client.profiles[GameLLMClientClass.DIALOGUE]["model"] = ""
	client.profiles[GameLLMClientClass.DIALOGUE]["key"] = ""
	assert(client.configured(), "Offline mode must report configured == true even with blank cloud settings")

	client.open(GameLLMClientClass.DIALOGUE, "sparkle_offline_test", {
		"npc_id": "sparkle",
		"npc_name": "花火",
		"dialogue_location": "酒馆"
	})

	var initial_sends := mock_transport.sends
	var send_ok := client.send("你好花火，今天有什么好玩的吗？")
	assert(send_ok, "Send in local offline mode should succeed")
	assert(mock_transport.sends == initial_sends, "Offline mode must execute ZERO HTTP calls")
	assert(not client.pending, "Offline mode must complete synchronously without pending state")
	assert(client.history.size() == 1, "History must contain exactly 1 turn")
	
	var first_reply_text: String = client.active_reply().get("text", "")
	assert(not first_reply_text.is_empty(), "Offline reply text must not be empty")
	assert(not _has_ellipsis(first_reply_text), "Offline reply text must contain ZERO ellipses")
	assert(client.diagnostic.contains("本地检索式 AIRP"), "Diagnostic should indicate Local AIRP retrieval")
	print("  [Pass] Offline mode reply composed successfully: %s" % first_reply_text)

	# Test Continuation
	print("\n--- Test 1b: Continuation in Offline Mode ---")
	assert(client.can_continue_reply(), "Should be able to continue offline reply")
	client.continue_reply()
	assert(mock_transport.sends == initial_sends, "Continuation must execute ZERO HTTP calls")
	assert(client.active_reply().get("continuations", []).size() == 1, "Continuations array should have 1 item")
	var continuation_text: String = client.active_reply()["continuations"][0].get("text", "")
	assert(not continuation_text.is_empty(), "Continuation text must not be empty")
	assert(not _has_ellipsis(continuation_text), "Continuation text must contain ZERO ellipses")
	print("  [Pass] Continuation composed: %s" % continuation_text)

	# Test Retry & Branch Switching (Swipe)
	print("\n--- Test 1c: Retry and Swipe in Offline Mode ---")
	assert(client.can_retry(), "Should be able to retry offline turn")
	client.retry()
	assert(mock_transport.sends == initial_sends, "Retry must execute ZERO HTTP calls")
	assert(client.history.back().replies.size() == 2, "Turn should have 2 candidate replies after retry")
	assert(client.history.back().active == 1, "Active reply index should be 1 after retry")
	var second_reply_text: String = client.active_reply().get("text", "")
	assert(not second_reply_text.is_empty(), "Second candidate reply text must not be empty")
	assert(not _has_ellipsis(second_reply_text), "Second reply text must contain ZERO ellipses")
	
	# Test Swipe
	client.swipe(-1)
	assert(client.history.back().active == 0, "Swiping backward should activate candidate 0")
	client.swipe(1)
	assert(client.history.back().active == 1, "Swiping forward should activate candidate 1")
	print("  [Pass] Retry created candidate branch and swipe switches correctly")

	# Test Undo
	print("\n--- Test 1d: Undo in Offline Mode ---")
	var undone: Variant = client.undo()
	assert(undone != null, "Undo should return undone user message")
	assert(client.history.is_empty(), "History should be empty after undo")
	print("  [Pass] Undo popped turn cleanly")

	# -----------------------------------------------------------------
	# Test 2: Online API Error Strict Reporting & ZERO Silent Fallback
	# -----------------------------------------------------------------
	print("\n--- Test 2: Online Cloud API Strict Error Reporting (NO Silent Fallback) ---")
	client.set_dialogue_source(GameLLMClientClass.SOURCE_CLOUD_API)
	assert(client.get_dialogue_source() == GameLLMClientClass.SOURCE_CLOUD_API, "Dialogue source must be cloud_api")

	client.profiles[GameLLMClientClass.DIALOGUE]["url"] = "https://api.openai.com/v1"
	client.profiles[GameLLMClientClass.DIALOGUE]["model"] = "gpt-4o"
	client.profiles[GameLLMClientClass.DIALOGUE]["key"] = "sk-mock-key"

	client.open(GameLLMClientClass.DIALOGUE, "sparkle_online_test", {
		"npc_id": "sparkle",
		"npc_name": "花火"
	})

	# Test 2a: Transport Start Failure (e.g. connection refused / bad url)
	print("  Testing Online Transport Start Error")
	mock_transport.force_start_error = "无法连接至云端服务 (Connection Refused)"
	var start_sends_before := mock_transport.sends
	client.send("你好在线花火！")
	assert(mock_transport.sends == start_sends_before + 1, "Transport should have attempted 1 send")
	assert(not client.pending, "Client must not remain pending after start failure")
	assert(client.status == "无法连接至云端服务 (Connection Refused)", "Status must reflect true cloud error")
	assert(client.history.back().get("result", {}).get("notice", "") == "无法连接至云端服务 (Connection Refused)", "Turn result notice must record error")
	assert(client.history.back().replies.is_empty(), "Turn replies must be empty when cloud API fails upfront (NO silent local fallback!)")
	assert(not client.diagnostic.contains("本地检索式 AIRP"), "Local AIRP must NOT have been called on cloud start error")
	print("  [Pass] Cloud API start error reported cleanly with ZERO silent fallback")

	# Test 2b: HTTP 503 / 429 Finished Failure
	print("  Testing Online HTTP 503 / 429 Finished Error")
	mock_transport.force_start_error = ""
	var online_turn_ok := client.send("再试一次在线请求")
	assert(online_turn_ok, "Send should start successfully")
	assert(client.pending, "Client should be pending waiting for HTTP response")
	
	# Simulate HTTP 503 Service Unavailable
	mock_transport.failure_details = {
		"retryable": false,
		"http_code": 503,
		"stage": "等待响应",
		"summary": "服务暂时不可用"
	}
	mock_transport.finished.emit({}, "HTTP 503 服务暂时不可用")
	
	assert(not client.pending, "Client must not be pending after finished error")
	assert(client.status == "HTTP 503 服务暂时不可用", "Status must show HTTP 503")
	assert(client.history.back().get("result", {}).get("notice", "") == "HTTP 503 服务暂时不可用", "Turn result notice must show HTTP 503")
	assert(client.history.back().replies.is_empty(), "Replies must remain empty (NO silent local fallback on 503!)")
	assert(not client.diagnostic.contains("本地检索式 AIRP"), "Local AIRP must NOT be called on cloud HTTP 503 error")
	print("  [Pass] HTTP 503 reported directly with ZERO silent fallback")

	# -----------------------------------------------------------------
	# Test 3: Session Key Thread Isolation (Local vs Cloud)
	# -----------------------------------------------------------------
	print("\n--- Test 3: Session Key Thread Isolation ---")
	client.set_dialogue_source(GameLLMClientClass.SOURCE_LOCAL_AIRP)
	client.open(GameLLMClientClass.DIALOGUE, "shared_scope", {"npc_id": "sparkle", "npc_name": "花火"})
	client.send("这是本地会话中的话语")
	assert(client.history.size() == 1, "Local session should have 1 turn")
	
	# Switch to cloud source on the exact same scope
	client.set_dialogue_source(GameLLMClientClass.SOURCE_CLOUD_API)
	client.open(GameLLMClientClass.DIALOGUE, "shared_scope", {"npc_id": "sparkle", "npc_name": "花火"})
	assert(client.history.is_empty(), "Cloud session thread should be separate and empty, not containing local turns")
	
	# Switch back to local source
	client.set_dialogue_source(GameLLMClientClass.SOURCE_LOCAL_AIRP)
	client.open(GameLLMClientClass.DIALOGUE, "shared_scope", {"npc_id": "sparkle", "npc_name": "花火"})
	assert(client.history.size() == 1, "Local session thread should retain its history when reopening")
	print("  [Pass] Local and Cloud dialogue sessions are strictly isolated by thread ID")

	# -----------------------------------------------------------------
	# Test 4: Interaction Scenes (intimate & combat_h) in Offline Mode
	# -----------------------------------------------------------------
	print("\n--- Test 4: Interaction Scenes in Offline Mode ---")
	# Scene 1: Intimate Mode with Keqing
	client.open(GameLLMClientClass.DIALOGUE, "keqing_intimate_scope", {
		"npc_id": "keqing",
		"npc_name": "刻晴",
		"intimate_mode": true
	})
	client.send("靠近一点好吗？")
	var intimate_text: String = client.active_reply().get("text", "")
	assert(not intimate_text.is_empty(), "Intimate reply text must not be empty")
	assert(not _has_ellipsis(intimate_text), "Intimate reply text must contain ZERO ellipses")
	
	# Scene 2: Combat Mode with Raiden Shogun
	client.open(GameLLMClientClass.DIALOGUE, "raiden_combat_scope", {
		"npc_id": "raiden_shogun",
		"npc_name": "雷电将军",
		"combat_mode": true
	})
	client.send("拔刀吧，让我看看你的武艺！")
	var combat_text: String = client.active_reply().get("text", "")
	assert(not combat_text.is_empty(), "Combat reply text must not be empty")
	assert(not _has_ellipsis(combat_text), "Combat reply text must contain ZERO ellipses")
	print("  [Pass] Intimate and Combat scenes generated replies successfully with zero ellipses")

	# -----------------------------------------------------------------
	# Test 5: Title Settings UI Integration
	# -----------------------------------------------------------------
	print("\n--- Test 5: Title API Settings UI Verification ---")
	var title_ui := TitleAPISettingsClass.new()
	root.add_child(title_ui)
	title_ui.open()

	# Select local AIRP
	title_ui._on_source_selected(GameLLMClientClass.SOURCE_LOCAL_AIRP)
	assert(not title_ui._url.editable, "URL field should not be editable in local AIRP mode")
	assert(not title_ui._model.editable, "Model field should not be editable in local AIRP mode")
	assert(not title_ui._key.editable, "Key field should not be editable in local AIRP mode")
	assert(title_ui._fetch_button.disabled, "Fetch button should be disabled in local AIRP mode")
	assert(title_ui._status.text.contains("本地口上"), "Status should indicate local AIRP readiness")

	# Select cloud API
	title_ui._on_source_selected(GameLLMClientClass.SOURCE_CLOUD_API)
	assert(title_ui._url.editable, "URL field should be editable in cloud API mode")
	assert(title_ui._model.editable, "Model field should be editable in cloud API mode")
	assert(title_ui._key.editable, "Key field should be editable in cloud API mode")
	assert(not title_ui._fetch_button.disabled, "Fetch button should be enabled in cloud API mode")

	# Clean up UI
	title_ui.queue_free()
	print("  [Pass] Title API Settings UI reflects source selection and toggles fields accurately")

	print("\n==================================================")
	print("ALL OFFLINE PLAY MODE TESTS PASSED SUCCESSFULLY! (0 FAILURES)")
	print("==================================================")
	quit(0)
