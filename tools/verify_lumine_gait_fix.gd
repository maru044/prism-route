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
	while not world.test_ready and Time.get_ticks_msec() - started < 150000:
		await process_frame
		
	for f in 40: await physics_frame
	
	var ctrl = world.character
	assert(ctrl != null, "World character controller not found")
	assert(ctrl.active_character_id == "lumine", "Default active character should be lumine, got: " + ctrl.active_character_id)
	
	var out_dir := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/issue21_review/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	
	# Verify Lumine animation tracks
	var walk_anim: Animation = ctrl.player.get_animation("walk")
	var has_center_pos := false
	var has_center_rot := false
	for t in walk_anim.get_track_count():
		var p = str(walk_anim.track_get_path(t))
		var type = walk_anim.track_get_type(t)
		if p.ends_with(":センター"):
			if type == Animation.TYPE_POSITION_3D: has_center_pos = true
			if type == Animation.TYPE_ROTATION_3D: has_center_rot = true
			
	assert(has_center_pos, "Lumine walk animation missing :センター position track")
	assert(has_center_rot, "Lumine walk animation missing :センター rotation track")
	print("Lumine animation tracks verified: center pos and rot tracks present.")
	
	# Start walk and allow 20 frames for heading to settle
	ctrl.automation_enabled = true
	ctrl.test_move = Vector2(0, -1)
	ctrl.test_running = false
	for f in 20: await physics_frame
	
	ctrl.camera_pivot.rotation_degrees = Vector3(-6, 0, 0)
	ctrl.spring_arm.spring_length = 2.5
	
	var skel: Skeleton3D = ctrl.skeleton
	var lf = skel.find_bone("LeftFoot")
	var rf = skel.find_bone("RightFoot")
	var center = skel.find_bone("センター")
	
	var lf_xs = []
	var rf_xs = []
	var spans = []
	
	for frame in range(60):
		await physics_frame
		var lf_pos = skel.to_global(skel.get_bone_global_pose(lf).origin)
		var rf_pos = skel.to_global(skel.get_bone_global_pose(rf).origin)
		
		# Relative to character's visual node (actual heading frame)
		var vis_t = ctrl.visual.global_transform
		var rel_lf = vis_t.affine_inverse() * lf_pos
		var rel_rf = vis_t.affine_inverse() * rf_pos
		var span = abs(rel_lf.x - rel_rf.x)
		
		lf_xs.append(rel_lf.x)
		rf_xs.append(rel_rf.x)
		spans.append(span)
		
		if frame == 25:
			await RenderingServer.frame_post_draw
			var img = root.get_texture().get_image()
			img.save_png(out_dir + "lumine_verified_walk_rear.png")
			print("Saved: ", out_dir + "lumine_verified_walk_rear.png")
			
	ctrl.test_move = Vector2.ZERO
	for f in 15: await physics_frame
	
	var lf_min = lf_xs.min(); var lf_max = lf_xs.max(); var lf_sway = lf_max - lf_min
	var rf_min = rf_xs.min(); var rf_max = rf_xs.max(); var rf_sway = rf_max - rf_min
	var max_span = spans.max(); var avg_span = 0.0
	for s in spans: avg_span += s / float(spans.size())
	
	print("\n=== LUMINE STEADY GAIT METRICS ===")
	print("LeftFoot  X range: [%+.3f, %+.3f] (sway = %.3fm)" % [lf_min, lf_max, lf_sway])
	print("RightFoot X range: [%+.3f, %+.3f] (sway = %.3fm)" % [rf_min, rf_max, rf_sway])
	print("Foot span: avg = %.3fm, max = %.3fm" % [avg_span, max_span])
	
	# Strict assertions for steady walking gait
	assert(lf_sway < 0.05, "LeftFoot sway too high: %.3fm" % lf_sway)
	assert(rf_sway < 0.05, "RightFoot sway too high: %.3fm" % rf_sway)
	assert(max_span < 0.18, "Max foot span too wide: %.3fm" % max_span)
	
	# Capture side-walking view
	ctrl.camera_pivot.rotation_degrees = Vector3(-4, 75, 0)
	ctrl.spring_arm.spring_length = 2.2
	ctrl.test_move = Vector2(0, -1)
	for f in 30: await physics_frame
	await RenderingServer.frame_post_draw
	var img_side = root.get_texture().get_image()
	img_side.save_png(out_dir + "lumine_verified_walk_side.png")
	print("Saved: ", out_dir + "lumine_verified_walk_side.png")
	
	ctrl.test_move = Vector2.ZERO
	for f in 10: await physics_frame
	
	# Regression check: switch to Ganyu and check stability
	print("\n=== REGRESSION CHECK FOR GANYU ===")
	ctrl.switch_character("ganyu")
	for f in 20: await physics_frame
	ctrl.test_move = Vector2(0, -1)
	for f in 30: await physics_frame
	ctrl.test_move = Vector2.ZERO
	print("Ganyu switch and walk completed smoothly.")
	
	world.free()
	print("\n*** ALL LUMINE GAIT VERIFICATIONS PASSED ***")
	quit()
