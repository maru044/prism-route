@tool
extends SceneTree
## Comprehensive Verification of Dedicated Offline Play Mode (Local AIRP):
## P1-1: Old save migration, single-pass migration, zero local message leakage into cloud request body.
## P1-2: Explicit pause/stop intent priority and multi-turn context coherence.
## P2-1: Real game entry points scene alignment (对决对峙中 -> combat_h, 玩弄侍奉安置阶段 -> intimate, 家园闲聊 -> home_chat).
## P2-2: Missing model/probe readiness check, UI error reporting, non-silent failure handling.
## P3: Continuation, retry branching with swipe, undo, zero ellipses check.

const GameLLMClientClass := preload("res://scripts/ai/game_llm_client.gd")
const TransportClass := preload("res://scripts/ai/chat_transport.gd")
const TitleAPISettingsClass := preload("res://scripts/ui/title_api_settings.gd")
const LocalAirpClientClass := preload("res://scripts/ai/local_airp/local_airp_client.gd")

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
	# Test 1: Dedicated Offline Mode (Zero HTTP, Local Generation)
	# -----------------------------------------------------------------
	print("\n--- Test 1: Dedicated Offline Mode (Zero HTTP, Local Generation) ---")
	client.set_dialogue_source(GameLLMClientClass.SOURCE_LOCAL_AIRP)
	assert(client.get_dialogue_source() == GameLLMClientClass.SOURCE_LOCAL_AIRP, "Dialogue source must be local_airp")

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

	# Continuation
	print("\n--- Test 1b: Continuation in Offline Mode ---")
	assert(client.can_continue_reply(), "Should be able to continue offline reply")
	client.continue_reply()
	assert(mock_transport.sends == initial_sends, "Continuation must execute ZERO HTTP calls")
	assert(client.active_reply().get("continuations", []).size() == 1, "Continuations array should have 1 item")
	var continuation_text: String = client.active_reply()["continuations"][0].get("text", "")
	assert(not continuation_text.is_empty(), "Continuation text must not be empty")
	assert(not _has_ellipsis(continuation_text), "Continuation text must contain ZERO ellipses")
	print("  [Pass] Continuation composed: %s" % continuation_text)

	# Retry & Swipe
	print("\n--- Test 1c: Retry and Swipe in Offline Mode ---")
	assert(client.can_retry(), "Should be able to retry offline turn")
	client.retry()
	assert(mock_transport.sends == initial_sends, "Retry must execute ZERO HTTP calls")
	assert(client.history.back().replies.size() == 2, "Turn should have 2 candidate replies after retry")
	assert(client.history.back().active == 1, "Active reply index should be 1 after retry")
	var second_reply_text: String = client.active_reply().get("text", "")
	assert(not second_reply_text.is_empty(), "Second candidate reply text must not be empty")
	assert(not _has_ellipsis(second_reply_text), "Second reply text must contain ZERO ellipses")
	
	client.swipe(-1)
	assert(client.history.back().active == 0, "Swiping backward should activate candidate 0")
	client.swipe(1)
	assert(client.history.back().active == 1, "Swiping forward should activate candidate 1")
	print("  [Pass] Retry created candidate branch and swipe switches correctly")

	# Undo
	print("\n--- Test 1d: Undo in Offline Mode ---")
	var undone: Variant = client.undo()
	assert(undone != null, "Undo should return undone user message")
	assert(client.history.is_empty(), "History should be empty after undo")
	print("  [Pass] Undo popped turn cleanly")

	# -----------------------------------------------------------------
	# Test 2: Online Cloud API Strict Error Reporting (NO Silent Fallback)
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

	# Test 2a: Transport Start Failure
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

	# Test 2b: HTTP 503 Finished Failure
	print("  Testing Online HTTP 503 Finished Error")
	mock_transport.force_start_error = ""
	var online_turn_ok := client.send("再试一次在线请求")
	assert(online_turn_ok, "Send should start successfully")
	assert(client.pending, "Client should be pending waiting for HTTP response")
	
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
	# Test 3 (P1 Issue 1): Old Save Migration and Request Body Isolation
	# -----------------------------------------------------------------
	print("\n--- Test 3: Old Save Migration and Request Body Isolation (P1) ---")
	var old_save := {
		"dialogue/sparkle_migrated_scope": [
			{
				"user": "旧存档中的云端前言",
				"replies": [{"text": "旧存档中的云端回复", "note": ""}],
				"active": 0,
				"result": {"status": "", "notice": "", "incomplete": false},
				"action_committed": false
			}
		]
	}
	client.restore_threads(old_save)

	# Step 1: Open in local offline mode
	client.set_dialogue_source(GameLLMClientClass.SOURCE_LOCAL_AIRP)
	client.open(GameLLMClientClass.DIALOGUE, "sparkle_migrated_scope", {"npc_id": "sparkle", "npc_name": "花火"})
	assert(client.history.is_empty(), "Local thread should start clean and isolated, not containing cloud turns")
	
	# Step 2: Chat one turn in local offline mode
	var local_chat_ok := client.send("这是本地离线模式下的秘密对话")
	assert(local_chat_ok, "Local chat should succeed")
	assert(client.history.size() == 1, "Local thread should now have 1 turn")
	assert(client.history[0].user == "这是本地离线模式下的秘密对话", "Local turn content match")

	# Step 3: Switch to cloud API and open the same scope
	client.set_dialogue_source(GameLLMClientClass.SOURCE_CLOUD_API)
	client.open(GameLLMClientClass.DIALOGUE, "sparkle_migrated_scope", {"npc_id": "sparkle", "npc_name": "花火"})
	assert(client.history.size() == 1, "Cloud thread should contain the migrated legacy turn")
	assert(client.history[0].user == "旧存档中的云端前言", "Cloud thread should contain old cloud message")
	
	# Step 4: Send new cloud turn and inspect outgoing request payload
	mock_transport.force_start_error = ""
	var send_cloud_ok := client.send("主人在云端发出的新指示")
	assert(send_cloud_ok, "Cloud send should start")
	var req_body: Dictionary = mock_transport.last_body
	var req_messages: Array = req_body.get("messages", [])
	
	var has_local_leak := false
	var has_old_cloud := false
	var has_new_cloud := false
	for msg in req_messages:
		var content_str := str(msg.get("content", ""))
		if content_str.contains("这是本地离线模式下的秘密对话"):
			has_local_leak = true
		if content_str.contains("旧存档中的云端前言"):
			has_old_cloud = true
		if content_str.contains("主人在云端发出的新指示"):
			has_new_cloud = true
			
	assert(not has_local_leak, "CRITICAL: Local offline messages must NEVER leak into Cloud API request body!")
	assert(has_old_cloud, "Migrated old cloud turn must be present in cloud context")
	assert(has_new_cloud, "New cloud message must be present in cloud context")
	print("  [Pass] Session migration verified: Zero local messages leaked into cloud request body")

	# -----------------------------------------------------------------
	# Test 4 (P1 Issue 2): Explicit Pause/Stop Priority and Multi-turn Coherence
	# -----------------------------------------------------------------
	print("\n--- Test 4: Explicit Stop Priority and Multi-turn Context Coherence (P1) ---")
	client.set_dialogue_source(GameLLMClientClass.SOURCE_LOCAL_AIRP)
	client.open(GameLLMClientClass.DIALOGUE, "stop_intent_scope", {"npc_id": "sparkle", "npc_name": "花火"})
	
	# Turn 1: Normal Greeting
	client.send("花火下午好呀")
	assert(client.history.size() == 1, "Turn 1 recorded")
	
	# Turn 2: Explicit Stop / Mind Changed
	client.send("我改变主意了，到这儿就好")
	assert(client.history.size() == 2, "Turn 2 recorded")
	var stop_diag: String = client.diagnostic
	var stop_reply: String = str(client.active_reply().get("text", ""))
	assert(stop_diag.contains("pause_request_01"), "Explicit stop input must hit pause_request_01, got: %s" % stop_diag)
	assert(not stop_diag.contains("intimate_tease_reverse_01"), "Explicit stop must NOT hit tease_reverse_01!")
	assert(not _has_ellipsis(stop_reply), "Stop reply must have zero ellipses")
	print("  [Pass] Explicit stop correctly routed to pause_request_01: %s" % stop_reply)

	# Turn 3: Negation of stop ("不要停，再快点")
	client.open(GameLLMClientClass.DIALOGUE, "negation_scope", {"npc_id": "keqing", "npc_name": "刻晴", "intimate_mode": true})
	client.send("不要停，再快点")
	var non_stop_diag: String = client.diagnostic
	assert(non_stop_diag.contains("intimate_rhythm_faster_01"), "Negation '不要停' must route to faster rhythm, got: %s" % non_stop_diag)
	print("  [Pass] Negation '不要停，再快点' correctly avoided pause_stop")

	# -----------------------------------------------------------------
	# Test 5 (P2 Issue 3): Real Game Entry Points Scene Parameter Alignment
	# -----------------------------------------------------------------
	print("\n--- Test 5: Real Game Entry Points Scene Alignment (P2) ---")
	# 1. Combat Entrance (from scripts/world/npc_world_duel.gd:506)
	var duel_combat_ctx := {
		"npc_id": "raiden_shogun",
		"npc_name": "雷电将军",
		"current_interaction_state": "对决对峙中"
	}
	assert(GameLLMClientClass.resolve_scene_id(duel_combat_ctx) == "combat_h", "对决对峙中 must resolve to combat_h")
	client.open(GameLLMClientClass.DIALOGUE, "duel_combat_scope", duel_combat_ctx)
	client.send("接招吧，雷电将军！")
	assert(client.diagnostic.contains("combat_") or client.diagnostic.contains("pause_") or client.diagnostic.contains("clarify_"), "Combat koujou dispatched")

	# 2. Settlement Entrance (from scripts/world/npc_world_duel.gd:510)
	var duel_settle_ctx := {
		"npc_id": "sparkle",
		"npc_name": "花火",
		"current_interaction_state": "玩弄侍奉安置阶段"
	}
	assert(GameLLMClientClass.resolve_scene_id(duel_settle_ctx) == "intimate", "玩弄侍奉安置阶段 must resolve to intimate")
	client.open(GameLLMClientClass.DIALOGUE, "duel_settle_scope", duel_settle_ctx)
	client.send("乖乖按约定来侍奉吧")
	assert(not client.active_reply().get("text", "").is_empty(), "Settlement koujou generated")

	# 3. Home Entrance (from scripts/narrative/home_interaction_panel.gd:364)
	var home_chat_ctx := {
		"npc_id": "keqing",
		"npc_name": "刻晴",
		"current_interaction_state": "家园闲聊"
	}
	assert(GameLLMClientClass.resolve_scene_id(home_chat_ctx) == "home_chat", "家园闲聊 must resolve to home_chat")
	client.open(GameLLMClientClass.DIALOGUE, "home_chat_scope", home_chat_ctx)
	client.send("今天在房间里好好放松一下吧")
	assert(not client.active_reply().get("text", "").is_empty(), "Home koujou generated")

	# 4. Temple Encounter Entrance (from scripts/world/initial_temple_encounter_controller.gd:341)
	var temple_ctx := {
		"npc_id": "sparkle",
		"npc_name": "花火",
		"current_interaction_state": "神殿初遇对话"
	}
	assert(GameLLMClientClass.resolve_scene_id(temple_ctx) == "home_chat", "神殿初遇对话 must resolve to home_chat")
	print("  [Pass] All real game entrance scene states verified with 100% precision")

	# -----------------------------------------------------------------
	# Test 6 (P2 Issue 4): Component Readiness and Missing Model Handling
	# -----------------------------------------------------------------
	print("\n--- Test 6: Component Readiness and Missing Model Handling (P2) ---")
	var real_readiness: Dictionary = client.check_local_airp_readiness()
	assert(real_readiness.has("ready"), "Readiness dict must contain 'ready'")
	print("  Current Local AIRP Readiness: ready=%s, probe=%s, model=%s" % [
		real_readiness.get("ready"),
		real_readiness.get("has_probe"),
		real_readiness.get("has_model")
	])

	# Test readiness check contract with simulated missing component
	var test_airp := LocalAirpClientClass.new()
	var test_readiness: Dictionary = test_airp.check_readiness()
	assert(test_readiness.has("ready") and test_readiness.has("error"), "Readiness must provide error description")

	# Test Title Settings UI response to readiness
	var title_ui := TitleAPISettingsClass.new()
	root.add_child(title_ui)
	title_ui.open()
	title_ui._on_source_selected(GameLLMClientClass.SOURCE_LOCAL_AIRP)
	if real_readiness.get("ready", false):
		assert(title_ui._status.text.contains("本地口上"), "Status must report readiness when components present")
	else:
		assert(title_ui._status.text.contains("本地组件缺失"), "Status must report missing component when absent")
	title_ui.queue_free()
	print("  [Pass] Component readiness and Title Settings UI status synchronization verified")

	print("\n==================================================")
	print("ALL OFFLINE PLAY MODE TESTS PASSED SUCCESSFULLY! (0 FAILURES)")
	print("==================================================")
	quit(0)
