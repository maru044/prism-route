@tool
extends SceneTree

const MOTIONS := {"idle": "A01", "walk": "A05", "run": "A06", "jump_start": "A18", "jump_air": "A19", "jump_land": "A20", "greet": "A25"}
const SOURCE_REST_HIPS := Vector3(0.0, 0.661507, 0.0)

func _retarget_and_center_clip(animation: Animation, target_skeleton: Skeleton3D, skel_path: NodePath) -> void:
	var hips_idx: int = target_skeleton.find_bone("Hips")
	var target_rest_hips: Vector3 = target_skeleton.get_bone_rest(hips_idx).origin if hips_idx >= 0 else SOURCE_REST_HIPS
	
	for track in animation.get_track_count():
		var original_path: String = str(animation.track_get_path(track))
		var colon_idx: int = original_path.find(":")
		if colon_idx != -1:
			var bone_part: String = original_path.substr(colon_idx)
			animation.track_set_path(track, NodePath(str(skel_path) + bone_part))
		
		if animation.track_get_type(track) == Animation.TYPE_POSITION_3D and original_path.ends_with(":Hips"):
			var count: int = animation.track_get_key_count(track)
			if count == 0:
				continue
			
			for key in count:
				var old_val: Vector3 = animation.track_get_key_value(track, key)
				var delta: Vector3 = old_val - SOURCE_REST_HIPS
				var new_val: Vector3 = target_rest_hips + delta
				animation.track_set_key_value(track, key, new_val)
			
			var avg_xz := Vector2.ZERO
			for key in count:
				var val: Vector3 = animation.track_get_key_value(track, key)
				avg_xz += Vector2(val.x, val.z) / float(count)
			
			var offset_x: float = avg_xz.x - target_rest_hips.x
			var offset_z: float = avg_xz.y - target_rest_hips.z
			for key in count:
				var val: Vector3 = animation.track_get_key_value(track, key)
				val.x -= offset_x
				val.z -= offset_z
				animation.track_set_key_value(track, key, val)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var world_scene = load("res://scenes/characters/world_ganyu.tscn")
	var controller = world_scene.instantiate()
	root.add_child(controller)
	
	var all_ok := true
	for char_id in ["ganyu", "stelle", "lumine", "firefly"]:
		controller.switch_character(char_id)
		var skel: Skeleton3D = controller.skeleton
		var skel_path: NodePath = controller.character.get_path_to(skel)
		
		# Replace player animations with retargeted ones
		for state in MOTIONS:
			var raw_anim: Animation = load("res://assets/characters/motion_review/%s.tres" % MOTIONS[state])
			var anim: Animation = raw_anim.duplicate(true)
			_retarget_and_center_clip(anim, skel, skel_path)
			controller.player.get_animation_library("").add_animation(state, anim)
			
		var l_toes = skel.find_bone("LeftToes")
		var r_toes = skel.find_bone("RightToes")
		var l_foot = skel.find_bone("LeftFoot")
		var r_foot = skel.find_bone("RightFoot")
		
		print("\n================== Character: ", char_id, " ==================")
		for state in ["idle", "walk", "run"]:
			controller.player.stop()
			controller.player.play(state)
			for f in 6: await physics_frame
			
			var l_t_y = skel.get_bone_global_pose(l_toes).origin.y if l_toes >= 0 else 0.0
			var r_t_y = skel.get_bone_global_pose(r_toes).origin.y if r_toes >= 0 else 0.0
			var min_toe_y = min(l_t_y, r_t_y)
			print(state.rpad(6), " -> LeftToes Y: ", "%0.3f" % l_t_y, " RightToes Y: ", "%0.3f" % r_t_y, " (min: %0.3f)" % min_toe_y)
			if min_toe_y > 0.15:
				all_ok = false
				push_error("Character %s still floating in %s! min_toe_y = %f" % [char_id, state, min_toe_y])
				
	print("\nALL TEST RESULT OK: ", all_ok)
	quit(0 if all_ok else 1)
