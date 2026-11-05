@tool
extends SceneTree

const CATALOG_PATH := "res://assets/characters/mmd_validation/paired/catalog.json"
const SHARED_ACTOR_SCENE := preload("res://scenes/characters/shared_humanoid_actor.tscn")

func _init() -> void:
	print("Analyzing Role B motion trajectory for Welcome - BJV2 (mmd_781d8c87fd79)...")
	var f := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	var cat: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	
	var target_pack: Dictionary = {}
	for p in cat.get("packs", []):
		if p.get("id") == "mmd_781d8c87fd79":
			target_pack = p
			break
			
	if target_pack.is_empty():
		print("Pack not found!")
		quit(1)
		return
		
	var root := Node3D.new()
	get_root().add_child(root)
	
	var role_b: Dictionary = target_pack.roles[1]
	var inst: Node3D = SHARED_ACTOR_SCENE.instantiate()
	inst.auto_play = false
	inst.model_resource = role_b.model
	inst.motion_resource = role_b.motion
	inst.profile_resource = role_b.report
	root.add_child(inst)
	
	if not inst.ready_for_review:
		await inst.initialized
		
	var duration: float = float(target_pack.duration)
	var skel: Skeleton3D = inst.skeleton
	
	var hips_idx := skel.find_bone("Hips")
	var chest_idx := skel.find_bone("UpperChest")
	if chest_idx < 0: chest_idx = skel.find_bone("Chest")
	var neck_idx := skel.find_bone("Neck")
	var head_idx := skel.find_bone("Head")
	
	# Sample at 0s, 10s, 26s (frame 782), 40s, 60s
	for t in [0.0, 5.0, 11.0, 26.06, 40.0, 60.0]:
		inst.seek(t)
		var h_pos = skel.global_transform * skel.get_bone_global_pose(hips_idx).origin if hips_idx >= 0 else Vector3.ZERO
		var c_pos = skel.global_transform * skel.get_bone_global_pose(chest_idx).origin if chest_idx >= 0 else Vector3.ZERO
		var n_pos = skel.global_transform * skel.get_bone_global_pose(neck_idx).origin if neck_idx >= 0 else Vector3.ZERO
		var hd_pos = skel.global_transform * skel.get_bone_global_pose(head_idx).origin if head_idx >= 0 else Vector3.ZERO
		
		# Angle of spine (Hips to Neck) relative to vertical:
		var spine_vec: Vector3 = n_pos - h_pos
		var spine_angle_deg: float = rad_to_deg(atan2(-spine_vec.z, spine_vec.y))
		
		print("Time %.2fs: Hips Y=%.3f, Z=%.3f | Neck Y=%.3f, Z=%.3f | Head Y=%.3f, Z=%.3f | Recline Angle = %.1f deg" % [
			t, h_pos.y, h_pos.z, n_pos.y, n_pos.z, hd_pos.y, hd_pos.z, spine_angle_deg
		])
		
	quit(0)
