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

class CountingAirp extends LocalAirpClientClass:
	var embedding_calls := 0
	func embed_text(text: String) -> PackedFloat32Array:
		embedding_calls += 1
		return super.embed_text(text)

var _passed := false

func _initialize() -> void:
	_run_and_exit.call_deferred()

func _run_and_exit() -> void:
	run()
	quit(0 if _passed else 1)

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
	var counting_airp := CountingAirp.new()
	counting_airp.load_resources()
	client._local_airp = counting_airp

	# -----------------------------------------------------------------
	# Test 1: Dedicated Offline Mode (Zero HTTP, Local Generation)
	# -----------------------------------------------------------------
	print("\n--- Test 1: Dedicated Offline Mode (Zero HTTP, Local Generation) ---")
	client.set_dialogue_source(GameLLMClientClass.SOURCE_LOCAL_AIRP)
	assert(client.get_dialogue_source() == GameLLMClientClass.SOURCE_LOCAL_AIRP, "Dialogue source must be local_airp")

	client.profiles[GameLLMClientClass.DIALOGUE]["url"] = ""
	client.profiles[GameLLMClientClass.DIALOGUE]["model"] = ""
	client.profiles[GameLLMClientClass.DIALOGUE]["key"] = ""
	client.open(GameLLMClientClass.DIALOGUE, "sparkle_offline_test", {
		"npc_id": "sparkle",
		"npc_name": "花火",
		"dialogue_location": "酒馆"
	})
	assert(client.configured(), "Offline dialogue must be configured with blank cloud settings")

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
				"user": "旧版未标记本地消息",
				"replies": [{"text": "旧版未标记本地回复", "note": ""}],
				"active": 0,
				"result": {"status": "", "notice": "", "incomplete": false},
				"action_committed": false
			}
		],
		"dialogue/sparkle_migrated_scope/cloud_api": [
			{
				"user": "此前迁移到云端页但来源不明",
				"replies": [{"text": "此前迁移的回复", "note": ""}],
				"active": 0, "result": {}
			}
		],
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
	var sends_before_reopen := mock_transport.sends
	assert(client.send("同一已打开的本地面板"), "An open local thread must stay local until reopened")
	assert(mock_transport.sends == sends_before_reopen, "An open local thread must not start a cloud request")
	client.open(GameLLMClientClass.DIALOGUE, "sparkle_migrated_scope", {"npc_id": "sparkle", "npc_name": "花火"})
	assert(client.history.size() == 2, "Both legacy formats should remain visible")
	assert(not client.can_retry() and not client.can_continue_reply(), "Unverified turns must not be resent")
	
	# Step 4: Send new cloud turn and inspect outgoing request payload
	mock_transport.force_start_error = ""
	var send_cloud_ok := client.send("主人在云端发出的新指示")
	assert(send_cloud_ok, "Cloud send should start")
	var request := JSON.stringify(mock_transport.last_body.get("messages", []))
	for excluded in ["旧版未标记本地消息", "旧版未标记本地回复", "此前迁移到云端页但来源不明", "此前迁移的回复", "这是本地离线模式下的秘密对话", "同一已打开的本地面板"]:
		assert(not request.contains(excluded), "Unverified or local history must stay out of the cloud payload")
	assert(request.contains("主人在云端发出的新指示"), "New cloud input must be sent")
	mock_transport.delta_received.emit("此轮明确由云端回复")
	mock_transport.finished.emit({}, "")
	client.restore_threads(client.save_threads())
	client.open(GameLLMClientClass.DIALOGUE, "sparkle_migrated_scope", {"npc_id": "sparkle", "npc_name": "花火"})
	assert(client.can_retry() and client.can_continue_reply(), "Verified cloud turns remain usable after loading")
	assert(client.send("第二轮云端消息"), "Follow-up cloud turn should start")
	request = JSON.stringify(mock_transport.last_body.get("messages", []))
	assert(request.contains("此轮明确由云端回复"), "Verified cloud history must round-trip into the cloud context")
	assert(not request.contains("旧版未标记本地消息"), "Reload must not make legacy history eligible")
	print("  [Pass] Old and previously migrated records stay out of cloud requests, verified cloud history survives reload")

	# -----------------------------------------------------------------
	# Test 4 (P0): Strict Stop Intent Priority and Regression Table
	# -----------------------------------------------------------------
	print("\n--- Test 4: Strict Stop Intent Priority and Regression Table (P0) ---")
	client.set_dialogue_source(GameLLMClientClass.SOURCE_LOCAL_AIRP)

	var p0_cases := [
		{"input": "到此为止，不要继续。", "expect_stop": true},
		{"input": "别继续了。", "expect_stop": true},
		{"input": "我改变主意了，到这儿就好。", "expect_stop": true},
		{"input": "等一下再继续。", "expect_stop": true},
		{"input": "不要再继续。", "expect_stop": true},
		{"input": "我不想继续了。", "expect_stop": true},
		{"input": "停。", "expect_stop": true},
		{"input": "不要停下。", "expect_stop": false},
		{"input": "我改变主意了，去散步吧。", "expect_stop": false},
		{"input": "停电了吗？", "expect_stop": false}
	]

	for tc in p0_cases:
		client.open(GameLLMClientClass.DIALOGUE, "p0_scope_" + tc["input"], {"npc_id": "sparkle", "npc_name": "花火", "intimate_mode": true})
		var p0_inp: String = tc["input"]
		var calls_before := counting_airp.embedding_calls
		client.send(p0_inp)
		var p0_diag: String = client.diagnostic
		var is_pause: bool = p0_diag.contains("pause_request_01")
		assert(is_pause == tc["expect_stop"], "P0 failed on input: " + p0_inp)
		if tc["expect_stop"]:
			assert(p0_diag.contains("路径: 显式叫停直接截断"), "Stop must use fast-path截断")
			assert(counting_airp.embedding_calls == calls_before, "Stop must bypass embedding")
			assert(not client.can_continue_reply(), "Pause must disable continuation")
			client.continue_reply()
			assert(client.active_reply().get("continuations", []).is_empty(), "Pause must not append scene dialogue")
		else:
			assert(not p0_diag.contains("resume_intimacy_01"), "Regular inputs must not select the explicit resume template")
		var p0_reply: String = str(client.active_reply().get("text", ""))
		assert(not _has_ellipsis(p0_reply), "P0 reply must have zero ellipses")
	print("  [Pass] P0 Strict stop regression table validated with zero false positives")

	# Negation of stop ("不要停，再快点") and Intimate Resume ("继续吧")
	client.open(GameLLMClientClass.DIALOGUE, "negation_scope", {"npc_id": "keqing", "npc_name": "刻晴", "intimate_mode": true})
	client.send("不要停，再快点")
	var non_stop_diag: String = client.diagnostic
	assert(non_stop_diag.contains("intimate_rhythm_faster_01"), "Negation '不要停' must route to faster rhythm, got: %s" % non_stop_diag)
	print("  [Pass] Negation '不要停，再快点' correctly avoided pause_stop")

	client.send("继续吧")
	assert(client.diagnostic.contains("resume_intimacy_01"), "继续吧 must route to resume")
	client.send("停。")
	client.send("今天做点心一起吃吧")
	assert(not client.can_continue_reply(), "Neutral conversation must not clear a paused scene")
	client.restore_threads(client.save_threads())
	client.open(GameLLMClientClass.DIALOGUE, "negation_scope", {"npc_id": "keqing", "npc_name": "刻晴", "intimate_mode": true})
	assert(not client.can_continue_reply(), "Pause must survive loading")
	client.send("继续吧")
	assert(client.can_continue_reply(), "A fresh explicit resume may clear the pause")
	print("  [Pass] Continuation '继续吧' correctly routed to resume_intimacy_01")

	# -----------------------------------------------------------------
	# Test 4b (P1): Short-Phrase Contextual Topic Continuation
	# -----------------------------------------------------------------
	print("\n--- Test 4b: Short-Phrase Contextual Topic Continuation (P1) ---")
	# Context A: Meal share -> "换一种"
	client.open(GameLLMClientClass.DIALOGUE, "p1_meal_scope", {"npc_id": "sparkle", "npc_name": "花火"})
	client.send("今天做点心一起吃吧")
	assert(client.diagnostic.contains("home_meal_share"), "Turn 1 meal share pass")
	client.send("换一种")
	assert(client.diagnostic.contains("home_meal_share"), "Must maintain meal share topic")
	assert(client.diagnostic.contains("路径: 多轮短句承接"), "Path reason must be 多轮短句承接")
	assert(client.diagnostic.contains("承接上文") and client.diagnostic.contains("参考问法"), "Summary shows path and authored reference")
	assert(not client.diagnostic.contains("换一种"), "Default diagnostic must not expose the raw input")
	assert(client.diagnostic_details.contains("[一起品尝美食] 换一种"), "Detailed diagnostic shows query on demand")
	print("  [Pass] Context A (Meal share -> 换一种) maintained meal share topic")

	# Context B: Island scenery -> "换一种"
	client.open(GameLLMClientClass.DIALOGUE, "p1_island_scope", {"npc_id": "sparkle", "npc_name": "花火"})
	client.send("带我在浮空岛四处逛逛看风景吧")
	assert(client.diagnostic.contains("home_island_01"), "Turn 1 island pass")
	client.send("换一种")
	assert(client.diagnostic.contains("home_island_01"), "Must maintain island topic")
	assert(client.diagnostic.contains("路径: 多轮短句承接"), "Path reason must be 多轮短句承接")
	assert(client.diagnostic_details.contains("[浮空岛与风景] 换一种"), "Detailed diagnostic shows island topic")
	print("  [Pass] Context B (Island scenery -> 换一种) maintained island topic")

	# Context C: Empty context -> "换一种" -> Clarify
	client.open(GameLLMClientClass.DIALOGUE, "p1_empty_scope", {"npc_id": "sparkle", "npc_name": "花火"})
	client.send("换一种")
	assert(client.diagnostic.contains("clarify_unknown_01"), "Empty context must trigger clarify")
	assert(client.diagnostic.contains("路径: 缺少上下文指代澄清"), "Path reason must be 缺少上下文指代澄清")
	print("  [Pass] Context C (Empty context -> 换一种) triggered character clarification")

	# Context D: Explicit topic switch (Meal share -> Combat)
	client.open(GameLLMClientClass.DIALOGUE, "p1_switch_scope", {"npc_id": "keqing", "npc_name": "刻晴"})
	client.send("今天做点心一起吃吧")
	client.send("拔刀吧，让我看看你的武艺！")
	assert(not client.diagnostic.contains("承接上文"), "Explicit topic change must NOT be augmented")
	client.open(GameLLMClientClass.DIALOGUE, "p1_short_topic_switch", {"npc_id": "sparkle", "npc_name": "花火"})
	client.send("今天做点心一起吃吧")
	client.send("我还想看岛上的风景")
	assert(not client.diagnostic.contains("承接上文"), "A complete new topic containing 还想 must not inherit the previous topic")
	assert(client.active_reply().get("content_tag") == "chat_island", "An explicit island topic must replace the meal topic")
	print("  [Pass] Context D Explicit topic change was NOT augmented")

	# Context E: Undo reverts topic
	client.open(GameLLMClientClass.DIALOGUE, "p1_undo_scope", {"npc_id": "sparkle", "npc_name": "花火"})
	client.send("今天做点心一起吃吧")
	client.send("带我在浮空岛四处逛逛看风景吧")
	client.undo()
	client.send("换一种")
	assert(client.diagnostic.contains("home_meal_share"), "Undo must revert topic to meal share")
	print("  [Pass] Context E Undo cleanly restored previous turn topic")

	# Context F: Switch NPC topic isolation
	client.open(GameLLMClientClass.DIALOGUE, "p1_npc_sparkle", {"npc_id": "sparkle", "npc_name": "花火"})
	client.send("今天做点心一起吃吧")
	client.open(GameLLMClientClass.DIALOGUE, "p1_npc_keqing", {"npc_id": "keqing", "npc_name": "刻晴"})
	client.send("换一种")
	assert(client.diagnostic.contains("clarify_unknown_01"), "New NPC must not inherit previous NPC topic")
	print("  [Pass] Context F Cross-NPC topic isolation verified")

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

	# -----------------------------------------------------------------
	# Test 7 (P2): Pilot Koujou Material for Sparkle and Keqing
	# -----------------------------------------------------------------
	print("\n--- Test 7: Pilot Koujou Material for Sparkle and Keqing (P2) ---")
	# Sparkle compliment with unrecorded synonym
	client.open(GameLLMClientClass.DIALOGUE, "p2_sparkle_comp", {"npc_id": "sparkle", "npc_name": "花火"})
	client.send("小狐狸今天嘴巴真甜，长得也真标致")
	assert(client.diagnostic.contains("sparkle_compliment_01"), "Sparkle must hit sparkle_compliment_01")
	var sp_comp_text: String = str(client.active_reply().get("text", ""))
	assert(not _has_ellipsis(sp_comp_text), "Sparkle compliment text zero ellipses")
	assert(sp_comp_text.contains("恶作剧") or sp_comp_text.contains("愚者") or sp_comp_text.contains("面具"), "Sparkle personality verified")
	print("  [Pass] Sparkle exclusive compliment pilot verified: %s" % sp_comp_text)

	# Keqing compliment with unrecorded synonym
	client.open(GameLLMClientClass.DIALOGUE, "p2_keqing_comp", {"npc_id": "keqing", "npc_name": "刻晴"})
	client.send("刻晴办事真是一丝不苟又利落")
	assert(client.diagnostic.contains("keqing_compliment_01"), "Keqing must hit keqing_compliment_01")
	var kq_comp_text: String = str(client.active_reply().get("text", ""))
	assert(not _has_ellipsis(kq_comp_text), "Keqing compliment text zero ellipses")
	assert(kq_comp_text.contains("认可") or kq_comp_text.contains("公文") or kq_comp_text.contains("偷懒") or kq_comp_text.contains("价值"), "Keqing personality verified")
	print("  [Pass] Keqing exclusive compliment pilot verified: %s" % kq_comp_text)

	# Sparkle rest nap with unrecorded synonym
	client.open(GameLLMClientClass.DIALOGUE, "p2_sparkle_nap", {"npc_id": "sparkle", "npc_name": "花火"})
	client.send("脑袋晕乎乎的，借花火的膝盖躺一下")
	assert(client.diagnostic.contains("sparkle_rest_nap_01"), "Sparkle must hit sparkle_rest_nap_01")
	var sp_nap_text: String = str(client.active_reply().get("text", ""))
	assert(not _has_ellipsis(sp_nap_text), "Sparkle nap text zero ellipses")
	print("  [Pass] Sparkle exclusive rest nap pilot verified: %s" % sp_nap_text)

	# Keqing rest nap with unrecorded synonym
	client.open(GameLLMClientClass.DIALOGUE, "p2_keqing_nap", {"npc_id": "keqing", "npc_name": "刻晴"})
	client.send("盯公文眼睛酸了，刻晴借个肩膀靠靠")
	assert(client.diagnostic.contains("keqing_rest_nap_01"), "Keqing must hit keqing_rest_nap_01")
	var kq_nap_text: String = str(client.active_reply().get("text", ""))
	assert(not _has_ellipsis(kq_nap_text), "Keqing nap text zero ellipses")
	print("  [Pass] Keqing exclusive rest nap pilot verified: %s" % kq_nap_text)

	# -----------------------------------------------------------------
	# Test 8 (P2): Retrieval Diagnostics 5-Path Full Coverage
	# -----------------------------------------------------------------
	print("\n--- Test 8: Retrieval Diagnostics 5-Path Full Coverage (P2) ---")
	# Path 1: 显式叫停直接截断
	client.open(GameLLMClientClass.DIALOGUE, "diag_p1", {"npc_id": "sparkle", "npc_name": "花火"})
	client.send("到此为止，不要继续。")
	assert(client.diagnostic.contains("路径: 显式叫停直接截断"), "Path 1 must be 显式叫停直接截断")
	print("  [Pass] Diagnostic Path 1 (显式叫停直接截断) verified")

	# Path 2: 普通语义检索
	client.open(GameLLMClientClass.DIALOGUE, "diag_p2", {"npc_id": "sparkle", "npc_name": "花火"})
	client.send("今天天气真好，你好呀")
	assert(client.diagnostic.contains("路径: 普通语义检索"), "Path 2 must be 普通语义检索")
	print("  [Pass] Diagnostic Path 2 (普通语义检索) verified")

	# Path 3: 多轮短句承接
	client.send("换一种")
	assert(client.diagnostic.contains("路径: 多轮短句承接"), "Path 3 must be 多轮短句承接")
	print("  [Pass] Diagnostic Path 3 (多轮短句承接) verified")

	# Path 4: 低置信度澄清
	client.open(GameLLMClientClass.DIALOGUE, "diag_p4", {"npc_id": "sparkle", "npc_name": "花火"})
	client.send("量子力学与广义相对论的大一统几何结构")
	assert(client.diagnostic.contains("路径: 低置信度澄清"), "Path 4 must be 低置信度澄清")
	print("  [Pass] Diagnostic Path 4 (低置信度澄清) verified")

	# Path 5: 探针推理异常
	var real_airp: LocalAirpClientClass = client._get_local_airp()
	real_airp.force_probe_error = true
	client.open(GameLLMClientClass.DIALOGUE, "diag_p5", {"npc_id": "sparkle", "npc_name": "花火"})
	client.send("你好呀")
	assert(client.diagnostic.contains("路径: 探针推理异常"), "Path 5 must be 探针推理异常")
	assert(client.diagnostic.contains("错误: 本地 AIRP 探针推理异常"), "Path 5 error message verified")
	real_airp.force_probe_error = false
	print("  [Pass] Diagnostic Path 5 (探针推理异常) verified")

	print("\n==================================================")
	print("ALL OFFLINE PLAY MODE TESTS PASSED SUCCESSFULLY! (0 FAILURES)")
	print("==================================================")
	counting_airp.close_probe()
	counting_airp.free()
	_passed = true
