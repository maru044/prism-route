extends CharacterBody3D
const SURFACE_MOTION := preload("res://scripts/surface_motion.gd")
const MTOON_MATERIALS := preload("res://scripts/characters/mtoon_materials.gd")
const WETNESS := preload("res://scripts/characters/character_wetness.gd")
## Basic camera-relative world controller using Ganyu's reviewed baked clips.

const MOTIONS := {"idle": "A01", "walk": "A05", "run": "A06", "jump_start": "A18", "jump_air": "A19", "jump_land": "A20", "greet": "A25"}
const MOTION_LABELS := {"idle": "待机", "walk": "步行", "run": "奔跑", "jump_start": "起跳", "jump_air": "空中", "jump_land": "落地", "greet": "招呼"}
@export var walking_speed := 1.6
@export var running_speed := 4.2
@export var jump_speed := 7.0
@export var gravity_strength := 22.0
@export var surface_step_height := 0.0
@export var use_mtoon := true
@onready var visual: Node3D = $Visual
@onready var character: Node3D = $Visual/GanyuModel
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var animation_state := ""
var respawn_transform := Transform3D.IDENTITY
var automation_enabled := false
var test_move := Vector2.ZERO
var test_running := false
var test_jump := false
var dragging_camera := false
var jump_requested := false
var jump_time := 1.0
var landing_time := 0.0
var greeting := false
var mtoon_report: Dictionary = {}
var wetness: Node

func _ready() -> void:
	if use_mtoon:
		mtoon_report = MTOON_MATERIALS.apply(character)
		if not mtoon_report.skipped.is_empty(): push_warning("MToon kept unmapped source materials: " + str(mtoon_report.skipped))
		wetness = WETNESS.new()
		wetness.name = "CharacterWetness"
		wetness.bind(self,character)
		add_child(wetness)
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(48)
	respawn_transform = global_transform
	spring_arm.add_excluded_object(get_rid())
	skeleton = character.find_child("GeneralSkeleton", true, false)
	skeleton.motion_scale = 1.0
	var original: AnimationPlayer = character.find_child("AnimationPlayer", true, false)
	if original:
		original.stop()
	skeleton.reset_bone_poses()
	player = AnimationPlayer.new()
	player.name = "WorldMotionPlayer"
	# AnimationMixer physics callback: keep poses in step with body movement.
	player.callback_mode_process = 0
	character.add_child(player)
	var library := AnimationLibrary.new()
	for state: String in MOTIONS:
		var animation: Animation = load("res://assets/characters/motion_review/%s.tres" % MOTIONS[state]).duplicate(true)
		animation.loop_mode = Animation.LOOP_LINEAR if state in ["idle", "walk", "run", "jump_air"] else Animation.LOOP_NONE
		_center_clip(animation)
		library.add_animation(state, animation)
	player.add_animation_library("", library)
	player.animation_finished.connect(func(state: StringName):
		if state == "greet": greeting = false)
	_set_animation("idle")
	_reset_springs.call_deferred()

func _center_clip(animation: Animation) -> void:
	# Keep the reviewed pelvic sway and vertical pose; remove only its constant
	# horizontal anchor. Translation through the world belongs to this body.
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D or not str(animation.track_get_path(track)).ends_with(":Hips"):
			continue
		var count := animation.track_get_key_count(track)
		var anchor := Vector3.ZERO
		for key in count:
			anchor += animation.track_get_key_value(track, key) / float(count)
		anchor.y = 0
		for key in count:
			animation.track_set_key_value(track, key, animation.track_get_key_value(track, key) - anchor)

func _physics_process(delta: float) -> void:
	var movement := test_move if automation_enabled else Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var running := test_running if automation_enabled else Input.is_physical_key_pressed(KEY_SHIFT)
	if automation_enabled and test_jump:
		jump_requested = true
		test_jump = false
	var was_grounded := is_on_floor()
	var jumped := false
	if jump_requested and was_grounded:
		velocity.y = jump_speed
		jump_time = 0
		landing_time = 0
		greeting = false
		jumped = true
	elif was_grounded:
		velocity.y = -0.5
	else:
		velocity.y -= gravity_strength * delta
	jump_requested = false
	jump_time += delta
	landing_time = maxf(0.0, landing_time - delta)
	var direction := camera_pivot.global_basis * Vector3(movement.x, 0, movement.y)
	direction.y = 0
	direction = direction.normalized() * minf(movement.length(), 1.0)
	var desired := direction * (running_speed if running else walking_speed)
	var acceleration := 12.0 if was_grounded else 6.0
	velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
	if direction.length_squared() > 0.001:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), minf(delta * 12, 1))
		greeting = false
	SURFACE_MOTION.move(self,delta,surface_step_height)
	if not was_grounded and is_on_floor():
		landing_time = 0.22
	var speed := Vector2(velocity.x, velocity.z).length()
	if jumped or not is_on_floor():
		_set_animation("jump_start" if jump_time < 0.14 else "jump_air")
	elif landing_time > 0:
		_set_animation("jump_land")
	elif speed > 0.12:
		_set_animation("run" if running else "walk")
	elif greeting:
		_set_animation("greet")
	else:
		_set_animation("idle")
	if animation_state in ["walk", "run"]:
		player.speed_scale = clampf(speed / (running_speed if animation_state == "run" else walking_speed), 0.6, 1.35)
	else:
		player.speed_scale = 1
	if global_position.y < -25:
		reset_to_respawn()

func _set_animation(state: String) -> void:
	if animation_state == state:
		return
	animation_state = state
	player.play(state, 0.14)

func set_control_enabled(enabled: bool) -> void:
	set_physics_process(enabled)
	set_process_unhandled_input(enabled)
	dragging_camera = false
	if not enabled:
		velocity = Vector3.ZERO
		jump_requested = false

func set_spawn(point: Vector3, heading: float) -> void:
	global_position = point
	rotation = Vector3.ZERO
	visual.rotation = Vector3(0, heading + PI, 0)
	camera_pivot.rotation = Vector3(-0.16, heading, 0)
	velocity = Vector3.ZERO
	respawn_transform = Transform3D(Basis(Vector3.UP, heading), point)
	jump_time = 1
	landing_time = 0
	greeting = false
	_set_animation("idle")
	_reset_springs.call_deferred()

func reset_to_respawn() -> void:
	if wetness != null: wetness.reset()
	set_spawn(respawn_transform.origin, respawn_transform.basis.get_euler().y)

func _reset_springs() -> void:
	var controller = character.find_child("VRMSpringBoneController", true, false)
	var simulation = skeleton.get_node_or_null("VRMSpringBoneSimulation")
	if controller and simulation:
		simulation.setup(controller.spring_bones, controller.collider_groups)
		simulation.active = true

func get_speed_kph() -> float:
	return Vector2(velocity.x, velocity.z).length() * 3.6

func get_motion_label() -> String:
	return MOTION_LABELS.get(animation_state, "待机")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode if event.physical_keycode != 0 else event.keycode:
			KEY_SPACE: jump_requested = true
			KEY_R: reset_to_respawn()
			KEY_G: greeting = is_on_floor()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging_camera = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			spring_arm.spring_length = clampf(spring_arm.spring_length + (0.4 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -0.4), 1.8, 10.0)
	if event is InputEventMouseMotion and dragging_camera:
		camera_pivot.rotation.y -= event.relative.x * 0.004
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - event.relative.y * 0.003, -0.72, 0.45)
