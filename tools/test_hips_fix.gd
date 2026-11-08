@tool
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world_scene = load("res://scenes/characters/world_ganyu.tscn")
	var controller = world_scene.instantiate()
	root.add_child(controller)
	
	controller.active_character_id = "stelle"
	controller._apply_character_setup("stelle", true)
	
	# Let's inspect before adjusting track
	for f in 5: await physics_frame
	
	var skel: Skeleton3D = controller.skeleton
	var hips = skel.find_bone("Hips")
	var l_foot = skel.find_bone("LeftFoot")
	var r_foot = skel.find_bone("RightFoot")
	var l_toes = skel.find_bone("LeftToes")
	var r_toes = skel.find_bone("RightToes")
	
	print("--- Before fix (Stelle) ---")
	print("Hips pose pos: ", skel.get_bone_pose_position(hips))
	print("Hips global pos: ", skel.get_bone_global_pose(hips).origin)
	print("LeftFoot global Y: ", skel.get_bone_global_pose(l_foot).origin.y)
	print("RightFoot global Y: ", skel.get_bone_global_pose(r_foot).origin.y)
	print("LeftToes global Y: ", skel.get_bone_global_pose(l_toes).origin.y)
	print("RightToes global Y: ", skel.get_bone_global_pose(r_toes).origin.y)
	
	# Now let's adjust the Hips position track in controller.player
	var anim: Animation = controller.player.get_animation("idle")
	var track_idx = -1
	for t in anim.get_track_count():
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and str(anim.track_get_path(t)).ends_with(":Hips"):
			track_idx = t
			break
			
	print("Found Hips position track: ", track_idx)
	var ganyu_rest_hips := Vector3(0.0, 0.661507, 0.0)
	var stelle_rest_hips := skel.get_bone_rest(hips).origin
	print("Ganyu rest hips: ", ganyu_rest_hips, " Stelle rest hips: ", stelle_rest_hips)
	
	for k in anim.track_get_key_count(track_idx):
		var old_val: Vector3 = anim.track_get_key_value(track_idx, k)
		# Delta from Ganyu rest:
		var delta: Vector3 = old_val - ganyu_rest_hips
		# Apply to Stelle rest:
		var new_val: Vector3 = stelle_rest_hips + delta
		anim.track_set_key_value(track_idx, k, new_val)
		
	# Replay idle
	controller.player.stop()
	controller.player.play("idle")
	for f in 5: await physics_frame
	
	print("\n--- After fix (Stelle) ---")
	print("Hips pose pos: ", skel.get_bone_pose_position(hips))
	print("Hips global pos: ", skel.get_bone_global_pose(hips).origin)
	print("LeftFoot global Y: ", skel.get_bone_global_pose(l_foot).origin.y)
	print("RightFoot global Y: ", skel.get_bone_global_pose(r_foot).origin.y)
	print("LeftToes global Y: ", skel.get_bone_global_pose(l_toes).origin.y)
	print("RightToes global Y: ", skel.get_bone_global_pose(r_toes).origin.y)
	
	quit(0)
