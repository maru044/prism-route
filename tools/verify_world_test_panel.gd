extends SceneTree
## Exercise AA choices, modal control ownership, persistence and responsive UI.

var failures: Array[String] = []
var scene
var capture := false
var output := "res://.map_1012_build/test_panel"

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

func shot(name: String) -> void:
	if not capture:
		return
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output + "/" + name + ".png") == OK, "Failed capture: " + name)

func click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	capture = "--capture-test-panel" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1920, 1080)
	scene = load("res://scenes/map_1012_drive_test.tscn").instantiate()
	scene.automation_enabled = true
	scene.get_node("CamperVan").automation_enabled = true
	root.add_child(scene)
	var start := Time.get_ticks_msec()
	while not scene.test_ready:
		if Time.get_ticks_msec() - start > 60000:
			check(false, "Startup timeout")
			quit(1)
			return
		await process_frame
	await frames(60)
	var panel = scene.test_panel
	check(not panel.menu_open and not panel.menu_root.visible, "Menu should start closed")
	check(not root.use_taa and root.msaa_3d == Viewport.MSAA_4X and root.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "Original 4x MSAA without postprocessing not applied")
	check(panel.tabs.get_tab_count() == 5, "Missing menu category")
	check(not panel.persist_graphics, "Automation must not change player preferences")
	check(panel.show_statistics and panel.statistics_switch.button_pressed and "Draws" in panel.status.text, "Detailed performance statistics should be enabled by default")
	await shot("compact")
	await click(panel.menu_button)
	check(panel.menu_open, "Menu entry button did not react to pointer input")
	await key(KEY_ESCAPE)
	check(not panel.menu_open, "Esc did not close menu opened with pointer")
	await key(KEY_ESCAPE)
	await frames(2)
	check(panel.menu_open and not scene.camper.can_process(), "Esc did not open modal and suspend camper")
	var parked: Vector3 = scene.camper.position
	scene.camper.test_throttle = 1.0
	await frames(30)
	check(scene.camper.position.is_equal_approx(parked), "Camper moved while interacting with menu")
	await key(KEY_C)
	await frames(2)
	check(not scene.character_mode, "Gameplay shortcut leaked through menu")
	panel.tabs.current_tab = 2
	for mode in panel.AA_NAMES.size():
		panel.aa_choice.select(mode)
		panel.aa_choice.item_selected.emit(mode)
		check(panel.sample_choice.disabled == (mode != 1), "Inapplicable sampling option remained active")
		check(not root.use_taa and root.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "Postprocessing AA was re-enabled")
		if mode == 1:
			for sample in 3:
				panel.sample_choice.select(sample)
				panel.sample_choice.item_selected.emit(sample)
				check(root.msaa_3d == sample + 1, "MSAA sample strength mismatch")
		else:
			check(root.msaa_3d == Viewport.MSAA_DISABLED, "AA disabled/FXAA retained MSAA")
		check(is_equal_approx(root.scaling_3d_scale, 1.0), "AA choice reduced resolution")
	# Round-trip preference data in a sandbox-local file; never overwrite user://.
	panel.preferences_path = output + "/verification_preferences.cfg"
	panel.aa_mode = 1
	panel.sample_level = 2
	panel.save_graphics()
	panel.aa_mode = 0
	panel.sample_level = 0
	panel.load_graphics()
	check(panel.aa_mode == 1 and panel.sample_level == 2, "Graphics preferences did not round-trip")
	var config := ConfigFile.new()
	for legacy_mode in [2, 3]:
		config.set_value("antialiasing", "mode", legacy_mode)
		config.set_value("antialiasing", "samples", 2)
		config.save(panel.preferences_path)
		panel.load_graphics()
		panel.apply_graphics(false)
		check(panel.aa_mode == 1 and panel.sample_level == 1 and not root.use_taa and root.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "Legacy TAA/FXAA preference was not restored to 4x MSAA")
	config.set_value("antialiasing", "mode", "invalid")
	config.set_value("antialiasing", "samples", 99)
	config.save(panel.preferences_path)
	panel.aa_mode = 1
	panel.sample_level = 1
	panel.load_graphics()
	check(panel.aa_mode == 1 and panel.sample_level == 1, "Invalid preferences changed valid defaults")
	panel.apply_graphics(false)
	await shot("graphics")
	root.size = Vector2i(960, 540)
	root.content_scale_size = root.size
	await frames(3)
	check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(panel.menu_panel.get_global_rect()), "Menu extends beyond small viewport")
	await shot("graphics_960")
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	await frames(3)
	panel.tabs.current_tab = 3
	panel.lod_switch.toggled.emit(false)
	check(not scene.lod_enabled, "LOD switch did not change scene")
	scene.set_lod_enabled(true)
	check(panel.lod_switch.button_pressed, "LOD shortcut/UI state diverged")
	panel.vegetation_switch.toggled.emit(false)
	check(not scene.vegetation_enabled, "Vegetation switch failed")
	scene.set_vegetation_enabled(true)
	check(panel.vegetation_switch.button_pressed, "Vegetation shortcut/UI state diverged")
	panel.interaction_switch.toggled.emit(false)
	check(not scene.vegetation.grass_interaction_enabled, "Grass interaction switch failed")
	panel.interaction_switch.toggled.emit(true)
	panel.statistics_switch.toggled.emit(true)
	check("Draws" in panel.status.text, "Detailed statistics are missing")
	panel.statistics_switch.toggled.emit(false)
	check(not "Draws" in panel.status.text, "Detailed statistics did not collapse")
	await shot("vegetation")
	await key(KEY_ESCAPE)
	await frames(45)
	check(not panel.menu_open and scene.camper.can_process(), "Closing menu did not restore camper")
	check(scene.camper.position.distance_to(parked) > 1.0, "Driving did not resume")
	scene.camper.test_throttle = 0
	scene.camper.test_braking = true
	await frames(60)
	panel.set_menu_open(true)
	panel.actor_button.pressed.emit()
	while scene.switching_actor:
		await physics_frame
	check(scene.character_mode and not scene.character.can_process(), "Actor button escaped modal suspension")
	panel.set_menu_open(false)
	await frames(20)
	check(scene.character.can_process() and scene.character.camera.is_current(), "Closing menu did not restore character control/camera")
	scene.character.test_move = Vector2(0, -1)
	parked = scene.character.position
	await frames(30)
	check(scene.character.position.distance_to(parked) > 0.5, "Character cannot move after menu actor switch")
	scene.character.test_move = Vector2.ZERO
	panel.set_menu_open(true)
	panel.tabs.current_tab = 4
	check("人物" in panel.controls_label.text, "Help did not follow selected actor")
	await shot("help")
	panel.set_menu_open(false)
	check(scene.vegetation.tree_instance_count == 20000 and scene.vegetation.large_tree_instance_count == 2000, "World population changed")
	# Leaving the test scene should not alter another scene's viewport settings.
	panel.aa_mode = 0
	panel.apply_graphics(false)
	scene.free()
	check(not root.use_taa and root.msaa_3d == Viewport.MSAA_4X and root.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED, "Leaving the test did not restore viewport settings")
	var report := {"failures": failures, "godot": Engine.get_version_info().string,
		"capture": capture, "aa_choices": 2, "msaa_strengths": [2, 4, 8], "tabs": 5,
		"taa": false, "fxaa": false, "legacy_postprocessing_preferences_migrated": true,
		"detailed_statistics_default": true,
		"menu_pauses_control": true, "preferences_round_trip": true, "small_viewport": "960x540"}
	FileAccess.open(output + "/report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("WORLD_TEST_PANEL_VERIFY ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
