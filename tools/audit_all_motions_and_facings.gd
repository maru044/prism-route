@tool
extends SceneTree

const CATALOG_PATH := "res://assets/characters/mmd_validation/paired/catalog.json"
const SHARED_ACTOR_SCENE := preload("res://scenes/characters/shared_humanoid_actor.tscn")
const ACTOR_SCENE := preload("res://scenes/characters/keqing_mmd_vrm.tscn")

func _init() -> void:
	print("Starting comprehensive motion facing & role audit...")
	var f := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if not f:
		print("Failed to open catalog")
		quit(1)
		return
	var cat: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	
	var packs: Array = cat.get("packs", [])
	print("Total packs: %d" % packs.size())
	
	for pack in packs:
		var pid: String = pack.get("id", "")
		var title: String = pack.get("title_zh", pack.get("label", ""))
		var roles: Array = pack.get("roles", [])
		var prop: String = pack.get("placement", {}).get("prop_needed", "none")
		var ptype: String = pack.get("placement", {}).get("type", "ground")
		
		print("\n==================================================")
		print("PACK: [%s] %s (Roles: %d, Prop: %s, Type: %s)" % [pid, title, roles.size(), prop, ptype])
		
		# Instantiate actors
		var root := Node3D.new()
		root_node_to_tree(root)
		
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
			
		# Wait for initialization
		for inst in actor_instances.values():
			if not inst.ready_for_review:
				await inst.initialized
				
		# Sample at frame 0, middle frame, and last frame
		var duration: float = float(pack.get("duration", 1.0))
		for sample_t in [0.0, duration * 0.5]:
			print("--- Sample at t = %.2f s ---" % sample_t)
			for inst in actor_instances.values():
				inst.seek(sample_t)
			
			for rid in actor_instances:
				var inst: Node3D = actor_instances[rid]
				var skel: Skeleton3D = inst.skeleton
				var hips_idx := skel.find_bone("Hips")
				if hips_idx < 0: hips_idx = skel.find_bone("下半身")
				var chest_idx := skel.find_bone("Chest")
				if chest_idx < 0: chest_idx = skel.find_bone("上半身")
				var head_idx := skel.find_bone("Head")
				if head_idx < 0: head_idx = skel.find_bone("頭")
				
				var hips_world: Vector3 = skel.global_transform * skel.get_bone_global_pose(hips_idx).origin if hips_idx >= 0 else inst.global_position
				var chest_world: Vector3 = skel.global_transform * skel.get_bone_global_pose(chest_idx).origin if chest_idx >= 0 else inst.global_position
				var head_world: Vector3 = skel.global_transform * skel.get_bone_global_pose(head_idx).origin if head_idx >= 0 else inst.global_position
				
				# Determine facing direction:
				# In humanoid skeleton, chest or head forward vector:
				# Local Z or local -Z depending on bone rest pose
				var hips_trans: Transform3D = skel.global_transform * skel.get_bone_global_pose(hips_idx) if hips_idx >= 0 else inst.global_transform
				# VRM humanoid forward is typically +Z or -Z:
				var fwd: Vector3 = -hips_trans.basis.z # in Godot -Z is forward
				var facing_deg: float = rad_to_deg(atan2(fwd.x, fwd.z))
				
				# Also check feet or knee position to see if kneeling or seated or standing
				var l_knee_idx := skel.find_bone("LeftLowerLeg")
				var l_foot_idx := skel.find_bone("LeftFoot")
				var l_knee_y: float = (skel.global_transform * skel.get_bone_global_pose(l_knee_idx).origin).y if l_knee_idx >= 0 else 0.0
				var l_foot_y: float = (skel.global_transform * skel.get_bone_global_pose(l_foot_idx).origin).y if l_foot_idx >= 0 else 0.0
				
				print("  Role %s: Hips=(%.3f, %.3f, %.3f) Chest=(%.3f, %.3f, %.3f) Head=(%.3f, %.3f, %.3f)" % [
					rid, hips_world.x, hips_world.y, hips_world.z,
					chest_world.x, chest_world.y, chest_world.z,
					head_world.x, head_world.y, head_world.z
				])
				print("          Facing forward vector=(%.2f, %.2f, %.2f) (Yaw deg: %.1f°), Knee Y=%.2f, Foot Y=%.2f" % [
					fwd.x, fwd.y, fwd.z, facing_deg, l_knee_y, l_foot_y
				])
				
		root.queue_free()
		await process_frame
		
	print("\nAudit completed!")
	quit(0)

func root_node_to_tree(node: Node) -> void:
	get_root().add_child(node)
