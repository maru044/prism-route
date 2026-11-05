extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 900)
	var scene_res := load("res://scenes/character_mmd_vrm_validation.tscn")
	var scene: Node = scene_res.instantiate()
	root.add_child(scene)
	
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	
	var out_dir := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/recline_fix_verified/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	
	var entries: Array = scene.catalog.get("entries", [])
	
	# Test 1: Welcome - BJV2 with Silver Wolf at frame 782 (time 26.06s)
	var welcome_entry_id := ""
	for e in entries:
		if e.get("pack", "") == "mmd_781d8c87fd79":
			welcome_entry_id = e.get("id", "")
			break
			
	if welcome_entry_id != "":
		print("Selecting entry: ", welcome_entry_id)
		scene.select_entry(welcome_entry_id)
		while scene.loading:
			await process_frame
		for f in 15:
			await process_frame
		await RenderingServer.frame_post_draw
		
		# Switch Role B to Silver Wolf
		print("Calling set_role_model to silver_wolf...")
		scene.set_role_model("B", "silver_wolf")
		while scene.loading:
			await process_frame
		for f in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		print("Role B is now: ", scene.pack.roles[1].profile if scene.pack else "none")
		
		# Pause and seek to frame 782 (time 26.06 s)
		scene.playing = false
		scene.seek_frame(782)
		for f in 20:
			await process_frame
		await RenderingServer.frame_post_draw
				
		# 1. Perspective view matching Master's screenshot angle
		scene.yaw = 0.60
		scene.pitch = 0.22
		scene.distance = 2.85
		scene.camera_target = Vector3(0, 0.45, -0.45)
		scene._update_camera()
		
		for f in 15:
			await process_frame
		await RenderingServer.frame_post_draw
		
		var pic_sw_oblique := root.get_texture().get_image()
		pic_sw_oblique.save_png(out_dir + "welcome_bjv2_silverwolf_frame782_oblique.png")
		print("SAVED: ", out_dir + "welcome_bjv2_silverwolf_frame782_oblique.png")
		
		# 2. Side view
		scene.yaw = 1.57
		scene.pitch = 0.15
		scene.distance = 2.85
		scene.camera_target = Vector3(0, 0.45, -0.45)
		scene._update_camera()
		
		for f in 15:
			await process_frame
		await RenderingServer.frame_post_draw
		
		var pic_sw_side := root.get_texture().get_image()
		pic_sw_side.save_png(out_dir + "welcome_bjv2_silverwolf_frame782_side.png")
		print("SAVED: ", out_dir + "welcome_bjv2_silverwolf_frame782_side.png")
		
	quit(0)
