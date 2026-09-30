extends SceneTree

func _initialize() -> void:
	var manifest := FileAccess.get_file_as_string("res://.vegetation_art_build/foliage_mips/manifest.json")
	var parsed = JSON.parse_string(manifest)
	if not parsed is Array or parsed.is_empty():
		push_error("Run tools/build_foliage_mips.py before importing foliage mips.")
		quit(1)
		return
	var entries: Array = parsed
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/vegetation/textures/filtered_lod"))
	for entry in entries:
		var data := FileAccess.get_file_as_bytes("res://.vegetation_art_build/foliage_mips/%s.rgba" % entry.stem)
		var image := Image.create_from_data(entry.width, entry.height, true, Image.FORMAT_RGBA8, data)
		if image.is_empty():
			quit(1)
			return
		var texture := ImageTexture.create_from_image(image)
		var path := "res://assets/vegetation/textures/filtered_lod/%s.res" % entry.stem
		if ResourceSaver.save(texture, path, ResourceSaver.FLAG_COMPRESS) != OK:
			quit(1)
			return
		print("FOLIAGE_MIP_IMPORT ", path, " mip_count=", image.get_mipmap_count())
	var metadata := FileAccess.open("res://assets/vegetation/textures/filtered_lod/build_metadata.json", FileAccess.WRITE)
	if metadata == null:
		quit(1)
		return
	metadata.store_string(manifest)
	quit()
