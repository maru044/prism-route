extends Node3D

const COAST := preload("res://assets/title/title_coast.glb")
const WORDMARK := preload("res://assets/title/prism_route_wordmark.png")
const WORLD_GRASS := preload("res://scripts/grass_wind_world.gd")
const VEGETATION := preload("res://scripts/map_1012_vegetation.gd")
const MEADOW := preload("res://scripts/meadow_palette.gd")
const GRASS_BUFFER := preload("res://scripts/grass_instance_buffer.gd")
const MEADOW_LAYER := 1 << 26
const TITLE_GRASS_HEIGHT_SCALE := .46
const TITLE_GRASS_GOLD := Color("#b18e4b")
const FOLIAGE_STYLE := preload("res://scripts/foliage_style.gd")
const WORLD_CHARACTER := preload("res://scenes/characters/world_ganyu.tscn")
const CHARACTER_CONTROLLER := preload("res://scripts/world_character_controller.gd")
const SKY := preload("res://assets/environment/sky/fresh_cumulus_sky.tres")
const WATER := preload("res://scripts/water/water_manager.gd")
const WORLD_AUDIO := preload("res://scripts/audio/world_audio_1030.gd")
const WORLD := "res://scenes/main.tscn"
const UI := preload("res://scenes/combat/encounter_ui_style.gd")
const PALETTE := preload("res://scenes/combat/temple_paper_palette.tres")
const SETTINGS := preload("res://scripts/ui/title_api_settings.gd")

var _menu: VBoxContainer
var _start_button: Button
var _start_status: Label
var _settings: SETTINGS
var _loading := false
var _ambient_gain := 1.0
var _gull: AudioStreamPlayer
var _gull_timer: Timer
var _last_gull := -1
var _gull_volume_db := -12.0


func _ready() -> void:
	var coast := COAST.instantiate() as Node3D
	add_child(coast)
	var camera := coast.find_child("TitleCamera", true, false) as Camera3D
	camera.make_current()
	_setup_lumine(coast, camera)
	var vegetation := VEGETATION.new()
	vegetation.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(vegetation)
	vegetation.biome_noise_texture = MEADOW.make_biome_noise()
	vegetation._load_meshes_and_materials()
	MEADOW.apply_grass(vegetation.grass_material)
	_plant_trees(coast, vegetation)
	_setup_sea(camera, _setup_lighting())
	_setup_menu()
	_setup_audio()
	set_process(false)
	_plant_meadow(coast.find_child("TitleMeadow", true, false) as MeshInstance3D, vegetation)


func _setup_lumine(coast: Node3D, camera: Camera3D) -> void:
	var anchor := coast.find_child("LumineAnchor", true, false) as Node3D
	var look_target := coast.find_child("LumineLookTarget", true, false) as Node3D
	var lumine := WORLD_CHARACTER.instantiate() as CHARACTER_CONTROLLER
	lumine.active_character_id = "lumine"
	lumine.presentation_only = true
	lumine.collision_layer = 0
	lumine.collision_mask = 0
	anchor.add_child(lumine)
	var facing := look_target.global_position - anchor.global_position
	lumine.set_spawn(anchor.global_position, atan2(-facing.x, -facing.z))
	var eye_height := lumine.camera_pivot.position.y + lumine.camera_pivot.basis.z.y * lumine.spring_arm.spring_length
	camera.global_position.y = anchor.global_position.y + eye_height
	camera.fov = lumine.camera.fov
	camera.near = lumine.camera.near


func _plant_meadow(ground: MeshInstance3D, vegetation: VEGETATION) -> void:
	var material := vegetation.grass_material
	WORLD_GRASS.apply_wind_material(material)
	material.set_shader_parameter("palette_dry", TITLE_GRASS_GOLD)
	material.set_shader_parameter("palette_green", TITLE_GRASS_GOLD)
	material.set_shader_parameter("coastal_enabled", false)
	material.set_shader_parameter("root_tone", .83)
	material.set_shader_parameter("tip_tone", 1.04)
	var source_mesh := vegetation._extract_first_mesh(WORLD_GRASS.MESH)
	var near_mesh := WORLD_GRASS.make_presentation_mesh(source_mesh, material, 4)
	var wind := WORLD_GRASS.new()
	wind.material = material
	add_child(wind)
	wind.advance(0.0)

	var meadow_ground := StandardMaterial3D.new()
	meadow_ground.albedo_color = Color("#94773f")
	meadow_ground.roughness = .92
	var triangles := PackedVector3Array()
	for index in ground.mesh.get_surface_count():
		if ground.mesh.surface_get_material(index).resource_name == "Footpath":
			continue
		ground.set_surface_override_material(index, meadow_ground)
		var arrays := ground.mesh.surface_get_arrays(index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for face_vertex: int in arrays[Mesh.ARRAY_INDEX]:
			triangles.append(ground.global_transform * vertices[face_vertex])

	var surface := StaticBody3D.new()
	surface.collision_layer = MEADOW_LAYER
	surface.collision_mask = 0
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(triangles)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	surface.add_child(collider)
	add_child(surface)
	await get_tree().physics_frame

	var bounds := ground.global_transform * ground.get_aabb()
	var cell_size: float = VEGETATION.GRASS_CHUNK_SIZE
	var first := Vector2i(floori(bounds.position.x / cell_size), floori(bounds.position.z / cell_size))
	var last := Vector2i(floori(bounds.end.x / cell_size), floori(bounds.end.z / cell_size))
	var ground_min := bounds.position.y - .01
	var ground_max := bounds.end.y + .01
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = MEADOW_LAYER
	query.hit_back_faces = true
	var space := get_world_3d().direct_space_state
	for cell_z in range(first.y, last.y + 1):
		for cell_x in range(first.x, last.x + 1):
			var cell := Vector3i(cell_x, floori(ground_min / cell_size), cell_z)
			_plant_meadow_cell(cell, ground_min, ground_max, space, query, near_mesh, material, vegetation)
			await get_tree().physics_frame
	surface.queue_free()
	vegetation.queue_free()


func _plant_meadow_cell(cell: Vector3i, ground_min: float, ground_max: float,
		space: PhysicsDirectSpaceState3D, query: PhysicsRayQueryParameters3D,
		near_mesh: Mesh, material: ShaderMaterial, vegetation: VEGETATION) -> void:
	var size: float = VEGETATION.GRASS_CHUNK_SIZE
	var origin := Vector3(cell) * size
	var rng := RandomNumberGenerator.new()
	# Same cell seed and shared blade buffers as the world grass streamer.
	rng.seed = abs(cell.x * 73856093 ^ cell.y * 83492791 ^ cell.z * 19349663 ^ 0x4A31)
	var near: Array = []
	var far: Array = []
	var near_data: Array = []
	var far_data: Array = []
	for sample in VEGETATION.GRASS_SAMPLES_PER_CHUNK:
		var x := rng.randf_range(0.0, size)
		var z := rng.randf_range(0.0, size)
		query.from = Vector3(origin.x + x, ground_max, origin.z + z)
		query.to = Vector3(origin.x + x, ground_min, origin.z + z)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit.normal
		var root: Vector3 = hit.position
		if normal.y <= .72 or rng.randf() > vegetation._grass_coverage(root, normal):
			continue
		GRASS_BUFFER.append_blades(rng, x, z, root.y - origin.y, normal,
			near, far, near_data, far_data, VEGETATION.GRASS_FAR_SURVIVOR_FRACTION)
	near.append_array(far)
	near_data.append_array(far_data)
	if near.is_empty():
		return
	for index in near.size():
		var blade: Transform3D = near[index]
		blade.basis.y *= TITLE_GRASS_HEIGHT_SCALE
		near[index] = blade
	var buffer := GRASS_BUFFER.pack(near, near_data)
	var grass := GRASS_BUFFER.make_node("TitleMeadowGrass", near_mesh, material, buffer, 0.0,
		GRASS_BUFFER.bounds(buffer, near_mesh.get_aabb()))
	grass.position = origin
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.extra_cull_margin = WORLD_GRASS.CULL_MARGIN
	add_child(grass, true)


func _plant_trees(coast: Node3D, vegetation: VEGETATION) -> void:
	var broad_trunk := _tree_mesh_without_lods(vegetation.tree_large_broad_trunk_mesh)
	var small_trunk := _tree_mesh_without_lods(vegetation.tree_near_trunk_mesh)
	var to_coast := coast.global_transform.affine_inverse()
	# The palette indices match the world planting editor.
	var palettes := {"Orange": 3, "Red": 4, "Green": 0}
	for color: String in palettes:
		var locations: Array[Transform3D] = []
		var prefix := "TitleTree" + color
		for marker: Node3D in coast.find_children(prefix + "*", "Node3D", true, false):
			locations.append(to_coast * marker.global_transform)
		if locations.is_empty():
			continue
		var small := color == "Green"
		# The streamer already merges crown meshes without imported LOD tables.
		var crown: Mesh = vegetation.tree_near_leaf_mesh if small else vegetation.tree_large_broad_leaf_mesh
		var material := vegetation.tree_small_lod0_material if small else vegetation.tree_broad_lod0_material
		vegetation._add_tree_mesh_pair(coast, prefix, small_trunk if small else broad_trunk,
			crown, locations, material, 0.0, 0.0, 0, palettes[color])
	FOLIAGE_STYLE.new().bind_streamer(vegetation)
	for layer: MultiMeshInstance3D in vegetation.tree_lod0_nodes:
		if layer.material_override is ShaderMaterial:
			(layer.material_override as ShaderMaterial).set_shader_parameter("tree_lod_fade", Vector4(-100000, -99999, 99999, 100000))


func _tree_mesh_without_lods(source: Mesh) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface), source.surface_get_arrays(surface))
	return mesh


func _setup_lighting() -> Environment:
	var sky := Sky.new()
	var material := SKY.duplicate() as ShaderMaterial
	material.set_shader_parameter("display_yaw", deg_to_rad(10.0))
	material.set_shader_parameter("display_energy", .72)
	sky.sky_material = material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = .38
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = .82
	var lighting := WorldEnvironment.new()
	lighting.environment = environment
	add_child(lighting)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-33, -42, 0)
	sun.light_color = Color(1.0, .95, .86)
	sun.light_energy = .72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 115
	add_child(sun)
	return environment


func _setup_sea(camera: Camera3D, environment: Environment) -> void:
	var sea := MeshInstance3D.new()
	sea.name = "OpenSea"
	var surface := PlaneMesh.new()
	surface.size = Vector2(9250, 9250)
	sea.mesh = surface
	add_child(sea)
	var manager := WATER.new()
	manager.name = "TitleWater"
	manager.style = WATER.Style.SKY
	manager.interactions_enabled = false
	manager.wind_override = .40
	add_child(manager)
	manager.initialize(environment, Callable(), func(): return camera)
	manager.register_water(sea, "title_ocean", "open_sea")
	var material := sea.material_override as ShaderMaterial
	var painted_sky := environment.sky.sky_material as ShaderMaterial
	var display_yaw: float = painted_sky.get_shader_parameter("display_yaw")
	# Positive water yaw adds to the panorama longitude, just like display_yaw.
	material.set_shader_parameter("sky_yaw", environment.sky_rotation.y + display_yaw)
	material.set_shader_parameter("sky_panorama", painted_sky.get_shader_parameter("display_panorama"))
	var display_energy: float = painted_sky.get_shader_parameter("display_energy")
	material.set_shader_parameter("sky_reflection_energy", display_energy * .90)
	material.set_shader_parameter("deep_color", Color("#245e92"))
	material.set_shader_parameter("shallow_color", Color("#438fa3"))


func _setup_menu() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := TextureRect.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.texture = WORDMARK
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(title)
	title.anchor_left = .017
	title.anchor_top = .080
	title.anchor_right = .395
	title.anchor_bottom = .284

	_menu = UI.column(14)
	root.add_child(_menu)
	_menu.anchor_left = .062
	_menu.anchor_right = .234
	_menu.anchor_top = .327
	_menu.anchor_bottom = .327
	_start_button = _add_menu_button("开始游戏", _start_game)
	_add_menu_button("设置", _open_settings)
	_add_menu_button("退出游戏", get_tree().quit)
	_start_status = UI.text_label("", 21, Color("#fff6e5"), UI.DEFAULT_PALETTE)
	_start_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu.add_child(_start_status)
	_start_button.grab_focus()

	_settings = SETTINGS.new()
	_settings.hide()
	root.add_child(_settings)
	_settings.closed.connect(_close_settings)


func _add_menu_button(caption: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = caption
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.custom_minimum_size.y = 65
	item.add_theme_font_override("font", UI.command_font())
	item.add_theme_font_size_override("font_size", 40)
	var padding := StyleBoxEmpty.new()
	padding.content_margin_left = 72
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		item.add_theme_stylebox_override(state, padding)
	item.add_theme_color_override("font_color", Color("#fff6e3"))
	item.add_theme_color_override("font_disabled_color", Color("#fff6e3"))
	item.add_theme_color_override("font_hover_color", PALETTE.text)
	item.add_theme_color_override("font_focus_color", PALETTE.text)
	item.add_theme_color_override("font_pressed_color", PALETTE.text)
	_menu.add_child(item)

	var focus_paper := ColorRect.new()
	focus_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_paper.show_behind_parent = true
	var material := UI.paper_material(PALETTE, .74)
	material.set_shader_parameter("selected", .54)
	focus_paper.material = material
	item.add_child(focus_paper)
	focus_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cursor := UI.text_label("◇", 27, PALETTE.text, PALETTE)
	focus_paper.add_child(cursor)
	cursor.position = Vector2(22, 14)
	var update := func():
		focus_paper.visible = item.has_focus() and not item.disabled
	item.resized.connect(func(): material.set_shader_parameter("plate_size", item.size))
	item.focus_entered.connect(update)
	item.focus_exited.connect(update)
	item.mouse_entered.connect(func():
		if not item.disabled:
			item.grab_focus())
	item.pressed.connect(action)
	update.call()
	return item


func _open_settings() -> void:
	_menu.hide()
	_settings.open()


func _close_settings() -> void:
	_menu.show()
	_menu.get_child(1).grab_focus()


func _start_game() -> void:
	if _loading:
		return
	var error := ResourceLoader.load_threaded_request(WORLD, "PackedScene")
	if error != OK:
		_start_status.text = "无法加载游戏（%s）" % error_string(error)
		return
	_loading = true
	_start_status.text = "正在加载…"
	for item in _menu.get_children():
		if item is Button:
			item.release_focus()
			item.disabled = true
	set_process(true)


func _process(_delta: float) -> void:
	var status := ResourceLoader.load_threaded_get_status(WORLD)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var world := ResourceLoader.load_threaded_get(WORLD) as PackedScene
		if world != null and get_tree().change_scene_to_packed(world) == OK:
			set_process(false)
			return
	_loading = false
	set_process(false)
	for item in _menu.get_children():
		if item is Button:
			item.disabled = false
	_start_status.text = "无法加载游戏。"
	_start_button.grab_focus()


func _setup_audio() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/world_1030/settings.json"))
	var config: Dictionary = data if data is Dictionary else {}
	if not config.get("enabled", true):
		return
	_ambient_gain = float(config.get("master", .8)) * float(config.get("ambience", .85))
	_gull_volume_db = float(config.get("gull_db", -6.0)) - 6.0
	var surf := AudioStreamPlayer.new()
	var loop := WORLD_AUDIO.WAVES.duplicate() as AudioStreamOggVorbis
	loop.loop = true
	surf.name = "TitleSurf"
	surf.stream = loop
	surf.volume_db = linear_to_db(maxf(.0001, _ambient_gain * float(config.get("waves_gain", .40))))
	add_child(surf)
	surf.play()
	_gull = AudioStreamPlayer.new()
	_gull.name = "TitleGulls"
	_gull.volume_db = _gull_volume_db + linear_to_db(maxf(.0001, _ambient_gain))
	add_child(_gull)
	_gull_timer = Timer.new()
	_gull_timer.one_shot = true
	_gull_timer.timeout.connect(_play_gull)
	add_child(_gull_timer)
	_gull_timer.start(4.0)


func _play_gull() -> void:
	var pick := randi_range(0, WORLD_AUDIO.GULLS.size() - 1)
	if pick == _last_gull:
		pick = (pick + 1) % WORLD_AUDIO.GULLS.size()
	_last_gull = pick
	_gull.stream = WORLD_AUDIO.GULLS[pick]
	_gull.pitch_scale = randf_range(.95, 1.05)
	_gull.play()
	_gull_timer.start(randf_range(12.0, 24.0))
