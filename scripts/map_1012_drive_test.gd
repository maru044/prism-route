extends Node3D
## 1012 world review: original CAD surfaces, spaced trees and the short camper.

const ASSETS := "res://assets/world/map_1012_test/"
const VIEW_NAMES := ["道路出生点", "林地", "沙滩", "高层平台"]
const FRESH_SKY := preload("res://assets/environment/sky/fresh_cumulus_sky.tres")
const TERRAIN_SHADER := preload("res://assets/world/terrain/shaders/terrain_draft.gdshader")
const TEST_PANEL := preload("res://scripts/world_test_panel.gd")

@onready var camper: CharacterBody3D = $CamperVan
@onready var chase_camera: Camera3D = $CamperVan/CameraPivot/SpringArm3D/Camera3D
@onready var vegetation = $VegetationLodStreamer
@onready var character = $WorldGanyu
var model: Node3D
var metadata: Dictionary
var anchors: Array[Vector3] = []
var test_ready := false
var free_mode := false
var overview_mode := false
var automation_enabled := false
var viewpoint := 0
var camera: Camera3D
var status: Label
var fly_button: Button
var actor_button: Button
var controls_label: Label
var test_panel
var character_mode := false
var switching_actor := false
var terrain_material: ShaderMaterial
var lod_enabled := true
var vegetation_enabled := true
var biome_noise: NoiseTexture2D

func _ready() -> void:
	metadata = JSON.parse_string(FileAccess.get_file_as_string(ASSETS + "build_metadata.json"))
	biome_noise = _noise_texture(46129, 0.012)
	_build_environment()
	_build_map()
	for point: Array in metadata.anchors:
		anchors.append(_vec3(point))
	camera = Camera3D.new()
	camera.far = 12000
	camera.fov = 60
	add_child(camera)
	_build_hud()
	character.automation_enabled = automation_enabled
	_sync_actor_controls()
	camper.calibrate_wheels()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await select_spawn(0)
	vegetation.initialize(camper, biome_noise, 2)
	test_ready = true
	print("MAP_1012_READY trees=%d large=%d old_camper_unscaled=true" % [vegetation.tree_instance_count, vegetation.large_tree_instance_count])

func _vec3(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func _noise_texture(seed_value: int, frequency: float) -> NoiseTexture2D:
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.generate_mipmaps = true
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 4
	texture.noise = noise
	return texture

func _build_map() -> void:
	model = (load(ASSETS + "map_1012.glb") as PackedScene).instantiate()
	add_child(model)
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = TERRAIN_SHADER
	terrain_material.set_shader_parameter("biome_noise_texture", biome_noise)
	terrain_material.set_shader_parameter("use_height_sand", false)
	var sand := ShaderMaterial.new()
	sand.shader = load(ASSETS + "sand.gdshader")
	sand.set_shader_parameter("grain_texture", _noise_texture(1012, 0.075))
	var water := ShaderMaterial.new()
	water.shader = load(ASSETS + "water.gdshader")
	var road := ShaderMaterial.new()
	road.shader = load(ASSETS + "road.gdshader")
	var projection: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ASSETS + "road_projection_metadata.json"))
	var atlas: Texture2D = load(ASSETS + "road_projection.res")
	terrain_material.set_shader_parameter("project_roads", true)
	for material: ShaderMaterial in [terrain_material, road]:
		material.set_shader_parameter("road_projection", atlas)
		material.set_shader_parameter("road_origin_xz", Vector2(projection.origin_xz[0], projection.origin_xz[1]))
		material.set_shader_parameter("road_extent_xz", Vector2(projection.extent_xz[0], projection.extent_xz[1]))
		material.set_shader_parameter("ground_road_height_tolerance", projection.ground_road_height_tolerance_m)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(model, meshes)
	for mesh in meshes:
		var kind: String = mesh.name
		mesh.material_override = {"Terrain": terrain_material, "Roads": road, "Beaches": sand, "Water": water}.get(kind, terrain_material)
		if kind == "Water":
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var shape := mesh.mesh.create_trimesh_shape()
		shape.backface_collision = true
		var body := StaticBody3D.new()
		body.name = "ExactMeshCollision"
		# Water is a vegetation occluder on layer 4, not a drivable floor.
		body.collision_layer = 4 if kind == "Water" else (9 if kind == "Roads" else 1)
		body.collision_mask = 0
		body.set_meta("map_surface", kind)
		mesh.add_child(body)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)

func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_collect_meshes(child, result)

func _build_environment() -> void:
	var sky := Sky.new()
	sky.sky_material = FRESH_SKY
	sky.radiance_size = Sky.RADIANCE_SIZE_1024
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.sky_rotation = Vector3(0, deg_to_rad(70), 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.38
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.82
	environment.ssao_enabled = true
	environment.ssao_radius = 1.25
	environment.ssao_intensity = 1.20
	var world := WorldEnvironment.new()
	world.name = "FreshSkyEnvironment"
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-43, -128, 0)
	sun.light_color = Color("ffe2b8")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180
	add_child(sun)

func _build_hud() -> void:
	test_panel = TEST_PANEL.new()
	test_panel.name = "HUD"
	add_child(test_panel)
	test_panel.setup(self)
	# Retain these handles for the existing world/actor verification tools.
	fly_button = test_panel.fly_button
	actor_button = test_panel.actor_button
	controls_label = test_panel.controls_label
	status = test_panel.status

func ground_hit(point: Vector3, include_water := false) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 400, point.z), Vector3(point.x, -30, point.z), 5 if include_water else 1)
	query.hit_back_faces = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func select_spawn(index: int) -> void:
	viewpoint = index
	await get_tree().physics_frame
	var spawn_point := anchors[index]
	if character_mode and index in [1, 3]:
		# Keep the established character viewpoints. The builder reserves a
		# ten-metre tree clearance around these fixed terrain bookmarks.
		spawn_point.x += 4.0
	var hit := ground_hit(spawn_point)
	if hit.is_empty():
		push_error("Bookmark has no surface: " + VIEW_NAMES[index])
		return
	var direction := _vec3(metadata.road_direction)
	var heading := atan2(-direction.x, -direction.z) if index == 0 else -0.60
	if character_mode:
		character.set_spawn(hit.position + Vector3.UP * 0.1, heading)
	else:
		camper.global_position = hit.position + Vector3.UP * 0.25
		camper.rotation.y = heading
		camper.velocity = Vector3.ZERO
		camper.drive_speed = 0
		camper.set_respawn_transform(camper.global_transform)
		$CamperVan/CameraPivot.rotation = Vector3(-0.20, 0, 0)
	if free_mode:
		show_detail(index)

func set_free_mode(enabled: bool) -> void:
	if enabled and not free_mode:
		camera.global_transform = active_camera().global_transform
	free_mode = enabled
	overview_mode = false
	_sync_actor_controls()

func active_actor() -> CharacterBody3D:
	return character if character_mode else camper

func active_camera() -> Camera3D:
	return character.camera if character_mode else chase_camera

func _sync_actor_controls() -> void:
	camper.visible = not character_mode
	camper.set_physics_process(not free_mode and not character_mode)
	camper.set_process_unhandled_input(not free_mode and not character_mode)
	character.visible = character_mode
	character.process_mode = Node.PROCESS_MODE_INHERIT if character_mode else Node.PROCESS_MODE_DISABLED
	character.set_control_enabled(character_mode and not free_mode)
	if free_mode:
		camera.make_current()
	else:
		active_camera().make_current()
	vegetation.target = camera if free_mode else active_actor()
	vegetation.set_grass_actor(active_actor(), not character_mode)
	fly_button.text = "F 返回角色" if free_mode and character_mode else ("F 返回驾驶" if free_mode else "F 自由观景")
	actor_button.text = "C 切换为房车" if character_mode else "C 切换为甘雨"
	controls_label.text = ("人物：WASD 移动 · Shift 奔跑\n空格跳跃 · G 招呼 · R 复位" if character_mode else "房车：W/S 前进倒车 · A/D 转向\n空格刹车 · R 复位") + "\n\n镜头：右键拖动 · 滚轮缩放\n自由观景：WASD/QE 移动 · Shift 加速"
	test_panel.refresh()

func set_character_mode(enabled: bool) -> void:
	if switching_actor or enabled == character_mode:
		return
	switching_actor = true
	actor_button.disabled = true
	var point := active_actor().global_position
	var heading: float = camper.rotation.y if enabled else character.visual.rotation.y - PI
	camper.drive_speed = 0
	camper.velocity = Vector3.ZERO
	camper.set_physics_process(false)
	character.set_control_enabled(false)
	await get_tree().physics_frame
	# Preserve the current storey instead of teleporting to the highest surface
	# above a character standing on a lower road beneath a megastructure.
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 3, point - Vector3.UP * 12, 1)
	query.hit_back_faces = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		point = hit.position
	character_mode = enabled
	if enabled:
		character.set_spawn(point + Vector3.UP * 0.1, heading)
	else:
		camper.global_position = point + Vector3.UP * 0.25
		camper.rotation.y = heading
		camper.set_respawn_transform(camper.global_transform)
		camper.camera_pivot.rotation = Vector3(-0.20, 0, 0)
	switching_actor = false
	actor_button.disabled = false
	_sync_actor_controls()

func show_overview() -> void:
	if not free_mode:
		set_free_mode(true)
	overview_mode = true
	camera.position = Vector3(1400, 1450, 1900)
	camera.look_at(Vector3(0, 35, 0))

func show_detail(index := 1) -> void:
	if not free_mode:
		set_free_mode(true)
	overview_mode = false
	viewpoint = index
	var target := anchors[index]
	var hit := ground_hit(target)
	if not hit.is_empty():
		target = hit.position
	camera.position = target + (Vector3(100, 90, 130) if index == 2 else Vector3(45, 18, 65))
	camera.look_at(target)

func _unhandled_input(event: InputEvent) -> void:
	if not test_ready or test_panel.menu_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F: set_free_mode(not free_mode)
			KEY_TAB: show_overview()
			KEY_C: set_character_mode(not character_mode)
			KEY_L:
				set_lod_enabled(not lod_enabled)
			KEY_V:
				set_vegetation_enabled(not vegetation_enabled)
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			await select_spawn(event.keycode - KEY_1)
	if free_mode and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera.rotation.y -= event.relative.x * 0.003
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003, -1.50, 1.50)

func _process(delta: float) -> void:
	if not test_ready:
		return
	if free_mode and not automation_enabled:
		var direction := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		camera.position += camera.basis * direction.normalized() * (160.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 28.0) * delta

func set_lod_enabled(enabled: bool) -> void:
	lod_enabled = enabled
	vegetation.set_lod_enabled(enabled)
	test_panel.refresh()

func set_vegetation_enabled(enabled: bool) -> void:
	vegetation_enabled = enabled
	vegetation.set_vegetation_enabled(enabled)
	test_panel.refresh()
