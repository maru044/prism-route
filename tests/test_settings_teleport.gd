extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- Running test_settings_teleport ---")
	var initial_title := root.title
	var world = load("res://scenes/main.tscn").instantiate()
	world.automation_enabled = true
	root.add_child(world)
	current_scene = world
	while not world.test_ready:
		await process_frame

	assert(world.settings_panel != null, "Settings panel should exist")
	assert(root.title == initial_title, "Entering the world should preserve the application title")
	world.settings_panel.open()
	var page: Control = world.settings_panel._pages[0]
	for label: Label in page.find_children("*", "Label", true, false):
		assert(label.text != "快捷传送", "Settings must not show the teleport section")
	for button: Button in page.find_children("*", "Button", true, false):
		assert(button.text not in ["【沙洲 · 刻晴】", "【神殿 · 花火】", "【海岬小镇】"],
			"Settings must not offer a destination")
	assert(page.find_children("*", "OptionButton", true, false).is_empty(),
		"Settings must not offer a spawn selector")
	world.settings_panel.close()

	# Test teleporting to sandbar pavilion (Keqing)
	world._teleport_to_key("sandbar_pavilion")
	await process_frame
	await process_frame
	var keqing_anchor = world.sandbar_duel.anchor
	var dist_keqing: float = world.character.global_position.distance_to(keqing_anchor.global_position)
	assert(dist_keqing < 25.0, "Player should be near sandbar pavilion, got dist=" + str(dist_keqing))
	print("TELEPORT_TO_SANDBAR_OK dist=", dist_keqing)

	# Test teleporting to initial ruin (Sparkle)
	world._teleport_to_key("initial_ruin")
	await process_frame
	await process_frame
	var sparkle_anchor = world.initial_ruin.npc_anchor
	var dist_sparkle: float = world.character.global_position.distance_to(sparkle_anchor.global_position)
	assert(dist_sparkle < 25.0, "Player should be near initial ruin, got dist=" + str(dist_sparkle))
	print("TELEPORT_TO_TEMPLE_OK dist=", dist_sparkle)

	print("--- ALL SETTINGS TELEPORT TESTS PASSED ---")
	world.queue_free()
	await process_frame
	quit(0)
