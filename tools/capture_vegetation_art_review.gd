extends SceneTree
## Fixed observation sites and matched lighting/population for A/B screenshots.

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var scene: Node3D = load("res://scenes/vegetation_art_review.tscn").instantiate()
	root.add_child(scene)
	while not scene.review_ready:
		await process_frame
	# Preserve this tool's historical baseline meaning after filtering became default.
	scene.set_filtered_version(false)
	var failed := false
	var measurements: Array[Dictionary] = []
	for material in scene.vegetation.painted_lod_materials:
		material.set_shader_parameter("wind_strength", 0.0)
	for index in 4:
		scene.select_view(index)
		# Wait until this location's visible grass has streamed in; both variants
		# then share the same meshes and frame content, including the grass.
		await create_timer(1.0).timeout
		while scene.vegetation.get_pending_visible_grass_chunk_count() > 0:
			await process_frame
		for painted in [false, true]:
			if painted and not scene.vegetation.has_painted_lod_assets():
				continue
			scene.set_painted_version(painted)
			for frame in 36:
				await process_frame
			await RenderingServer.frame_post_draw
			var image: Image = root.get_texture().get_image()
			var name := "vegetation_art_site_%d_%s.png" % [index + 1, "painted" if painted else "baseline"]
			failed = image.save_png(ProjectSettings.globalize_path("res://screenshots/" + name)) != OK or failed
			var measurement := {"site": index + 1, "painted": painted,
				"camera": str(scene.review_camera.global_position),
				"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
				"fps": Engine.get_frames_per_second()}
			measurements.append(measurement)
			print("ART_REVIEW_CAPTURE ", name, " ", measurement)
	var report := FileAccess.open("res://screenshots/vegetation_art_metrics.json", FileAccess.WRITE)
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
