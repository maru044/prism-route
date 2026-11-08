@tool
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var world = load("res://scenes/map_1021.tscn").instantiate()
	world.automation_enabled = true
	root.add_child(world)
	
	var started := Time.get_ticks_msec()
	while not world.test_ready and Time.get_ticks_msec() - started < 120000:
		await process_frame
		
	print("Map ready. Waiting for settle...")
	for f in 40: await physics_frame
	
	var char_ctrl = world.character
	print("Current character: ", char_ctrl.active_character_id)
	
	var out_dir = "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/batch09_review/"
	
	# 1. Stelle NPR Full Body Hero Shot
	char_ctrl.camera_pivot.rotation_degrees = Vector3(-8, 35, 0)
	char_ctrl.spring_arm.spring_length = 3.2
	for f in 25: await physics_frame
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	img.save_png(out_dir + "npr_stelle_full_body.png")
	print("Saved npr_stelle_full_body.png")
	
	# 2. Stelle NPR Face & Hair Closeup (Under directional lighting)
	char_ctrl.camera_pivot.rotation_degrees = Vector3(-2, 160, 0) # front-three-quarter view of face
	char_ctrl.spring_arm.spring_length = 1.15
	for f in 25: await physics_frame
	await RenderingServer.frame_post_draw
	img = root.get_texture().get_image()
	img.save_png(out_dir + "npr_stelle_face_closeup.png")
	print("Saved npr_stelle_face_closeup.png")
	
	# 3. Switch to Lumine and capture closeup
	char_ctrl.switch_character("lumine")
	for f in 25: await physics_frame
	await RenderingServer.frame_post_draw
	img = root.get_texture().get_image()
	img.save_png(out_dir + "npr_lumine_face_closeup.png")
	print("Saved npr_lumine_face_closeup.png")
	
	# 4. Switch to Firefly and capture closeup
	char_ctrl.switch_character("firefly")
	for f in 25: await physics_frame
	await RenderingServer.frame_post_draw
	img = root.get_texture().get_image()
	img.save_png(out_dir + "npr_firefly_face_closeup.png")
	print("Saved npr_firefly_face_closeup.png")
	
	# 5. Switch back to Stelle, 3rd person game camera
	char_ctrl.switch_character("stelle")
	char_ctrl.camera_pivot.rotation_degrees = Vector3(-12, 0, 0)
	char_ctrl.spring_arm.spring_length = 3.8
	for f in 25: await physics_frame
	await RenderingServer.frame_post_draw
	img = root.get_texture().get_image()
	img.save_png(out_dir + "npr_stelle_third_person.png")
	print("Saved npr_stelle_third_person.png")
	
	print("ALL NPR UPGRADE CAPTURES SAVED!")
	quit(0)
