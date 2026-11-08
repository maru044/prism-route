@tool
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world_scene = load("res://scenes/characters/world_ganyu.tscn")
	var controller = world_scene.instantiate()
	root.add_child(controller)
	
	for char_id in ["ganyu", "stelle", "lumine", "firefly"]:
		controller.switch_character(char_id)
		for f in 10:
			await physics_frame
			
		var skel: Skeleton3D = controller.skeleton
		var l_foot = skel.find_bone("LeftFoot")
		var r_foot = skel.find_bone("RightFoot")
		var l_toes = skel.find_bone("LeftToes")
		var r_toes = skel.find_bone("RightToes")
		var hips = skel.find_bone("Hips")
		
		var l_f_pos = skel.get_bone_global_pose(l_foot).origin if l_foot >= 0 else Vector3.ZERO
		var r_f_pos = skel.get_bone_global_pose(r_foot).origin if r_foot >= 0 else Vector3.ZERO
		var l_t_pos = skel.get_bone_global_pose(l_toes).origin if l_toes >= 0 else Vector3.ZERO
		var r_t_pos = skel.get_bone_global_pose(r_toes).origin if r_toes >= 0 else Vector3.ZERO
		var hips_pos = skel.get_bone_global_pose(hips).origin if hips >= 0 else Vector3.ZERO
		
		# Also find lowest mesh vertex after skinning / deformation if possible, or global Y
		print("\n=== Character: ", char_id, " ===")
		print("Hips global Y: ", hips_pos.y)
		print("LeftFoot global Y: ", l_f_pos.y, " RightFoot global Y: ", r_f_pos.y)
		print("LeftToes global Y: ", l_t_pos.y, " RightToes global Y: ", r_t_pos.y)
		print("Capsule height: ", controller.collision_shape.shape.height, " pos: ", controller.collision_shape.position)
		
	quit(0)
