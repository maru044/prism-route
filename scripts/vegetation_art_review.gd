extends "res://scripts/world_lod_test.gd"
## Same terrain, seed, vegetation population and sunlight as the playable world.

const VIEW_NAMES := ["Forest edge", "Autumn hillside", "Distant ridge", "Coastal overlook"]
const VIEW_ANCHORS := [Vector2(-480, 320), Vector2(380, -420), Vector2(220, 640), Vector2(660, 540)]
const VIEW_OFFSETS := [Vector3(105, 40, 165), Vector3(25, 76, 120), Vector3(-140, 95, 430), Vector3(-150, 48, 260)]
var review_ready := false
var review_camera: Camera3D
var review_sites: Array[Vector3] = []
var view_index := 0
var camera_dragging := false


func _ready() -> void:
	vegetation.record_tree_layout_for_review = true
	await super._ready()
	camper.set_physics_process(false)
	camper.set_process_unhandled_input(false)
	review_camera = Camera3D.new()
	review_camera.name = "ArtReviewCamera"
	review_camera.fov = 52.0
	review_camera.far = 5000.0
	add_child(review_camera)
	for anchor in VIEW_ANCHORS:
		review_sites.append(_find_review_site(anchor))
	vegetation.target = review_camera
	# The accepted smooth small-tree baseline is used by every live entry.
	select_view(0)
	review_ready = true
	print("ART_REVIEW_SITES ", review_sites)


func _find_review_site(anchor: Vector2) -> Vector3:
	var best := Vector3(anchor.x, 30.0, anchor.y)
	var best_score := -INF
	# Prefer a planted, reasonably level region near the requested map location.
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var candidate := anchor + Vector2(dx, dz) * 48.0
			var hit := _raycast_terrain(candidate.x, candidate.y)
			if hit.is_empty() or hit.position.y < 3.0:
				continue
			var count := 0
			var colorful := 0
			for record in vegetation.review_tree_records:
				var point: Vector3 = record.transform.origin
				if Vector2(point.x, point.z).distance_squared_to(candidate) < 10000.0:
					count += 1
					if record.palette > 0:
						colorful += 1
			var score := count + colorful * 0.8 - candidate.distance_to(anchor) * 0.12
			if score > best_score:
				best_score = score
				best = hit.position
	if best_score == -INF:
		# An anchor may lie off the irregular island boundary. Select an actual
		# planted terrain point instead of constructing a view over empty water.
		var nearest := INF
		for record in vegetation.review_tree_records:
			var point: Vector3 = record.transform.origin
			var distance := Vector2(point.x, point.z).distance_squared_to(anchor)
			if distance < nearest:
				nearest = distance
				best = point
	return best


func select_view(index: int) -> void:
	view_index = clampi(index, 0, 3)
	var center := review_sites[view_index]
	review_camera.global_position = center + VIEW_OFFSETS[view_index]
	var ground := _raycast_terrain(review_camera.position.x, review_camera.position.z)
	if not ground.is_empty():
		review_camera.position.y = maxf(review_camera.position.y, ground.position.y + 4.0)
	review_camera.look_at(center + Vector3.UP * 6.0)
	review_camera.current = true
	_update_review_heading()


func _update_review_heading() -> void:
	info_label.text = "VEGETATION ART REVIEW  /  %s  /  ACCEPTED BASELINE\n1–4: viewpoints   Right-drag: look   WASD/QE: fly   Shift: faster\nSmooth small-tree shading and coverage-preserving mips." % VIEW_NAMES[view_index]


func _process(delta: float) -> void:
	super._process(delta)
	if not review_ready:
		return
	var movement := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): movement.z -= 1.0
	if Input.is_key_pressed(KEY_S): movement.z += 1.0
	if Input.is_key_pressed(KEY_A): movement.x -= 1.0
	if Input.is_key_pressed(KEY_D): movement.x += 1.0
	if Input.is_key_pressed(KEY_Q): movement.y -= 1.0
	if Input.is_key_pressed(KEY_E): movement.y += 1.0
	var speed := 90.0 if Input.is_key_pressed(KEY_SHIFT) else 18.0
	review_camera.position += review_camera.basis * movement.normalized() * speed * delta


func _unhandled_input(event: InputEvent) -> void:
	if not review_ready:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			select_view(event.keycode - KEY_1)
		elif event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/main.tscn")
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		camera_dragging = event.pressed
	elif event is InputEventMouseMotion and camera_dragging:
		review_camera.rotation.y -= event.relative.x * 0.003
		review_camera.rotation.x = clampf(review_camera.rotation.x - event.relative.y * 0.003, -1.4, 1.4)
