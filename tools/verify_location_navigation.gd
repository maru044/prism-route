extends SceneTree
## Exercise real menu callbacks and keyboard input, including paused collisions.

var failures: Array[String] = []
var results: Array[Dictionary] = []
var scene

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func click(button: Button) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func check_location(index: int, label: String) -> void:
	var actor: CharacterBody3D = scene.active_actor()
	var expected: Vector3 = scene.anchors[index]
	if scene.character_mode and index in [1, 3]:
		expected.x += 4.0
	var error := actor.global_position.distance_to(expected)
	check(error < 1.0, label + ": actor did not reach bookmark")
	check(scene.viewpoint == index and not scene.test_panel.menu_open, label + ": wrong place/menu state")
	if scene.free_mode:
		check(scene.camera.global_position.distance_to(scene.anchors[index]) < 220, label + ": observer camera did not move")
	results.append({"case":label,"position_error_m":error,"free_mode":scene.free_mode})

func run() -> void:
	root.size = Vector2i(1920, 1080)
	for path in ["res://scenes/cliff_b_gameplay_test.tscn", "res://scenes/map_1012_drive_test.tscn"]:
		scene = load(path).instantiate()
		scene.automation_enabled = true
		scene.get_node("CamperVan").automation_enabled = true
		root.add_child(scene)
		var start := Time.get_ticks_msec()
		while not scene.test_ready:
			if Time.get_ticks_msec() - start > 45000:
				check(false, "Startup timeout: " + path)
				quit(1)
				return
			await process_frame
		await frames(20)
		scene.show_overview()
		var panel = scene.test_panel
		for index in 4:
			panel.set_menu_open(true)
			panel.tabs.current_tab = 1
			await frames(3)
			var parked: Vector3 = scene.active_actor().position
			await frames(3)
			check(scene.active_actor().position.is_equal_approx(parked), "Menu should pause actor")
			var button: Button
			for node in panel.tabs.get_child(1).find_children("*", "Button", true, false):
				if node.text.begins_with(str(index+1)+"  "):
					button = node
					break
			check(button != null, "Missing place button")
			if button != null:
				await click(button)
			await frames(12)
			check_location(index, path + " menu " + str(index+1))
		# Keyboard routes from a playable camera, then from an open modal.
		scene.set_free_mode(false)
		for index in 4:
			await key(KEY_1 + index)
			await frames(12)
			check_location(index, path + " key " + str(index+1))
		for index in 4:
			panel.set_menu_open(true)
			await key(KEY_1 + index)
			await frames(12)
			check_location(index, path + " modal key " + str(index+1))
		for index in 4:
			await key(KEY_KP_1 + index)
			await frames(12)
			check_location(index, path + " keypad " + str(index+1))
		scene.queue_free()
		await frames(3)
	var report := {"failures":failures,"cases":results,"godot":Engine.get_version_info().string}
	var file := FileAccess.open("res://.cliff_b_build/location_navigation_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("LOCATION_NAVIGATION cases=",results.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
