extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- Running test_settings_teleport ---")
	var world = load("res://scenes/main.tscn").instantiate()
	world.automation_enabled = true
	root.add_child(world)
	current_scene = world
	while not world.test_ready:
		await process_frame

	assert(world.settings_panel != null, "Settings panel should exist")
	assert(world.settings_panel.teleport_options != null, "Teleport options container should exist in settings")
	assert(world.spawn_menu != null, "Spawn menu option button should exist")
	assert(world.spawn_menu.item_count == world.metadata.spawns.size(), "Spawn menu should have all spawns")

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
