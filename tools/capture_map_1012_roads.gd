extends SceneTree
## Inspect the road surface from low, reversed and elevated camera positions.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var scene = load("res://scenes/map_1012_drive_test.tscn").instantiate()
	scene.automation_enabled = true
	scene.get_node("CamperVan").automation_enabled = true
	root.add_child(scene)
	while not scene.test_ready:
		await process_frame
	for frame in 60:
		await physics_frame
	scene.set_free_mode(true)
	var p: Vector3 = scene.anchors[0]
	var d := Vector3(scene.metadata.road_direction[0], 0, scene.metadata.road_direction[2])
	var side := d.cross(Vector3.UP)
	var views := [
		[p - d * 18 + side * 12 + Vector3.UP * 8, p + d * 60],
		[p + d * 18 - side * 12 + Vector3.UP * 8, p - d * 60],
		[p - d * 35 + side * 20 + Vector3.UP * 35, p + d * 100]]
	DirAccess.make_dir_recursive_absolute("res://.map_1012_build/captures")
	for index in views.size():
		scene.camera.position = views[index][0]
		scene.camera.look_at(views[index][1])
		await create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png("res://.map_1012_build/captures/road_%d.png" % index)
		if error != OK:
			quit(1)
			return
		print("MAP_1012_ROAD_VIEW ", index)
	scene.free()
	quit()
