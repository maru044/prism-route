extends Node3D

const ASSETS := "res://assets/world/map_1009_test/"
const VARIANT_NAMES := ["Rhino 原始平滑版", "Blender 自然起伏版"]
const VIEW_NAMES := ["道路出生点", "起伏草地", "中层接缝", "高层平台"]
const SKY_TEXTURE := preload("res://assets/environment/hdri/rosendal_park_sunset_puresky_4k.exr")

@onready var camper: CharacterBody3D = $CamperVan
@onready var chase_camera: Camera3D = $CamperVan/CameraPivot/SpringArm3D/Camera3D

var variants: Array[Node3D] = []
var metadata: Dictionary
var anchors: Array[Vector3] = []
var variant := 0
var viewpoint := 0
var test_ready := false
var free_mode := false
var overview_mode := false
var camera: Camera3D
var label: Label
var status: Label
var variant_button: Button
var fly_button: Button
var changing_variant := false
var automation_enabled := false

func _ready() -> void:
	metadata = JSON.parse_string(FileAccess.get_file_as_string(ASSETS + "build_metadata.json"))
	_build_environment()
	var terrain_material := ShaderMaterial.new()
	terrain_material.shader = load(ASSETS + "terrain_review.gdshader")
	var road_material := StandardMaterial3D.new()
	road_material.albedo_color = Color(0.21, 0.23, 0.24)
	road_material.roughness = 0.93
	road_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for filename in ["map_1009_original.glb", "map_1009_natural.glb"]:
		var model := (load(ASSETS + filename) as PackedScene).instantiate() as Node3D
		add_child(model)
		variants.append(model)
		var meshes: Array[MeshInstance3D] = []
		_collect_meshes(model, meshes)
		for mesh in meshes:
			mesh.material_override = road_material if "Roads" in mesh.name else terrain_material
			var shape := mesh.mesh.create_trimesh_shape()
			shape.backface_collision = true
			var body := StaticBody3D.new()
			body.name = "ExactMeshCollision"
			body.collision_layer = 0
			body.collision_mask = 0
			mesh.add_child(body)
			var collider := CollisionShape3D.new()
			collider.shape = shape
			body.add_child(collider)
		model.visible = false
	_scale_camper_model()
	camera = Camera3D.new()
	camera.far = 6500
	camera.fov = 60
	add_child(camera)
	_build_hud()
	var translate := _vec3(metadata.model_translation)
	anchors.append(_vec3(metadata.road_spawn))
	anchors.append(_vec3(metadata.natural.relief_view))
	anchors.append(Vector3(825, 15, -765) + translate)
	anchors.append(_vec3(metadata.upper_view))
	await set_variant(0, false)
	await select_spawn(0)
	test_ready = true
	print("MAP_1009_READY variants=2 camper=11x3 collision=mesh")

func _vec3(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_collect_meshes(child, result)

func _scale_camper_model() -> void:
	var model: Node3D = $CamperVan/Visual/CamperModel
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	var bounds := AABB()
	var first := true
	for mesh in meshes:
		var box: AABB = (model.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	model.scale = Vector3(3.0 / bounds.size.x, 3.4 / bounds.size.y, 11.0 / bounds.size.z)
	camper.calibrate_wheels()

func _build_environment() -> void:
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = SKY_TEXTURE
	panorama.energy_multiplier = 0.55
	var sky := Sky.new()
	sky.sky_material = panorama
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.95
	environment.ssao_enabled = true
	environment.ssao_radius = 1.0
	environment.ssao_intensity = 0.65
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32, -125, 0)
	sun.light_color = Color("ffe5c5")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220
	add_child(sun)
	var ocean := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8500, 8500)
	ocean.mesh = plane
	ocean.position.y = -0.65
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.19, 0.36, 0.40)
	water.roughness = 0.30
	water.metallic = 0.05
	ocean.material_override = water
	add_child(ocean)

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 18)
	canvas.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 22)
	column.add_child(label)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	variant_button = Button.new()
	variant_button.focus_mode = Control.FOCUS_NONE
	variant_button.pressed.connect(func(): await set_variant(1 - variant))
	buttons.add_child(variant_button)
	fly_button = Button.new()
	fly_button.focus_mode = Control.FOCUS_NONE
	fly_button.text = "F 自由观景"
	fly_button.pressed.connect(func(): set_free_mode(not free_mode))
	buttons.add_child(fly_button)
	var overview := Button.new()
	overview.focus_mode = Control.FOCUS_NONE
	overview.text = "Tab 全岛"
	overview.pressed.connect(show_overview)
	buttons.add_child(overview)
	var places := HBoxContainer.new()
	column.add_child(places)
	for i in range(VIEW_NAMES.size()):
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.text = "%d %s" % [i + 1, VIEW_NAMES[i]]
		button.pressed.connect(select_spawn.bind(i))
		places.add_child(button)
	var help := Label.new()
	help.text = "W/S 前进倒车 · A/D 转向 · 空格刹车 · R 复位\n右键拖动视角 · 滚轮缩放 · M 切换地形\n自由观景：WASD/QE 移动 · Shift 加速 · F 返回驾驶"
	help.add_theme_font_size_override("font_size", 17)
	column.add_child(help)
	status = Label.new()
	status.position = Vector2(22, 960)
	status.add_theme_font_size_override("font_size", 20)
	status.add_theme_color_override("font_shadow_color", Color.BLACK)
	status.add_theme_constant_override("shadow_offset_x", 2)
	status.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(status)

func _set_collision(node: Node, enabled: bool) -> void:
	if node is StaticBody3D:
		node.collision_layer = 1 if enabled else 0
	for child in node.get_children():
		_set_collision(child, enabled)

func set_variant(value: int, reposition := true) -> void:
	if changing_variant:
		return
	changing_variant = true
	camper.set_physics_process(false)
	variant = value
	for i in range(variants.size()):
		variants[i].visible = i == variant
		_set_collision(variants[i], i == variant)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if reposition:
		var hit := ground_hit(camper.global_position)
		if not hit.is_empty():
			camper.global_position = hit.position + Vector3.UP * 0.20
			camper.velocity = Vector3.ZERO
			camper.drive_speed = 0.0
			camper.set_respawn_transform(camper.global_transform)
	camper.set_physics_process(not free_mode)
	label.text = "model_1009｜%s\n11 m × 3 m 房车 · 简化驾驶控制" % VARIANT_NAMES[variant]
	variant_button.text = "M 切换到%s" % VARIANT_NAMES[1 - variant]
	changing_variant = false

func ground_hit(point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 400, point.z), Vector3(point.x, -30, point.z), 1)
	query.hit_back_faces = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func select_spawn(index: int) -> void:
	viewpoint = index
	await get_tree().physics_frame
	var target := anchors[index]
	var hit := ground_hit(target)
	if hit.is_empty():
		# The high-level target is a convenience bookmark; search its nearby
		# plateau if the authored silhouette leaves that coordinate empty.
		for dx in range(-4, 5):
			for dz in range(-4, 5):
				var nearby := ground_hit(target + Vector3(dx * 25, 0, dz * 25))
				if not nearby.is_empty() and absf(nearby.normal.y) > 0.9:
					hit = nearby
	if hit.is_empty():
		push_warning("Bookmark has no terrain: " + VIEW_NAMES[index])
		return
	camper.global_position = hit.position + Vector3.UP * 0.20
	if index == 0:
		var forward := _vec3(metadata.road_direction)
		camper.rotation.y = atan2(-forward.x, -forward.z)
	else:
		camper.rotation.y = -0.60
	camper.velocity = Vector3.ZERO
	camper.drive_speed = 0.0
	camper.set_respawn_transform(camper.global_transform)
	$CamperVan/CameraPivot.rotation = Vector3(-0.20, 0, 0)
	if free_mode:
		show_detail(index)

func set_free_mode(enabled: bool) -> void:
	free_mode = enabled
	overview_mode = false
	camper.set_physics_process(not enabled)
	camper.set_process_unhandled_input(not enabled)
	if enabled:
		camera.global_transform = chase_camera.global_transform
		camera.make_current()
	else:
		chase_camera.make_current()
	fly_button.text = "F 返回驾驶" if enabled else "F 自由观景"

func show_overview() -> void:
	if not free_mode:
		set_free_mode(true)
	overview_mode = true
	camera.position = Vector3(1750, 2300, 2400)
	camera.look_at(Vector3(0, 30, 0))

func show_detail(index := 1) -> void:
	if not free_mode:
		set_free_mode(true)
	overview_mode = false
	viewpoint = index
	var target := anchors[index]
	var hit := ground_hit(target)
	if not hit.is_empty():
		target = hit.position
	camera.position = target + Vector3(45, 18, 65)
	camera.look_at(target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			await set_variant(1 - variant)
		elif event.keycode == KEY_F:
			set_free_mode(not free_mode)
		elif event.keycode == KEY_TAB:
			show_overview()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
			await select_spawn(event.keycode - KEY_1)
	if free_mode and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera.rotation.y -= event.relative.x * 0.003
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003, -1.50, 1.50)

func _process(delta: float) -> void:
	if not test_ready:
		return
	if free_mode and not automation_enabled:
		var direction := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		var speed := 160.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 28.0
		camera.position += camera.basis * direction.normalized() * speed * delta
	status.position.y = get_viewport().get_visible_rect().size.y - 64
	var shown_position := camera.position if free_mode else camper.position
	var place: String = "全岛" if overview_mode else VIEW_NAMES[viewpoint]
	status.text = "%s · %s｜%.1f km/h｜FPS %d\n位置 %.1f, %.1f, %.1f m｜地形与碰撞同步切换" % ["自由观景" if free_mode else "驾驶", place, camper.get_speed_kph(), Engine.get_frames_per_second(), shown_position.x, shown_position.y, shown_position.z]
