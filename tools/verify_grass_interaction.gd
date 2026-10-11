extends SceneTree
## Real renderer comparisons plus the actual world/actor/camera integration.

const INTERACTION := preload("res://scripts/grass_interaction.gd")
var failures: Array[String] = []
var report := {}
var viewport: SubViewport
var capture := false

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func shot(name: String) -> Image:
	if not capture:
		return null
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	check(image.save_png("res://.map_1012_build/captures/%s.png" % name) == OK, "Capture failed: " + name)
	return image

func changed_pixels(a: Image, b: Image) -> int:
	var aa := a.get_data()
	var bb := b.get_data()
	var count := 0
	for i in range(0, mini(aa.size(), bb.size()), 4):
		if maxi(abs(int(aa[i]) - int(bb[i])), maxi(abs(int(aa[i+1]) - int(bb[i+1])), abs(int(aa[i+2]) - int(bb[i+2])))) > 2:
			count += 1
	return count

func _run() -> void:
	capture = "--capture-grass" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute("res://.map_1012_build/captures")
	root.size = Vector2i(1280, 720)
	viewport = SubViewport.new()
	viewport.size = root.size
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	var container := SubViewportContainer.new()
	root.add_child(container)
	container.add_child(viewport)
	if capture:
		await _render_fixture()
	await _world()
	report["failures"] = failures
	report["capture"] = capture
	report["godot"] = Engine.get_version_info().string
	var file := FileAccess.open("res://.map_1012_build/grass_interaction_verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("GRASS_INTERACTION_VERIFY ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _render_fixture() -> void:
	var fixture := Node3D.new()
	viewport.add_child(fixture)
	var body := Node3D.new()
	fixture.add_child(body)
	body.position.y = 0.03
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/vegetation/shaders/vegetation_wind.gdshader")
	material.set_shader_parameter("albedo_texture", load("res://assets/vegetation/textures/grass_tuft_straw_minimal_v5.png"))
	material.set_shader_parameter("alpha_cutoff", 0.34)
	material.set_shader_parameter("wind_strength", 0.0)
	material.set_shader_parameter("light_wrap", 0.46)
	var source = load("res://assets/vegetation/models/grass_star_3card_v6.glb").instantiate()
	var mesh: Mesh = source.find_children("*", "MeshInstance3D", true, false)[0].mesh
	var rng := RandomNumberGenerator.new()
	rng.seed = 1012
	for side in 2:
		var batch := MultiMeshInstance3D.new()
		batch.position = Vector3(-4.5 if side == 0 else 0.0, 0, -4.5)
		batch.material_override = material
		batch.extra_cull_margin = 1.5
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = mesh
		instances.instance_count = 25 * 50
		for x in 25:
			for z in 50:
				var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(rng.randf_range(0.9, 1.2), rng.randf_range(0.9, 1.15), 1.0))
				instances.set_instance_transform(x * 50 + z, Transform3D(basis, Vector3(x * 0.18, 0, z * 0.18)))
		batch.multimesh = instances
		fixture.add_child(batch)
	source.free()
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(13, 13)
	floor_mesh.mesh = plane
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color("9d9659")
	floor_mesh.material_override = ground
	fixture.add_child(floor_mesh)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("90b9c6")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.75
	var world := WorldEnvironment.new()
	world.environment = environment
	fixture.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-65, -35, 0)
	sun.light_energy = 0.7
	fixture.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12
	fixture.add_child(camera)
	camera.position = Vector3(5, 7, 8)
	camera.look_at(Vector3(0, 0.4, 0))
	camera.make_current()
	await frames(8)
	var baseline := await shot("grass_push_baseline")
	var interaction = INTERACTION.new()
	interaction.set_actor(body, false)
	interaction.update(0.016, material)
	await frames(4)
	var character := await shot("grass_push_character_fixture")
	var character_pixels := changed_pixels(baseline, character)
	check(character_pixels > 500, "GPU character footprint did not displace the real grass mesh")
	body.rotation.y = PI * 0.5
	interaction.set_actor(body, true)
	interaction.update(0.016, material)
	await frames(4)
	var vehicle := await shot("grass_push_vehicle_fixture")
	var vehicle_pixels := changed_pixels(baseline, vehicle)
	check(vehicle_pixels > character_pixels * 2, "GPU vehicle capsule is not substantially wider/longer than the character footprint")
	# A flat grass patch makes the original short camper's footprint easy to review.
	var camper_visual = load("res://assets/vehicles/models/camper_van_placeholder.glb").instantiate()
	fixture.add_child(camper_visual)
	camper_visual.position = body.position
	camper_visual.rotation.y = body.rotation.y
	await frames(4)
	await shot("grass_push_camper_patch")
	camper_visual.free()
	body.position.z += 9
	interaction.update(1.65, material)
	await frames(4)
	var recovered := await shot("grass_push_recovered")
	var recovered_pixels := changed_pixels(baseline, recovered)
	check(recovered_pixels < 20, "GPU grass did not return to baseline after recovery")
	# At the same XZ but on another storey, even a vehicle must leave grass alone.
	body.position = Vector3(0, 4, 0)
	interaction.reset()
	interaction.update(0.016, material)
	await frames(4)
	var other_storey := await shot("grass_push_other_storey")
	check(changed_pixels(baseline, other_storey) < 20, "GPU interaction leaks to a different storey")
	report["gpu_pixels_changed"] = {"character": character_pixels, "vehicle": vehicle_pixels, "recovered": recovered_pixels}
	fixture.free()
	await frames(2)

func _world() -> void:
	var scene = load("res://scenes/map_1012_drive_test.tscn").instantiate()
	scene.automation_enabled = true
	scene.get_node("CamperVan").automation_enabled = true
	viewport.add_child(scene)
	var start := Time.get_ticks_msec()
	while not scene.test_ready:
		if Time.get_ticks_msec() - start > 60000:
			check(false, "World startup timeout")
			return
		await process_frame
	await frames(4)
	var vegetation = scene.vegetation
	check(vegetation.grass_interaction.actor == scene.camper, "Camper not registered for interaction")
	check(vegetation.grass_material.get_shader_parameter("use_grass_interaction") == true, "Interaction not enabled on streamed grass")
	check(vegetation.grass_interaction.vehicle, "Camper footprint type failed")
	scene.set_free_mode(true)
	scene.camera.position += Vector3(100, 20, 100)
	await frames(4)
	check(vegetation.target == scene.camera and vegetation.grass_interaction.actor == scene.camper, "Free camera changed the grass presser")
	scene.set_free_mode(false)
	await scene.set_character_mode(true)
	await scene.select_spawn(1)
	scene.character.camera_pivot.rotation = Vector3(-0.45, PI, 0)
	await frames(90)
	check(vegetation.grass_interaction.actor == scene.character and not vegetation.grass_interaction.vehicle, "Character switching did not change grass footprint")
	if capture:
		vegetation.grass_interaction_enabled = false
		await frames(4)
		await shot("grass_push_ganyu_before")
		vegetation.grass_interaction_enabled = true
		await frames(5)
		await shot("grass_push_ganyu_world")
	scene.character.test_move = Vector2(0, -1)
	scene.character.test_running = true
	await frames(90)
	check(vegetation.grass_interaction.history.size() > 2, "Moving character leaves no recovery samples")
	check(vegetation.grass_interaction.history.size() < INTERACTION.MAX_SOURCES, "Grass history grew beyond its GPU budget")
	await shot("grass_push_ganyu_moving")
	scene.character.test_move = Vector2.ZERO
	# Allow for controller braking before the last path sample starts recovering.
	await frames(140)
	check(vegetation.grass_interaction.history.is_empty(), "Recent path did not expire after standing still")
	await scene.select_spawn(1)
	await scene.set_character_mode(false)
	scene.camper.rotation.y += PI
	await frames(50)
	check(vegetation.grass_interaction.vehicle and vegetation.grass_interaction.actor == scene.camper, "Switching back did not restore camper footprint")
	await shot("grass_push_camper_world")
	scene.camper.test_throttle = 1
	await frames(40)
	check(vegetation.grass_interaction.history.size() > 2, "Moving camper leaves no recovery samples")
	await shot("grass_push_camper_moving")
	scene.camper.test_throttle = 0
	scene.camper.test_braking = true
	var old_position: Vector3 = scene.camper.position
	await scene.select_spawn(2)
	await frames(4)
	# Shader sources update in _process; several physics ticks can precede one
	# render frame during capture. Wait until that update has actually happened.
	await process_frame
	await process_frame
	check(scene.camper.position.distance_to(old_position) > INTERACTION.TELEPORT_DISTANCE, "Teleport test was not a teleport")
	var teleport_sample_distance := 0.0
	for sample: Dictionary in vegetation.grass_interaction.history:
		var centre: Vector3 = (sample.start + sample.end) * 0.5
		teleport_sample_distance = maxf(teleport_sample_distance, centre.distance_to(scene.camper.position))
	check(teleport_sample_distance < 3.0, "Teleport retained a distant grass path")
	report["max_sample_distance_after_teleport_m"] = teleport_sample_distance
	report["world"] = {"trees": vegetation.tree_instance_count, "large_trees": vegetation.large_tree_instance_count,
		"free_camera_does_not_push": true, "actor_switching": true, "recovery_seconds": INTERACTION.RECOVERY_SECONDS, "max_sources": INTERACTION.MAX_SOURCES}
	scene.free()
