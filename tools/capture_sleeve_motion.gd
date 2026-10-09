extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1440, 1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.model_import_build/sleeve_frames"))
	for model in ["keqing", "huahuo"]:
		for enabled in [false, true]:
			var path := "res://scenes/character_huahuo_import_test.tscn" if model == "huahuo" else "res://scenes/character_model_import_test.tscn"
			var scene = load(path).instantiate()
			root.add_child(scene)
			scene._select(4)
			scene.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			scene._set_springs(enabled)
			scene.camera_target = Vector3(0, .8, 0)
			scene.distance = 2.8
			scene.yaw = .65
			scene._update_camera()
			for frame in 320:
				scene.player.advance(1.0 / 60)
				await process_frame
				if frame >= 160 and frame % 4 == 0:
					await RenderingServer.frame_post_draw
					var picture := root.get_texture().get_image()
					picture = picture.get_region(Rect2i(550, 90, 620, picture.get_height() - 90))
					picture.resize(395, roundi(picture.get_height() * 395.0 / 620), Image.INTERPOLATE_LANCZOS)
					picture.save_png(ProjectSettings.globalize_path("res://.model_import_build/sleeve_frames/%s_%s_%02d.png" % [model, "on" if enabled else "off", (frame - 160) / 4]))
			scene.free()
	print("SLEEVE_MOTION_CAPTURE complete")
	quit()
