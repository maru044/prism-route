extends Node3D
## Existing VRM mesh/materials, retargeted body animation and native spring bones.
signal initialized
const MODEL := "res://assets/characters/mmd_validation/keqing_physics.vrm"
const MOTION := "res://assets/characters/mmd_validation/keqing_vrm_loop03.tres"
const BUILD_REPORT := "res://assets/characters/mmd_validation/keqing_vrm_build_report.json"
@export var auto_play := true
@export_file("*.vrm") var model_resource := MODEL
@export_file("*.tres") var motion_resource := MOTION
@export_file("*.json") var profile_resource := BUILD_REPORT
@export_flags_3d_physics var environment_mask: int = 1
var duration := 16.0
var character: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var simulation: SkeletonModifier3D
var controller: Node
var ready_for_review := false
var time := 0.0
var hair_enabled := true
var clothes_enabled := true
var physical_indices: Array[int] = []
var all_springs: Array = []
var active_springs: Array = []
var collider_groups: Array = []
var last_physics_rotations := {}
var last_physics_globals := {}
var simulation_steps := 0

func _ready() -> void:
	character = load(model_resource).instantiate()
	add_child(character)
	skeleton = character.find_child("GeneralSkeleton", true, false)
	skeleton.motion_scale = 1.0
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE
	var original: AnimationPlayer = character.find_child("AnimationPlayer", true, false)
	if original: original.stop()
	controller = character.find_child("VRMSpringBoneController", true, false)
	controller.process_mode = Node.PROCESS_MODE_DISABLED
	player = AnimationPlayer.new()
	player.name = "MMDRetargetedPlayer"
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	character.add_child(player)
	var library := AnimationLibrary.new()
	var motion: Animation = load(motion_resource)
	duration = motion.length
	library.add_animation("loop03", motion)
	player.add_animation_library("mmd", library)
	player.play("mmd/loop03")
	await get_tree().process_frame
	await get_tree().process_frame
	simulation = skeleton.get_node("VRMSpringBoneSimulation")
	simulation.modification_processed.connect(_capture_physics_pose)
	for child in skeleton.get_children():
		if child is SkeletonModifier3D and child != simulation: child.active = false
	var report = JSON.parse_string(FileAccess.get_file_as_string(profile_resource))
	assert(skeleton.get_bone_count() == int(report.target_bones), "Target rest profile changed")
	for name in report.physics_bones:
		var index := skeleton.find_bone(name)
		assert(index >= 0, "Missing spring bone: " + name)
		physical_indices.append(index)
	for spring in controller.spring_bones:
		# Keep collider-group resource identity shared with the simulation's library.
		var copy: Resource = spring.duplicate(false)
		copy.enable_environment_collision = true
		copy.environment_collision_mask = environment_mask
		all_springs.append(copy)
	collider_groups = controller.collider_groups
	ready_for_review = true
	set_physics_enabled(true, true)
	seek(0.0)
	initialized.emit()

func _process(delta: float) -> void:
	if auto_play and ready_for_review and time < duration: advance_animation(delta)

func _reset_physical_poses() -> void:
	for index in physical_indices:
		var rest := skeleton.get_bone_rest(index)
		skeleton.set_bone_pose_position(index, rest.origin)
		skeleton.set_bone_pose_rotation(index, rest.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(index, rest.basis.get_scale())

func _configure_simulation() -> void:
	_reset_physical_poses()
	active_springs.clear()
	for spring in all_springs:
		var is_hair: bool = spring.comment.begins_with("Hair ") or spring.comment.begins_with("SideHair ")
		if (is_hair and hair_enabled) or (not is_hair and clothes_enabled): active_springs.append(spring)
	simulation.setup(active_springs, collider_groups)
	simulation.set_enable_body_collisions(true)
	simulation.set_environment_collision_enabled(true)
	simulation.set_environment_collision_mask(environment_mask)
	simulation.set_environment_collision_bounce_damping(0.9)
	simulation.active = not active_springs.is_empty()

func set_physics_enabled(hair: bool, clothes: bool) -> void:
	hair_enabled = hair
	clothes_enabled = clothes
	if not ready_for_review: return
	_configure_simulation()

func _capture_physics_pose() -> void:
	simulation_steps += 1
	for index in physical_indices:
		last_physics_rotations[index] = skeleton.get_bone_pose_rotation(index)
		last_physics_globals[index] = skeleton.get_bone_global_pose(index)

func seek(value: float) -> void:
	time = clampf(value, 0.0, duration)
	skeleton.reset_bone_poses()
	player.seek(time, true)
	if ready_for_review:
		_configure_simulation()
	skeleton.force_update_all_bone_transforms()

func advance_animation(delta: float) -> void:
	sample_time(time + minf(delta, 0.1))

func sample_time(value: float) -> void:
	time = clampf(value, 0.0, duration)
	_reset_physical_poses()
	player.seek(time, true)
