@tool
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ganyu_scene: PackedScene = load("res://scenes/characters/ganyu.tscn")
	var ganyu: Node3D = ganyu_scene.instantiate()
	root.add_child(ganyu)
	
	var skel: Skeleton3D = ganyu.find_child("GeneralSkeleton", true, false)
	print("--- Ganyu Skeleton Tree ---")
	for b_name in ["Root", "Hips", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes"]:
		var b = skel.find_bone(b_name)
		if b >= 0:
			var parent = skel.get_bone_parent(b)
			var p_name = skel.get_bone_name(parent) if parent >= 0 else "NONE"
			var rest = skel.get_bone_rest(b)
			var g_rest = skel.get_bone_global_rest(b)
			print("Bone: ", b_name, " (parent: ", p_name, ")")
			print("   rest pos: ", rest.origin, " global rest pos: ", g_rest.origin)
			
	print("\n--- Now playing A01 on Ganyu ---")
	var player = AnimationPlayer.new()
	ganyu.add_child(player)
	var a01: Animation = load("res://assets/characters/motion_review/A01.tres").duplicate(true)
	var skel_path = ganyu.get_path_to(skel)
	for t in a01.get_track_count():
		var p = str(a01.track_get_path(t))
		var col = p.find(":")
		if col != -1:
			var bone_part = p.substr(col)
			a01.track_set_path(t, NodePath(str(skel_path) + bone_part))
			
	var lib = AnimationLibrary.new()
	lib.add_animation("idle", a01)
	player.add_animation_library("", lib)
	player.play("idle")
	
	for i in 5:
		await physics_frame
		
	print("After playing A01 on Ganyu:")
	for b_name in ["Root", "Hips", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes"]:
		var b = skel.find_bone(b_name)
		if b >= 0:
			var pose_pos = skel.get_bone_pose_position(b)
			var g_pose = skel.get_bone_global_pose(b)
			print("Bone: ", b_name)
			print("   pose pos: ", pose_pos, " global pose pos: ", g_pose.origin)
			
	quit(0)
