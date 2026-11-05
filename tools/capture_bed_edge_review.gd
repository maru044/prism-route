extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 900)
	var scene_res := load("res://scenes/character_mmd_vrm_validation.tscn")
	var scene: Node = scene_res.instantiate()
	root.add_child(scene)
	
	for i in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	
	var out_dir := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/bed_edge_verified/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	
	var entries: Array = scene.catalog.get("entries", [])
	print("Found %d entries in review catalog" % entries.size())
	
	var target_entry_id := ""
	for idx in range(entries.size()):
		var e: Dictionary = entries[idx]
		if e.get("pack", "") == "mmd_0a3f6ba5f5de" or e.get("id", "").begins_with("mmd_0a3f6ba5f5de"):
			target_entry_id = e.get("id", "")
			break
			
	if target_entry_id != "":
		print("Found target entry id: ", target_entry_id)
		scene.select_entry(target_entry_id)
		
		# Pause and seek to 4.0s for good interaction posture
		for p in scene.role_proxies.values():
			if p.player:
				p.player.pause()
				p.player.seek(4.0, true)
				
		# 1. Front view
		scene.yaw = 0.0
		scene.pitch = 0.15
		scene.distance = 2.6
		scene.camera_target = Vector3(0, 0.45, 0)
		scene._update_camera()
		
		for f in 15:
			await process_frame
		await RenderingServer.frame_post_draw
		
		var pic_front := root.get_texture().get_image()
		pic_front.save_png(out_dir + "armchair_paizuri_bed_edge_front.png")
		print("SAVED: ", out_dir + "armchair_paizuri_bed_edge_front.png")
		
		# 2. Oblique 3/4 view
		scene.yaw = 0.65
		scene.pitch = 0.25
		scene.distance = 2.8
		scene.camera_target = Vector3(0, 0.45, 0)
		scene._update_camera()
		
		for f in 15:
			await process_frame
		await RenderingServer.frame_post_draw
		
		var pic_oblique := root.get_texture().get_image()
		pic_oblique.save_png(out_dir + "armchair_paizuri_bed_edge_oblique.png")
		print("SAVED: ", out_dir + "armchair_paizuri_bed_edge_oblique.png")
		
		# 3. Side view
		scene.yaw = 1.57
		scene.pitch = 0.15
		scene.distance = 2.6
		scene.camera_target = Vector3(0, 0.45, 0)
		scene._update_camera()
		
		for f in 15:
			await process_frame
		await RenderingServer.frame_post_draw
		
		var pic_side := root.get_texture().get_image()
		pic_side.save_png(out_dir + "armchair_paizuri_bed_edge_side.png")
		print("SAVED: ", out_dir + "armchair_paizuri_bed_edge_side.png")
		
		# Print verification details
		print("\n=== UI DISPLAY VERIFICATION ===")
		print("Heading: ", scene.heading.text)
		print("Details:\n", scene.details.text)
		var has_furn: bool = scene.furniture_instance != null and scene.furniture_instance.visible
		print("Furniture Visible: ", has_furn)
		print("================================")
	else:
		printerr("Could not find mmd_0a3f6ba5f5de in catalog!")
		
	quit(0)
