extends SceneTree
## Matched A/B/C shots in the unchanged current map through the opt-in wrapper.
var output_dir := "res://docs/character_shader_lab/"
var modes := ["standard", "mtoon", "custom"]
var world
var failures: Array[String] = []
var report := {"views": [], "unchanged_formal_entry": true}

func _initialize() -> void: call_deferred("run")

func frames(n: int) -> void:
	for i in n: await process_frame

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	if "--c1" in OS.get_cmdline_user_args():
		output_dir = "res://docs/character_shader_c1/"
		modes = ["mtoon", "custom", "genshin"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	report.candidate_modes = modes
	root.size = Vector2i(1920, 1080)
	Engine.max_fps = 60
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/map_1021.tscn", "Formal entry changed")
	world = load("res://scenes/character_shader_world_lab.tscn").instantiate()
	world.automation_enabled = true
	root.add_child(world)
	var started := Time.get_ticks_msec()
	while world.appearance == null and Time.get_ticks_msec() - started < 150000: await process_frame
	check(world.appearance != null, "World wrapper startup timeout")
	if world.appearance:
		world.set_review_ui_visible(false)
		world.grass_wind.set_mode(0)
		var title_layer := CanvasLayer.new()
		root.add_child(title_layer)
		var caption := Label.new()
		caption.position = Vector2(24, 22)
		caption.add_theme_font_size_override("font_size", 28)
		caption.add_theme_color_override("font_outline_color", Color("15232c"))
		caption.add_theme_constant_override("outline_size", 6)
		title_layer.add_child(caption)
		var sheet := Image.create(1920, 1440, false, Image.FORMAT_RGB8)
		var close_sheet := Image.create(1920, 1440, false, Image.FORMAT_RGB8)
		var row := 0
		for view in [{"spawn": 4, "name": "waterfront", "label": "亲水平台"}, {"spawn": 5, "name": "grove", "label": "山坡林地"},
			{"spawn": 3, "name": "road", "label": "台地道路"}, {"spawn": 8, "name": "cave", "label": "初始洞穴"}]:
			Engine.time_scale = 1.0
			await world.select_spawn(view.spawn)
			await frames(8)
			world.set_free(true)
			world.character.player.pause()
			world.character.player.seek(0.6, true)
			world.character.visual.rotation.y = 0.0
			world.character.skeleton.force_update_all_bone_transforms()
			var position_value: Vector3 = world.character.global_position
			world.camera.fov = 55
			world.camera.position = position_value + Vector3(1.0, 1.50, 4.4)
			world.camera.look_at(position_value + Vector3(0, 0.85, 0))
			world.camera.make_current()
			var start := Time.get_ticks_msec()
			await frames(60)
			while world.vegetation.get_pending_visible_grass_chunk_count() > 0 and Time.get_ticks_msec() - start < 45000: await process_frame
			check(world.vegetation.get_pending_visible_grass_chunk_count() == 0, "Grass not settled: " + view.name)
			Engine.time_scale = 0.0
			var column := 0
			for mode in modes:
				world.appearance.set_mode(mode)
				caption.text = "%s / %s / 4.5m / 4× MSAA" % [view.label, mode]
				await frames(12)
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				check(image.save_png(output_dir + "world_%s_%s.png" % [view.name, mode]) == OK, "World capture failed")
				image.resize(640, 360, Image.INTERPOLATE_LANCZOS)
				sheet.blit_rect(image, Rect2i(0, 0, 640, 360), Vector2i(column * 640, row * 360))
				report.views.append({"case": view.name, "mode": mode, "actor_position": str(position_value), "camera": str(world.camera.global_transform),
					"grass_pending_visible": world.vegetation.get_pending_visible_grass_chunk_count(), "pose": "idle@0.6s", "time_scale": 0.0})
				column += 1
			world.camera.position = position_value + Vector3(0.20, 1.43, 1.28)
			world.camera.look_at(position_value + Vector3(0, 1.25, 0))
			column = 0
			for mode in modes:
				world.appearance.set_mode(mode)
				caption.text = "%s / %s / 近景" % [view.label, mode]
				await frames(12)
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				check(image.save_png(output_dir + "world_%s_close_%s.png" % [view.name, mode]) == OK, "World close capture failed")
				image.resize(640, 360, Image.INTERPOLATE_LANCZOS)
				close_sheet.blit_rect(image, Rect2i(0, 0, 640, 360), Vector2i(column * 640, row * 360))
				report.views.append({"case": view.name + "_close", "mode": mode, "actor_position": str(position_value),
					"camera": str(world.camera.global_transform), "pose": "idle@0.6s", "time_scale": 0.0})
				column += 1
			row += 1
		check(sheet.save_png(output_dir + "world_comparison.png") == OK, "World sheet save failed")
		check(close_sheet.save_png(output_dir + "world_close_comparison.png") == OK, "World close sheet save failed")
		# Close-up in the actual cave catches detached brightness and facial shading.
		world.camera.position = world.character.global_position + Vector3(0.12, 1.40, 0.86)
		world.camera.look_at(world.character.global_position + Vector3(0, 1.36, 0))
		for mode in modes:
			world.appearance.set_mode(mode)
			caption.text = "洞穴近景 / " + mode
			await frames(12)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output_dir + "world_cave_face_" + mode + ".png")
		world.appearance.set_mode("standard")
		for entry in world.appearance.entries: check(entry.mesh.get_active_material(entry.index) == entry.source, "World original restoration failed")
		check(world.water_manager != null, "Water manager lost")
		check(world.resolved_spawns.size() == 9, "Spawn count changed")
		Engine.time_scale = 1.0
		title_layer.queue_free()
	report.passed = failures.is_empty()
	report.failures = failures
	report.renderer = RenderingServer.get_video_adapter_name()
	var file := FileAccess.open(output_dir + "world_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("CHARACTER_WORLD_VERIFY ", JSON.stringify({"passed": report.passed, "failures": failures, "captures": report.views.size()}))
	world.queue_free()
	await frames(5)
	quit(0 if failures.is_empty() else 1)
