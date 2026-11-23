extends SceneTree

const TEST_SCENE := preload("res://scenes/test/vrm_chest_interaction_test.tscn")

func _init() -> void:
	print("Starting test_vrm_chest_scene_runtime.gd")
	var scene = TEST_SCENE.instantiate()
	root.add_child(scene)
	await process_frame

	# Wait for ready and first model
	while scene._is_loading:
		await process_frame

	print("Initial model loaded: %s, models count: %d" % [scene._models[scene._current_index].label, scene._models.size()])
	assert(scene._models.size() >= 45, "Must have at least 45 models")
	assert(not scene.targets.is_empty(), "Keqing should have resolved targets")

	# Test switching to Ganyu (index 1)
	print("Switching to index 1~")
	scene.select_model(1)
	while scene._is_loading:
		await process_frame
	print("Loaded index 1: %s, targets: %d" % [scene._models[scene._current_index].label, scene.targets.size()])
	assert(scene.targets.size() == 2, "Ganyu should have 2 targets")

	# Test switching to Black Swan (numbered bones)
	var bs_idx := -1
	for i in scene._models.size():
		if scene._models[i].id == "black_swan":
			bs_idx = i
			break
	assert(bs_idx >= 0, "Black Swan should be in model list")
	print("Switching to Black Swan (index %d)~" % bs_idx)
	scene.select_model(bs_idx)
	while scene._is_loading:
		await process_frame
	print("Loaded Black Swan: %s, targets: %d, scheme: %s" % [scene._models[scene._current_index].label, scene.targets.size(), scene._current_scheme])
	assert(scene.targets.size() == 2, "Black Swan should have 2 targets")
	assert(scene._current_scheme.contains("数字编号"), "Black Swan should resolve numbered scheme")

	# Test switching to Ayaka (single chest bone)
	var ayaka_idx := -1
	for i in scene._models.size():
		if scene._models[i].id == "ayaka":
			ayaka_idx = i
			break
	assert(ayaka_idx >= 0, "Ayaka should be in model list")
	print("Switching to Ayaka (index %d)~" % ayaka_idx)
	scene.select_model(ayaka_idx)
	while scene._is_loading:
		await process_frame
	print("Loaded Ayaka: %s, targets: %d, scheme: %s" % [scene._models[scene._current_index].label, scene.targets.size(), scene._current_scheme])
	assert(scene.targets.size() == 2, "Ayaka should have 2 targets")

	# Test relative switching (< [Q] / [E] >)
	var cur: int = scene._current_index
	scene._switch_character_relative(1)
	while scene._is_loading:
		await process_frame
	assert(scene._current_index == (cur + 1) % scene._models.size(), "Relative switch next should step by 1")

	scene._switch_character_relative(-1)
	while scene._is_loading:
		await process_frame
	assert(scene._current_index == cur, "Relative switch prev should step back")

	scene.queue_free()
	print("\n==================================================")
	print("VRM CHEST INTERACTION TEST SCENE FULLY VERIFIED!")
	print("==================================================")
	quit(0)
