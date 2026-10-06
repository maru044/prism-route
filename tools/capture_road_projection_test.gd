extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var scene = load("res://scenes/road_projection_test.tscn").instantiate()
	root.add_child(scene)
	while not scene.test_ready:
		await process_frame
	DirAccess.make_dir_recursive_absolute("res://.road_projection_build/captures")
	for view in range(4):
		scene.select_view(view)
		for mode in range(4):
			scene.height_tolerance = 2.0 if mode == 3 else 4.0
			scene.set_mode(mode)
			await _settle()
			var path := "res://.road_projection_build/captures/view_%d_mode_%d.png" % [view, mode]
			var result := root.get_texture().get_image().save_png(path)
			assert(result == OK, "Capture failed")
			print("ROAD_CAPTURE ", path)
	# Strict protection deliberately rejects the current elevated road patch.
	scene.select_view(3)
	scene.height_tolerance = 2.0
	scene.set_mode(0)
	await _settle()
	root.get_texture().get_image().save_png("res://.road_projection_build/captures/view_3_tolerance_2.png")
	quit()

func _settle() -> void:
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
