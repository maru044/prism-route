extends Control
## Self-contained rendering test. Run scenes/product_preview.tscn directly.

const PRODUCT := preload("res://assets/products/classic_drop/classic_drop.glb")
const PRODUCTS: Array[PackedScene] = [PRODUCT,
	preload("res://assets/products/progressive_beads/progressive_beads.glb"),
	preload("res://assets/products/elongated_plug/elongated_plug.glb"),
	preload("res://assets/products/triple_lobe/triple_lobe.glb")]
const PRODUCT_NAMES := ["Classic drop", "Progressive five beads", "Elongated oval", "Triple lobe"]
const PRODUCT_SLUGS := ["classic_drop", "progressive_beads", "elongated_plug", "triple_lobe"]
const MATERIAL_NAMES := ["Clear shell / drifting gel", "Frosted silicone", "Polished steel"]
const STUDIO := preload("res://assets/products/classic_drop/synthetic_studio.exr")
const SHELL_SHADER := preload("res://assets/products/classic_drop/outer_shell.gdshader")
const GEL_SHADER := preload("res://assets/products/classic_drop/blue_gel.gdshader")
const SHADOW_SHADER := preload("res://assets/products/classic_drop/contact_shadow.gdshader")

var viewport: SubViewport
var product: Node3D
var bubbles: Array[Node3D] = []
var bubble_heights: Array[float] = []
var rotating := true
var dragging := false
var elapsed := 0.0
var product_index := 0
var material_index := 0
var shape_picker: OptionButton
var material_picker: OptionButton
var shadow: MeshInstance3D


func _ready() -> void:
	_build_interface()
	_build_stage()


func _process(delta: float) -> void:
	elapsed += delta
	if rotating:
		product.rotate_y(delta * 0.22)
	for i in bubbles.size():
		bubbles[i].position.y = bubble_heights[i] + sin(elapsed * (0.6 + i * 0.09) + i) * 0.025


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("e9ebee")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 8)
	add_child(layout)

	var heading := Label.new()
	heading.text = "COLLECTIBLE FORMS  /  PRODUCT LIGHTING STUDY"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color("293745"))
	heading.add_theme_font_size_override("font_size", 20)
	layout.add_child(heading)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 16)
	layout.add_child(controls)
	shape_picker = OptionButton.new()
	for title in PRODUCT_NAMES:
		shape_picker.add_item(title)
	shape_picker.item_selected.connect(select_product)
	controls.add_child(shape_picker)
	material_picker = OptionButton.new()
	for title in MATERIAL_NAMES:
		material_picker.add_item(title)
	material_picker.item_selected.connect(select_material)
	controls.add_child(material_picker)
	var reset_button := Button.new()
	reset_button.text = "Reset view"
	reset_button.pressed.connect(func():
		product.rotation = Vector3(0.0, 0.25, 0.0)
		rotating = true)
	controls.add_child(reset_button)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.gui_input.connect(_on_preview_input)
	layout.add_child(container)

	viewport = SubViewport.new()
	viewport.name = "IsolatedProductViewport"
	viewport.size = Vector2i(1024, 768)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)

	var caption := Label.new()
	caption.text = "Drag to rotate    ·    Space: pause rotation    ·    Synthetic softbox HDR environment"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", Color("4b5a67"))
	caption.add_theme_font_size_override("font_size", 15)
	layout.add_child(caption)


func _build_stage() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("e9ebee")
	environment.sky = Sky.new()
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = STUDIO
	environment.sky.sky_material = panorama
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_exposure = 0.85
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.65, 6.2)
	camera.fov = 32.0
	viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 1.37, 0.0))
	camera.current = true

	shadow = MeshInstance3D.new()
	var shadow_mesh := PlaneMesh.new()
	shadow_mesh.size = Vector2(2.7, 2.7)
	shadow.mesh = shadow_mesh
	shadow.position.y = 0.005
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = SHADOW_SHADER
	shadow.material_override = shadow_material
	viewport.add_child(shadow)

	select_product(0)
	_add_area_light(Vector3(-2.8, 3.3, 2.4), Vector2(1.1, 3.4), 5.0)
	_add_area_light(Vector3(2.8, 2.4, 2.1), Vector2(0.35, 2.9), 2.5)
	_add_area_light(Vector3(0.1, 5.0, -1.7), Vector2(2.8, 1.1), 2.0)


func select_product(index: int) -> void:
	product_index = index
	shape_picker.select(index)
	dragging = false
	bubbles.clear()
	bubble_heights.clear()
	if is_instance_valid(product):
		viewport.remove_child(product)
		product.queue_free()
	product = PRODUCTS[index].instantiate()
	viewport.add_child(product)
	# Equal display height keeps the existing camera and lighting study consistent.
	# Source units are concept proportions, not production dimensions.
	var bounds := AABB()
	var first := true
	for node in product.find_children("*", "MeshInstance3D", true, false):
		var item := node as MeshInstance3D
		var local_transform := product.global_transform.affine_inverse() * item.global_transform
		for corner in 8:
			var point: Vector3 = local_transform * item.get_aabb().get_endpoint(corner)
			if first:
				bounds = AABB(point, Vector3.ZERO)
				first = false
			else:
				bounds = bounds.expand(point)
	var fit := 1.0 if index == 0 else 2.76 / bounds.end.y
	product.scale = Vector3.ONE * fit
	product.rotation.y = 0.25
	shadow.scale = Vector3.ONE * clampf(bounds.size.x * fit / 1.92, 0.35, 1.0)
	select_material(material_index)


func select_material(index: int) -> void:
	material_index = index
	material_picker.select(index)
	bubbles.clear()
	bubble_heights.clear()
	var shell_material := ShaderMaterial.new()
	shell_material.shader = SHELL_SHADER
	shell_material.render_priority = 1
	var connector_material := shell_material.duplicate() as ShaderMaterial
	connector_material.set_shader_parameter("face_opacity", 0.08)
	var base_material := StandardMaterial3D.new()
	base_material.albedo_color = Color(0.86, 0.93, 1.0, 0.35)
	base_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	base_material.roughness = 0.06
	base_material.metallic = 0.0
	var bubble_material := StandardMaterial3D.new()
	bubble_material.albedo_color = Color(0.75, 0.94, 1.0, 0.75)
	bubble_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bubble_material.roughness = 0.04
	bubble_material.metallic = 0.0
	var opaque_material := StandardMaterial3D.new()
	if index == 1:
		opaque_material.albedo_color = Color("96b9c7")
		opaque_material.roughness = 0.62
	else:
		opaque_material.albedo_color = Color("d3d8dc")
		opaque_material.metallic = 1.0
		opaque_material.roughness = 0.11
	var core_index := 0
	for mesh in product.find_children("*", "MeshInstance3D", true, false):
		var item := mesh as MeshInstance3D
		var name_lower := item.name.to_lower() + " " + item.get_parent().name.to_lower()
		var interior := "bluegelcore" in name_lower or "bubble" in name_lower
		item.visible = index == 0 or not interior
		if index != 0:
			item.material_override = opaque_material
			continue
		if "outershell" in name_lower:
			item.material_override = connector_material if "connector" in name_lower or "handle" in name_lower else shell_material
		elif "bluegelcore" in name_lower:
			var gel_material := ShaderMaterial.new()
			gel_material.shader = GEL_SHADER
			if product_index != 0:
				var bounds := item.get_aabb()
				var flow_scale := Vector3(0.948 / bounds.size.x, 1.67 / bounds.size.y, 0.948 / bounds.size.z)
				gel_material.set_shader_parameter("flow_scale", flow_scale)
				gel_material.set_shader_parameter("flow_offset", Vector3(0.0, 0.72, 0.0) - Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * flow_scale)
				gel_material.set_shader_parameter("flow_phase", core_index * 1.7)
			item.material_override = gel_material
			core_index += 1
		elif "clearbase" in name_lower:
			item.material_override = base_material
		elif "bubble" in name_lower:
			item.material_override = bubble_material
			bubbles.append(item)
			bubble_heights.append(item.position.y)

func _add_area_light(position_3d: Vector3, dimensions: Vector2, energy: float) -> void:
	var light := AreaLight3D.new()
	light.position = position_3d
	light.area_size = dimensions
	light.light_energy = energy
	viewport.add_child(light)
	light.look_at(Vector3(0.0, 1.4, 0.0))


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		rotating = false
		product.rotate_y(event.relative.x * 0.008)
		product.rotate_x(event.relative.y * 0.004)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		rotating = not rotating
