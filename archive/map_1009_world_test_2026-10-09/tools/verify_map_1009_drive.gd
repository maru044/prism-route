extends SceneTree
## Exercise real physics contacts, A/B collision switching, and a short drive.

var failures: Array[String] = []
var records: Array = []
var scene
var capture := false
var test_viewport: SubViewport

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	root.size = Vector2i(1440, 900)
	capture = "--capture-map-1009" in OS.get_cmdline_user_args()
	# Fixed render target avoids desktop window size/DPI changes between A/B.
	test_viewport = SubViewport.new()
	test_viewport.size = Vector2i(1440, 900)
	test_viewport.own_world_3d = true
	test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	test_viewport.msaa_3d = Viewport.MSAA_2X
	var container := SubViewportContainer.new()
	root.add_child(container)
	container.add_child(test_viewport)
	scene = load("res://scenes/map_1009_drive_test.tscn").instantiate()
	scene.automation_enabled = true
	scene.set_process_unhandled_input(false)
	scene.get_node("CamperVan").automation_enabled = true
	scene.get_node("CamperVan").set_process_unhandled_input(false)
	test_viewport.add_child(scene)
	while not scene.test_ready:
		await process_frame
	var heights: Array[float] = []
	var detail_camera := Transform3D.IDENTITY
	var overview_camera := Transform3D.IDENTITY
	for variant in range(2):
		await scene.set_variant(variant)
		for bookmark in range(4):
			await scene.select_spawn(bookmark)
			for frame in range(90):
				await physics_frame
			var hit: Dictionary = scene.ground_hit(scene.camper.position)
			check(not hit.is_empty(), "Missing ground at variant %d / bookmark %d" % [variant, bookmark])
			check(scene.camper.is_on_floor(), "Vehicle did not settle at variant %d / bookmark %d" % [variant, bookmark])
			if not hit.is_empty():
				check(scene.variants[variant].is_ancestor_of(hit.collider), "Ray hit inactive variant")
			var gaps: Array = scene.camper.wheel_ground_gaps()
			check(gaps.size() == 4, "Missing actual tire probes")
			if bookmark == 0:
				for gap in gaps:
					check(absf(gap) < 0.02, "Visible tire floats or sinks on road: %s m" % gap)
			records.append({"variant": variant, "bookmark": bookmark, "on_floor": scene.camper.is_on_floor(), "wheel_ground_gaps_m": gaps, "position": [scene.camper.position.x, scene.camper.position.y, scene.camper.position.z]})
		var relief_hit: Dictionary = scene.ground_hit(scene.anchors[1])
		check(not relief_hit.is_empty(), "Missing relief comparison ground")
		heights.append(float(relief_hit.position.y))
		if capture:
			scene.show_overview()
			if variant == 0:
				overview_camera = scene.camera.global_transform
			else:
				scene.camera.global_transform = overview_camera
			await _capture("overview_%d" % variant)
			scene.show_detail(1)
			if variant == 0:
				detail_camera = scene.camera.global_transform
			else:
				scene.camera.global_transform = detail_camera
			await _capture("relief_%d" % variant)
			scene.set_free_mode(false)
			await scene.select_spawn(0)
			for frame in range(90):
				await physics_frame
			await _capture("drive_%d" % variant)
			scene.set_free_mode(true)
			scene.camera.global_position = scene.camper.global_position + scene.camper.global_basis * Vector3(14, 2, 1)
			scene.camera.look_at(scene.camper.get_node("Visual").global_position + Vector3.UP * 1.2)
			await _capture("wheel_contact_%d" % variant)
			scene.set_free_mode(false)
		await scene.select_spawn(0)
		for frame in range(60):
			await physics_frame
		var start: Vector3 = scene.camper.position
		scene.camper.automation_enabled = true
		scene.camper.test_throttle = 1.0
		for frame in range(110):
			await physics_frame
		scene.camper.test_throttle = 0.0
		var distance: float = Vector2(scene.camper.position.x - start.x, scene.camper.position.z - start.z).length()
		check(distance > 8.0, "Short drive failed to advance")
		check(scene.camper.position.y > start.y - 4.0, "Vehicle fell during short drive")
		var drive_gaps: Array = scene.camper.wheel_ground_gaps()
		for gap in drive_gaps:
			check(absf(gap) < 0.03, "Visible tire floats or sinks after driving: %s m" % gap)
		records.append({"variant": variant, "driven_m": distance, "on_floor_after_drive": scene.camper.is_on_floor(), "wheel_ground_gaps_m": drive_gaps})
	check(absf(heights[1] - heights[0]) > 1.0, "Natural collision did not follow relief")
	var report := {"failures": failures, "checks": records, "relief_ground_heights": heights,
		"relief_collision_difference_m": heights[1] - heights[0], "camper_dimensions_m": [3, 3.4, 11]}
	DirAccess.make_dir_recursive_absolute("res://.map_1009_build")
	var file := FileAccess.open("res://.map_1009_build/verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("MAP_1009_VERIFY ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _capture(name: String) -> void:
	for frame in range(16):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.map_1009_build/captures")
	var result := test_viewport.get_texture().get_image().save_png("res://.map_1009_build/captures/%s.png" % name)
	check(result == OK, "Capture failed: " + name)
