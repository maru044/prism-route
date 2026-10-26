extends SceneTree
## Integration checks, matched rendered evidence, and warmed uncapped GPU timings.
const APPEARANCE = preload("res://scripts/characters/character_appearance.gd")
const AUDIT = preload("res://tools/audit_character_materials.gd")
const OUT := "res://docs/character_shader_lab/"
var failures: Array[String] = []
var report: Dictionary = {}
var lab
var render := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in count: await process_frame

func picture() -> Image:
	await frames(8)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func save_picture(name_value: String) -> Image:
	var image: Image = await picture()
	check(image.save_png(OUT + name_value + ".png") == OK, "Capture failed: " + name_value)
	return image

func logic() -> void:
	check(lab.appearance.entries.size() == 19, "Not all 19 surfaces mapped")
	check(lab.appearance.warnings.is_empty(), "Unexpected mapping warning")
	check(root.msaa_3d == Viewport.MSAA_4X, "Baseline must be 4x MSAA")
	var original_materials: Array = []
	var blend_count := 0
	for entry in lab.appearance.entries:
		original_materials.append(entry.source)
		blend_count += entry.mesh.mesh.get_blend_shape_count()
		check(entry.mesh.material_override == null, "Whole mesh override introduced")
		for key in ["mtoon", "custom"]:
			var material: ShaderMaterial = entry.cache[key]
			check(material.shader != null, "Missing shader")
			check(material.get_shader_parameter("_MainTex" if key == "mtoon" else "base_texture") == entry.source.albedo_texture, "Base texture lost")
	var other: Node3D = load("res://scenes/characters/ganyu.tscn").instantiate()
	root.add_child(other)
	other.hide()
	var alternate = APPEARANCE.new()
	root.add_child(alternate)
	alternate.bind(other)
	alternate.set_mode("custom")
	check(alternate.profile != lab.appearance.profile, "Profile shared between characters")
	for i in 19:
		check(alternate.entries[i].cache.custom != lab.appearance.entries[i].cache.custom, "ShaderMaterial shared between characters")
	for mode in ["mtoon", "custom", "standard", "custom", "standard"]:
		lab.set_mode(mode)
		for entry in lab.appearance.entries:
			check(entry.mesh.get_active_material(entry.index) == (entry.source if mode == "standard" else entry.cache[mode]), "Mode switch did not reach a surface")
	check(not lab.appearance.set_mode("invalid"), "Invalid mode accepted")
	lab.mode_buttons[1].pressed.emit()
	check(lab.appearance.mode == "mtoon", "MToon button callback failed")
	lab.mode_buttons[2].pressed.emit()
	check(lab.appearance.mode == "custom", "Custom button callback failed")
	lab.pause_button.pressed.emit()
	check(lab.playing, "Play button callback failed")
	lab.pause_button.pressed.emit()
	check(not lab.playing, "Pause button callback failed")
	for id in ["A01", "A05", "A06", "A25"]:
		lab.set_animation(id, 0.35)
		for bone in lab.skeleton.get_bone_count(): check(lab.skeleton.get_bone_global_pose(bone).origin.is_finite(), "Invalid animation transform")
	var phase: float = lab.player.current_animation_position
	lab.set_mode("custom")
	check(is_equal_approx(lab.player.current_animation_position, phase), "Material switch reset animation")
	lab.appearance.profile.hair_highlight = 0.0
	lab.appearance.update_parameters()
	check(is_equal_approx(alternate.profile.hair_highlight, 0.12), "Changing one profile contaminated the other actor")
	for entry in lab.appearance.entries:
		check(is_zero_approx(entry.cache.custom.get_shader_parameter("hair_highlight")), "Hair toggle not applied")
	lab.appearance.profile.hair_highlight = 0.12
	lab.appearance.update_parameters()
	lab.timeline.value = 0.2
	check(is_equal_approx(lab.player.current_animation_position, 0.2), "Timeline seek callback failed")
	# A missing mapping must leave original resources alone, with a visible warning.
	var empty_profile: Resource = alternate.profile.duplicate(true)
	empty_profile.regions = {}
	alternate.bind(other, empty_profile)
	alternate.set_mode("custom")
	check(alternate.entries.is_empty() and alternate.warnings.size() == 19, "Unknown surfaces were silently converted")
	alternate.queue_free()
	other.queue_free()
	await frames(2)
	lab.set_mode("standard")
	for i in 19: check(lab.appearance.entries[i].source == original_materials[i], "Original material reference replaced")
	report.logic = {"mapped_surfaces": 19, "regions": lab.appearance.profile.regions, "restores_original_references": true,
		"instance_isolation": true, "unknown_region_fallback": true, "source_mesh_blend_shapes": blend_count / 19,
		"motion_clips": ["A01", "A05", "A06", "A25"], "msaa": "4x"}
	var audit := AUDIT.inspect(lab.character)
	audit.source_glb = AUDIT.inspect_source()
	var file := FileAccess.open(OUT + "material_audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(audit, "\t"))
	file.close()

func captures() -> void:
	lab.set_animation("A01", 0.6)
	lab.playing = false
	lab.set_mode("custom")
	await save_picture("lab_ui")
	lab.ui.hide()
	lab.set_lighting(true)
	var caption_layer := CanvasLayer.new()
	root.add_child(caption_layer)
	var caption := Label.new()
	caption.position = Vector2(24, 20)
	caption.add_theme_font_size_override("font_size", 28)
	caption.add_theme_color_override("font_outline_color", Color("15232c"))
	caption.add_theme_constant_override("outline_size", 6)
	caption_layer.add_child(caption)
	var tiles: Array[Image] = []
	for view in [0, 2]:
		lab.set_view(view)
		for mode in ["standard", "mtoon", "custom"]:
			lab.set_mode(mode)
			caption.text = ("全身" if view == 0 else "脸部") + " / " + mode + " / 同一海岛光照"
			var shot: Image = await save_picture("island_%s_%s" % ["full" if view == 0 else "face", mode])
			shot.resize(640, 360, Image.INTERPOLATE_LANCZOS)
			tiles.append(shot)
	var sheet := Image.create(1920, 720, false, Image.FORMAT_RGB8)
	for i in tiles.size(): sheet.blit_rect(tiles[i], Rect2i(0, 0, 640, 360), Vector2i(i % 3 * 640, i / 3 * 360))
	check(sheet.save_png(OUT + "comparison.png") == OK, "Contact sheet save failed")
	var lighting_sheet := Image.create(1920, 1080, false, Image.FORMAT_RGB8)
	lab.set_view(2)
	for row in 3:
		lab.sun.rotation_degrees = Vector3(-30, [0, 90, 180][row], 0)
		for column in 3:
			var mode: String = ["standard", "mtoon", "custom"][column]
			lab.set_mode(mode)
			caption.text = "%s / %s" % [["正光", "侧光", "背光"][row], mode]
			var image: Image = await save_picture("light_%d_%s" % [row, mode])
			image.resize(640, 360, Image.INTERPOLATE_LANCZOS)
			lighting_sheet.blit_rect(image, Rect2i(0, 0, 640, 360), Vector2i(column * 640, row * 360))
	check(lighting_sheet.save_png(OUT + "lighting_comparison.png") == OK, "Lighting sheet save failed")
	lab.sun.rotation_degrees = Vector3(-48, 45, 0)
	# Shadow reception: compare an unchanged face view against a real opaque roof.
	report.shadow = {}
	lab.set_view(2)
	caption.hide()
	for mode in ["standard", "mtoon", "custom"]:
		lab.set_mode(mode)
		lab.occluder.show()
		lab.sun.shadow_enabled = false
		var lit: Image = await save_picture("shadow_lit_" + mode)
		lab.sun.shadow_enabled = true
		var shadow: Image = await save_picture("shadow_roof_" + mode)
		var lit_value := 0.0
		var dark_value := 0.0
		var samples := 0
		# Face view center, excluding the sky and roof, same pixels for all modes.
		var region := Rect2i(850, 320, 220, 200)
		for y in range(region.position.y, region.end.y, 2):
			for x in range(region.position.x, region.end.x, 2):
				lit_value += lit.get_pixel(x, y).get_luminance()
				dark_value += shadow.get_pixel(x, y).get_luminance()
				samples += 1
		var ratio := dark_value / maxf(lit_value, 0.0001)
		report.shadow[mode] = {"lit_luminance": lit_value / samples, "roof_luminance": dark_value / samples, "ratio": ratio, "roi": [850, 320, 220, 200]}
		check(ratio < 0.98, "Roof shadow has no measurable effect: " + mode)
	report.shadow_method = "Same opaque roof and SSAO/environment in both images; only directional shadow_enabled toggled. ROI is face-view center, display-referred luminance, not radiometric measurement."
	lab.occluder.hide()
	lab.set_mode("custom")
	for azimuth in [0, 90, 180, -90]:
		lab.sun.rotation_degrees = Vector3(-30, azimuth, 0)
		await save_picture("custom_sun_" + str(azimuth))
	lab.sun.rotation_degrees = Vector3(-48, 45, 0)
	lab.appearance.profile.tone_bands = 3
	lab.appearance.update_parameters()
	await save_picture("custom_three_bands")
	lab.appearance.profile.tone_bands = 2
	lab.appearance.update_parameters()
	lab.local_light.show()
	await save_picture("custom_local_light")
	lab.local_light.hide()
	lab.set_animation("A06", 0.35)
	lab.set_view(0)
	lab.set_springs(true)
	await frames(60)
	await save_picture("custom_run_springs")
	lab.set_springs(false)
	root.msaa_3d = Viewport.MSAA_2X
	await save_picture("custom_2x_msaa")
	root.msaa_3d = Viewport.MSAA_4X
	caption_layer.queue_free()

func performance_samples() -> void:
	lab.set_animation("A01", 0.6)
	lab.set_view(0)
	lab.ui.hide()
	lab._update_camera()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	report.performance = []
	var copies: Array[Node3D] = []
	var appearances: Array = [lab.appearance]
	for count in [1, 5, 20]:
		while copies.size() < count - 1:
			var duplicate: Node3D = load("res://scenes/characters/ganyu.tscn").instantiate()
			root.add_child(duplicate)
			var animator: AnimationPlayer = duplicate.find_child("AnimationPlayer", true, false)
			if animator: animator.stop()
			var bones: Skeleton3D = duplicate.find_child("GeneralSkeleton", true, false)
			bones.reset_bone_poses()
			var springs = duplicate.find_child("VRMSpringBoneController", true, false)
			if springs: springs.process_mode = Node.PROCESS_MODE_DISABLED
			var simulation = bones.get_node_or_null("VRMSpringBoneSimulation")
			if simulation: simulation.active = false
			var appearance = APPEARANCE.new()
			root.add_child(appearance)
			appearance.bind(duplicate)
			appearances.append(appearance)
			copies.append(duplicate)
		# All copies visible in a 5-column grid; matching framing across modes.
		lab.character.position = Vector3(-2.0, 0, 0)
		for i in copies.size(): copies[i].position = Vector3(((i + 1) % 5 - 2) * 0.9, 0, -(i + 1) / 5 * 1.3)
		lab.target = Vector3(0, 0.7, -1.2)
		lab.distance = 9.0
		lab._update_camera()
		for mode in ["standard", "mtoon", "custom"]:
			for appearance in appearances: appearance.set_mode(mode)
			await frames(90)
			var gpu := PackedFloat64Array()
			var wall := PackedFloat64Array()
			var last := Time.get_ticks_usec()
			for sample in 120:
				await process_frame
				var now := Time.get_ticks_usec()
				wall.append((now - last) / 1000.0)
				last = now
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			gpu.sort()
			wall.sort()
			report.performance.append({"actors": count, "mode": mode, "gpu_median_ms": gpu[60], "gpu_p95_ms": gpu[113],
				"wall_median_ms": wall[60], "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"render_memory_mib": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0})
	for appearance in appearances.slice(1): appearance.queue_free()
	for duplicate in copies: duplicate.queue_free()
	await frames(2)
	report.performance_note = "1920x1080, Forward+/D3D12, 4x MSAA; vsync/FPS cap off; 90 warmup + 120 samples; frozen poses/no springs. Draw calls include stage/shadows. All candidate materials pre-created, so memory is process-level, not per-mode attribution."

func run() -> void:
	render = "--render" in OS.get_cmdline_user_args()
	Engine.max_fps = 0
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	lab = load("res://scenes/character_shader_lab.tscn").instantiate()
	root.add_child(lab)
	await frames(4)
	check(lab.ready_for_review, "Lab failed to initialize")
	if lab.ready_for_review:
		await logic()
		if render:
			await captures()
			await performance_samples()
	report.passed = failures.is_empty()
	report.failures = failures
	report.rendered = render
	report.engine = Engine.get_version_info()
	report.adapter = RenderingServer.get_video_adapter_name()
	var file := FileAccess.open(OUT + ("render_report.json" if render else "logic_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("CHARACTER_SHADER_VERIFY ", JSON.stringify(report))
	lab.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
