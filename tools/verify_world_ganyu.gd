extends SceneTree
## Exercise switching, real world movement, motion transitions and storey retention.

var failures: Array[String] = []
var scene
var viewport: SubViewport
var capture := false
var movement_report: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func frames(count: int) -> void:
	for frame in count:
		await physics_frame

func _run() -> void:
	capture = "--capture-world-ganyu" in OS.get_cmdline_user_args()
	root.size = Vector2i(1920, 1080)
	viewport = SubViewport.new()
	viewport.size = root.size
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	var container := SubViewportContainer.new()
	root.add_child(container)
	container.add_child(viewport)
	scene = load("res://scenes/map_1012_drive_test.tscn").instantiate()
	scene.automation_enabled = true
	scene.get_node("CamperVan").automation_enabled = true
	viewport.add_child(scene)
	var start := Time.get_ticks_msec()
	while not scene.test_ready:
		check(Time.get_ticks_msec() - start < 60000, "Scene startup timeout")
		if not failures.is_empty():
			quit(1)
			return
		await process_frame
	await frames(60)
	var original_position: Vector3 = scene.camper.position
	# Exercise the actual button callback, not just its implementation method.
	scene.actor_button.pressed.emit()
	while scene.switching_actor:
		await physics_frame
	await frames(45)
	var actor = scene.character
	check(scene.character_mode and actor.visible and not scene.camper.visible, "Button did not swap visible actors")
	check(actor.camera.is_current() and actor.is_physics_processing() and not scene.camper.is_physics_processing(), "Actor camera/control ownership failed")
	check(scene.vegetation.target == actor, "Grass streamer does not follow Ganyu")
	check(Vector2(actor.position.x-original_position.x, actor.position.z-original_position.z).length() < 0.02, "Switch moved actor away from current location")
	check(actor.is_on_floor() and actor.animation_state == "idle", "Ganyu did not settle/idle")
	for state: String in actor.MOTIONS:
		var animation: Animation = actor.player.get_animation(state)
		check(animation != null, "Missing motion: " + state)
		for track in animation.get_track_count():
			var path := animation.track_get_path(track)
			check(actor.character.get_node_or_null(NodePath(str(path).get_slice(":", 0))) == actor.skeleton, "Invalid animation node path: " + state)
			check(actor.skeleton.find_bone(str(path).get_slice(":", 1)) >= 0, "Invalid animation bone: " + state)
	await _capture("ganyu_road")
	var p: Vector3 = actor.position
	actor.test_move = Vector2(0, -1)
	await frames(90)
	var walk_distance := Vector2(actor.position.x-p.x, actor.position.z-p.z).length()
	check(walk_distance > 2.1 and actor.animation_state == "walk", "Walking/motion transition failed")
	await _capture("ganyu_walk")
	p = actor.position
	actor.test_running = true
	await frames(90)
	var run_distance := Vector2(actor.position.x-p.x, actor.position.z-p.z).length()
	check(run_distance > walk_distance * 1.8 and actor.animation_state == "run", "Running is not faster or animation failed")
	await _capture("ganyu_run")
	actor.test_move = Vector2.ZERO
	actor.test_running = false
	await frames(35)
	check(actor.animation_state == "idle", "Stopping did not return to idle")
	p = actor.position
	var camera_yaw: float = actor.camera_pivot.rotation.y
	actor.camera_pivot.rotation.y += PI * 0.5
	var expected_direction: Vector3 = -actor.camera_pivot.global_basis.z
	expected_direction.y = 0
	expected_direction = expected_direction.normalized()
	actor.test_move = Vector2(0, -1)
	await frames(90)
	var camera_relative_direction: Vector3 = (actor.position-p).normalized()
	check(camera_relative_direction.dot(expected_direction) > 0.97, "Movement did not follow camera yaw")
	check(actor.visual.global_basis.z.dot(expected_direction) > 0.99, "Model did not face movement direction")
	actor.test_move = Vector2.ZERO
	await frames(35)
	actor.camera_pivot.rotation.y = camera_yaw
	var floor_y: float = actor.position.y
	var jump_height := 0.0
	var jump_states: Array[String] = []
	actor.test_jump = true
	for frame in 80:
		await physics_frame
		jump_height = maxf(jump_height, actor.position.y-floor_y)
		if not actor.animation_state in jump_states:
			jump_states.append(actor.animation_state)
	check(jump_height > 0.8 and jump_height < 1.4, "Jump height is incorrect")
	check(actor.is_on_floor(), "Jump did not land")
	for state in ["jump_start", "jump_air", "jump_land", "idle"]:
		check(state in jump_states, "Jump motion stage missing: " + state)
	actor.greeting = true
	await frames(20)
	check(actor.animation_state == "greet", "Greeting motion did not play")
	await _capture("ganyu_greeting")
	scene.set_free_mode(true)
	p = actor.position
	actor.test_move = Vector2(0, -1)
	await frames(20)
	check(actor.position.is_equal_approx(p), "Inactive character moves during free camera")
	check(scene.camera.is_current() and scene.vegetation.target == scene.camera, "Free camera target ownership failed")
	actor.test_move = Vector2.ZERO
	scene.set_free_mode(false)
	check(actor.camera.is_current(), "Returning from free camera did not restore Ganyu camera")
	var bookmark_results: Array[Dictionary] = []
	for bookmark in 4:
		await scene.select_spawn(bookmark)
		await frames(60)
		check(actor.is_on_floor(), "Character did not ground at bookmark %d" % bookmark)
		check(actor.global_position.is_finite(), "Character position invalid")
		bookmark_results.append({"bookmark": bookmark, "on_floor": actor.is_on_floor(), "position": str(actor.position)})
		if capture and bookmark > 0:
			scene.set_free_mode(true)
			var forward: Vector3 = actor.visual.global_basis.z
			scene.camera.position = actor.position + forward * 3.8 + Vector3.UP * 1.55
			scene.camera.look_at(actor.position + Vector3.UP * 0.8)
			await _capture(["", "ganyu_forest", "ganyu_beach", "ganyu_upper"][bookmark])
			scene.set_free_mode(false)
	# A synthetic upper floor above the current lower road verifies that toggles
	# do not use the world's topmost surface and jump onto another storey.
	await scene.select_spawn(0)
	await frames(30)
	p = actor.position
	var overhead := StaticBody3D.new()
	overhead.collision_layer = 1
	overhead.position = p + Vector3.UP * 15
	var overhead_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	overhead_shape.shape = box
	overhead.add_child(overhead_shape)
	scene.add_child(overhead)
	await frames(2)
	scene.show_overview()
	scene.actor_button.pressed.emit()
	while scene.switching_actor:
		await physics_frame
	check(not scene.character_mode and scene.free_mode and scene.camera.is_current(), "Switch from overview did not preserve free camera")
	check(absf(scene.camper.position.y-p.y) < 1.0, "Actor switch teleported to overhead floor")
	scene.set_free_mode(false)
	await frames(60)
	check(scene.chase_camera.is_current() and scene.camper.is_on_floor(), "Camper camera/contact not restored")
	check(not actor.is_physics_processing() and not actor.visible, "Hidden character remains active")
	overhead.free()
	movement_report = {"walk_distance_1_5s_m": walk_distance, "run_distance_1_5s_m": run_distance,
		"camera_relative_direction_alignment": camera_relative_direction.dot(expected_direction),
		"jump_height_m": jump_height, "jump_states": jump_states, "bookmarks": bookmark_results}
	var report := {"failures": failures, "godot": Engine.get_version_info().string, "capture": capture,
		"motions": actor.MOTIONS, "movement": movement_report, "trees": scene.vegetation.tree_instance_count,
		"large_trees": scene.vegetation.large_tree_instance_count, "elapsed_ms": Time.get_ticks_msec()-start}
	var file := FileAccess.open("res://.map_1012_build/ganyu_verification.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("WORLD_GANYU_VERIFY ", JSON.stringify(report))
	scene.free()
	quit(0 if failures.is_empty() else 1)

func _capture(name: String) -> void:
	if not capture:
		return
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.map_1012_build/captures")
	check(viewport.get_texture().get_image().save_png("res://.map_1012_build/captures/%s.png" % name) == OK, "Capture failed: " + name)
	print("WORLD_GANYU_CAPTURE ", name)
