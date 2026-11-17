extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"

var failures: Array[String] = []

func _expect(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("[TEST FAIL] " + message)
	return ok

func _make_key_event(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	return ev

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.max_fps = 0
	var world_packed: PackedScene = load(MAIN_SCENE)
	var world = world_packed.instantiate()
	root.add_child(world)

	var deadline := Time.get_ticks_msec() + 120000
	while not world.test_ready:
		if not _expect(Time.get_ticks_msec() < deadline, "World initialization timed out"):
			quit(1)
			return
		await process_frame

	var duel = world.sandbar_duel
	var temple = world.initial_ruin
	var player = world.character

	if not _expect(is_instance_valid(duel) and is_instance_valid(temple), "NPC duel / temple adapters missing"):
		quit(1)
		return

	# =========================================================
	# 1. TEST KEQING CORPSE INTERACTION
	# =========================================================
	print("--- Testing Keqing Kill & Corpse Play ---")
	# First place player next to Keqing before settlement kill
	player.global_position = duel.anchor.global_position + Vector3(0.5, 0.0, 0.5)
	await process_frame
	await process_frame
	duel._execute_settlement_kill()
	await process_frame
	await process_frame

	_expect(duel.is_ragdoll_active, "Keqing ragdoll must be active after kill")
	_expect(duel.corpse_actor.visible, "Keqing corpse actor must be visible")
	_expect(duel.corpse_actor.physical_bones.size() == 16, "Keqing corpse must have 16 physical bones")
	_expect(not duel.actor.visible, "Living Keqing actor must be hidden")

	# Settle physics near Keqing corpse
	for i in 10:
		await physics_frame
		await process_frame

	_expect(duel.prompt.visible, "Prompt must be visible when near Keqing corpse")
	_expect("【物理布娃娃 · 刻晴】" in duel.prompt.text, "Prompt text must identify Keqing corpse: " + duel.prompt.text)
	_expect("拖拽" in duel.prompt.text, "Prompt text must offer drag option: " + duel.prompt.text)

	# Grab limb with [E]
	var grab_key := _make_key_event(KEY_E)
	var handled: bool = duel.corpse_handler.handle_input(grab_key)
	_expect(handled, "Corpse handler must handle [E] key")
	_expect(duel.corpse_handler.is_dragging, "Corpse handler must enter dragging state")
	_expect(player.running_speed == 2.6, "Player running speed must reflect drag resistance (2.6)")
	_expect("正在物理拖拽: 刻晴" in duel.prompt.text, "Prompt must show dragging message: " + duel.prompt.text)

	# Move player while dragging
	for i in 15:
		player.global_position += Vector3(0.05, 0.0, 0.0)
		await physics_frame
		await process_frame

	# Drop limb with [E]
	var drop_handled: bool = duel.corpse_handler.handle_input(grab_key)
	_expect(drop_handled, "Corpse handler must handle second [E] key to drop")
	_expect(not duel.corpse_handler.is_dragging, "Corpse handler must exit dragging state")
	_expect(player.running_speed > 2.6, "Player speed must be restored after dropping")

	# Move player > 30m away to trigger respawn
	print("Moving player 35m away from Keqing corpse...")
	player.global_position = duel.corpse_handler.get_corpse_position() + Vector3(35.0, 0.0, 0.0)
	for i in 15:
		await physics_frame
		await process_frame

	_expect(not duel.is_ragdoll_active, "Keqing ragdoll must be deactivated after leaving 30m")
	_expect(not duel.corpse_actor.visible, "Keqing corpse actor must be hidden after respawn")
	_expect(duel.actor.visible, "Living Keqing actor must be restored after respawn")
	print("KEQING_CORPSE_INTERACTION_PASS")

	# =========================================================
	# 2. TEST SPARKLE CORPSE INTERACTION
	# =========================================================
	print("--- Testing Sparkle Kill & Corpse Play ---")
	var sparkle_encounter = temple.encounter
	# Place player next to Sparkle anchor before settlement kill
	player.global_position = temple.npc_anchor.global_position + Vector3(0.5, 0.0, 0.5)
	await process_frame
	await process_frame
	sparkle_encounter._execute_settlement_kill()
	await process_frame
	await process_frame

	_expect(sparkle_encounter.is_ragdoll_active, "Sparkle ragdoll must be active after kill")
	_expect(sparkle_encounter.corpse_actor.visible, "Sparkle corpse actor must be visible")
	_expect(sparkle_encounter.corpse_actor.physical_bones.size() == 16, "Sparkle corpse must have 16 physical bones")
	_expect(not sparkle_encounter.npc_avatar.visible, "Living Sparkle avatar must be hidden")

	# Settle physics near Sparkle corpse
	for i in 10:
		await physics_frame
		await process_frame

	_expect(temple.interact_prompt.visible, "Prompt must be visible when near Sparkle corpse")
	_expect("【物理布娃娃 · 花火】" in temple.interact_prompt.text, "Prompt text must identify Sparkle corpse: " + temple.interact_prompt.text)
	_expect("拖拽" in temple.interact_prompt.text, "Prompt text must offer drag option: " + temple.interact_prompt.text)

	# Grab limb with [E]
	var sparkle_grab: bool = sparkle_encounter.corpse_interaction_handler.handle_input(grab_key)
	_expect(sparkle_grab, "Sparkle corpse handler must handle [E] key")
	_expect(sparkle_encounter.corpse_interaction_handler.is_dragging, "Sparkle corpse handler must enter dragging state")
	_expect(player.running_speed == 2.6, "Player running speed must reflect drag resistance (2.6)")
	_expect("正在物理拖拽: 花火" in temple.interact_prompt.text, "Prompt must show dragging message: " + temple.interact_prompt.text)

	# Move player while dragging
	for i in 15:
		player.global_position += Vector3(0.05, 0.0, 0.0)
		await physics_frame
		await process_frame

	# Drop limb with [E]
	var sparkle_drop: bool = sparkle_encounter.corpse_interaction_handler.handle_input(grab_key)
	_expect(sparkle_drop, "Sparkle corpse handler must handle second [E] key to drop")
	_expect(not sparkle_encounter.corpse_interaction_handler.is_dragging, "Sparkle corpse handler must exit dragging state")
	_expect(player.running_speed > 2.6, "Player speed must be restored after dropping")

	# Move player > 30m away to trigger respawn
	print("Moving player 35m away from Sparkle corpse...")
	player.global_position = sparkle_encounter.get_corpse_position() + Vector3(35.0, 0.0, 0.0)
	for i in 15:
		await physics_frame
		await process_frame

	_expect(not sparkle_encounter.is_ragdoll_active, "Sparkle ragdoll must be deactivated after leaving 30m")
	_expect(not sparkle_encounter.corpse_actor.visible, "Sparkle corpse actor must be hidden after respawn")
	_expect(sparkle_encounter.npc_avatar.visible, "Living Sparkle avatar must be restored after respawn")
	print("SPARKLE_CORPSE_INTERACTION_PASS")

	if failures.is_empty():
		print("=== ALL CORPSE INTERACTION TESTS PASSED 100%! ===")
		world.queue_free()
		await process_frame
		quit(0)
	else:
		push_error("Corpse interaction tests failed with %d errors" % failures.size())
		world.queue_free()
		await process_frame
		quit(1)
