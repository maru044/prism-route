extends SceneTree
## Four fixed observation sites for the accepted foliage baseline.

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scene: Node3D = load("res://scenes/vegetation_art_review.tscn").instantiate()
	root.add_child(scene)
	while not scene.review_ready:
		await process_frame
	var failed := false
	var measurements: Array[Dictionary] = []
	for nodes in [scene.vegetation.tree_lod0_nodes, scene.vegetation.tree_lod1_nodes, scene.vegetation.tree_lod2_nodes]:
		for node in nodes:
			if node.material_override is ShaderMaterial:
				node.material_override.set_shader_parameter("wind_strength", 0.0)
	scene.vegetation.grass_material.set_shader_parameter("wind_strength", 0.0)
	scene.vegetation.grass_material.set_shader_parameter("wind_tone_strength", 0.0)
	for index in 4:
		scene.select_view(index)
		# Wait until this location's visible grass has streamed in.
		await create_timer(1.0).timeout
		while scene.vegetation.get_pending_visible_grass_chunk_count() > 0:
			await process_frame
		for frame in 36:
			await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var name := "vegetation_art_site_%d_accepted.png" % [index + 1]
		failed = image.save_png(ProjectSettings.globalize_path("res://screenshots/" + name)) != OK or failed
		var measurement := {"site": index + 1, "baseline": "smooth_small_tree_2026-10-01",
			"camera": str(scene.review_camera.global_position),
			"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"fps": Engine.get_frames_per_second()}
		measurements.append(measurement)
		print("ART_REVIEW_CAPTURE ", name, " ", measurement)
	var report := FileAccess.open("res://screenshots/vegetation_art_accepted_metrics.json", FileAccess.WRITE)
	if report == null:
		quit(1)
		return
	report.store_string(JSON.stringify(measurements, "\t"))
	# Save exact review trees for reproducible cluster HLOD bakes.
	var records: Array[Dictionary] = []
	for record in scene.vegetation.review_tree_records:
		var transform: Transform3D = record.transform
		records.append({"position": [transform.origin.x, transform.origin.y, transform.origin.z],
			"yaw": transform.basis.get_euler().y, "scale": transform.basis.get_scale().x,
			"model": record.model, "palette": record.palette})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.vegetation_art_build"))
	var manifest := FileAccess.open("res://.vegetation_art_build/world_tree_records.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"trees": records, "sites": scene.review_sites.map(func(p): return [p.x, p.y, p.z])}))
	quit(1 if failed else 0)
