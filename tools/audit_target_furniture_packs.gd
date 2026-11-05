@tool
extends SceneTree

const CATALOG_PATH := "res://assets/characters/mmd_validation/paired/catalog.json"
const SHARED_ACTOR_SCENE := preload("res://scenes/characters/shared_humanoid_actor.tscn")
const ACTOR_SCENE := preload("res://scenes/characters/keqing_mmd_vrm.tscn")

const TARGET_PACKS := [
	"mmd_781d8c87fd79", # Welcome - BJV2
	"mmd_6e891982bb51", # Loop 02
	"mmd_beee0d2eb57b", # Loop 20 Chikan 03
	"mmd_0a3f6ba5f5de", # Armchair Paizuri
	"mmd_160b1e7a411c", # Lap Sitting
	"mmd_71dec5bd8390", # Loop 03
	"mmd_aec34d147925", # Loop 05
	"mmd_16a2ecfb7781", # BJ in Bed
	"mmd_43916ffe3d35", # Bed Riding
	"mmd_fca4bab1635f"  # Table
]

func _init() -> void:
	print("Starting targeted furniture pack audit...")
	var f := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	var cat: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	
	var packs_by_id := {}
	for pack in cat.get("packs", []):
		packs_by_id[pack.get("id", "")] = pack
		
	for pid in TARGET_PACKS:
		if not packs_by_id.has(pid): continue
		var pack: Dictionary = packs_by_id[pid]
		var title: String = pack.get("title_zh", pack.get("label", ""))
		var roles: Array = pack.get("roles", [])
		
		print("\n--------------------------------------------------")
		print("PACK: [%s] %s (Roles: %d)" % [pid, title, roles.size()])
		
		var root := Node3D.new()
		get_root().add_child(root)
		
		var actor_instances := {}
		for r in roles:
			var rid: String = r.get("id", "")
			var inst: Node3D = (SHARED_ACTOR_SCENE if r.get("shared", false) else ACTOR_SCENE).instantiate()
			inst.name = "Role" + rid
			inst.auto_play = false
			inst.model_resource = r.get("model", "")
			inst.motion_resource = r.get("motion", "")
			inst.profile_resource = r.get("report", "")
			var offset: Array = r.get("presentation_offset", [0, 0, 0])
			inst.position = Vector3(offset[0], offset[1], offset[2])
			root.add_child(inst)
			actor_instances[rid] = inst
			
		for inst in actor_instances.values():
			if not inst.ready_for_review:
				await inst.initialized
				
		var duration: float = float(pack.get("duration", 1.0))
		for sample_t in [0.0, duration * 0.3]:
			print("Time = %.2f s:" % sample_t)
			for inst in actor_instances.values():
				inst.seek(sample_t)
				
			for rid in actor_instances:
				var inst: Node3D = actor_instances[rid]
				var skel: Skeleton3D = inst.skeleton
				var hips_idx := skel.find_bone("Hips")
				if hips_idx < 0: hips_idx = skel.find_bone("下半身")
				var chest_idx := skel.find_bone("Chest")
				if chest_idx < 0: chest_idx = skel.find_bone("上半身")
				var l_knee_idx := skel.find_bone("LeftLowerLeg")
				var r_knee_idx := skel.find_bone("RightLowerLeg")
				var l_foot_idx := skel.find_bone("LeftFoot")
				var r_foot_idx := skel.find_bone("RightFoot")
				
				var hips_pos: Vector3 = skel.global_transform * skel.get_bone_global_pose(hips_idx).origin if hips_idx >= 0 else inst.global_position
				var chest_pos: Vector3 = skel.global_transform * skel.get_bone_global_pose(chest_idx).origin if chest_idx >= 0 else inst.global_position
				var l_knee_pos: Vector3 = skel.global_transform * skel.get_bone_global_pose(l_knee_idx).origin if l_knee_idx >= 0 else Vector3.ZERO
				var r_knee_pos: Vector3 = skel.global_transform * skel.get_bone_global_pose(r_knee_idx).origin if r_knee_idx >= 0 else Vector3.ZERO
				var avg_knee_pos: Vector3 = (l_knee_pos + r_knee_pos) * 0.5
				var l_foot_pos: Vector3 = skel.global_transform * skel.get_bone_global_pose(l_foot_idx).origin if l_foot_idx >= 0 else Vector3.ZERO
				var r_foot_pos: Vector3 = skel.global_transform * skel.get_bone_global_pose(r_foot_idx).origin if r_foot_idx >= 0 else Vector3.ZERO
				var avg_foot_pos: Vector3 = (l_foot_pos + r_foot_pos) * 0.5
				
				# Facing relative to hips:
				var leg_forward_z: float = avg_knee_pos.z - hips_pos.z
				var chest_forward_z: float = chest_pos.z - hips_pos.z
				
				var pose_type := "Standing"
				if avg_knee_pos.y < 0.2 and avg_foot_pos.y < 0.2 and hips_pos.y < 0.45:
					pose_type = "Kneeling on floor (跪地)"
				elif hips_pos.y < 0.35 and chest_pos.y < 0.4:
					pose_type = "Lying flat (仰卧/平躺)"
				elif hips_pos.y > 0.15 and hips_pos.y < 0.65 and avg_knee_pos.y > 0.35:
					pose_type = "Seated on furniture (端坐/坐椅/半躺)"
					
				var facing_dir := "Faces +Z (Front camera)" if leg_forward_z > 0.05 else ("Faces -Z (Backwards)" if leg_forward_z < -0.05 else "Side/Neutral")
				
				print("  Role %s: [%s] Hips=(%.3f, %.3f, %.3f), Knee=(%.3f, %.3f, %.3f), Knee-Hips Z = %.3f => %s" % [
					rid, pose_type, hips_pos.x, hips_pos.y, hips_pos.z, avg_knee_pos.x, avg_knee_pos.y, avg_knee_pos.z, leg_forward_z, facing_dir
				])
				
		root.queue_free()
		await process_frame
		
	print("\nTargeted audit complete!")
	quit(0)
