extends RefCounted
## Shared interpretation of imported humanoid bones; never changes a source rig.
var skeleton: Skeleton3D
var semantic_bones: Dictionary = {}
var parents: Array[int] = []
var order: Array[int] = []
var rest_local: Array[Transform3D] = []
var rest_world: Array[Transform3D] = []
var pelvis := -1
var body_root := -1
var center := -1

func setup(target: Skeleton3D) -> bool:
	skeleton = target
	pelvis = -1; body_root = -1; center = -1
	semantic_bones.clear()
	parents.clear(); order.clear(); rest_local.clear(); rest_world.clear()
	for i in target.get_bone_count():
		parents.append(target.get_bone_parent(i))
		rest_local.append(target.get_bone_rest(i))
		rest_world.append(target.get_bone_global_rest(i))
	for i in target.get_parentless_bones(): _append_order(i)
	var profile := SkeletonProfileHumanoid.new()
	for i in profile.bone_size:
		var name: String = profile.get_bone_name(i)
		var index := target.find_bone(name)
		if index >= 0: semantic_bones[name] = index
	for name in ["Hips", "Spine", "LeftUpperLeg", "RightUpperLeg"]:
		if not semantic_bones.has(name): return false
	pelvis = lca(semantic_bones.LeftUpperLeg, semantic_bones.RightUpperLeg)
	body_root = lca(pelvis, semantic_bones.Spine)
	if pelvis < 0 or body_root < 0 or rest_world[pelvis].origin.y <= 0.1: return false
	var declared: int = semantic_bones.Hips
	center = target.find_bone("センター")
	if center < 0 or lca(center, body_root) != center:
		center = declared if lca(declared, body_root) == declared else body_root
	semantic_bones.Hips = pelvis
	semantic_bones.BodyRoot = body_root
	for side in ["Left", "Right"]:
		for pair in [["LowerArm", "UpperArm", "UpperArmTwist"], ["Hand", "LowerArm", "ForearmTwist"]]:
			if not semantic_bones.has(side + pair[0]) or not semantic_bones.has(side + pair[1]): continue
			var index: int = parents[semantic_bones[side + pair[0]]]
			var stop: int = semantic_bones[side + pair[1]]
			while index >= 0 and index != stop:
				var name := target.get_bone_name(index)
				if name.contains("捩") or name.to_lower().contains("twist"):
					semantic_bones[side + pair[2]] = index
					break
				index = parents[index]
	return true

func _append_order(index: int) -> void:
	order.append(index)
	for child in skeleton.get_bone_children(index): _append_order(child)

func lca(a: int, b: int) -> int:
	var ancestors: Dictionary = {}
	while a >= 0:
		ancestors[a] = true
		a = parents[a]
	while b >= 0 and not ancestors.has(b): b = parents[b]
	return b

func physical_index(role: String) -> int:
	# The physical root must be an ancestor of BOTH the torso and leg branches.
	return body_root if role == "Hips" else int(semantic_bones.get(role, -1))

func capture_pose(model_offset := Vector3.ZERO) -> Dictionary:
	var globals: Array[Transform3D] = []
	for i in rest_local.size(): globals.append(skeleton.get_bone_global_pose(i))
	return _encode_pose(globals, model_offset)

func _encode_pose(globals: Array[Transform3D], model_offset: Vector3) -> Dictionary:
	var rotations: Dictionary = {}
	for role: String in semantic_bones:
		if role == "Root": continue # Locomotion belongs to the model root.
		var i: int = semantic_bones[role]
		var q := (globals[i].basis.get_rotation_quaternion() * rest_world[i].basis.get_rotation_quaternion().inverse()).normalized()
		rotations[role] = [q.x, q.y, q.z, q.w]
	var displacement := globals[pelvis].origin + model_offset - rest_world[pelvis].origin
	return {"schema": 1, "rotations": rotations, "pelvis_displacement": [displacement.x, displacement.y, displacement.z], "reference_height": rest_world[pelvis].origin.y}

func convert_legacy_pose(data: Dictionary) -> Dictionary:
	var globals: Array[Transform3D] = []
	globals.resize(rest_local.size())
	var bones: Dictionary = data.get("bones", {})
	for i in order:
		var local := rest_local[i]
		var entry: Dictionary = bones.get(skeleton.get_bone_name(i), {})
		if entry.has("rot"):
			var q: Array = entry.rot
			local.basis = Basis(Quaternion(q[0], q[1], q[2], q[3]).normalized()).scaled(local.basis.get_scale())
		if entry.has("pos"): local.origin = _vector(entry.pos)
		globals[i] = local if parents[i] < 0 else globals[parents[i]] * local
	return _encode_pose(globals, _vector(data.get("character_pos", [0, 0, 0])))

static func pose_payload(data: Dictionary) -> Dictionary:
	if data.has("humanoid_pose"):
		var payload: Dictionary = data.humanoid_pose
		if int(payload.get("schema", 0)) == 1 and payload.has("rotations") and payload.has("pelvis_displacement") and float(payload.get("reference_height", 0)) > 0.1:
			return payload
		return {}
	# Old local snapshots require their actual source, never a guessed bone-count match.
	var source: String = data.get("source_model", "")
	if source.is_empty() or not ResourceLoader.exists(source): return {}
	var model: Node = load(source).instantiate()
	var source_skeleton := model.find_child("GeneralSkeleton", true, false) as Skeleton3D
	var rig = load("res://scripts/characters/humanoid_rig.gd").new()
	if source_skeleton == null or not rig.setup(source_skeleton):
		model.free()
		return {}
	var result: Dictionary = rig.convert_legacy_pose(data)
	model.free()
	return result

func solve_pose(payload: Dictionary, height_scaled := true) -> Dictionary:
	var desired: Dictionary = {}
	var rotations: Dictionary = payload.rotations
	# Same precedence as shared_humanoid_motion.gd when BodyRoot == Hips.
	for role in ["BodyRoot"] + rotations.keys().filter(func(n): return n != "BodyRoot" and n != "Hips") + ["Hips"]:
		if not semantic_bones.has(role) or not rotations.has(role): continue
		var i: int = semantic_bones[role]
		var q: Array = rotations[role]
		desired[i] = (Quaternion(q[0], q[1], q[2], q[3]).normalized() * rest_world[i].basis.get_rotation_quaternion()).normalized()
	var current: Array[Transform3D] = []
	var current_rotations: Array[Quaternion] = []
	current.resize(rest_local.size()); current_rotations.resize(rest_local.size())
	var local_rotations: Dictionary = {}
	for i in order:
		var parent := Transform3D.IDENTITY if parents[i] < 0 else current[parents[i]]
		var parent_rotation := Quaternion.IDENTITY if parents[i] < 0 else current_rotations[parents[i]]
		var local := rest_local[i]
		var q := local.basis.get_rotation_quaternion()
		if desired.has(i): q = (parent_rotation.inverse() * desired[i]).normalized()
		local.basis = Basis(q).scaled(rest_local[i].basis.get_scale())
		local_rotations[i] = q
		current[i] = parent * local
		current_rotations[i] = (parent_rotation * q).normalized()
	var ratio: float = rest_world[pelvis].origin.y / float(payload.reference_height) if height_scaled else 1.0
	var desired_pelvis := rest_world[pelvis].origin + _vector(payload.pelvis_displacement) * ratio
	return {"rotations": local_rotations, "root_displacement": desired_pelvis - current[pelvis].origin, "pelvis_position": desired_pelvis}

func apply_solution(solution: Dictionary) -> void:
	for i in order:
		skeleton.set_bone_pose_position(i, rest_local[i].origin)
		skeleton.set_bone_pose_scale(i, rest_local[i].basis.get_scale())
		skeleton.set_bone_pose_rotation(i, solution.rotations[i])
	skeleton.force_update_all_bone_transforms()

static func _vector(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])
