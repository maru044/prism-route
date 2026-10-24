extends CharacterBody3D
const SURFACE_MOTION := preload("res://scripts/surface_motion.gd")

@export var maximum_forward_speed := 22.0
@export var maximum_reverse_speed := 8.0
@export var acceleration := 8.5
@export var rolling_deceleration := 4.0
@export var brake_deceleration := 18.0
@export var steering_speed := 0.78
@export var gravity_strength := 24.0
@export var surface_step_height := 0.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D

var drive_speed := 0.0
var respawn_transform := Transform3D.IDENTITY
var dragging_camera := false
var respawn_resolver: Callable
var _reset_requested := false


func _ready() -> void:
	floor_snap_length = 1.2
	floor_max_angle = deg_to_rad(48.0)
	respawn_transform = global_transform


func _physics_process(delta: float) -> void:
	var throttle := float(Input.is_key_pressed(KEY_W))
	throttle -= float(Input.is_key_pressed(KEY_S))
	var steering := float(Input.is_key_pressed(KEY_A))
	steering -= float(Input.is_key_pressed(KEY_D))
	var braking := Input.is_key_pressed(KEY_SPACE)
	_step_driving(throttle, steering, braking, delta)


func _step_driving(throttle: float, steering: float, braking: bool, delta: float) -> void:
	if _reset_requested or global_position.y < -25.0:
		_reset_requested = false
		reset_to_respawn()
		return
	var target_speed := 0.0
	if throttle > 0.0:
		target_speed = maximum_forward_speed
	elif throttle < 0.0:
		target_speed = -maximum_reverse_speed

	var change_rate := acceleration if throttle != 0.0 else rolling_deceleration
	if braking:
		target_speed = 0.0
		change_rate = brake_deceleration
	drive_speed = move_toward(drive_speed, target_speed, change_rate * delta)

	if abs(drive_speed) > 0.08:
		rotation.y += steering * _steering_yaw_rate() * delta

	var forward := -global_transform.basis.z.normalized()
	velocity.x = forward.x * drive_speed
	velocity.z = forward.z * drive_speed
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= gravity_strength * delta
	SURFACE_MOTION.move(self,delta,surface_step_height)

func _steering_yaw_rate() -> float:
	var steering_weight: float = clamp(abs(drive_speed) / 5.0, 0.18, 1.0)
	return steering_speed * steering_weight * sign(drive_speed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_R:
			# Resolve against physics in the next tick; holding R must allow settling.
			_reset_requested = true
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging_camera = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = max(4.5, spring_arm.spring_length - 0.8)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = min(16.0, spring_arm.spring_length + 0.8)
	elif event is InputEventMouseMotion and dragging_camera:
		camera_pivot.rotation.y -= event.relative.x * 0.004
		camera_pivot.rotation.x = clamp(
			camera_pivot.rotation.x - event.relative.y * 0.003,
			deg_to_rad(-42.0),
			deg_to_rad(18.0)
		)


func set_respawn_transform(value: Transform3D) -> void:
	respawn_transform = value


func reset_to_respawn() -> bool:
	var target := respawn_transform
	if respawn_resolver.is_valid():
		var resolved: Variant = respawn_resolver.call(target)
		if not resolved is Transform3D:
			velocity = Vector3.ZERO
			drive_speed = 0.0
			return false
		target = resolved
	restore_pose(target)
	return true


func restore_pose(value: Transform3D) -> void:
	global_transform = Transform3D(Basis(Vector3.UP, value.basis.get_euler().y), value.origin)
	velocity = Vector3.ZERO
	drive_speed = 0.0
	_reset_requested = false
	dragging_camera = false
	_reset_visual_pose()
	# Snap an airborne body near its destination; grounded bodies settle next tick.
	apply_floor_snap()


func _reset_visual_pose() -> void:
	pass


func get_speed_kph() -> float:
	return abs(drive_speed) * 3.6
