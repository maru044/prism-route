@tool
extends SceneTree

func _init() -> void:
	var anim_a: Animation = load("res://assets/characters/mmd_selected/animations/mmd_781d8c87fd79_a.tres")
	var anim_b: Animation = load("res://assets/characters/mmd_selected/animations/mmd_781d8c87fd79_b.tres")
	
	print("=== Welcome - BJV2 2021 Uptade Animation Analysis ===")
	print("Length: ", anim_a.length, "s")
	
	for sec in [0.0, 1.0, 5.0, 10.92, 20.0]:
		print("\n--- Time: %.2fs ---" % sec)
		# Find tracks
		for t in range(anim_a.get_track_count()):
			var p := str(anim_a.track_get_path(t))
			if p.to_lower().contains("hips") and anim_a.track_get_type(t) == Animation.TYPE_POSITION_3D:
				var pos := anim_a.position_track_interpolate(t, sec)
				print("  Role A Hips Pos: ", pos)
			if p.to_lower().contains("hips") and anim_a.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				var rot := anim_a.rotation_track_interpolate(t, sec)
				print("  Role A Hips Rot (euler deg): ", Vector3(rad_to_deg(rot.get_euler().x), rad_to_deg(rot.get_euler().y), rad_to_deg(rot.get_euler().z)))
		for t in range(anim_b.get_track_count()):
			var p := str(anim_b.track_get_path(t))
			if p.to_lower().contains("hips") and anim_b.track_get_type(t) == Animation.TYPE_POSITION_3D:
				var pos := anim_b.position_track_interpolate(t, sec)
				print("  Role B Hips Pos: ", pos)
			if p.to_lower().contains("hips") and anim_b.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				var rot := anim_b.rotation_track_interpolate(t, sec)
				print("  Role B Hips Rot (euler deg): ", Vector3(rad_to_deg(rot.get_euler().x), rad_to_deg(rot.get_euler().y), rad_to_deg(rot.get_euler().z)))
				
	quit(0)
