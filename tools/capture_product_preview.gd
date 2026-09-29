extends SceneTree
## Capture the real Forward+ SubViewport, not an editor thumbnail.


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1200, 900)
	var scene: Control = load("res://scenes/product_preview.tscn").instantiate() as Control
	root.add_child(scene)
	scene.rotating = false
	var failed := false
	for view in [
		{"angle": 0.25, "name": "product_preview_classic_drop.png"},
		{"angle": 1.15, "name": "product_preview_classic_drop_side.png"},
	]:
		scene.product.rotation.y = view.angle
		for frame in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = scene.viewport.get_texture().get_image()
		var path: String = ProjectSettings.globalize_path("res://screenshots/" + view.name)
		var result := image.save_png(path)
		print("product_preview_capture=", result, " size=", image.get_size(), " path=", path)
		failed = failed or result != OK
	scene.product.rotation.y = 0.25
	await create_timer(8.0).timeout
	for frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var motion_image: Image = scene.viewport.get_texture().get_image()
	var motion_path := ProjectSettings.globalize_path("res://screenshots/product_preview_classic_drop_motion.png")
	var motion_result := motion_image.save_png(motion_path)
	print("product_preview_motion_capture=", motion_result, " path=", motion_path)
	failed = failed or motion_result != OK
	quit(1 if failed else 0)
