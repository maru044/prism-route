extends "res://scripts/camper_controller.gd"
## Short, original camper visual with the archived wheel-contact adjustment.

@export var low_speed_turn_radius := 4.5
@export var high_speed_turn_radius := 14.0
@export_flags_3d_physics var ground_query_mask := 1

var test_throttle := 0.0
var test_steering := 0.0
var test_braking := false
var automation_enabled := false
var visual: Node3D
var wheel_feet: Array[Vector3] = []
var wheels: Array[MeshInstance3D] = []
var wheel_parts: Array = []
var wheel_rest_positions: Array = []
var visual_rest_transform := Transform3D.IDENTITY

func _ready() -> void:
	super._ready()
	visual = $Visual
	visual_rest_transform = visual.transform
	maximum_forward_speed = 18.0
	maximum_reverse_speed = 5.0
	floor_snap_length = 0.8
	spring_arm.spring_length = 10.0
	camera_pivot.position.y = 2.45
	camera_pivot.rotation.x = -0.20

func _physics_process(delta: float) -> void:
	if automation_enabled:
		_step_driving(test_throttle, test_steering, test_braking, delta)
	else:
		super._physics_process(delta)
	_align_wheels(delta)

func _steering_yaw_rate() -> float:
	# Tight manoeuvres at walking/parking speeds; gradually widen the arc at
	# road speed. Signed speed also preserves opposite steering in reverse.
	var road_speed_weight := smoothstep(5.0, 18.0, absf(drive_speed))
	var radius := lerpf(low_speed_turn_radius, high_speed_turn_radius, road_speed_weight)
	return drive_speed / maxf(radius, 0.5)

func calibrate_wheels() -> void:
	# Probe the original tire geometry; the model keeps its authored scale.
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

func _reset_visual_pose() -> void:
	if not is_instance_valid(visual):
		return
	visual.transform = visual_rest_transform
	for index in wheel_parts.size():
		for part_index in wheel_parts[index].size():
			wheel_parts[index][part_index].position = wheel_rest_positions[index][part_index]

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
	for index in wheel_feet.size():
		var foot := wheel_feet[index]
		var world_foot := visual.global_transform * foot
		correction += (heights[index] - world_foot.y) * 0.25
	visual.position.y += correction
	# Four terrain contacts need not be coplanar. Allow a small visual wheel
	# travel, including the hub, without inventing a physical suspension.
	for index in range(4):
		var point := visual.global_transform * wheel_feet[index]
		var travel := clampf(heights[index] - point.y, -0.3, 0.3)
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
	# Anchor to the physical chassis, never to accumulated visual suspension.
	# A six-metre ray above a tire can select the next storey's roof.
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(point.x, global_position.y + 1.0, point.z),
		Vector3(point.x, global_position.y - 2.0, point.z), ground_query_mask)
	query.exclude = [get_rid()]
	query.hit_back_faces = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() and hit.normal.y >= cos(floor_max_angle) else INF

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = minf(36.0, spring_arm.spring_length + 1.8)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = maxf(8.0, spring_arm.spring_length - 1.8)
			return
	super._unhandled_input(event)
