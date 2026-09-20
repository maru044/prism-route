extends Camera3D

@export var target := Vector3(0.0, 2.25, 0.0)
@export var distance := 14.2
@export var yaw := -0.72
@export var pitch := 0.31

var _dragging := false


func _ready() -> void:
	_update_camera()


func _process(delta: float) -> void:
	var changed := false
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		yaw -= delta * 0.75
		changed = true
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		yaw += delta * 0.75
		changed = true
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		distance = maxf(6.0, distance - delta * 5.0)
		changed = true
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		distance = minf(70.0, distance + delta * 5.0)
		changed = true
	if changed:
		_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(6.0, distance - 0.8)
			_update_camera()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(70.0, distance + 0.8)
			_update_camera()
	elif event is InputEventMouseMotion and _dragging:
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch - event.relative.y * 0.005, 0.08, 1.18)
		_update_camera()


func _update_camera() -> void:
	var horizontal := cos(pitch) * distance
	position = target + Vector3(
		sin(yaw) * horizontal,
		sin(pitch) * distance,
		cos(yaw) * horizontal
	)
	look_at(target, Vector3.UP)
