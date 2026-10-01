extends SceneTree
## Actual main-entry renders for terrain design discussions; no scene edits.

const OUT := "res://screenshots/terrain_planning_2026-10-01/"
var world: Node3D
var camera: Camera3D
var measurements: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	world = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(world)
	while not world.vegetation.initialized:
		await process_frame
	world.camper.set_physics_process(false)
	world.camper.set_process_unhandled_input(false)
	world.get_node("HUD").hide()
	for nodes in [world.vegetation.tree_lod0_nodes, world.vegetation.tree_lod1_nodes, world.vegetation.tree_lod2_nodes]:
		for node in nodes:
			if node.material_override is ShaderMaterial:
				node.material_override.set_shader_parameter("wind_strength", 0.0)
	world.vegetation.grass_material.set_shader_parameter("wind_strength", 0.0)
	world.vegetation.grass_material.set_shader_parameter("wind_tone_strength", 0.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	camera = world.get_viewport().get_camera_3d()
	await _save("01_main_entry")
	camera = Camera3D.new()
	camera.name = "TerrainPlanningCamera"
	camera.far = 6000.0
	world.add_child(camera)
	camera.current = true
	world.vegetation.target = camera
	await _view("02_forest", Vector3(-327, 94.23975, 389), Vector3(-432, 60.23975, 224), 52.0)
	await _view("03_hillside", Vector3(501, 83.71725, -252), Vector3(476, 13.717255, -372), 52.0)
	var terrain: MeshInstance3D = world.primary_terrain
	var bounds: AABB = terrain.global_transform * terrain.mesh.get_aabb()
	var center := bounds.get_center()
	var span := maxf(bounds.size.x, bounds.size.z)
	await _view("04_overview", center + Vector3(span * 0.50, span * 0.90, span * 0.90), center, 60.0)
	for direction in [-1, 1]:
		var edge := _shore_point(bounds, direction)
		var from := edge + Vector3(150, 65, direction * 230)
		var toward := edge + Vector3(0, 5, -direction * 90)
		await _view("05_shore_negative_z" if direction < 0 else "06_shore_positive_z", from, toward, 60.0)
	var report := FileAccess.open(OUT + "capture_metadata.json", FileAccess.WRITE)
	if report == null:
		quit(1)
		return
	report.store_string(JSON.stringify({"entry": ProjectSettings.get_setting("application/run/main_scene"),
		"baseline": "smooth_small_tree_2026-10-01", "terrain_bounds": str(bounds),
		"compass_note": "Godot +/-Z views; geographic north is not assumed from the CAD export.",
		"wind_frozen": true, "hud_hidden": true, "captures": measurements}, "\t"))
	quit()

func _shore_point(bounds: AABB, direction: int) -> Vector3:
	var best := bounds.get_center()
	var best_height := INF if direction < 0 else -INF
	for column in range(2, 9):
		var x := bounds.position.x + bounds.size.x * float(column) / 10.0
		for step in range(41):
			var fraction := float(step) / 80.0
			var z := bounds.position.z + bounds.size.z * (fraction if direction < 0 else 1.0 - fraction)
			var hit: Dictionary = world._raycast_terrain(x, z)
			if hit.is_empty():
				continue
			var point: Vector3 = hit.position
			if (direction < 0 and point.y < best_height) or (direction > 0 and point.y > best_height):
				best = point
				best_height = point.y
			break
	return best

func _view(label: String, from: Vector3, toward: Vector3, fov: float) -> void:
	camera.position = from
	camera.fov = fov
	camera.look_at(toward)
	await _save(label)

func _save(label: String) -> void:
	await create_timer(1.0).timeout
	while world.vegetation.get_pending_visible_grass_chunk_count() > 0:
		await process_frame
	for frame in 36:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := OUT + label + ".png"
	if root.get_texture().get_image().save_png(path) != OK:
		quit(1)
		return
	measurements.append({"file": label + ".png", "camera": str(camera.global_position),
		"fov": camera.fov, "draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	print("TERRAIN_PLANNING_CAPTURE ", path, " camera=", camera.global_position)
