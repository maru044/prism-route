extends SceneTree

const LocalAirpClientScript := preload("res://scripts/ai/local_airp/local_airp_client.gd")
const LocalAirpComposerScript := preload("res://scripts/ai/local_airp/local_airp_composer.gd")

func _init() -> void:
	print("Starting test_local_airp_game_runtime.gd")
	var failures := 0
	
	# 1. Test Composer
	var composer := LocalAirpComposerScript.new()
	composer.load_data("res://assets/ai/local_airp")
	if composer.sparkle_wildcards.is_empty():
		push_error("Composer failed to load sparkle wildcards")
		failures += 1
	if composer.keqing_wildcards.is_empty():
		push_error("Composer failed to load keqing wildcards")
		failures += 1
	print("Composer load data: OK")
	
	# 2. Test Client & Probe
	var client := LocalAirpClientScript.new()
	client.load_resources()
	if client.templates.is_empty():
		push_error("Client templates empty!")
		failures += 1
	if client.reference_embeddings.is_empty():
		push_error("Client reference embeddings empty!")
		failures += 1
	print("Client load resources: OK")
	
	var probe_ok := client.ensure_probe()
	if not probe_ok:
		push_error("Failed to ensure probe in Godot runtime!")
		failures += 1
		_finish(failures)
		return
	print("Probe initialization: OK")
	
	# 3. Test Sparkle Greet
	var r1 := client.retrieve_and_compose("花火早上好呀", "sparkle", "home_chat", {}, 101)
	print("Test 1 (Sparkle Greet): ", r1["reply_id"], " score: ", r1["score"], " text: ", r1["text"])
	if r1["content_tag"] != "greet":
		push_error("Expected greet for Sparkle, got: " + r1["content_tag"])
		failures += 1
	if _has_ellipsis(r1["text"]):
		push_error("Ellipsis detected in r1 text!")
		failures += 1
		
	# 4. Test Keqing Intimate Faster
	var r2 := client.retrieve_and_compose("好舒服，请再快一点！", "keqing", "intimate", {}, 102)
	print("Test 2 (Keqing Faster): ", r2["reply_id"], " score: ", r2["score"], " text: ", r2["text"])
	if r2["content_tag"] != "intimate_rhythm_faster":
		push_error("Expected intimate_rhythm_faster for Keqing, got: " + r2["content_tag"])
		failures += 1
	if _has_ellipsis(r2["text"]):
		push_error("Ellipsis detected in r2 text!")
		failures += 1
		
	# 5. Test Pause Stop
	var r3 := client.retrieve_and_compose("等一下，太激烈了先暂停缓口气", "keqing", "intimate", {}, 103)
	print("Test 3 (Pause Stop): ", r3["reply_id"], " score: ", r3["score"], " text: ", r3["text"])
	if r3["content_tag"] != "pause_stop":
		push_error("Expected pause_stop, got: " + r3["content_tag"])
		failures += 1
	if _has_ellipsis(r3["text"]):
		push_error("Ellipsis detected in r3 text!")
		failures += 1
		
	# 6. Test Out-of-scope Clarify
	var r4 := client.retrieve_and_compose("量子力学薛定谔波动方程计算", "sparkle", "home_chat", {}, 104)
	print("Test 4 (Clarify): ", r4["reply_id"], " is_fallback: ", r4["is_fallback"], " text: ", r4["text"])
	if r4["content_tag"] != "clarify_unknown":
		push_error("Expected clarify_unknown, got: " + r4["content_tag"])
		failures += 1
	if _has_ellipsis(r4["text"]):
		push_error("Ellipsis detected in r4 text!")
		failures += 1
		
	client.close_probe()
	_finish(failures)

func _has_ellipsis(text: String) -> bool:
	if text.contains("\u2026"):
		return true
	if text.contains("." + "." + "."):
		return true
	return false

func _finish(failures: int) -> void:
	if failures == 0:
		print("ALL GODOT RUNTIME AIRP TESTS PASSED! (failures=0)")
		quit(0)
	else:
		push_error("GODOT RUNTIME AIRP TESTS FAILED! Failures: %d" % failures)
		quit(1)
