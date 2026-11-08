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
	
	# Spawn index 8 is cave (the default in map_1021)
	var char_ctrl = world.character
	print("Current character: ", char_ctrl.active_character_id)
	
	var out_dir = "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/batch09_review/"
	
	# 1. Capture Stelle standing grounded
	for f in 20: await physics_frame
	await RenderingServer.frame_post_draw
	var img = root.get_texture().get_image()
	img.save_png(out_dir + "fix_stelle_grounded_cave.png")
	print("Saved fix_stelle_grounded_cave.png")
	
	# Let's adjust camera to side-view of feet to clearly see ground contact
	var cam_pivot = char_ctrl.camera_pivot
	cam_pivot.rotation_degrees = Vector3(-5, 90, 0)
	char_ctrl.spring_arm.spring_length = 2.2
	for f in 15: await physics_frame
	await RenderingServer.frame_post_draw
	img = root.get_texture().get_image()
	img.save_png(out_dir + "fix_stelle_feet_closeup.png")
	print("Saved fix_stelle_feet_closeup.png")
	
	# 2. Switch to Lumine
	char_ctrl.switch_character("lumine")
	for f in 20: await physics_frame
	await RenderingServer.frame_post_draw
	img = root.get_texture().get_image()
	img.save_png(out_dir + "fix_lumine_feet_closeup.png")
	print("Saved fix_lumine_feet_closeup.png")
	
	# 3. Switch to Firefly
	char_ctrl.switch_character("firefly")
	for f in 20: await physics_frame
	await RenderingServer.frame_post_draw
	img = root.get_texture().get_image()
	img.save_png(out_dir + "fix_firefly_feet_closeup.png")
	print("Saved fix_firefly_feet_closeup.png")
	
	# 4. Switch to Ganyu
	char_ctrl.switch_character("ganyu")
	for f in 20: await physics_frame
	await RenderingServer.frame_post_draw
	img = root.get_texture().get_image()
	img.save_png(out_dir + "fix_ganyu_feet_closeup.png")
	print("Saved fix_ganyu_feet_closeup.png")
	
	# 5. Switch back to Stelle and capture full hero view
	char_ctrl.switch_character("stelle")
	cam_pivot.rotation_degrees = Vector3(-10, 30, 0)
	char_ctrl.spring_arm.spring_length = 3.5
	for f in 20: await physics_frame
	await RenderingServer.frame_post_draw
	img = root.get_texture().get_image()
	img.save_png(out_dir + "fix_stelle_grounded_full.png")
	print("Saved fix_stelle_grounded_full.png")
	
	print("ALL CAPTURES SAVED SUCCESSFULLY!")
	quit(0)
