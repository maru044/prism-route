extends SceneTree
## Real Forward+ captures: 3 new shapes x 3 materials, plus clear side views.

func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(1200, 900)
	var scene: Control = load("res://scenes/product_preview.tscn").instantiate()
	root.add_child(scene)
	scene.rotating = false
	var panels: Array[Image] = []
	var failed := false
	for material in 3:
		for shape in range(1, 4):
			scene.select_product(shape)
			scene.select_material(material)
			scene.product.rotation.y = 0.25
			await _settle()
			var image: Image = scene.viewport.get_texture().get_image()
			var slug: String = scene.PRODUCT_SLUGS[shape]
			var path := "res://screenshots/product_%s_material_%d.png" % [slug, material]
			failed = image.save_png(ProjectSettings.globalize_path(path)) != OK or failed
			print("Captured ", path)
			var edge := image.get_height()
			image = image.get_region(Rect2i((image.get_width() - edge) / 2, 0, edge, edge))
			image.resize(480, 480, Image.INTERPOLATE_LANCZOS)
			panels.append(image)
			if material == 0:
				scene.product.rotation.y = 1.57
				await _settle()
				var side: Image = scene.viewport.get_texture().get_image()
				failed = side.save_png(ProjectSettings.globalize_path("res://screenshots/product_%s_side.png" % slug)) != OK or failed
	# Exercise returning from an opaque preset to the accepted classic material.
	scene.select_product(0)
	scene.select_material(0)
	await _settle()
	var regression: Image = scene.viewport.get_texture().get_image()
	failed = regression.save_png(ProjectSettings.globalize_path("res://screenshots/product_classic_regression.png")) != OK or failed
	# Arrange actual render textures in a labeled 3 x 3 comparison, using Godot UI.
	var names: Array = scene.PRODUCT_NAMES.duplicate()
	root.remove_child(scene)
	scene.queue_free()
	var comparison := SubViewport.new()
	comparison.size = Vector2i(1500, 1040)
	comparison.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(comparison)
	var background := ColorRect.new()
	background.color = Color("e9ebee")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	comparison.add_child(background)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.position = Vector2(18, 18)
	comparison.add_child(grid)
	for i in panels.size():
		var panel := VBoxContainer.new()
		grid.add_child(panel)
		var title := Label.new()
		title.text = "%s / %s" % [names[1 + i % 3], ["Clear gel", "Silicone", "Steel"][i / 3]]
		title.add_theme_color_override("font_color", Color("293745"))
		title.add_theme_font_size_override("font_size", 18)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(title)
		var texture := TextureRect.new()
		texture.texture = ImageTexture.create_from_image(panels[i])
		texture.custom_minimum_size = Vector2(480, 300)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		panel.add_child(texture)
	await _settle()
	var matrix: Image = comparison.get_texture().get_image()
	failed = matrix.save_png(ProjectSettings.globalize_path("res://screenshots/product_variants_comparison.png")) != OK or failed
	quit(1 if failed else 0)


func _settle() -> void:
	for frame in 24:
		await process_frame
	await RenderingServer.frame_post_draw
