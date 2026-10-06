extends Node3D
## Isolated CAD road material validation. No changes to the game's main scene.

const ASSETS := "res://assets/world/road_projection_test/"
const MODE_NAMES := ["地形遮罩（高度保护）", "原实体路面", "纯 XZ 投影（无保护）", "遮罩 + 高差路段实体"]
const VIEW_NAMES := ["全图", "贴地道路", "坡道", "高度差路段"]
var metadata: Dictionary
var terrain_material: ShaderMaterial
var road_layer: Node3D
var hybrid: MeshInstance3D
var camera: Camera3D
var label: Label
var mode := 0
var view_index := 0
var test_ready := false
# 4 m accommodates the current CAD road/ground offsets; 2 m is diagnostic.
var height_tolerance := 4.0

func _ready() -> void:
	metadata = JSON.parse_string(FileAccess.get_file_as_string(ASSETS + "bake_metadata.json"))
	var model: Node3D = (load(ASSETS + "model_1006.gltf") as PackedScene).instantiate()
	add_child(model)
	model.position = _vec3(metadata.model_translation)
	var terrain: Node3D = model.find_child("地形", true, false)
	road_layer = model.find_child("路面", true, false)
	assert(terrain != null and road_layer != null, "Missing CAD terrain/road layer")
	# Only these two CAD layers participate in this comparison.
	for child in model.get_children():
		if child is Node3D:
			child.visible = child == terrain or child == road_layer
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = load(ASSETS + "world_road_projection.gdshader")
	terrain_material.set_shader_parameter("grass_texture", load(ASSETS + "grass_placeholder.png"))
	terrain_material.set_shader_parameter("road_texture", load(ASSETS + "road_placeholder.png"))
	terrain_material.set_shader_parameter("road_projection", load(ASSETS + "road_projection.res"))
	terrain_material.set_shader_parameter("mask_origin_xz", Vector2(metadata.mask_origin_xz[0], metadata.mask_origin_xz[1]))
	terrain_material.set_shader_parameter("mask_extent_xz", Vector2(metadata.mask_extent_xz[0], metadata.mask_extent_xz[1]))
	_apply_material(terrain, terrain_material)
	var road_material := StandardMaterial3D.new()
	road_material.albedo_texture = load(ASSETS + "road_placeholder.png")
	road_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	road_material.roughness = 0.95
	road_material.metallic_specular = 0.08
	_apply_material(road_layer, road_material)
	_make_hybrid(road_material)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.20, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.4
	add_child(sun)
	camera = Camera3D.new()
	camera.far = 8000
	camera.near = 0.1
	camera.fov = 55
	add_child(camera)
	camera.make_current()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	label = Label.new()
	label.position = Vector2(20, 16)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(label)
	select_view(0)
	set_mode(0)
	test_ready = true
	print("ROAD_SCENE_READY terrain=", metadata.terrain_triangles, " road=", metadata.road_triangles, " hybrid=", metadata.retained_hybrid_triangles)

func _vec3(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

func _apply_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
		# Same shadow treatment in both comparisons; isolate the material/geometry.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_material(child, material)

func _make_hybrid(material: Material) -> void:
	var positions: Array = JSON.parse_string(FileAccess.get_file_as_string(ASSETS + "unsupported_road_triangles.json"))
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(0, positions.size(), 3):
		var a := _vec3(positions[i])
		var b := _vec3(positions[i + 1])
		var c := _vec3(positions[i + 2])
		# Godot front faces are clockwise: normal is opposite the usual CCW cross.
		var n := (c - a).cross(b - a).normalized()
		if n.y < 0:
			var temp := b
			b = c
			c = temp
			n = -n
		vertices.append_array(PackedVector3Array([a, b, c]))
		normals.append_array(PackedVector3Array([n, n, n]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	hybrid = MeshInstance3D.new()
	hybrid.name = "ConservativeHeightMismatchRoads"
	hybrid.mesh = mesh
	hybrid.material_override = material
	hybrid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(hybrid)

func set_mode(value: int) -> void:
	mode = value % MODE_NAMES.size()
	road_layer.visible = mode == 1
	hybrid.visible = mode == 3
	terrain_material.set_shader_parameter("projection_enabled", mode != 1)
	terrain_material.set_shader_parameter("height_and_slope_guard", mode != 2)
	terrain_material.set_shader_parameter("height_tolerance", height_tolerance)
	_update_label()

func select_view(value: int) -> void:
	view_index = value % VIEW_NAMES.size()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	var target := Vector3(0, 25, 0)
	var offset := Vector3(1700, 2350, 2250)
	if view_index > 0:
		var key: String = ["near", "slope", "unsupported"][view_index - 1]
		target = _vec3(metadata.views[key])
		offset = Vector3(30, 30, 45)
		if view_index == 3:
			offset = Vector3(23, 23, 35)
	camera.position = target + offset
	camera.look_at(target)
	_update_label()

func _update_label() -> void:
	if label == null:
		return
	var road_triangles := 0
	if mode == 1:
		road_triangles = int(metadata.road_triangles)
	elif mode == 3:
		road_triangles = int(metadata.retained_hybrid_triangles)
	label.text = "model_1006 | %s | %s\n可见道路实体：%d 三角面 | 高度容差 %.1f m\nM 切换方案 · 1–4 观景 · H 切换 2/4 m · 右键拖动 · WASD/QE 移动 · Shift 加速" % [MODE_NAMES[mode], VIEW_NAMES[view_index], road_triangles, height_tolerance]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			height_tolerance = 2.0 if (mode + 1) % MODE_NAMES.size() == 3 else 4.0
			set_mode(mode + 1)
		elif event.keycode >= KEY_1 and event.keycode <= KEY_4:
			select_view(event.keycode - KEY_1)
		elif event.keycode == KEY_H:
			height_tolerance = 4.0 if height_tolerance == 2.0 else 2.0
			set_mode(mode)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera.rotation.y -= event.relative.x * 0.003
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003, -1.5, 1.5)

func _process(delta: float) -> void:
	if not test_ready:
		return
	var direction := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var speed := 80.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 15.0
	camera.position += camera.basis * direction * speed * delta
