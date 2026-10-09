extends "res://scripts/camper_controller.gd"
## Isolated 11 x 3 m scale probe; the production prototype controller is unchanged.

var test_throttle := 0.0
var automation_enabled := false
var visual: Node3D
var wheel_feet: Array[Vector3] = []
var wheels: Array[MeshInstance3D] = []
var wheel_parts: Array = []
var wheel_rest_positions: Array = []

func _ready() -> void:
	super._ready()
	visual = $Visual
	maximum_forward_speed = 18.0
	maximum_reverse_speed = 5.0
	steering_speed = 0.48
	floor_snap_length = 0.8
	spring_arm.spring_length = 19.0
	camera_pivot.position.y = 4.0
	camera_pivot.rotation.x = -0.20

func _physics_process(delta: float) -> void:
	if automation_enabled:
		var forward := -global_transform.basis.z.normalized()
		drive_speed = move_toward(drive_speed, test_throttle * maximum_forward_speed, acceleration * delta)
		velocity.x = forward.x * drive_speed
		velocity.z = forward.z * drive_speed
		velocity.y = -0.5 if is_on_floor() else velocity.y - gravity_strength * delta
		move_and_slide()
	else:
		super._physics_process(delta)
	_align_wheels(delta)

func calibrate_wheels() -> void:
	# Called after the parent scales the model to 11 x 3 m. Probe the actual
	# tire geometry rather than dimensions from the unscaled placeholder.
	wheel_feet.clear()
	wheels.clear()
	wheel_parts.clear()
	wheel_rest_positions.clear()
	for node in visual.find_children("RV_Wheel_*", "MeshInstance3D", true, false):
		if str(node.name).ends_with("_Hub"):
			continue
		var wheel := node as MeshInstance3D
		var box: AABB = (visual.global_transform.affine_inverse() * wheel.global_transform) * wheel.get_aabb()
		var foot := box.get_center()
		foot.y = box.position.y
		wheel_feet.append(foot)
		wheels.append(wheel)
		var parts: Array[Node3D] = [wheel]
		var hub := visual.find_child(str(wheel.name) + "_Hub", true, false) as Node3D
		if hub:
			parts.append(hub)
		var positions: Array[Vector3] = []
		for part in parts:
			positions.append(part.position)
		wheel_parts.append(parts)
		wheel_rest_positions.append(positions)

func _align_wheels(delta: float) -> void:
	if wheel_feet.size() != 4 or not is_on_floor():
		return
	var heights: Array[float] = []
	var mean_height := 0.0
	for foot in wheel_feet:
		var height := _ground_height(global_transform * foot)
		if not is_finite(height):
			return
		heights.append(height)
		mean_height += height * 0.25
	var x_slope := 0.0
	var z_slope := 0.0
	var x_squared := 0.0
	var z_squared := 0.0
	for index in range(4):
		var foot := wheel_feet[index]
		x_slope += foot.x * (heights[index] - mean_height)
		z_slope += foot.z * (heights[index] - mean_height)
		x_squared += foot.x * foot.x
		z_squared += foot.z * foot.z
	var normal := Vector3(-x_slope / x_squared, 1.0, -z_slope / z_squared).normalized()
	var back := Vector3.BACK.slide(normal).normalized()
	var target := Basis(normal.cross(back).normalized(), normal, back).get_euler()
	target.x = clampf(target.x, -0.32, 0.32)
	target.z = clampf(target.z, -0.24, 0.24)
	visual.quaternion = visual.quaternion.slerp(Quaternion.from_euler(target), minf(1.0, delta * 10.0))
	# A long, upright collision box rests on the highest point underneath it.
	# Correct the visible chassis height separately to keep tires on the road.
	var correction := 0.0
	for foot in wheel_feet:
		var world_foot := visual.global_transform * foot
		var height := _ground_height(world_foot)
		if not is_finite(height):
			return
		correction += (height - world_foot.y) * 0.25
	visual.position.y += correction
	# Four terrain contacts need not be coplanar. Allow a small visual wheel
	# travel, including the hub, without inventing a physical suspension.
	for index in range(4):
		var point := visual.global_transform * wheel_feet[index]
		var travel := clampf(_ground_height(point) - point.y, -0.3, 0.3)
		for part_index in range(wheel_parts[index].size()):
			var part: Node3D = wheel_parts[index][part_index]
			var rest: Vector3 = wheel_rest_positions[index][part_index]
			part.position = rest + part.get_parent().global_basis.inverse() * (Vector3.UP * travel)

func wheel_ground_gaps() -> Array[float]:
	var gaps: Array[float] = []
	# Measure the rendered tire vertices, independently of the fit probes.
	for wheel in wheels:
		var point := Vector3.ZERO
		point.y = INF
		for vertex in wheel.mesh.get_faces():
			var world_vertex: Vector3 = wheel.global_transform * vertex
			if world_vertex.y < point.y:
				point = world_vertex
		gaps.append(point.y - _ground_height(point))
	return gaps

func _ground_height(point: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 6.0, point - Vector3.UP * 10.0, 1)
	query.hit_back_faces = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else INF

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = minf(36.0, spring_arm.spring_length + 1.8)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = maxf(8.0, spring_arm.spring_length - 1.8)
			return
	super._unhandled_input(event)
