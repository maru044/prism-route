extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var scene = load("res://scenes/vegetation_art_review.tscn").instantiate()
	root.add_child(scene)
	while not scene.review_ready:
		await process_frame
	for nodes in [scene.vegetation.tree_lod0_nodes, scene.vegetation.tree_lod1_nodes, scene.vegetation.tree_lod2_nodes]:
		for node in nodes:
			if node.material_override is ShaderMaterial:
				node.material_override.set_shader_parameter("wind_strength", 0.0)
	scene.vegetation.grass_material.set_shader_parameter("wind_strength", 0.0)
	scene.vegetation.grass_material.set_shader_parameter("wind_tone_strength", 0.0)
	var comparison := Image.create(1920, 2160, false, Image.FORMAT_RGB8)
	var measurements: Array[Dictionary] = []
	var out := "res://.vegetation_art_build/simplification/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for index in 4:
		scene.select_view(index)
		await create_timer(1.0).timeout
		while scene.vegetation.get_pending_visible_grass_chunk_count() > 0:
			await process_frame
		for filtered in [false, true]:
			scene.set_filtered_version(filtered)
			for frame in 36:
				await process_frame
			var sample_start := Time.get_ticks_usec()
			for frame in 60:
				await process_frame
			var milliseconds := float(Time.get_ticks_usec() - sample_start) / 60000.0
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var name := "world_%d_%s.png" % [index + 1, "filtered" if filtered else "original"]
			if image.save_png(out + name) != OK:
				quit(1)
				return
			image.resize(960, 540, Image.INTERPOLATE_LANCZOS)
			image.convert(Image.FORMAT_RGB8)
			comparison.blit_rect(image, Rect2i(0, 0, 960, 540), Vector2i(960 if filtered else 0, index * 540))
			measurements.append({"site": index+1, "filtered": filtered,
				"average_frame_ms_60": milliseconds,
				"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
			print("SMALL_TREE_WORLD ", name)
	if comparison.save_png("res://screenshots/foliage_filtering_world_comparison.png") != OK:
		quit(1)
		return
	var report := FileAccess.open(out + "world_metrics.json", FileAccess.WRITE)
	if report == null:
		quit(1)
		return
	report.store_string(JSON.stringify(measurements, "\t"))
	var saved_report := FileAccess.open("res://screenshots/foliage_filtering_world_metrics.json", FileAccess.WRITE)
	if saved_report == null:
		quit(1)
		return
	saved_report.store_string(JSON.stringify(measurements, "\t"))
	quit()
