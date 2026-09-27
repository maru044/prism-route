extends Camera3D

@export var target := Vector3(0.0, 2.25, 0.0)
@export var distance := 14.2
@export var yaw := -0.72
@export var pitch := 0.31
@export var move_speed := 8.0
@export var fast_move_multiplier := 3.0

var _dragging := false
var _look_yaw := 0.0
var _look_pitch := 0.0


func _ready() -> void:
	_place_from_orbit_settings()
	var initial_forward := (target - position).normalized()
	_look_yaw = atan2(-initial_forward.x, -initial_forward.z)
	_look_pitch = asin(clampf(initial_forward.y, -1.0, 1.0))
	_apply_free_look()


func _process(delta: float) -> void:
	var changed := false
	# Arrow keys provide a keyboard look fallback. WASD/QE translate the camera
	# itself, so looking upward never moves it below the ground as orbiting would.
	# Automated captures disable processing before assigning their fixed camera.
	if Input.is_key_pressed(KEY_LEFT):
		_look_yaw += delta * 0.75
		changed = true
	if Input.is_key_pressed(KEY_RIGHT):
		_look_yaw -= delta * 0.75
		changed = true
	if Input.is_key_pressed(KEY_UP):
		_look_pitch = minf(1.48, _look_pitch + delta * 0.65)
		changed = true
	if Input.is_key_pressed(KEY_DOWN):
		_look_pitch = maxf(-1.48, _look_pitch - delta * 0.65)
		changed = true

	var move_input := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_W)) - float(Input.is_key_pressed(KEY_S))
	)
	if not move_input.is_zero_approx():
		var forward := Vector3(
			-sin(_look_yaw), 0.0, -cos(_look_yaw)
		).normalized()
		var right := forward.cross(Vector3.UP).normalized()
		var move_direction := (
			right * move_input.x + forward * move_input.y
		).normalized()
		var speed := move_speed
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= fast_move_multiplier
		position += move_direction * speed * delta
		changed = true

	var vertical_input := (
		float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q))
	)
	if not is_zero_approx(vertical_input):
		var vertical_speed := move_speed
		if Input.is_key_pressed(KEY_SHIFT):
			vertical_speed *= fast_move_multiplier
		position.y += vertical_input * vertical_speed * delta
		changed = true
	if changed:
		_apply_free_look()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			position += _forward_vector() * 0.8
			_apply_free_look()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			position -= _forward_vector() * 0.8
			_apply_free_look()
	elif event is InputEventMouseMotion and _dragging:
		_look_yaw -= event.relative.x * 0.006
		_look_pitch = clampf(
			_look_pitch - event.relative.y * 0.005,
			-1.48,
			1.48
		)
		_apply_free_look()


func _place_from_orbit_settings() -> void:
	var horizontal := cos(pitch) * distance
	position = target + Vector3(
		sin(yaw) * horizontal,
		sin(pitch) * distance,
		cos(yaw) * horizontal
	)
	look_at(target, Vector3.UP)


func _forward_vector() -> Vector3:
	var horizontal := cos(_look_pitch)
	return Vector3(
		-sin(_look_yaw) * horizontal,
		sin(_look_pitch),
		-cos(_look_yaw) * horizontal
	).normalized()


func _apply_free_look() -> void:
	var forward := _forward_vector()
	target = position + forward * distance
	look_at(target, Vector3.UP)
