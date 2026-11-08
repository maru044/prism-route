@tool
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world_scene = load("res://scenes/characters/world_ganyu.tscn")
	var controller = world_scene.instantiate()
	root.add_child(controller)
	
	var ganyu_rest_hips := Vector3(0.0, 0.661507, 0.0)
	
	for char_id in ["ganyu", "stelle", "lumine", "firefly"]:
		controller.switch_character(char_id)
		var skel: Skeleton3D = controller.skeleton
		var hips = skel.find_bone("Hips")
		var l_toes = skel.find_bone("LeftToes")
		var r_toes = skel.find_bone("RightToes")
		var target_rest_hips = skel.get_bone_rest(hips).origin
		
		# Apply Hips delta retargeting to all animations in controller.player
		for anim_name in controller.player.get_animation_list():
			var anim: Animation = controller.player.get_animation(anim_name)
			for t in anim.get_track_count():
				if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and str(anim.track_get_path(t)).ends_with(":Hips"):
					for k in anim.track_get_key_count(t):
						var old_val: Vector3 = anim.track_get_key_value(t, k)
						var delta: Vector3 = old_val - ganyu_rest_hips
						var new_val: Vector3 = target_rest_hips + delta
						anim.track_set_key_value(t, k, new_val)
						
		controller.player.stop()
		controller.player.play("idle")
		for f in 5: await physics_frame
		
		print("\n=== Character: ", char_id, " ===")
		print("Hips global Y: ", skel.get_bone_global_pose(hips).origin.y)
		print("LeftToes global Y: ", skel.get_bone_global_pose(l_toes).origin.y if l_toes >= 0 else -1)
		print("RightToes global Y: ", skel.get_bone_global_pose(r_toes).origin.y if r_toes >= 0 else -1)
		
	quit(0)
