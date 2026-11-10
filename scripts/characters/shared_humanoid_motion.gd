extends Node3D
const HUMANOID_RIG := preload("res://scripts/characters/humanoid_rig.gd")
## Immutable shared clip; per-instance rest calibration and physics state only.
signal initialized
@export_file("*.vrm") var model_resource := ""
@export_file("*.tres", "*.res") var motion_resource := ""
@export_file("*.json") var profile_resource := ""
@export var auto_play := false
@export_enum("height_scaled", "shared_world") var translation_policy := "height_scaled"
@export_flags_3d_physics var environment_mask: int = 1
var character: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var motion: Animation
var duration := 0.0
var time := 0.0
var ready_for_review := false
var is_active_playback: bool = true
var simulation: SkeletonModifier3D
var controller: Node
var all_springs: Array = []
var collider_groups: Array = []
var physical_indices: Array[int] = []
var simulation_steps := 0
var simulation_reset_count := 0
var last_physics_globals := {}
var last_physics_rotations := {}
var semantic_bones := {}
var rotation_tracks := {}
var translation_track := -1
var rest_local: Array[Transform3D] = []
var rest_world: Array[Transform3D] = []
var parents: Array[int] = []
var bone_order: Array[int] = []
var target_height := 1.0
var translation_scale := 1.0
var pelvis := -1
var body_root := -1
var root_displacement := Vector3.ZERO
var _model_origin := Vector3.ZERO
var _skeleton_in_actor := Transform3D.IDENTITY

func _ready() -> void:
	motion = load(motion_resource) as Animation
	assert(motion != null and motion.get_meta("shared_humanoid_schema", 0) == 1)
	duration = motion.length
	character = load(model_resource).instantiate()
	add_child(character)
	skeleton = character.find_child("GeneralSkeleton", true, false)
	assert(skeleton != null)
	var original: AnimationPlayer = character.find_child("AnimationPlayer", true, false)
	if original: original.stop()
	skeleton.motion_scale = 1.0 # This sampler applies explicit translation policy once.
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE
	for i in skeleton.get_bone_count():
		parents.append(skeleton.get_bone_parent(i))
		rest_local.append(skeleton.get_bone_rest(i))
		rest_world.append(skeleton.get_bone_global_rest(i))
	for i in skeleton.get_parentless_bones(): _append_order(i)
	var rig := HUMANOID_RIG.new()
	if not rig.setup(skeleton):
		push_error("Invalid humanoid rig")
		return
	semantic_bones = rig.semantic_bones.duplicate()
	for name in ["Hips", "Spine", "Head", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot"]:
		assert(semantic_bones.has(name), "Missing required humanoid bone: " + name)
	pelvis = rig.pelvis
	body_root = rig.body_root
	assert(pelvis >= 0 and body_root >= 0)
	semantic_bones.Hips = pelvis
	semantic_bones.BodyRoot = body_root
	target_height = absf(rest_world[pelvis].origin.y)
	assert(target_height > .1)
	translation_scale = target_height / float(motion.get_meta("reference_height")) if translation_policy == "height_scaled" else 1.0
	for track in motion.get_track_count():
		var semantic := String(motion.track_get_path(track).get_subname(0))
		if motion.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			rotation_tracks[semantic] = track
		elif motion.track_get_type(track) == Animation.TYPE_POSITION_3D:
			assert(semantic == "Hips" and translation_track == -1)
			translation_track = track
	assert(translation_track >= 0)
	_model_origin = character.position
	_skeleton_in_actor = global_transform.affine_inverse() * skeleton.global_transform
	controller = character.find_child("VRMSpringBoneController", true, false)
	if controller:
		controller.process_mode = Node.PROCESS_MODE_DISABLED
		collider_groups = controller.collider_groups
		for spring in controller.spring_bones:
			var copy: Resource = spring.duplicate(false)
			copy.enable_environment_collision = true
			copy.environment_collision_mask = environment_mask
			all_springs.append(copy)
			for bone_name in copy.joint_nodes:
				var index := skeleton.find_bone(bone_name)
				if index >= 0 and not physical_indices.has(index): physical_indices.append(index)
	await get_tree().process_frame
	await get_tree().process_frame
	simulation = skeleton.get_node_or_null("VRMSpringBoneSimulation")
	for child in skeleton.get_children():
		if child is SkeletonModifier3D and child != simulation: child.active = false
	if simulation: simulation.modification_processed.connect(_capture_physics_pose)
	ready_for_review = true
	set_physics_enabled(true, true)
	if not is_active_playback:
		set_process(false)
		if simulation:
			simulation.active = false
	initialized.emit()

func _append_order(index: int) -> void:
	bone_order.append(index)
	for child in skeleton.get_bone_children(index): _append_order(child)

func sample_time(value: float) -> void:
	time = clampf(value, 0.0, duration)
	skeleton.reset_bone_poses()
	var desired := {}
	# BodyRoot may coincide with the pelvis on conventional humanoid rigs.
	for semantic in ["BodyRoot"] + rotation_tracks.keys().filter(func(n): return n != "BodyRoot" and n != "Hips") + ["Hips"]:
		if not semantic_bones.has(semantic) or not rotation_tracks.has(semantic): continue
		var index: int = semantic_bones[semantic]
		var delta := motion.rotation_track_interpolate(rotation_tracks[semantic], time)
		desired[index] = (delta * rest_world[index].basis.get_rotation_quaternion()).normalized()
	var current: Array[Transform3D] = []
	current.resize(rest_local.size())
	var current_rotations: Array[Quaternion] = []
	current_rotations.resize(rest_local.size())
	for index in bone_order:
		var parent := Transform3D.IDENTITY if parents[index] < 0 else current[parents[index]]
		var parent_rotation := Quaternion.IDENTITY if parents[index] < 0 else current_rotations[parents[index]]
		var local := rest_local[index]
		var local_rotation := rest_local[index].basis.get_rotation_quaternion()
		if desired.has(index):
			var rotation: Quaternion = (parent_rotation.inverse() * desired[index]).normalized()
			local.basis = Basis(rotation).scaled(rest_local[index].basis.get_scale())
			skeleton.set_bone_pose_rotation(index, rotation)
			local_rotation=rotation
		current[index] = parent * local
		current_rotations[index]=(parent_rotation*local_rotation).normalized()
	var displacement := motion.position_track_interpolate(translation_track, time) * translation_scale
	var desired_pelvis := rest_world[pelvis].origin + displacement
	root_displacement = desired_pelvis - current[pelvis].origin
	character.position = _model_origin + _skeleton_in_actor.basis * root_displacement
	skeleton.force_update_all_bone_transforms()

func seek(value: float) -> void:
	sample_time(value)
	if simulation:
		simulation_reset_count += 1
		simulation.setup(_active_springs, collider_groups)
		simulation.set_enable_body_collisions(true)
		simulation.set_environment_collision_enabled(true)
		simulation.set_environment_collision_mask(environment_mask)
		simulation.active = not _active_springs.is_empty()

var _active_springs: Array = []
func set_physics_enabled(hair: bool, clothes: bool) -> void:
	_active_springs.clear()
	for spring in all_springs:
		var is_hair: bool = spring.group.to_lower().contains("hair") or spring.comment.begins_with("Hair") or spring.comment.begins_with("SideHair")
		if (is_hair and hair) or (not is_hair and clothes): _active_springs.append(spring)
	if ready_for_review: seek(time)

func _capture_physics_pose() -> void:
	simulation_steps += 1
	for index in physical_indices:
		last_physics_globals[index] = skeleton.get_bone_global_pose(index)
		last_physics_rotations[index] = skeleton.get_bone_pose_rotation(index)

func set_playback_active(active: bool) -> void:
	is_active_playback = active
	set_process(active)
	if simulation:
		simulation.active = active and not _active_springs.is_empty()
	if not active and skeleton:
		skeleton.reset_bone_poses()

func _process(delta: float) -> void:
	if not is_active_playback:
		return
	if ready_for_review and auto_play:
		sample_time(fmod(time + delta, duration) if duration > 0.0 else 0.0)

func set_motion(res_path: String) -> bool:
	var new_motion := load(res_path) as Animation
	if new_motion == null or new_motion.get_meta("shared_humanoid_schema", 0) != 1:
		push_warning("Failed to load valid shared humanoid motion: " + res_path)
		return false
	motion_resource = res_path
	motion = new_motion
	duration = motion.length
	time = 0.0
	translation_scale = target_height / float(motion.get_meta("reference_height")) if translation_policy == "height_scaled" else 1.0
	rotation_tracks.clear()
	translation_track = -1
	for track in motion.get_track_count():
		var semantic := String(motion.track_get_path(track).get_subname(0))
		if motion.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			rotation_tracks[semantic] = track
		elif motion.track_get_type(track) == Animation.TYPE_POSITION_3D:
			if semantic == "Hips" and translation_track == -1:
				translation_track = track
	if ready_for_review:
		seek(0.0)
	return true
