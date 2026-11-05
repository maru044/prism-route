@tool
extends SceneTree

const VALIDATION_SCENE := "res://scenes/character_mmd_vrm_validation.tscn"

func _init() -> void:
	print("Starting test render of furniture fixes...")
	var scene = load(VALIDATION_SCENE).instantiate()
	get_root().add_child(scene)
	await process_frame
	
	while not scene.initialized:
		await process_frame
		
	var tests := [
		{
			"pack_id": "mmd_781d8c87fd79", # Welcome - BJV2
			"name": "welcome_bjv2",
			"furn_id": "scifi_round_chair",
			"offset": Vector3(0.0, 0.0, -0.51),
			"rot": 0.0,
			"frame": 269
		},
		{
			"pack_id": "mmd_6e891982bb51", # Loop 02
			"name": "loop02_round_chair",
			"furn_id": "scifi_round_chair",
			"offset": Vector3(0.0, 0.0, -0.14),
			"rot": 0.0,
			"frame": 57
		},
		{
			"pack_id": "mmd_0a3f6ba5f5de", # Armchair Paizuri
			"name": "armchair_paizuri",
			"furn_id": "scifi_round_chair",
			"offset": Vector3(0.0, 0.0, -0.11),
			"rot": 0.0,
			"frame": 300
		},
		{
			"pack_id": "mmd_beee0d2eb57b", # Loop 20 Chikan 03
			"name": "chikan03_round_chair",
			"furn_id": "scifi_round_chair",
			"offset": Vector3(0.0, 0.0, 0.0),
			"rot": 0.0,
			"frame": 200
		},
		{
			"pack_id": "mmd_71dec5bd8390", # Loop 03
			"name": "loop03_long_sofa",
			"furn_id": "scifi_long_sofa",
			"offset": Vector3(0.0, 0.0, -0.55),
			"rot": 0.0,
			"frame": 120
		},
		{
			"pack_id": "mmd_160b1e7a411c", # Lap Sitting
			"name": "lap_sitting_donut_chair",
			"furn_id": "scifi_donut_chair",
			"offset": Vector3(0.0, 0.0, -0.45),
			"rot": 0.0,
			"frame": 200
		},
		{
			"pack_id": "mmd_16a2ecfb7781", # BJ in Bed
			"name": "bj_in_bed_platform",
			"furn_id": "scifi_platform_bed",
			"offset": Vector3(0.0, 0.0, -0.50),
			"rot": 0.0,
			"frame": 200
		}
	]
	
	var out_dir := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/renders"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var vp: Viewport = get_root().get_viewport()
	
	for cfg in tests:
		print("\nRendering test: %s..." % cfg.name)
		var entry_id := ""
		for candidate in scene.catalog.entries:
			if candidate.pack == cfg.pack_id:
				entry_id = candidate.id
				break
				
		if entry_id == "":
			print("Entry not found for pack: %s" % cfg.pack_id)
			continue
			
		await scene.select_entry(entry_id)
		
		# Set furniture manually
		scene.furniture_visible = true
		scene.auto_furn_match = false
		for item in scene.furniture_catalog:
			if item.id == cfg.furn_id:
				scene._load_furniture(item, cfg.offset, cfg.rot)
				break
				
		scene.seek_frame(cfg.frame)
		
		# Front view
		scene.yaw = 0.0
		scene.pitch = -0.15
		scene.distance = 2.8
		scene._update_camera()
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		var img_front = vp.get_texture().get_image()
		var p_front = "%s/%s_front.png" % [out_dir, cfg.name]
		img_front.save_png(p_front)
		print("Saved: %s" % p_front)
		
		# Oblique view
		scene.yaw = 0.55
		scene.pitch = -0.2
		scene.distance = 3.0
		scene._update_camera()
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		var img_obl = vp.get_texture().get_image()
		var p_obl = "%s/%s_oblique.png" % [out_dir, cfg.name]
		img_obl.save_png(p_obl)
		print("Saved: %s" % p_obl)
		
		# Side view
		scene.yaw = 1.45
		scene.pitch = -0.1
		scene.distance = 2.8
		scene._update_camera()
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		var img_side = vp.get_texture().get_image()
		var p_side = "%s/%s_side.png" % [out_dir, cfg.name]
		img_side.save_png(p_side)
		print("Saved: %s" % p_side)
		
	print("\nAll renders completed successfully!")
	quit(0)
