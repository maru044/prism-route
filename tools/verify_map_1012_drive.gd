extends SceneTree
## Check the actual imported scene, population, contacts and short drive.

var failures: Array[String] = []
var records: Array[Dictionary] = []
var scene
var capture := false
var viewport: SubViewport

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	capture = "--capture-map-1012" in OS.get_cmdline_user_args()
	root.size = Vector2i(1920, 1080)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	var container := SubViewportContainer.new()
	root.add_child(container)
	container.add_child(viewport)
	scene = load("res://scenes/map_1012_drive_test.tscn").instantiate()
	scene.automation_enabled = true
	scene.set_process_unhandled_input(false)
	scene.get_node("CamperVan").automation_enabled = true
	scene.get_node("CamperVan").set_process_unhandled_input(false)
	scene.get_node("VegetationLodStreamer").record_tree_layout_for_review = true
	viewport.add_child(scene)
	var start := Time.get_ticks_msec()
	while not scene.test_ready:
		if Time.get_ticks_msec() - start > 60000:
			push_error("Map startup timed out")
			quit(1)
			return
		await process_frame
	var startup_ms := Time.get_ticks_msec() - start
	check(scene.vegetation.tree_instance_count == 20000, "Tree count is not 20000")
	check(scene.vegetation.large_tree_instance_count == 2000, "Large tree count is not 2000")
	check(scene.camper.get_node("Visual/CamperModel").scale.is_equal_approx(Vector3.ONE), "Old camper was resized")
	check(scene.camper.get_node("CollisionShape3D").shape.size.is_equal_approx(Vector3(2.2, 2.5, 5.6)), "Old collision box was not restored")
	check(scene.get_node("FreshSkyEnvironment").environment.sky.sky_material == load("res://assets/environment/sky/fresh_cumulus_sky.tres"), "New sky is missing")
	check(not scene.has_node("OceanBackdrop"), "Extra generated ocean is still present")
	check(scene.terrain_material.get_shader_parameter("use_height_sand") == false, "Authored low land was treated as sand")
	var water: MeshInstance3D = scene.model.find_child("Water", true, false)
	check(water != null, "Authored water mesh is missing")
	if water:
		check(water.position.is_equal_approx(Vector3.ZERO), "Authored water was moved")
		check(water.mesh.get_faces().size() / 3 == int(scene.metadata.source_polygon_counts.Water), "Authored water geometry count differs")
		check(water.get_node("ExactMeshCollision").collision_layer == 4, "Water became a drivable floor")
	check(scene.vegetation._grass_coverage(Vector3(0, -4, 0), Vector3.UP) > 0.99, "Low land cannot grow grass")
	check(scene.vegetation._raycast_terrain(scene.anchors[2].x, scene.anchors[2].z).is_empty(), "Grass grows on the beach")
	check(scene.vegetation._raycast_terrain(scene.anchors[0].x, scene.anchors[0].z).is_empty(), "Grass grows on the road spawn")
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/map_1012_test/tree_layout.json"))
	var ground_errors := 0
	var max_height_error := 0.0
	var root_discrepancies: Array[Dictionary] = []
	var min_spacing := INF
	var min_large_spacing := INF
	var bins := {}
	var large_bins := {}
	var large_count := 0
	var below_zero_count := 0
	for index in rows.size():
		var row: Array = rows[index]
		var point := Vector3(row[0], row[1], row[2])
		if point.y < 0:
			below_zero_count += 1
		var hit: Dictionary = scene.ground_hit(point, true)
		if hit.is_empty() or hit.collider.get_meta("map_surface", "") != "Terrain":
			ground_errors += 1
		else:
			var height_error: float = absf(hit.position.y - point.y)
			max_height_error = maxf(max_height_error, height_error)
			if height_error > 0.03:
				root_discrepancies.append({"index": index, "root": [point.x, point.y, point.z], "hit": [hit.position.x, hit.position.y, hit.position.z], "error_m": height_error})
		var distance := _nearest_previous(point, bins, 9.0)
		min_spacing = minf(min_spacing, distance)
		if int(row[5]) == 1:
			large_count += 1
			min_large_spacing = minf(min_large_spacing, _nearest_previous(point, large_bins, 22.0))
	check(ground_errors == 0, "Trees hit a road, beach or empty space: %d" % ground_errors)
	check(max_height_error < 0.03, "Tree roots disagree with imported collision")
	check(min_spacing >= 8.999, "Tree spacing below 9 m")
	check(min_large_spacing >= 21.999, "Large tree spacing below 22 m")
	check(large_count == 2000, "Layout large tree count differs")
	check(scene.vegetation.review_tree_records.size() == rows.size(), "LOD population differs from layout")
	var vegetation_result := {"trees": rows.size(), "large": large_count, "trees_below_zero": below_zero_count, "ground_errors": ground_errors,
		"max_root_height_error_m": max_height_error, "minimum_tree_spacing_m": min_spacing,
		"minimum_large_spacing_m": min_large_spacing}
	print("MAP_1012_POPULATION ", JSON.stringify(vegetation_result))
	# Validate four actual bookmarks independently of baked positions.
	for bookmark in 4:
		await scene.select_spawn(bookmark)
		for frame in 75:
			await physics_frame
		var hit: Dictionary = scene.ground_hit(scene.camper.position)
		check(not hit.is_empty(), "Bookmark %d has no collision" % bookmark)
		check(scene.camper.is_on_floor(), "Camper did not settle at bookmark %d" % bookmark)
		if bookmark == 0 and not hit.is_empty():
			check(hit.collider.get_meta("map_surface", "") == "Roads", "Driving spawn is covered by terrain")
		var gaps: Array = scene.camper.wheel_ground_gaps()
		check(gaps.size() == 4, "Missing old camper wheel probes")
		for gap in gaps:
			check(absf(gap) < 0.04, "Wheel gap at bookmark %d: %s" % [bookmark, gap])
		records.append({"bookmark": bookmark, "surface": hit.collider.get_meta("map_surface", "") if not hit.is_empty() else "missing", "on_floor": scene.camper.is_on_floor(), "wheel_gaps_m": gaps})
	await scene.select_spawn(0)
	for frame in 60:
		await physics_frame
	var position: Vector3 = scene.camper.position
	scene.camper.test_throttle = 1.0
	for frame in 95:
		await physics_frame
	scene.camper.test_throttle = 0.0
	var distance: float = Vector2(scene.camper.position.x-position.x, scene.camper.position.z-position.z).length()
	check(distance > 7.0, "Camper did not advance along road")
	check(scene.camper.is_on_floor(), "Camper lost floor during short drive")
	var drive_gaps: Array = scene.camper.wheel_ground_gaps()
	for gap in drive_gaps:
		check(absf(gap) < 0.05, "Wheel gap after drive: %s" % gap)
	records.append({"driven_m": distance, "on_floor": scene.camper.is_on_floor(), "wheel_gaps_m": drive_gaps})
	if capture:
		scene.camper.test_throttle = 0
		await scene.select_spawn(0)
		for frame in 60:
			await physics_frame
		await _capture("drive")
		scene.show_overview()
		await _capture("overview")
		for bookmark in [1, 2, 3]:
			scene.show_detail(bookmark)
			await _capture(["", "forest", "beach", "upper"][bookmark])
		scene.camera.position = Vector3(-350, 260, 700)
		scene.camera.look_at(Vector3(150, 25, 200))
		await _capture("coast_wide")
	var report := {"failures": failures, "godot": Engine.get_version_info().string, "population": vegetation_result,
		"root_discrepancies": root_discrepancies,
		"checks": records, "startup_ms": startup_ms, "validation_ms": Time.get_ticks_msec()-start, "capture": capture}
	DirAccess.make_dir_recursive_absolute("res://.map_1012_build")
	var file := FileAccess.open("res://.map_1012_build/verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("MAP_1012_VERIFY ", JSON.stringify(report))
	scene.free()
	quit(0 if failures.is_empty() else 1)

func _nearest_previous(point: Vector3, bins: Dictionary, cell_size: float) -> float:
	var cell := Vector2i(floori(point.x / cell_size), floori(point.z / cell_size))
	var nearest := INF
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for other: Vector3 in bins.get(cell + Vector2i(dx, dz), []):
				nearest = minf(nearest, Vector2(point.x-other.x, point.z-other.z).length())
	if not bins.has(cell):
		bins[cell] = []
	(bins[cell] as Array).append(point)
	return nearest

func _capture(name: String) -> void:
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.map_1012_build/captures")
	check(viewport.get_texture().get_image().save_png("res://.map_1012_build/captures/%s.png" % name) == OK, "Capture failed: " + name)
	print("MAP_1012_CAPTURE ", name, " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
