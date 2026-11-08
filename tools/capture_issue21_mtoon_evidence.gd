@tool
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var world: Node = load("res://scenes/map_1021.tscn").instantiate()
	world.automation_enabled = true
	root.add_child(world)
	
	var started := Time.get_ticks_msec()
	while not world.test_ready and Time.get_ticks_msec() - started < 150000:
		await process_frame
		
	print("Map ready. Waiting for settle...")
	for f in 40: await physics_frame
	
	var char_ctrl = world.character
	var out_dir := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/issue21_review/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	
	var characters := ["ganyu", "stelle", "lumine"]
	
	for cid in characters:
		print("Capturing for character: ", cid)
		char_ctrl.switch_character(cid)
		for f in 30: await physics_frame
		
		# 1. Face & Hair 3/4 Closeup
		char_ctrl.camera_pivot.rotation_degrees = Vector3(-4, 155, 0)
		char_ctrl.spring_arm.spring_length = 1.15
		for f in 25: await physics_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var p1 := out_dir + "mtoon_%s_face_closeup.png" % cid
		img.save_png(p1)
		print("Saved: ", p1)
		
		# 2. Full Body Third-Person Hero View
		char_ctrl.camera_pivot.rotation_degrees = Vector3(-10, 30, 0)
		char_ctrl.spring_arm.spring_length = 3.2
		for f in 25: await physics_frame
		await RenderingServer.frame_post_draw
		img = root.get_texture().get_image()
		var p2 := out_dir + "mtoon_%s_full_body.png" % cid
		img.save_png(p2)
		print("Saved: ", p2)
		
		# 3. Side Light / Rim Light Profile
		char_ctrl.camera_pivot.rotation_degrees = Vector3(-6, 90, 0)
		char_ctrl.spring_arm.spring_length = 1.8
		for f in 25: await physics_frame
		await RenderingServer.frame_post_draw
		img = root.get_texture().get_image()
		var p3 := out_dir + "mtoon_%s_sidelight.png" % cid
		img.save_png(p3)
		print("Saved: ", p3)
		
	print("ALL ISSUE 21 MTOON CAPTURES FINISHED!")
	quit(0)
