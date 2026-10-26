extends SceneTree
## C1 visual evidence and behavioral checks; keep the C0 reports intact.
const OUT := "res://docs/character_shader_c1/"
const APPEARANCE = preload("res://scripts/characters/character_appearance.gd")
var lab
var failures: Array[String] = []
var report := {}
var caption: Label
var caption_layer: CanvasLayer
var render := false

func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func shot(name_value: String) -> Image:
	await frames(8)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(image.save_png(OUT + name_value + ".png") == OK, "Capture failed: " + name_value)
	return image

func logic() -> void:
	check(lab.appearance.entries.size() == 19, "C1 lost surfaces")
	check(lab.appearance.profile.face_sdf != null, "No UV matched face map")
	check(lab.appearance.profile.body_material_mask != null, "No body material mask")
	check(root.msaa_3d == Viewport.MSAA_4X, "Wrong AA baseline")
	lab.mode_buttons[3].pressed.emit()
	check(lab.appearance.mode == "genshin", "C1 button does not activate C1")
	var other: Node3D = load("res://scenes/characters/ganyu.tscn").instantiate()
	root.add_child(other)
	other.hide()
	var appearance = APPEARANCE.new()
	root.add_child(appearance)
	appearance.bind(other)
	appearance.set_mode("genshin")
	var face_entry: Dictionary = lab.appearance.entries[0]
	var other_face: Dictionary = appearance.entries[0]
	var before: Vector3 = face_entry.cache.genshin.get_shader_parameter("head_forward")
	var isolated: Vector3 = other_face.cache.genshin.get_shader_parameter("head_forward")
	lab.character.rotation.y = 0.8
	lab.appearance.update_head()
	var after: Vector3 = face_entry.cache.genshin.get_shader_parameter("head_forward")
	check(before.distance_to(after) > 0.4, "Head axes do not follow actor rotation")
	check(isolated.is_equal_approx(other_face.cache.genshin.get_shader_parameter("head_forward")), "Other actor head axes contaminated")
	lab.character.rotation.y = 0
	lab.appearance.update_head()
	check(is_equal_approx(face_entry.cache.genshin.get_shader_parameter("head_up").length(), 1.0), "Degenerate head frame")
	var outlines := 0
	for entry in lab.appearance.entries:
		check(entry.cache.genshin != appearance.entries[entry.index].cache.genshin, "C1 material instance shared")
		check(entry.source.next_pass == null, "Original next_pass was mutated")
		check(entry.cache.custom.next_pass == null, "C0 contaminated by C1 outline")
		if entry.has("outline"): outlines += 1
	lab.appearance.profile.outline_enabled = false
	lab.appearance.update_parameters()
	for entry in lab.appearance.entries: check(entry.cache.genshin.next_pass == null, "Outline switch did not detach pass")
	check(not lab.appearance.outline_shell.visible, "Outline shell did not hide")
	lab.appearance.profile.outline_enabled = true
	lab.appearance.update_parameters()
	check(lab.appearance.outline_shell.mesh.get_blend_shape_count() == 60, "Outline lost morph targets")
	check(lab.appearance.outline_shell.skin == lab.appearance.outlined_source.skin, "Outline uses a different skin")
	lab.appearance.outlined_source.set_blend_shape_value(0, 0.4)
	lab.appearance._process(0)
	check(is_equal_approx(lab.appearance.outline_shell.get_blend_shape_value(0), 0.4), "Outline did not follow expression weights")
	lab.appearance.outlined_source.set_blend_shape_value(0, 0)
	lab.appearance._process(0)
	for id in ["A01", "A05", "A06", "A25"]:
		lab.set_animation(id, 0.4)
		var time_before: float = lab.player.current_animation_position
		for mode in ["standard", "mtoon", "custom", "genshin"]:
			lab.set_mode(mode)
			check(is_equal_approx(time_before, lab.player.current_animation_position), "C1 switch changed animation time")
	lab.appearance.profile.sdf_enabled = false
	lab.appearance.update_parameters()
	check(not face_entry.cache.genshin.get_shader_parameter("sdf_enabled"), "SDF disable did not reach face")
	lab.appearance.profile.sdf_enabled = true
	lab.appearance.update_parameters()
	lab.set_mode("standard")
	for entry in lab.appearance.entries: check(entry.mesh.get_active_material(entry.index) == entry.source, "A material restoration failed")
	appearance.queue_free()
	other.queue_free()
	await frames(2)
	report.logic = {"surfaces": 19, "outline_surfaces": outlines, "head_frame_follows_actor": true,
		"instance_isolation": true, "sdf_fallback_switch": true, "original_and_c0_unchanged": true}

func captures() -> void:
	lab.set_animation("A01", 0.6)
	lab.playing = false
	lab.set_mode("genshin")
	await shot("lab_ui")
	lab.ui.hide()
	lab.set_view(2)
	lab.target = Vector3(0, 1.40, 0.02)
	lab.distance = 0.70
	lab.camera.fov = 32.0
	lab._update_camera()
	lab.set_lighting(true)
	caption_layer = CanvasLayer.new()
	root.add_child(caption_layer)
	caption = Label.new()
	caption.position = Vector2(24, 20)
	caption.add_theme_font_size_override("font_size", 28)
	caption.add_theme_color_override("font_outline_color", Color("15232c"))
	caption.add_theme_constant_override("outline_size", 6)
	caption_layer.add_child(caption)
	var modes := ["mtoon", "custom", "genshin"]
	var sheet := Image.create(1920, 1440, false, Image.FORMAT_RGB8)
	for row in 4:
		var azimuth: float = [0, 60, 100, 180][row]
		lab.sun.rotation_degrees = Vector3(-25, azimuth, 0)
		for column in 3:
			lab.set_mode(modes[column])
			caption.text = "%s / %s" % [["正光", "60°侧光", "100°侧逆光", "背光"][row], ["B · MToon", "C0 · 基础 Toon", "C1 · 原神式 NPR"][column]]
			var image: Image = await shot("face_%d_%s" % [int(azimuth), modes[column]])
			image.resize(640, 360, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(image, Rect2i(0, 0, 640, 360), Vector2i(column * 640, row * 360))
	check(sheet.save_png(OUT + "face_comparison.png") == OK, "Comparison save failed")
	lab.set_mode("genshin")
	lab.sun.rotation_degrees = Vector3(-25, 75, 0)
	caption.text = "C1 · SDF 开启"
	var sdf_on: Image = await shot("sdf_on")
	lab.appearance.profile.sdf_enabled = false
	lab.appearance.update_parameters()
	caption.text = "C1 · SDF 关闭 / 几何法线对照"
	var sdf_off: Image = await shot("sdf_off")
	report.sdf_changed_pixels = changed_pixels(sdf_on, sdf_off, Rect2i(760, 590, 450, 320))
	check(report.sdf_changed_pixels > 300, "SDF has no visible effect")
	lab.appearance.profile.sdf_enabled = true
	lab.appearance.update_parameters()
	# Identical roof geometry/SSAO, only directional shadow switch changes.
	caption.hide()
	lab.occluder.show()
	lab.sun.shadow_enabled = false
	var lit: Image = await shot("world_shadow_off")
	lab.sun.shadow_enabled = true
	var dark: Image = await shot("world_shadow_on")
	report.shadow_changed_pixels = changed_pixels(lit, dark, Rect2i(750, 280, 450, 380))
	check(report.shadow_changed_pixels > 300, "C1 ignores scene shadow")
	lab.occluder.hide()
	# Self rotation and head pitch/roll must remain finite, with independent frames.
	report.rotations = []
	for degrees in range(0, 361, 30):
		lab.character.rotation.y = deg_to_rad(degrees)
		lab.appearance.update_head()
		var forward: Vector3 = lab.appearance.entries[0].cache.genshin.get_shader_parameter("head_forward")
		check(forward.is_finite(), "Nonfinite head direction during rotation")
		report.rotations.append({"degrees": degrees, "forward": str(forward)})
		await frames(2)
	lab.character.rotation.y = 0
	lab.appearance.update_head()
	var head: int = lab.skeleton.find_bone("Head")
	var original_head: Quaternion = lab.skeleton.get_bone_pose_rotation(head)
	lab.skeleton.set_bone_pose_rotation(head, original_head * Quaternion.from_euler(Vector3(0.25, 0.0, 0.18)))
	lab.skeleton.force_update_all_bone_transforms()
	lab.appearance.update_head()
	check(lab.appearance.entries[0].cache.genshin.get_shader_parameter("head_forward").is_finite(), "Head pitch/roll produced invalid axes")
	await shot("head_pitch_roll")
	lab.skeleton.set_bone_pose_rotation(head, original_head)
	lab.skeleton.force_update_all_bone_transforms()
	lab.appearance.update_head()
	for elevation in [-90, 90]:
		lab.sun.rotation_degrees = Vector3(elevation, 0, 0)
		await shot("vertical_light_" + str(elevation))
	lab.sun.rotation_degrees = Vector3(-35, 40, 0)
	lab.camera.fov = 38.0
	lab.set_view(0)
	lab.appearance.profile.outline_enabled = true
	lab.appearance.update_parameters()
	var with_outline: Image = await shot("outline_on")
	lab.appearance.profile.outline_enabled = false
	lab.appearance.update_parameters()
	var without_outline: Image = await shot("outline_off")
	report.outline_changed_pixels = changed_pixels(with_outline, without_outline, Rect2i(600, 60, 700, 980))
	check(report.outline_changed_pixels > 100, "Outline has no visible effect")
	lab.appearance.profile.outline_enabled = true
	lab.appearance.update_parameters()
	lab.set_animation("A06", 0.35)
	lab.set_springs(true)
	await frames(45)
	await shot("run_springs")
	lab.set_springs(false)
	root.msaa_3d = Viewport.MSAA_2X
	await shot("run_2x_msaa")
	root.msaa_3d = Viewport.MSAA_4X
	caption_layer.queue_free()

func performance_samples() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	lab.set_springs(false)
	lab.set_animation("A01", 0.6)
	lab.camera.fov = 38
	lab.target = Vector3(0, 0.7, -1.2)
	lab.distance = 9.0
	lab._update_camera()
	lab.character.position = Vector3(-2.0, 0, 0)
	var copies: Array[Node3D] = []
	var appearances: Array = [lab.appearance]
	report.performance = []
	for count in [1, 5, 20]:
		while copies.size() < count - 1:
			var character: Node3D = load("res://scenes/characters/ganyu.tscn").instantiate()
			root.add_child(character)
			var animator: AnimationPlayer = character.find_child("AnimationPlayer", true, false)
			animator.stop()
			var bones: Skeleton3D = character.find_child("GeneralSkeleton", true, false)
			bones.reset_bone_poses()
			var springs = character.find_child("VRMSpringBoneController", true, false)
			if springs: springs.process_mode = Node.PROCESS_MODE_DISABLED
			var simulation = bones.get_node_or_null("VRMSpringBoneSimulation")
			if simulation: simulation.active = false
			var appearance = APPEARANCE.new()
			root.add_child(appearance)
			appearance.bind(character)
			appearances.append(appearance)
			copies.append(character)
		for i in copies.size(): copies[i].position = Vector3(((i + 1) % 5 - 2) * 0.9, 0, -(i + 1) / 5 * 1.3)
		for mode in ["mtoon", "custom", "genshin"]:
			for appearance in appearances: appearance.set_mode(mode)
			await frames(90)
			var gpu := PackedFloat64Array()
			var wall := PackedFloat64Array()
			var previous := Time.get_ticks_usec()
			for i in 120:
				await process_frame
				var now := Time.get_ticks_usec()
				wall.append((now - previous) / 1000.0)
				previous = now
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			gpu.sort()
			wall.sort()
			report.performance.append({"actors": count, "mode": mode, "gpu_median_ms": gpu[60], "gpu_p95_ms": gpu[113], "wall_median_ms": wall[60],
				"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "render_memory_mib": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0})
	for appearance in appearances.slice(1): appearance.queue_free()
	for character in copies: character.queue_free()
	await frames(2)
	report.performance_method = "1920x1080, Forward+/D3D12, 4x MSAA; uncapped, VSync off, 90 warmup +120 frames; static poses, no spring simulation. Same current process/camera per mode. C1 includes outline shell; mesh shared across actors; memory is process-level, not attributed to a mode."

func changed_pixels(a: Image, b: Image, rect: Rect2i) -> int:
	var count := 0
	for y in range(rect.position.y, rect.end.y, 2):
		for x in range(rect.position.x, rect.end.x, 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))) > 0.015: count += 1
	return count

func run() -> void:
	render = "--render" in OS.get_cmdline_user_args()
	root.size = Vector2i(1920, 1080)
	Engine.max_fps = 60
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	lab = load("res://scenes/character_shader_lab.tscn").instantiate()
	root.add_child(lab)
	await frames(4)
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
	print("CHARACTER_C1_VERIFY ", JSON.stringify(report))
	lab.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
