extends SceneTree

func _initialize() -> void:
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/road_projection_test/bake_metadata.json"))
	var data := FileAccess.get_file_as_bytes("res://.road_projection_build/road_projection.rg16f")
	var resolution := int(metadata.resolution)
	var image := Image.create_from_data(resolution, resolution, false, Image.FORMAT_RGH, data)
	if image.is_empty() or image.generate_mipmaps() != OK:
		push_error("Failed to create road mask/height mip texture")
		quit(1)
		return
	var texture := ImageTexture.create_from_image(image)
	if ResourceSaver.save(texture, "res://assets/world/road_projection_test/road_projection.res", ResourceSaver.FLAG_COMPRESS) != OK:
		quit(1)
		return
	print("ROAD_TEXTURE_READY RG16F ", resolution, " mips=", image.get_mipmap_count())
	quit()
