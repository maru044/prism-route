extends SceneTree
## Render art views and compare actual HDR radiance before/after the sky change.

var output := "res://.model_import_build/sky_art_review/"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=").trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1920, 1080)
	var scene = load("res://scenes/vegetation_grove_test.tscn").instantiate()
	root.add_child(scene)
	var camera: Camera3D = scene.get_node("OrbitCamera")
	camera.set_process(false)
	scene.get_node("Instructions").hide()
	await create_timer(2.0).timeout
	_freeze(scene)
	var environment: Environment = scene.get_node("RosendalParkEnvironment").environment
	var fresh: Sky = environment.sky
	var original := Sky.new()
	original.process_mode = fresh.process_mode
	original.radiance_size = fresh.radiance_size
	var original_material := PanoramaSkyMaterial.new()
	original_material.panorama = scene.SKY_TEXTURE
	original_material.energy_multiplier = 0.48
	original.sky_material = original_material
	var maps: Array[Image] = []
	var views := [
		{"name": "01_character", "position": Vector3(4, 2.7, 8.4), "target": Vector3(4, 1, 2.4)},
		{"name": "02_grove_wide", "position": Vector3(0, 6, 43), "target": Vector3(0, 7, 1)},
		{"name": "03_ground_canopy", "position": Vector3(-18, 2.6, 19), "target": Vector3(-2, 3.5, -5)},
		{"name": "04_sky_open", "position": Vector3(0, 22, 38), "target": Vector3(0, 28, 0)}]
	for variant in ["before", "fresh"]:
		environment.sky = original if variant == "before" else fresh
		for frame in 30: await process_frame
		await RenderingServer.frame_post_draw
		for irradiance in [false, true]:
			var size := Vector2i(128, 64) if irradiance else Vector2i(512, 256)
			var image := RenderingServer.environment_bake_panorama(environment.get_rid(), irradiance, size)
			if image == null or image.is_empty():
				failures.append("Missing baked lighting: " + variant)
				quit(1)
				return
			maps.append(image)
		for view in views:
			camera.position = view.position
			camera.look_at(view.target, Vector3.UP)
			await _capture(variant + "_" + view.name)
	var lighting_checks: Array = []
	for i in 2:
		var a: Image = maps[i]
		var b: Image = maps[i + 2]
		var max_error := 0.0
		var total_error := 0.0
		for y in a.get_height():
			for x in a.get_width():
				var ca := a.get_pixel(x, y)
				var cb := b.get_pixel(x, y)
				var error := maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b)))
				max_error = maxf(max_error, error)
				total_error += error
		lighting_checks.append({"map": "radiance" if i == 0 else "irradiance",
			"max_linear_rgb_difference": max_error,
			"mean_max_channel_difference": total_error / (a.get_width() * a.get_height())})
		if max_error > 0.001: failures.append("Lighting changed: " + str(lighting_checks[-1]))
	# Sky-only views expose every longitude, the wrap, and both poles.
	camera.position = Vector3(0, 40, 0)
	for angle in range(0, 360, 45):
		var radians := deg_to_rad(float(angle))
		camera.look_at(camera.position + Vector3(sin(radians), 0.12, -cos(radians)), Vector3.UP)
		await _capture("sky_%03d" % angle)
	camera.look_at(camera.position + Vector3.UP, Vector3.FORWARD)
	await _capture("sky_zenith")
	camera.look_at(camera.position + Vector3.DOWN, Vector3.FORWARD)
	await _capture("sky_nadir")
	var report := {"godot": Engine.get_version_info().string, "lighting_checks": lighting_checks,
		"views": views.size(), "sky_longitude_views": 8, "sky_pole_views": 2,
		"display_texture_size": fresh.sky_material.get_shader_parameter("display_panorama").get_size(),
		"failures": failures}
	FileAccess.open(output + "validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("FRESH_SKY_RESULT ", JSON.stringify(report))
	scene.free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _freeze(node: Node) -> void:
	if node is AnimationPlayer:
		node.pause()
	if node is MeshInstance3D:
		var materials: Array[Material] = [node.material_override]
		for surface in node.mesh.get_surface_count() if node.mesh else 0:
			materials.append(node.get_active_material(surface))
		for material in materials:
			if material is ShaderMaterial:
				material.set_shader_parameter("wind_strength", 0.0)
				material.set_shader_parameter("wind_tone_strength", 0.0)
	if node is MultiMeshInstance3D and node.material_override is ShaderMaterial:
		node.material_override.set_shader_parameter("wind_strength", 0.0)
		node.material_override.set_shader_parameter("wind_tone_strength", 0.0)
	for child in node.get_children(): _freeze(child)

func _capture(filename: String) -> void:
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	var status := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output + filename + ".png"))
	if status != OK: failures.append("Capture failed: " + filename)
	print("FRESH_SKY_CAPTURE ", filename)
