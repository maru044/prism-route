extends SceneTree
## Measure actual half-turn paths on the imported map, using the player drive step.

var failures: Array[String] = []
var cases: Array[Dictionary] = []
var scene

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	scene = load("res://scenes/map_1012_drive_test.tscn").instantiate()
	scene.automation_enabled = true
	scene.get_node("CamperVan").automation_enabled = true
	root.add_child(scene)
	while not scene.test_ready:
		await process_frame
	# Hold speed during each measured arc; acceleration and keyboard input still
	# use the same drive step in the normal scene and its existing drive verifier.
	scene.camper.acceleration = 0.0
	for inputs in [[2.0, 1.0], [5.0, 1.0], [5.0, -1.0], [-3.0, 1.0], [-3.0, -1.0], [18.0, 1.0]]:
		await _half_turn(inputs[0], inputs[1])
	scene.camper.test_throttle = 0
	scene.camper.test_steering = 1
	scene.camper.drive_speed = 0
	var stationary_yaw: float = scene.camper.rotation.y
	for frame in 30:
		await physics_frame
	check(absf(scene.camper.rotation.y - stationary_yaw) < 0.0001, "Stationary vehicle pivots in place")
	var report := {"failures": failures, "cases": cases, "stationary_yaw_change_rad": scene.camper.rotation.y - stationary_yaw}
	var file := FileAccess.open("res://.map_1012_build/turning_verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("MAP_1012_TURNING_VERIFY ", JSON.stringify(report))
	scene.free()
	quit(0 if failures.is_empty() else 1)

func _half_turn(speed: float, steering: float) -> void:
	scene.camper.test_throttle = 0
	scene.camper.test_steering = 0
	await scene.select_spawn(0)
	for frame in 60:
		await physics_frame
	var start: Vector3 = scene.camper.position
	var previous := start
	var yaw_previous: float = scene.camper.rotation.y
	var yaw_total := 0.0
	var distance := 0.0
	var off_floor_frames := 0
	var contact_events: Array[Dictionary] = []
	var steps := 0
	scene.camper.drive_speed = speed
	scene.camper.test_throttle = signf(speed)
	scene.camper.test_steering = steering
	while absf(yaw_total) < PI and steps < 900:
		await physics_frame
		var position: Vector3 = scene.camper.position
		var step_distance := Vector2(position.x - previous.x, position.z - previous.z).length()
		distance += step_distance
		if step_distance > absf(speed) / 60.0 * 1.5 or not scene.camper.is_on_floor():
			var contacts: Array[Dictionary] = []
			for collision_index in scene.camper.get_slide_collision_count():
				var collision: KinematicCollision3D = scene.camper.get_slide_collision(collision_index)
				contacts.append({"surface": collision.get_collider().get_meta("map_surface", ""), "normal": str(collision.get_normal())})
			contact_events.append({"step": steps, "distance": step_distance, "position": str(position), "contacts": contacts})
		yaw_total += wrapf(scene.camper.rotation.y - yaw_previous, -PI, PI)
		previous = position
		yaw_previous = scene.camper.rotation.y
		off_floor_frames += int(not scene.camper.is_on_floor())
		steps += 1
	var expected_radius := 4.5 if absf(speed) <= 5 else 14.0
	var radius := distance / absf(yaw_total)
	var diameter := Vector2(previous.x - start.x, previous.z - start.z).length()
	check(steps < 900, "Half-turn timed out at speed %s steering %s" % [speed, steering])
	check(signf(yaw_total) == signf(speed * steering), "Reverse/left/right heading sign is wrong")
	# On the authored map, contact with a road edge can shorten/deflect the
	# travelled arc. Verify the manoeuvre fits, rather than requiring a perfect
	# mathematical circle on surfaces with overlapping CAD collision meshes.
	check(radius <= expected_radius + 0.15 and radius >= expected_radius * 0.8,
		"Actual turn radius is outside manoeuvre bounds at speed %s: %s" % [speed, radius])
	check(diameter < (12.0 if absf(speed) <= 5 else 30.0), "Half-turn occupies too much space")
	check(scene.camper.is_on_floor() and off_floor_frames <= 6, "Vehicle did not stay near the ground during turn at speed %s" % speed)
	var gaps: Array = scene.camper.wheel_ground_gaps()
	for gap in gaps:
		check(absf(gap) < 0.05, "Wheel lost ground after turn at speed %s: %s" % [speed, gap])
	cases.append({"speed_mps": speed, "steering": steering, "heading_change_deg": rad_to_deg(yaw_total),
		"measured_radius_m": radius, "half_turn_diameter_m": diameter, "off_floor_frames": off_floor_frames,
		"wheel_gaps_m": gaps, "physics_steps": steps, "contact_events": contact_events})
	print("MAP_1012_TURN_CASE ", JSON.stringify(cases.back()))
