@tool
extends SceneTree

const VALIDATION_SCENE := "res://scenes/character_mmd_vrm_validation.tscn"

func _init() -> void:
	print("Rendering Loop 03 with Rot 180 vs 0, and Bed Riding...")
	var scene = load(VALIDATION_SCENE).instantiate()
	get_root().add_child(scene)
	await process_frame
	while not scene.initialized:
		await process_frame
		
	var out_dir := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/renders"
	var vp: Viewport = get_root().get_viewport()
	
	# Test 1: Loop 03 with sofa Rot = 180 deg
	var entry_loop03 := ""
	for candidate in scene.catalog.entries:
		if candidate.pack == "mmd_71dec5bd8390":
			entry_loop03 = candidate.id
			break
	if entry_loop03 != "":
		await scene.select_entry(entry_loop03)
		scene.furniture_visible = true
		scene.auto_furn_match = false
		for item in scene.furniture_catalog:
			if item.id == "scifi_long_sofa":
				scene._load_furniture(item, Vector3(0.0, 0.0, -0.60), 180.0)
				break
		scene.seek_frame(120)
		# View from -Z looking at +Z (the girls' front faces)
		scene.yaw = PI
		scene.pitch = -0.15
		scene.distance = 2.8
		scene._update_camera()
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/loop03_rot180_frontface.png" % out_dir)
		print("Saved loop03_rot180_frontface.png")
		
		# View from oblique
		scene.yaw = PI + 0.5
		scene.pitch = -0.2
		scene.distance = 3.0
		scene._update_camera()
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/loop03_rot180_oblique.png" % out_dir)
		print("Saved loop03_rot180_oblique.png")

	# Test 2: Bed Riding (mmd_43916ffe3d35) on scifi_platform_bed
	var entry_bed := ""
	for candidate in scene.catalog.entries:
		if candidate.pack == "mmd_43916ffe3d35":
			entry_bed = candidate.id
			break
	if entry_bed != "":
		await scene.select_entry(entry_bed)
		scene.furniture_visible = true
		scene.auto_furn_match = false
		for item in scene.furniture_catalog:
			if item.id == "scifi_platform_bed":
				scene._load_furniture(item, Vector3(0.0, 0.0, -0.20), 0.0)
				break
		scene.seek_frame(150)
		scene.yaw = 0.6
		scene.pitch = -0.25
		scene.distance = 3.2
		scene._update_camera()
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/bed_riding_oblique.png" % out_dir)
		print("Saved bed_riding_oblique.png")

	print("Render script finished!")
	quit(0)
