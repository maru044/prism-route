extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 900)
	var scene_res := load("res://scenes/character_mmd_vrm_validation.tscn")
	var scene: Node = scene_res.instantiate()
	root.add_child(scene)
	
	# Wait for initialization
	for i in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	
	var out_dir := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/"
	
	# Test cases: (index_in_group_or_pack_id, capture_name, camera_yaw, camera_dist)
	# Find entries in scene.catalog
	var entries: Array = scene.catalog.get("entries", [])
	print("Found %d entries in review catalog" % entries.size())
	
	var targets := [
		{"pattern": "Loop 02", "name": "review_round_chair_loop02.png", "yaw": 0.35, "pitch": 0.25, "dist": 2.5, "seek": 2.0},
		{"pattern": "Welcome - BJV2", "name": "review_armchair_welcome_bjv2.png", "yaw": 0.5, "pitch": 0.25, "dist": 2.8, "seek": 5.0},
		{"pattern": "BJ in Bed", "name": "review_bed_bj_in_bed.png", "yaw": 0.6, "pitch": 0.35, "dist": 3.2, "seek": 3.0},
		{"pattern": "Loop 03", "name": "review_sofa_loop03.png", "yaw": 0.4, "pitch": 0.25, "dist": 3.0, "seek": 2.0}
	]
	
	for t in targets:
		var found_idx := -1
		for idx in range(entries.size()):
			var e: Dictionary = entries[idx]
			if e.get("title", "").contains(t["pattern"]) or e.get("id", "").contains(t["pattern"]):
				found_idx = idx
				break
				
		if found_idx != -1:
			print("Setting up target: ", t["name"], " at entry index ", found_idx)
			scene._select_entry(found_idx)
			scene.cam_yaw = t["yaw"]
			scene.cam_pitch = t["pitch"]
			scene.cam_distance = t["dist"]
			scene.cam_target = Vector3(0, 0.45, 0)
			scene._update_camera()
			
			if scene.playback_mode == 0: # PAIR
				for p in scene.role_proxies.values():
					if p.player:
						p.player.pause()
						p.player.seek(t["seek"], true)
			
			for f in 12:
				await process_frame
			await RenderingServer.frame_post_draw
			
			var pic := root.get_texture().get_image()
			var save_path: String = out_dir + str(t["name"])
			pic.save_png(save_path)
			print("SAVED: ", save_path)
			
	quit(0)
