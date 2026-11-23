extends SceneTree

const HVoiceManagerClass := preload("res://scripts/audio/h_voice_manager.gd")

func _init() -> void:
	print("--- BEGIN TEST: HVoiceManager ---")
	var vm := HVoiceManagerClass.new()
	root.add_child(vm)

	# 1. Pool definitions test
	assert(vm.POOLS.size() >= 13, "Expected at least 13 pools")
	print("Test 1: Pool count = ", vm.POOLS.size(), " (PASSED)")

	# 2. Verify all clips loadable
	var total_clips := 0
	for pool_id in vm.POOLS:
		var clips: Array = vm.POOLS[pool_id]
		for c in clips:
			total_clips += 1
			var stream := vm.get_stream(str(c))
			assert(stream != null, "Failed to load clip: " + str(c))
			assert(stream.get_length() > 0.0, "Clip length should be positive: " + str(c))
	print("Test 2: All %d clips loaded successfully into AudioStream (PASSED)" % total_clips)

	# 3. Motion pool resolution tests
	var test_cases := [
		[{"name": "沙发端坐受纳口交", "tier": "service"}, "voice_pool_oral"],
		[{"name": "床沿仰卧胸部侍奉", "tier": "service"}, "voice_pool_paizuri_chest"],
		[{"name": "长榻沙发骑乘深入", "tier": "honban"}, "voice_pool_honban_cowgirl"],
		[{"name": "日式后背犬交贯穿", "tier": "honban"}, "voice_pool_honban_doggy"],
		[{"name": "日式仰卧正常位", "tier": "honban"}, "voice_pool_honban_missionary"],
		[{"name": "面对面双手手交", "tier": "service"}, "voice_pool_service_manual"],
		[{"name": "特殊深入动作", "tier": "honban"}, "voice_pool_honban_missionary"],
	]
	for tc in test_cases:
		var resolved := vm.resolve_intimacy_pool(tc[0])
		assert(resolved == tc[1], "Mismatch for motion %s: expected %s, got %s" % [tc[0]["name"], tc[1], resolved])
	print("Test 3: Motion pool resolution mappings (PASSED)")

	# 4. Intimacy lifecycle & progression tests
	var played_events: Array[Dictionary] = []
	vm.voice_played.connect(func(pid: String, clip: String):
		played_events.append({"pool": pid, "clip": clip})
	)

	# Start intimacy (should play index 0: 初入浅尝)
	vm.start_intimacy({"name": "跨坐椅背俯身口交", "tier": "service"})
	assert(vm.is_intimacy_active == true, "Intimacy should be active")
	assert(vm.motion_stage == 0, "Motion stage should initially be 0")
	assert(played_events.size() == 1, "Should have played 1 clip")
	assert(played_events[0]["clip"] == "hime2561.ogg", "Stage 0 should play hime2561.ogg")
	print("Test 4: Initial entry stage 0 (PASSED)")

	# Stage advance to heated cycle
	var intensity_increased_called := [false]
	vm.intimacy_intensity_increased.connect(func(stage: int):
		intensity_increased_called[0] = true
	)
	vm._advance_intimacy_cycle()
	assert(vm.motion_stage == 1, "Motion stage should now be 1")
	assert(intensity_increased_called[0] == true, "intimacy_intensity_increased signal should have fired")
	assert(played_events.size() == 2, "Should have played second clip")
	var second_clip: String = played_events[1]["clip"]
	assert(second_clip in ["hime2634.ogg", "hime0860.ogg"], "Stage 1 should play index 1 or 2, got: " + second_clip)
	print("Test 5: Stage 1 heated cycle advancement (PASSED)")

	# Stop intimacy with aftercare
	vm.stop_intimacy(true)
	assert(vm.is_intimacy_active == false, "Intimacy should be inactive")
	assert(played_events.size() == 3, "Should have played aftercare clip")
	assert(played_events[2]["pool"] == "voice_pool_aftercare", "Aftercare pool should have played")
	print("Test 6: Intimacy stop & aftercare (PASSED)")

	# 5. Orgasm trigger
	vm.trigger_orgasm()
	assert(played_events.size() == 4, "Orgasm clip should have played")
	assert(played_events[3]["pool"] == "voice_pool_orgasm", "Orgasm pool should have played")
	print("Test 7: Orgasm trigger (PASSED)")

	# 6. Battle fuck tests
	played_events.clear()
	vm.play_battle_taunt()
	assert(played_events.size() == 1 and played_events[0]["pool"] == "voice_battle_taunt", "Battle taunt")

	vm.play_battle_reaction(20.0) # Low
	assert(played_events.size() == 2 and played_events[1]["pool"] == "voice_battle_pleasure_low", "Battle low")

	vm.play_battle_reaction(55.0) # Mid
	assert(played_events.size() == 3 and played_events[2]["pool"] == "voice_battle_pleasure_mid", "Battle mid")

	vm.play_battle_reaction(88.0) # High
	assert(played_events.size() == 4 and played_events[3]["pool"] == "voice_battle_pleasure_high", "Battle high")

	vm.play_battle_defeat()
	assert(played_events.size() == 5 and played_events[4]["pool"] == "voice_battle_defeat", "Battle defeat")
	print("Test 8: Battle fuck reactions (PASSED)")

	# 7. Chest fondle tests
	played_events.clear()
	vm.play_chest_fondle(false) # Single touch
	assert(played_events.size() == 1 and played_events[0]["clip"] == "hime0068.ogg", "Single chest touch should play hime0068")

	vm.play_chest_fondle(true) # Continuous/rapid
	assert(played_events.size() == 2 and played_events[1]["clip"] == "hime5294.ogg", "Continuous chest touch should play hime5294")
	print("Test 9: Tactile chest fondle (PASSED)")

	# 8. Free chat greet
	played_events.clear()
	vm.play_chat_greet("sparkle")
	assert(played_events.size() == 1 and played_events[0]["clip"] == "hime0013.ogg", "Sparkle greet")

	vm.play_chat_greet("charlotte")
	assert(played_events.size() == 2 and played_events[1]["clip"] == "char0088.ogg", "Charlotte greet")
	print("Test 10: Free chat greet (PASSED)")

	print("--- ALL 10 TESTS PASSED SUCCESFULLY! ---")
	vm.queue_free()
	quit(0)
