extends SceneTree

const VALIDATION_SCENE := "res://scenes/character_mmd_vrm_validation.tscn"
const BED_GLB := "res://assets/furniture/prism/prism_geo_bed.glb"
const OUT_DIR := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/bed_verified/"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	
	print("Starting bed motion alignment verification...")
	var scene_res := load(VALIDATION_SCENE)
	var scene: Node = scene_res.instantiate()
	root.add_child(scene)
	
	for i in 25:
		await process_frame
	await RenderingServer.frame_post_draw
	
	var bed_res = load(BED_GLB)
	if not bed_res:
		printerr("Failed to load BED_GLB: ", BED_GLB)
		quit(1)
		return
		
	var entries: Array = scene.catalog.get("entries", [])
	
	# Test configurations:
	var tests := [
		# 1. Bed Edge: mmd_0a3f6ba5f5de (Role B reclined on bed edge, Role A kneeling in front)
		{
			"pack": "mmd_0a3f6ba5f5de",
			"frame": 180,
			"pos": Vector3(0.0, 0.0, -1.33),
			"rot": 0.0,
			"yaw": 0.65,
			"pitch": 0.25,
			"dist": 3.4,
			"target": Vector3(0.0, 0.40, 0.0),
			"name": "bed_edge_paizuri_oblique.png",
			"desc": "Bed Edge Front Anchor: Role B reclined on mattress edge, Role A kneeling on floor"
		},
		{
			"pack": "mmd_0a3f6ba5f5de",
			"frame": 180,
			"pos": Vector3(0.0, 0.0, -1.33),
			"rot": 0.0,
			"yaw": PI * 0.5,
			"pitch": 0.15,
			"dist": 3.2,
			"target": Vector3(0.0, 0.40, 0.0),
			"name": "bed_edge_paizuri_side.png",
			"desc": "Bed Edge Front Anchor: Side profile showing flush bed edge thigh alignment"
		},
		# 2. Bed Edge: mmd_71dec5bd8390 (Loop 03 - Double seated at bed edge)
		{
			"pack": "mmd_71dec5bd8390",
			"frame": 120,
			"pos": Vector3(0.0, 0.0, -1.82),
			"rot": 0.0,
			"yaw": 0.55,
			"pitch": 0.22,
			"dist": 3.4,
			"target": Vector3(0.0, 0.45, -0.4),
			"name": "bed_edge_loop03_oblique.png",
			"desc": "Bed Edge Front Anchor: Double seated along bed foot edge"
		},
		# 3. Lying on Bed: mmd_aec34d147925 (Loop 05 - Intimate lying on bed)
		{
			"pack": "mmd_aec34d147925",
			"frame": 100,
			"pos": Vector3(0.0, 0.0, -0.65),
			"rot": 0.0,
			"yaw": 0.65,
			"pitch": 0.38,
			"dist": 3.4,
			"target": Vector3(0.0, 0.45, -0.3),
			"name": "bed_surface_loop05_oblique.png",
			"desc": "Bed Center Anchor: Lying on mattress surface"
		},
		# 4. Lying on Bed: mmd_43916ffe3d35 (Just Tonight - Bed riding posture)
		{
			"pack": "mmd_43916ffe3d35",
			"frame": 150,
			"pos": Vector3(0.0, 0.0, -0.30),
			"rot": 0.0,
			"yaw": 0.65,
			"pitch": 0.30,
			"dist": 3.4,
			"target": Vector3(0.0, 0.45, 0.0),
			"name": "bed_surface_just_tonight_oblique.png",
			"desc": "Bed Center Anchor: Dual interaction centered on mattress"
		},
		# 5. Reclined on Bed: mmd_6e891982bb51 (Loop 02 - Lounging back against headboard/pillows)
		{
			"pack": "mmd_6e891982bb51",
			"frame": 80,
			"pos": Vector3(0.0, 0.0, 0.45),
			"rot": 0.0,
			"yaw": 0.60,
			"pitch": 0.25,
			"dist": 3.0,
			"target": Vector3(0.0, 0.45, 0.0),
			"name": "bed_headboard_loop02_oblique.png",
			"desc": "Bed Headboard Anchor: Reclined posture leaning against bolster pillows"
		}
	]
	
	for tc in tests:
		print("\n--- Running Test: %s ---" % tc["desc"])
		var target_entry_id := ""
		for e in entries:
			if e.get("pack", "") == tc["pack"]:
				target_entry_id = e.get("id", "")
				break
		if target_entry_id == "":
			printerr("Entry not found for pack: ", tc["pack"])
			continue
			
		while scene.loading:
			await process_frame
			
		scene.select_entry(target_entry_id)
		while scene.loading:
			await process_frame
		for f in 15:
			await process_frame
		await RenderingServer.frame_post_draw
		
		scene.playing = false
		scene.furniture_visible = true
		scene.auto_furn_match = false
		
		# Replace furniture instance with our bed
		for c in scene.furniture_root.get_children():
			c.queue_free()
		var bed_inst: Node3D = bed_res.instantiate()
		scene.furniture_root.add_child(bed_inst)
		scene.furniture_instance = bed_inst
		bed_inst.visible = true
		
		# Set transform and frame
		scene._set_furniture_sliders(tc["pos"], tc["rot"])
		scene.seek_frame(tc["frame"])
		
		# Set camera
		scene.yaw = tc["yaw"]
		scene.pitch = tc["pitch"]
		scene.distance = tc["dist"]
		scene.camera_target = tc["target"]
		scene._update_camera()
		
		for f in 15:
			await process_frame
		await RenderingServer.frame_post_draw
		
		var img: Image = root.get_texture().get_image()
		var out_file: String = OUT_DIR + String(tc["name"])
		img.save_png(out_file)
		print("Saved verification capture: ", out_file)
		
	print("\nAll bed motion tests completed successfully!")
	quit(0)
