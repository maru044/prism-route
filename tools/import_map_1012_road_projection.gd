extends SceneTree

func _initialize() -> void:
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/map_1012_test/road_projection_metadata.json"))
	var data := FileAccess.get_file_as_bytes("res://.map_1012_build/road_projection.rgba16f")
	var resolution := int(metadata.resolution)
	var image := Image.create_from_data(resolution, resolution, false, Image.FORMAT_RGBAH, data)
	if image.is_empty():
		quit(1)
		return
	var texture := ImageTexture.create_from_image(image)
	var error := ResourceSaver.save(texture, "res://assets/world/map_1012_test/road_projection.res", ResourceSaver.FLAG_COMPRESS)
	print("MAP_1012_ROAD_TEXTURE_READY ", resolution, " error=", error)
	quit(0 if error == OK else 1)
