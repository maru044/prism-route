extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1440, 960)
	var scene = load("res://scenes/landscape_mask_test.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	assert(scene.test_ready)
	var tex: Texture2D = scene.material.get_shader_parameter("landscape_mask")
	assert(tex.get_width() == 4096 and tex.get_height() == 4096)
	print("MASK_RESOURCE_OK ", tex.get_width(), " RG16F")
	if "--verify-only" in OS.get_cmdline_user_args():
		quit(0)
		return
	var out := "res://assets/world/landscape_mask_test/review/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for shot in [[0, 0, "overview"], [1, 0, "near_sdf"], [1, 1, "near_coarse_diagnostic"], [2, 0, "grazing"]]:
		scene.select_view(shot[0])
		scene.set_mode(shot[1])
		for i in range(16): await process_frame
		await RenderingServer.frame_post_draw
		var path := out + str(shot[2]) + ".png"
		assert(root.get_texture().get_image().save_png(path) == OK)
		print("CAPTURE ", path)
	quit(0)
