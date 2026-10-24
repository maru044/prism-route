extends SceneTree
## Actual camper: layered surfaces, damaged visual pose, held R and map checkpoints.
const OUT := "res://assets/world/current_map_validation/review/camper_reset.json"
var failures: Array[String] = []
var rows: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func ticks(count: int) -> void:
	for i in count: await physics_frame

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func box(parent: Node3D, center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 32
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
	body.position = center
	return body

func damage(camper) -> void:
	camper.global_position += Vector3(0, 80, 0)
	camper.rotation.x = .6
	camper.rotation.z = -.5
	camper.velocity = Vector3(12, 70, -18)
	camper.drive_speed = 18
	camper.visual.position = Vector3(0, 30, 0)
	camper.visual.rotation = Vector3(.3, 0, .2)
	for parts in camper.wheel_parts:
		for part in parts: part.position += Vector3.UP * 7

func check_pose(camper, name: String) -> Array:
	var gaps: Array = camper.wheel_ground_gaps()
	check(camper.is_on_floor(), name + ": not grounded")
	check(gaps.size() == 4, name + ": missing tires")
	for gap in gaps: check(is_finite(gap) and absf(gap) < .05, name + ": tire not on floor")
	check(absf(camper.visual.position.y) < 1, name + ": chassis visual still displaced")
	return gaps

func run() -> void:
	Engine.max_fps = 0
	var stage := Node3D.new()
	root.add_child(stage)
	box(stage, Vector3(0, -.5, 0), Vector3(40, 1, 40))
	box(stage, Vector3(0, 4.25, 0), Vector3(40, .5, 40))
	var shell = load("res://scenes/map_1021.tscn").instantiate()
	var camper = shell.get_node("CamperVan")
	shell.remove_child(camper)
	shell.free()
	camper.automation_enabled = true
	stage.add_child(camper)
	camper.collision_mask = 32
	camper.ground_query_mask = 32
	camper.safe_margin = .006
	camper.calibrate_wheels()
	var checkpoint := Transform3D(Basis.IDENTITY, Vector3(0, .12, 0))
	camper.set_respawn_transform(checkpoint)
	camper.restore_pose(checkpoint)
	await ticks(70)
	var gaps := check_pose(camper, "under 4m roof")
	check(absf(camper.global_position.y) < .3, "Roof probe changed physical storey")
	rows.append({"case": "lower floor below overhead slab", "height": camper.position.y, "wheel_gaps_m": gaps})
	damage(camper)
	check(camper.reset_to_respawn(), "Fixture reset rejected")
	check(camper.visual.transform.is_equal_approx(camper.visual_rest_transform), "Reset did not clear chassis transform immediately")
	check(camper.velocity.is_zero_approx() and camper.drive_speed == 0, "Reset retained momentum")
	await ticks(70)
	rows.append({"case": "launched chassis and damaged suspension", "wheel_gaps_m": check_pose(camper, "launched fixture")})
	var resets := [0]
	camper.respawn_resolver = func(value: Transform3D) -> Transform3D:
		resets[0] += 1
		return value
	var key := InputEventKey.new()
	key.physical_keycode = KEY_R
	key.keycode = KEY_R
	key.pressed = true
	Input.parse_input_event(key)
	await ticks(10)
	var echo := key.duplicate()
	echo.echo = true
	Input.parse_input_event(echo)
	await ticks(60)
	key.pressed = false
	Input.parse_input_event(key)
	check(resets[0] == 1, "Holding R repeated reset or failed to trigger it")
	check_pose(camper, "held R")
	rows.append({"case": "hold R and key repeat", "reset_count": resets[0]})
	stage.queue_free()
	await ticks(3)

	var world = load("res://scenes/map_1021.tscn").instantiate()
	world.automation_enabled = true
	world.vegetation_bake_only = true
	root.add_child(world)
	while not world.test_ready: await process_frame
	await world.set_character_mode(false)
	check(not world.character_mode, "Could not enter camper")
	camper = world.camper
	for i in world.resolved_spawns.size():
		await world.select_spawn(i)
		await ticks(70)
		check(not world.character_mode, "Camper spawn unavailable: %d" % (i + 1))
		if world.character_mode: continue
		var saved: Transform3D = camper.respawn_transform
		damage(camper)
		check(camper.reset_to_respawn(), "Map reset rejected: %d" % (i + 1))
		check(camper.velocity.is_zero_approx() and camper.drive_speed == 0, "Map reset retained momentum")
		await ticks(70)
		var name := "map spawn %d" % (i + 1)
		gaps = check_pose(camper, name)
		check(absf(camper.global_position.y - saved.origin.y) < .7, name + ": reset to wrong storey")
		check(Vector2(camper.position.x - saved.origin.x, camper.position.z - saved.origin.z).length() < .1, name + ": reset shifted valid checkpoint")
		rows.append({"case": name, "height": camper.position.y, "wheel_gaps_m": gaps})
	# Deliberately corrupt the checkpoint height: fall back to the selected floor.
	var stale: Transform3D = camper.respawn_transform
	stale.origin.y += 80
	camper.set_respawn_transform(stale)
	damage(camper)
	check(camper.reset_to_respawn(), "Stale checkpoint fallback rejected")
	await ticks(70)
	check_pose(camper, "stale checkpoint")
	check(absf(camper.position.y - world.resolved_spawns[world.spawn_index].floor_position.y) < .7, "Stale checkpoint fallback picked wrong storey")
	rows.append({"case": "stale airborne checkpoint", "height": camper.position.y})
	# Occupied checkpoint must be relocated to a clear supported place nearby.
	await world.select_spawn(0)
	await ticks(70)
	var blocked: Transform3D = camper.respawn_transform
	var obstacle := box(world, blocked.origin + Vector3.UP * 2, Vector3(8, 4, 8))
	await ticks(2)
	damage(camper)
	check(camper.reset_to_respawn(), "Blocked checkpoint could not find nearby safe place")
	await ticks(70)
	check_pose(camper, "blocked checkpoint")
	check(camper.position.distance_to(blocked.origin) > 4, "Reset remained inside blocker")
	var collider: CollisionShape3D = camper.get_node("CollisionShape3D")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = collider.global_transform
	query.collision_mask = 32
	check(world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(), "Reset camper overlaps solid geometry")
	rows.append({"case": "occupied checkpoint", "relocation_m": camper.position.distance_to(blocked.origin)})
	obstacle.queue_free()
	var report := {"passed": failures.is_empty(), "failures": failures, "cases": rows,
		"mesh_sha256": world.metadata.mesh_sha256, "date": Time.get_datetime_string_from_system()}
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("CAMPER_RESET ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
