extends Node3D
## Current Rhino geometry, one opaque world-space material; no raised cover mesh.
const ASSETS = "res://assets/world/landscape_mask_test/"
var metadata: Dictionary
var camera: Camera3D
var material: ShaderMaterial
var test_ready := false
var current_mode := 0
var current_view := 0
var label: Label

func _ready() -> void:
	metadata = JSON.parse_string(FileAccess.get_file_as_string(ASSETS + "metadata.json"))
	var tex_path := ASSETS + "landscape_mask.res"
	var tex: Texture2D
	if ResourceLoader.exists(tex_path) and not "--rebuild-mask" in OS.get_cmdline_user_args():
		tex = load(tex_path)
	else:
		var raw := FileAccess.get_file_as_bytes("res://.landscape_mask_build/landscape_mask.rg16f")
		var size := int(metadata.resolution)
		assert(raw.size() == size * size * 4)
		var image := Image.create_from_data(size, size, false, Image.FORMAT_RGH, raw)
		image.generate_mipmaps()
		tex = ImageTexture.create_from_image(image)
		assert(ResourceSaver.save(tex, tex_path, ResourceSaver.FLAG_COMPRESS) == OK)
	material = ShaderMaterial.new()
	material.shader = load(ASSETS + "landscape.gdshader")
	material.set_shader_parameter("landscape_mask", tex)
	material.set_shader_parameter("mask_origin_xz", Vector2(metadata.origin_xz[0], metadata.origin_xz[1]))
	material.set_shader_parameter("mask_extent_xz", Vector2(metadata.extent_xz[0], metadata.extent_xz[1]))
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file(ProjectSettings.globalize_path(ASSETS + "current_region.glb"), state) == OK)
	var model := document.generate_scene(state)
	add_child(model)
	var road := StandardMaterial3D.new()
	road.albedo_color = Color(0.075, 0.085, 0.085)
	road.roughness = 0.94
	road.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sand := StandardMaterial3D.new()
	sand.albedo_color = Color(0.74, 0.68, 0.51)
	sand.roughness = 1.0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if str(node.name).begins_with("Terrain_"):
			node.material_override = material
		elif str(node.name).begins_with("Road_"):
			node.material_override = road
		else:
			node.material_override = sand
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.22, 0.46, 0.68)
	sky_material.sky_horizon_color = Color(0.73, 0.83, 0.88)
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky.sky_material = sky_material
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color(1.0, 0.95, 0.87)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 1200
	add_child(sun)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000, 4000)
	water.mesh = plane
	water.position.y = -2.5
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.12, 0.43, 0.48)
	blue.roughness = 0.3
	water.material_override = blue
	add_child(water)
	camera = Camera3D.new()
	camera.near = 0.15
	camera.far = 5000
	camera.fov = 53
	add_child(camera)
	camera.make_current()
	get_viewport().msaa_3d = Viewport.MSAA_4X
	var ui := CanvasLayer.new()
	add_child(ui)
	label = Label.new()
	label.position = Vector2(20, 16)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	ui.add_child(label)
	select_view(0)
	set_mode(0)
	test_ready = true
	print("LANDSCAPE_READY ", metadata.triangles, " triangles / original geometry / RG16F SDF")

func set_mode(mode: int) -> void:
	current_mode = mode
	material.set_shader_parameter("comparison_mode", mode)
	var names := ["CAD SDF / analytical edge AA", "Diagnostic ONLY: synthetic 128-grid hard threshold", "Original geometry / white material"]
	label.text = "CURRENT RHINO TERRAIN | " + names[mode] + "\n1 SDF   2 coarse diagnostic   3 white   V view   RMB + WASD/QE fly"

func select_view(index: int) -> void:
	current_view = index % 3
	var t: Array = metadata.near_target
	var target := Vector3(t[0], t[1], t[2])
	if current_view == 0:
		target = Vector3(40, 10, -10)
		camera.position = target + Vector3(455, 540, 540)
	elif current_view == 1:
		camera.position = target + Vector3(23, 33, 26)
	else:
		camera.position = target + Vector3(-30, 5, 24)
	camera.look_at(target + Vector3(0, 0.6, 0))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: set_mode(0)
			KEY_2: set_mode(1)
			KEY_3: set_mode(2)
			KEY_V: select_view(current_view + 1)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera.rotation.y -= event.relative.x * 0.003
		camera.rotation.x = clamp(camera.rotation.x - event.relative.y * 0.003, -1.5, 1.5)

func _process(delta: float) -> void:
	if not test_ready or not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): return
	var direction := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): direction.z -= 1
	if Input.is_physical_key_pressed(KEY_S): direction.z += 1
	if Input.is_physical_key_pressed(KEY_A): direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D): direction.x += 1
	if Input.is_physical_key_pressed(KEY_Q): direction.y -= 1
	if Input.is_physical_key_pressed(KEY_E): direction.y += 1
	camera.position += camera.basis * direction * delta * (65 if Input.is_key_pressed(KEY_SHIFT) else 15)
