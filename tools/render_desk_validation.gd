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
	
	var out_dir := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/desk_final/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	
	# Select TSFB V2 entry
	scene.select_entry("mmd_fca4bab1635f_all")
	while scene.loading:
		await process_frame
	for f in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	
	# Seek to mid frame
	scene.playing = false
	scene.seek_frame(50)
	for f in 15:
		await process_frame
	await RenderingServer.frame_post_draw
	
	# 1. Master View / Oblique Full View
	scene.yaw = 2.40
	scene.pitch = 0.22
	scene.distance = 2.9
	scene.camera_target = Vector3(0.0, 0.70, 0.10)
	scene._update_camera()
	for f in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var img1 := root.get_texture().get_image()
	img1.save_png(out_dir + "desk_action_oblique.png")
	
	# 2. Side View (Hands on Desk Surface & Leg Clearance)
	scene.yaw = 1.5708
	scene.pitch = 0.08
	scene.distance = 2.4
	scene.camera_target = Vector3(0.0, 0.75, 0.0)
	scene._update_camera()
	for f in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var img2 := root.get_texture().get_image()
	img2.save_png(out_dir + "desk_action_side.png")
	
	# 3. Front View (Hands Resting on Tabletop & Character Posture)
	scene.yaw = 3.14159
	scene.pitch = 0.12
	scene.distance = 2.5
	scene.camera_target = Vector3(0.0, 0.78, 0.0)
	scene._update_camera()
	for f in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var img3 := root.get_texture().get_image()
	img3.save_png(out_dir + "desk_action_front.png")
	
	# 4. Hide actors, showcase desk alone
	for actor_id in scene.actors:
		scene.actors[actor_id].visible = false
	
	scene.yaw = 2.30
	scene.pitch = 0.26
	scene.distance = 2.5
	scene.camera_target = Vector3(0.0, 0.45, -0.22)
	scene._update_camera()
	for f in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var img4 := root.get_texture().get_image()
	img4.save_png(out_dir + "desk_standalone_showcase.png")
	
	print("All desk validation screenshots saved to: ", out_dir)
	quit(0)
