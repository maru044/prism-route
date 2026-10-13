extends SceneTree
## Actual physics / Forward+ captures of the native B prototype, not concept art.

var scene
var viewport: SubViewport
var failures: Array[String] = []
var capture := false
var bookmarks: Array[Dictionary] = []
var max_tree_root_error := 0.0
var walk_distance := 0.0
var drive_distance := 0.0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for frame in count:
		await physics_frame

func shot(name: String) -> void:
	if not capture:
		return
	for frame in 25:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://screenshots/cliff_b_20261014/" + name + ".png"
	check(viewport.get_texture().get_image().save_png(path) == OK, "Capture failed: " + name)
	print("CLIFF_B_CAPTURE ", path)

func near_hit(position: Vector3, mask := 1) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 1.0, position - Vector3.UP * 1.0, mask)
	query.hit_back_faces = true
	return scene.get_world_3d().direct_space_state.intersect_ray(query)

func run() -> void:
	capture = "--capture-cliff-b" in OS.get_cmdline_user_args()
	root.size = Vector2i(1920, 1080)
	viewport = SubViewport.new()
	viewport.size = root.size
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	var container := SubViewportContainer.new()
	root.add_child(container)
	container.add_child(viewport)
	scene = load("res://scenes/cliff_b_gameplay_test.tscn").instantiate()
	scene.automation_enabled = true
	scene.get_node("CamperVan").automation_enabled = true
	viewport.add_child(scene)
	var start := Time.get_ticks_msec()
	while not scene.test_ready:
		if Time.get_ticks_msec() - start > 45000:
			check(false, "Scene startup timed out")
			quit(1)
			return
		await process_frame
	await frames(45)
	check(scene.character_mode and scene.character.is_on_floor(), "Roof entry did not settle")
	check(scene.vegetation.tree_instance_count == 801, "Tree layout was not loaded")
	check(scene.metadata.population.cliff_b_trees == 208, "Cliff B population mismatch")
	for index in 4:
		await scene.select_spawn(index)
		await frames(30)
		var p: Vector3 = scene.character.global_position
		var surface := near_hit(p)
		check(scene.character.is_on_floor() and not surface.is_empty(), "Character bookmark did not settle: " + str(index))
		check(absf(p.y - float(scene.anchors[index].y)) < 1.0, "Bookmark changed storey: " + str(index))
		bookmarks.append({"index":index,"position":[p.x,p.y,p.z],"on_floor":scene.character.is_on_floor(),"surface":surface.collider.get_meta("map_surface", "") if not surface.is_empty() else "missing"})
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/cliff_b_test/tree_layout.json"))
	for index in rows.size():
		var row: Array = rows[index]
		var p := Vector3(row[0],row[1],row[2])
		var surface := near_hit(p, 16 if index < 208 else 1)
		check(not surface.is_empty(), "Tree root has no matching surface: " + str(index))
		if not surface.is_empty():
			max_tree_root_error = maxf(max_tree_root_error, absf(p.y - surface.position.y))
	check(max_tree_root_error < 0.005, "Tree roots disagree with imported collision")
	await scene.select_spawn(3)
	await frames(60)
	var actor = scene.character
	var p: Vector3 = actor.position
	actor.test_move = Vector2(0,-1)
	await frames(90)
	walk_distance = Vector2(actor.position.x-p.x,actor.position.z-p.z).length()
	actor.test_move = Vector2.ZERO
	await frames(20)
	check(walk_distance > 2.0 and actor.is_on_floor(), "Roof walking failed")
	check(scene.vegetation.get_active_grass_chunk_count() > 0, "Roof grass did not stream")
	await shot("02_roof_walk")
	# Grass rays must not select the roof when standing on the lower terrace.
	await scene.select_spawn(2)
	await frames(25)
	var planting_hit: Dictionary = scene.vegetation._raycast_terrain(scene.anchors[2].x,scene.anchors[2].z)
	check(not planting_hit.is_empty() and absf(planting_hit.position.y-scene.anchors[2].y)<1.0, "Grass ray changed storey under the roof")
	await scene.set_character_mode(false)
	await scene.select_spawn(0)
	await frames(30)
	p = scene.camper.position
	scene.camper.test_throttle = .25
	await frames(60)
	scene.camper.test_throttle = 0
	drive_distance = Vector2(scene.camper.position.x-p.x,scene.camper.position.z-p.z).length()
	check(drive_distance > .5 and scene.camper.is_on_floor(), "Gallery vehicle movement failed")
	await shot("04_gallery_drive")
	await scene.set_character_mode(true)
	await scene.select_spawn(1)
	await frames(30)
	await shot("05_base_walkway")
	scene.set_free_mode(true)
	scene.camera.position = Vector3(80,58,220)
	scene.camera.look_at(Vector3(45,26,20))
	await shot("03_terraces")
	scene.show_overview()
	await shot("01_overview")
	scene.toggle_planting_regions()
	await shot("06_planting_regions")
	scene.toggle_planting_regions()
	var report := {"failures":failures,"godot":Engine.get_version_info().string,"render_captures":capture,
		"bookmarks":bookmarks,"trees":rows.size(),"cliff_b_trees":208,"max_tree_root_error_m":max_tree_root_error,
		"roof_walk_distance_m":walk_distance,"gallery_drive_distance_m":drive_distance,
		"scope":"Four bookmarks, local roof walking, short gallery drive, all tree roots and lower-storey grass rays. Not full circulation or final topology acceptance."}
	var file := FileAccess.open("res://docs/CLIFF_B_GAMEPLAY_TEST_REPORT.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("CLIFF_B_VERIFICATION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
