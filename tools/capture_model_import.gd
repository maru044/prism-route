extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1440, 1000)
	var scene = load("res://scenes/character_model_import_test.tscn").instantiate()
	root.add_child(scene)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var title := Label.new()
	title.position = Vector2(580, 100)
	title.add_theme_font_size_override("font_size", 26)
	layer.add_child(title)
	var tiles: Array[Image] = []
	var samples := [{"variant": 1, "id": "A05"}, {"variant": 0, "id": "A05"}]
	for id in ["A01", "A06", "A16", "A22", "A30", "A32", "A33", "A35", "A41", "A42"]:
		samples.append({"variant": 0, "id": id})
	for sample in samples:
		scene._switch_variant(sample.variant)
		for i in scene.catalog.size():
			if scene.catalog[i].id == sample.id: scene._select(i)
		scene.yaw = 1.0 if sample.id in ["A30", "A32", "A33"] else (0.6 if sample.id == "A05" else 0.22)
		scene.camera_target = Vector3(0, 0.42 if sample.id in ["A30", "A32", "A33"] else 0.8, 0)
		scene.distance = 3.2
		scene._update_camera()
		scene.player.pause()
		scene.player.seek(scene.catalog[scene.selected].duration * 0.35, true)
		scene.skeleton.force_update_all_bone_transforms()
		scene._center_character()
		title.text = "%s · %s" % [sample.id, "处理前" if sample.variant == 1 else "处理后"]
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		picture.save_png(ProjectSettings.globalize_path("res://.model_import_build/keqing_%s_%s.png" % [sample.id, sample.variant]))
		var tile := picture.get_region(Rect2i(390, 0, 1050, 1000))
		tile.resize(525, 500, Image.INTERPOLATE_LANCZOS)
		tiles.append(tile)
	var contact := Image.create(2100, 1500, false, Image.FORMAT_RGB8)
	for i in tiles.size(): contact.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, tiles[i].get_size()), Vector2i((i % 4) * 525, (i / 4) * 500))
	contact.save_png(ProjectSettings.globalize_path("res://.model_import_build/keqing_contact_sheet.png"))
	print("MODEL_IMPORT_CAPTURE complete")
	quit()
