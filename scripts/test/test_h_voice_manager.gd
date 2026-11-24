extends SceneTree

const VOICE := preload("res://scripts/audio/h_voice_manager.gd")
const COMBAT := preload("res://scripts/combat/turn_combat_manager.gd")
const PLEASURE := preload("res://scripts/combat/pleasure_component.gd")

var failures: Array[String] = []
var played: Array[String] = []
var vm: HVoiceManager

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, details: String) -> void:
	if not ok:
		failures.append(details)
		push_error(details)

func _run() -> void:
	vm = VOICE.new()
	root.add_child(vm)
	vm.set_process(false)
	vm.rng.seed = 5
	vm.voice_played.connect(func(pool: String, _clip: String): played.append(pool))
	_check_catalog()

	var home := Node.new()
	root.add_child(home)
	var battle := COMBAT.new()
	var hero := PLEASURE.new()
	var npc := PLEASURE.new()
	root.add_child(battle)
	root.add_child(hero)
	root.add_child(npc)
	battle.setup(hero, npc)
	battle.animation_delays = false

	var ready := [false]
	vm.start_intimacy(home, {"tier":"service"}, func() -> bool: return ready[0])
	vm._process(15.0)
	_check(played.is_empty(), "Home scene waits for animated actors")
	ready[0] = true
	vm._process(0.0)
	vm._process(3.49)
	_check(played.is_empty(), "Home opening remains silent before 3.5 s")
	vm.stop_scene(home)
	vm._process(6.0)
	_check(played.is_empty() and not vm.player.playing, "Closing before the first sound cancels it")

	vm.start_intimacy(home, {"tier":"service"})
	vm._process(3.51)
	_check(played == ["voice_pool_service_manual"] and vm.player.playing, "Home opening plays after the delay")
	vm.play_chat_greet()
	vm._process(20.0)
	_check(played.size() == 1, "An active scene clip cannot be interrupted or overlapped")
	vm.player.stop()
	vm.player.finished.emit()
	var pause := vm._next_clip_delay
	_check(pause >= 3.0 and pause <= 5.0, "Natural end starts a 3–5 s pause")
	vm._process(pause - 0.01)
	_check(played.size() == 1, "No home voice during the pause")
	vm._process(0.02)
	_check(played.size() == 2 and vm._motion_stage == 1, "The next home voice follows the pause")
	vm.stop_scene(home)
	_check(vm.player.playing and vm._fade != null, "Home exit starts a fade rather than playing a closing clip")

	battle.start_combat()
	vm.stop_scene(home)
	vm.play_battle_reaction(battle, 0.9)
	_check(played.size() == 2, "An old exit and an early hit cannot interrupt the new opening delay")
	vm._process(3.49)
	await create_timer(0.11).timeout
	_check(vm.player.volume_db < 0.0 and vm.player.playing, "The fade attenuates the current voice")
	await create_timer(0.25).timeout
	_check(not vm.player.playing and is_zero_approx(vm.player.volume_db), "Fade completes and restores volume")

	# Use a short, silent PCM stream to exercise AudioStreamPlayer.finished without
	# waiting for a full production clip or playing it during an automated run.
	var silence := AudioStreamWAV.new()
	silence.mix_rate = 8000
	var pcm := PackedByteArray()
	pcm.resize(800)
	silence.data = pcm
	for clip: String in vm.POOLS.voice_battle_taunt:
		vm._stream_cache[clip] = silence
	vm._process(0.02)
	_check(played.back() == "voice_battle_taunt", "Re-entering produces only the new battle opening")
	await create_timer(0.65).timeout
	_check(not vm.player.playing and vm._next_clip_delay >= 3.0 and vm._next_clip_delay <= 5.0,
		"A real playback completion starts the battle pause")
	var event_count := played.size()
	vm.play_battle_reaction(battle, 0.4)
	_check(played.size() == event_count, "Battle reactions skip during the pause")
	vm._process(5.01)
	_check(played.size() == event_count, "Battle reactions are not queued")
	vm.play_battle_reaction(battle, 0.4)
	vm.play_battle_reaction(battle, 0.9)
	_check(played.size() == event_count + 1 and played.back() == "voice_battle_pleasure_mid",
		"Only one eligible battle reaction plays")
	npc.add_pleasure(npc.max_pleasure)
	battle._check_battle_state()
	_check(vm._fade != null and played.size() == event_count + 1, "Victory fades without a closing clip")
	await create_timer(0.36).timeout

	battle.start_combat()
	vm._process(3.51)
	hero.add_pleasure(hero.max_pleasure)
	battle._check_battle_state()
	_check(vm._fade != null and vm._scene_voice == vm.SceneVoice.NONE, "Defeat also cancels the scene and fades")
	await create_timer(0.36).timeout

	battle.start_combat()
	var before_exit := played.size()
	battle.free()
	vm._process(4.0)
	_check(played.size() == before_exit, "Removing a battle cancels pending audio")
	vm.play_chat_greet("charlotte")
	_check(played.back() == "voice_chat_greet" and vm._feedback_player.playing, "Standalone greetings still play")
	vm.play_chest_fondle()
	_check(played.back() == "voice_touch_chest" and vm._feedback_player.playing, "Standalone short feedback still plays")
	vm.free()
	home.free()
	hero.free()
	npc.free()
	print("H_VOICE_TIMING_RESULT ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func _check_catalog() -> void:
	for clips: Array in vm.POOLS.values():
		for clip: String in clips:
			var stream := vm.get_stream(clip)
			_check(stream != null and stream.get_length() > 0.0, "Missing or empty clip: " + clip)
	var cases := [
		[{"name":"沙发端坐受纳口交", "tier":"service"}, "voice_pool_oral"],
		[{"name":"床沿仰卧胸部侍奉", "tier":"service"}, "voice_pool_paizuri_chest"],
		[{"name":"长榻沙发骑乘深入", "tier":"honban"}, "voice_pool_honban_cowgirl"],
		[{"name":"日式后背犬交贯穿", "tier":"honban"}, "voice_pool_honban_doggy"],
		[{"name":"日式仰卧正常位", "tier":"honban"}, "voice_pool_honban_missionary"],
		[{"name":"面对面双手手交", "tier":"service"}, "voice_pool_service_manual"],
	]
	for sample: Array in cases:
		_check(vm.resolve_intimacy_pool(sample[0]) == sample[1], "Expected pool: " + sample[1])
