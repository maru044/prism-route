extends SceneTree
## Fixed-camera GPU A/B diagnostics and warmed, uncapped frame timing.
var scene
var viewport: SubViewport
var output := "res://screenshots/cliff_b_rendering_20261014/"
var report: Dictionary = {"variants": [], "performance": [], "failures": []}
var env: Environment
var sun: DirectionalLight3D

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await process_frame

func capture(name: String) -> void:
	await frames(25)
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image().save_png(output + name + ".png")
	if result != OK:
		report.failures.append("Capture failed: " + name)
	print("RENDER_CAPTURE ", name)

func reset() -> void:
	scene.rendering.set_enabled(false)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 0.38
	env.ssao_enabled = true
	env.ssao_intensity = 1.20
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-43, -128, 0)
	sun.light_energy = 0.72
	scene.rendering.architecture.set_shader_parameter("arch_shadow_tint", Color("bca99a"))
	scene.rendering.architecture.set_shader_parameter("arch_ramp_start", -0.15)
	scene.rendering.architecture.set_shader_parameter("arch_ramp_end", 0.45)
	scene.rendering.architecture.set_shader_parameter("gloss_strength", 1.0)

func variant(name: String) -> void:
	reset()
	match name:
		"ao_off": env.ssao_enabled = false
		"ao_half": env.ssao_intensity = 0.60
		"ambient_050": env.ambient_light_energy = 0.50
		"ambient_060": env.ambient_light_energy = 0.60
		"sky_ambient": env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		"shadow_off": sun.shadow_enabled = false
		"road_only":
			for material in [scene.terrain_material, scene.rendering.road_material]:
				material.set_shader_parameter("road_color", Color(0.34, 0.35, 0.34))
		"plain_white":
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.91, 0.895, 0.865)
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.roughness = 0.73
			for mesh in scene.rendering.architecture_meshes:
				mesh.material_override = material
		"warm", "neutral", "cool", "warm_wide", "final", "no_gloss":
			scene.rendering.set_enabled(true)
			if name not in ["final", "no_gloss"]:
				scene.terrain_material.shader = preload("res://assets/world/terrain/shaders/terrain_draft.gdshader")
				scene.rendering.road_material.shader = preload("res://assets/world/map_1012_test/road.gdshader")
				for material in [scene.terrain_material, scene.rendering.road_material]:
					material.set_shader_parameter("road_color", Color(0.23, 0.25, 0.25))
			if name == "neutral": scene.rendering.architecture.set_shader_parameter("arch_shadow_tint", Color("b0b0ac"))
			if name == "cool": scene.rendering.architecture.set_shader_parameter("arch_shadow_tint", Color("a7b7be"))
			if name == "warm_wide":
				scene.rendering.architecture.set_shader_parameter("arch_ramp_start", -0.30)
				scene.rendering.architecture.set_shader_parameter("arch_ramp_end", 0.65)
			if name == "no_gloss": scene.rendering.architecture.set_shader_parameter("gloss_strength", 0.0)

func performance(name: String) -> void:
	variant(name)
	await frames(120)
	var durations: Array[float] = []
	var gpu_durations: Array[float] = []
	var cpu_durations: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in 1200:
		await process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		durations.append(float(now - previous) / 1000.0)
		gpu_durations.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid()))
		cpu_durations.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid()))
		previous = now
	var total := 0.0
	for value in durations: total += value
	var gpu_total := 0.0
	var cpu_total := 0.0
	for value in gpu_durations: gpu_total += value
	for value in cpu_durations: cpu_total += value
	durations.sort()
	var worst := 0.0
	var count := maxi(1, ceili(durations.size() * 0.01))
	for i in count: worst += durations[durations.size() - 1 - i]
	var result := {"profile": name, "samples": durations.size(), "mean_frame_ms": total / durations.size(), "average_fps": 1000.0 / (total / durations.size()), "one_percent_low_fps": 1000.0 / (worst / count), "viewport_gpu_ms": gpu_total / gpu_durations.size(), "viewport_cpu_ms": cpu_total / cpu_durations.size(), "draw_calls": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)}
	report.performance.append(result)
	print("RENDER_PERFORMANCE ", JSON.stringify(result))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1920, 1080)
	viewport = SubViewport.new()
	viewport.size = root.size
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	var container := SubViewportContainer.new()
	root.add_child(container)
	container.add_child(viewport)
	scene = load("res://scenes/cliff_b_gameplay_test.tscn").instantiate()
	scene.automation_enabled = true
	scene.get_node("CamperVan").automation_enabled = true
	viewport.add_child(scene)
	var start := Time.get_ticks_msec()
	while not scene.test_ready:
		if Time.get_ticks_msec() - start > 60000:
			push_error("Scene timed out")
			quit(1)
			return
		await process_frame
	env = scene.rendering.environment
	sun = scene.rendering.sun
	if scene.rendering.architecture_meshes.size() != 22:
		report.failures.append("Architecture binding count changed")
	# Exercise the user-facing rollback button and keyboard on the real scene.
	scene.rendering.compare_button.pressed.emit()
	if scene.stylized_architecture or scene.rendering.architecture_meshes[0].material_override != preload("res://assets/world/cliff_b_test/architecture.tres"):
		report.failures.append("Original material rollback failed")
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_M
	event.physical_keycode = KEY_M
	scene._unhandled_input(event)
	if not scene.stylized_architecture:
		report.failures.append("M key did not restore warm-white material")
	scene.test_panel.visible = false
	await frames(60)
	var cameras: Dictionary = {}
	await scene.set_character_mode(false)
	await scene.select_spawn(0)
	await frames(40)
	scene.set_free_mode(true)
	cameras.gallery = scene.camera.global_transform
	await scene.set_character_mode(true)
	await scene.select_spawn(1)
	scene.set_free_mode(false)
	await frames(40)
	scene.set_free_mode(true)
	cameras.base = scene.camera.global_transform
	# Freeze simulation and shader TIME after actor/grass placement for A/B.
	Engine.time_scale = 0.0
	for view in ["gallery", "base"]:
		scene.camera.global_transform = cameras[view]
		for name in ["baseline", "ao_off", "ao_half", "ambient_050", "ambient_060", "sky_ambient", "plain_white", "road_only", "shadow_off", "warm", "neutral", "cool", "warm_wide", "final", "no_gloss"]:
			variant(name)
			await capture(view + "_" + name)
			report.variants.append(view + "_" + name)
	variant("final")
	scene.camera.position = Vector3(80, 58, 220)
	scene.camera.look_at(Vector3(45, 26, 20))
	await capture("terraces_final")
	variant("baseline")
	await capture("terraces_baseline")
	variant("final")
	scene.camera.position = Vector3(-220, 65, 190)
	scene.camera.look_at(Vector3(0, 35, 0))
	await capture("exterior_final")
	variant("no_gloss")
	await capture("exterior_no_gloss")
	variant("baseline")
	await capture("exterior_baseline")
	# White rooftop pavilion: aim at the actual specular reflection direction.
	scene.camera.position = Vector3(-97, 136, 25)
	scene.camera.look_at(Vector3(-154, 68, -20))
	variant("final")
	await capture("roof_gloss_final")
	variant("no_gloss")
	await capture("roof_gloss_off")
	scene.camera.position += Vector3(28, 0, -18)
	scene.camera.look_at(Vector3(-154, 68, -20))
	variant("final")
	await capture("roof_gloss_orbit")
	variant("final")
	scene.show_overview()
	await capture("overview_final")
	variant("baseline")
	await capture("overview_baseline")
	variant("final")
	sun.rotation_degrees = Vector3(-22, 52, 0)
	scene.rendering.sync_sun()
	await capture("overview_reverse_sun")
	scene.camera.global_transform = cameras.base
	variant("final")
	scene.camera.rotate_y(0.12)
	await capture("base_camera_orbit")
	scene.camera.global_transform = cameras.base
	# Extra directional must not add a second NPR floor; test a local lamp too.
	var extra := DirectionalLight3D.new()
	extra.rotation_degrees = Vector3(-28, 60, 0)
	extra.light_energy = 0.12
	scene.add_child(extra)
	var lamp := OmniLight3D.new()
	lamp.omni_range = 18
	lamp.light_energy = 1.0
	lamp.position = scene.anchors[1] + Vector3(0, 4, 0)
	scene.add_child(lamp)
	await capture("base_multi_light")
	extra.queue_free()
	lamp.queue_free()
	scene.camera.position = Vector3(80, 58, 220)
	scene.camera.look_at(Vector3(45, 26, 20))
	for name in ["baseline", "final", "baseline", "final"]:
		await performance(name)
	variant("final")
	report.resolution = [1920,1080]
	report.msaa = 4
	report.taa = false
	report.godot = Engine.get_version_info().string
	report.rendering_device = RenderingServer.get_rendering_device().get_device_name()
	report.camera_transforms = {"gallery": str(cameras.gallery), "base": str(cameras.base)}
	report.population = {"trees": scene.vegetation.tree_instance_count, "large": scene.vegetation.large_tree_instance_count}
	report.timing_scope = "1200 uncapped post-draw intervals after 120 warm frames; fixed terraces camera, frozen simulation/TIME, alternating runs; includes CPU/GPU/display scheduling, not isolated GPU shader cost or gameplay benchmark. GPU/CPU viewport counters averaged over all samples."
	var file := FileAccess.open("res://docs/CLIFF_B_RENDERING_REPORT.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("RENDER_VERIFICATION ", JSON.stringify(report))
	quit(0 if report.failures.is_empty() else 1)
