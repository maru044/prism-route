extends SceneTree

func _initialize() -> void:
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/cliff_b_test/road_projection_metadata.json"))
	var bytes := FileAccess.get_file_as_bytes("res://.cliff_b_build/road_projection.rgba16f")
	var image := Image.create_from_data(int(metadata.resolution), int(metadata.resolution), false, Image.FORMAT_RGBAH, bytes)
	var error := ResourceSaver.save(ImageTexture.create_from_image(image), "res://assets/world/cliff_b_test/road_projection.res", ResourceSaver.FLAG_COMPRESS)
	print("B_ROAD_TEXTURE_READY ", error)
	quit(0 if error == OK else 1)
