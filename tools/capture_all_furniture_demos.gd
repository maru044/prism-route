extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 900)
	var scene_res := load("res://scenes/character_mmd_vrm_validation.tscn")
	var scene: Node = scene_res.instantiate()
	root.add_child(scene)
	
	# Wait for scene ready
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	
	var out_dir := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/"
	
	# Test configurations:
	# [entry_id, furniture_id, file_name, cam_yaw, cam_pitch, cam_dist, cam_y, seek_sec]
	var tests: Array = [
		{
			"entry": "mmd_6e891982bb51_all", # Loop 02
			"furn_id": "scifi_round_chair",
			"file": "verified_round_chair_loop02.png",
			"yaw": 0.4,
			"pitch": 0.2,
			"dist": 2.6,
			"cam_y": 0.45,
			"seek": 2.0
		},
		{
			"entry": "mmd_781d8c87fd79_all", # Welcome - BJV2
			"furn_id": "scifi_single_armchair",
			"file": "verified_armchair_welcome_bjv2.png",
			"rot_deg": 180.0, # Rotate armchair so its backrest matches Role A's back at +Z
			"yaw": 3.14,      # Look from front of Role A and B (yaw = PI)
			"pitch": 0.22,
			"dist": 2.8,
			"cam_y": 0.48,
			"seek": 4.0
		},
		{
			"entry": "mmd_6e891982bb51_all", # Loop 02
			"furn_id": "scifi_platform_bed",
			"file": "verified_platform_bed_loop02.png",
			"yaw": 0.55,
			"pitch": 0.35,
			"dist": 3.2,
			"cam_y": 0.45,
			"seek": 2.0
		},
		{
			"entry": "mmd_71dec5bd8390_all", # Loop 03
			"furn_id": "scifi_long_sofa",
			"file": "verified_long_sofa_loop03.png",
			"yaw": 0.35,
			"pitch": 0.25,
			"dist": 3.4,
			"cam_y": 0.50,
			"seek": 3.0
		},
		{
			"entry": "mmd_160b1e7a411c_all", # Lap Sitting
			"furn_id": "scifi_donut_chair",
			"file": "verified_donut_chair_lap_sitting.png",
			"yaw": 0.45,
			"pitch": 0.22,
			"dist": 2.8,
			"cam_y": 0.45,
			"seek": 2.0
		}
	]
	
	for t in tests:
		print("--- Running Test: ", t["file"], " ---")
		await scene.select_entry(t["entry"])
		scene.playing = false
		
		# Find furniture in catalog
		var furn_data: Dictionary = {}
		for f in scene.furniture_catalog:
			if f["id"] == t["furn_id"]:
				furn_data = f
				break
				
		if not furn_data.is_empty():
			scene.furniture_visible = true
			scene.auto_furn_match = false
			scene._load_furniture(furn_data, Vector3.ZERO)
			scene._set_furniture_sliders(Vector3.ZERO, t.get("rot_deg", 0.0))
			
		scene.yaw = t["yaw"]
		scene.pitch = t["pitch"]
		scene.distance = t["dist"]
		scene.camera_target = Vector3(0, t["cam_y"], 0)
		scene._update_camera()
		
		# Seek animation
		scene._seek_animation(t["seek"])
		
		for f in 15:
			await process_frame
		await RenderingServer.frame_post_draw
		
		var img: Image = root.get_texture().get_image()
		var full_path: String = out_dir + str(t["file"])
		img.save_png(full_path)
		print("SAVED: ", full_path)
		
	quit(0)
