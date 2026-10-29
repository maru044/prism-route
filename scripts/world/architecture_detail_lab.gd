extends Node3D
## Isolated no-UV architecture surface-material preview. Formal F5 map is untouched.
const DETAILS_SHADER=preload("res://shaders/environment/architecture_details_1029.gdshader")
const SEAM_PATH="res://assets/world/architecture_details_1029/seam_wear_mask_v1.png"
const ATLAS_PATH="res://assets/world/architecture_details_1029/foliage_leaf_mask_v2.png"
const FOLIAGE_STYLE=preload("res://scripts/foliage_style.gd")
var camera: Camera3D
var decorated: ShaderMaterial
var baseline: ShaderMaterial
var walls: Array[MeshInstance3D]=[]
var ui: CanvasLayer
var target:=Vector3(0,2.8,0)
var distance:=14.
var yaw:=0.
var pitch:=-.12
var dragging:=false
var ready_for_review:=false
var joints:=true
var plants:=true
var automation_enabled:=false

func _ready() -> void:
	_build_environment()
	var base: ShaderMaterial=load("res://assets/world/cliff_b_test/architecture.tres")
	baseline=_material(base);baseline.set_shader_parameter("joints_enabled",false);baseline.set_shader_parameter("plants_enabled",false)
	decorated=_material(base);decorated.set_shader_parameter("mapping_origin",Vector3(4.8,0,0))
	decorated.set_shader_parameter("plant_color",FOLIAGE_STYLE.GREEN_VALUES.species_mid_color)
	var rects:=PackedVector4Array([Vector4(-.5,-.16,1.,2.55),Vector4(-3.65,1.4,2.8,2.9),Vector4(.8,3.16,3.0,2.85),Vector4(-3.95,-.19,2.9,.85)])
	decorated.set_shader_parameter("plant_rects",rects)
	for x: float in [-4.8,4.8]:
		var primitive:=BoxMesh.new();primitive.size=Vector3(8.6,5.6,.35)
		var wall:=MeshInstance3D.new();wall.mesh=without_uv(primitive);wall.position=Vector3(x,2.8,-.175)
		wall.material_override=baseline if x<0 else decorated;wall.name="BaselineWall" if x<0 else "DetailWall"
		add_child(wall);walls.append(wall)
		var label:=Label3D.new();label.text="原始白墙" if x<0 else "接缝 + 纯色叶片 · 无茎"
		label.position=Vector3(x,6.0,0);label.font_size=60;label.pixel_size=.007;label.outline_size=7
		label.modulate=Color("23343b");label.outline_modulate=Color(.98,.98,.96,1);add_child(label)
	var floor_shape:=BoxMesh.new();floor_shape.size=Vector3(23,.2,13)
	var floor_mesh:=MeshInstance3D.new();floor_mesh.mesh=without_uv(floor_shape);floor_mesh.position=Vector3(0,-.13,3.5);floor_mesh.material_override=base;add_child(floor_mesh)
	camera=Camera3D.new();camera.near=.05;camera.far=120;camera.fov=49.;add_child(camera);camera.make_current()
	_build_ui();set_view(0);ready_for_review=true

func without_uv(primitive: PrimitiveMesh) -> ArrayMesh:
	var arrays:=primitive.get_mesh_arrays();arrays[Mesh.ARRAY_TEX_UV]=null;arrays[Mesh.ARRAY_TEX_UV2]=null;arrays[Mesh.ARRAY_TANGENT]=null
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh

func _material(base: ShaderMaterial) -> ShaderMaterial:
	var material:=ShaderMaterial.new();material.shader=DETAILS_SHADER
	for key: String in ["base_texture","micro_normal","roughness_texture","warm_white","detail_strength","normal_strength","texture_meters"]:
		material.set_shader_parameter(key,base.get_shader_parameter(key))
	material.set_shader_parameter("seam_mask",load(SEAM_PATH));material.set_shader_parameter("foliage_atlas",load(ATLAS_PATH))
	return material

func _build_environment() -> void:
	var settings:=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("9bd1e6")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("e5eff7");settings.ambient_light_energy=.6
	settings.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	var env:=WorldEnvironment.new();env.environment=settings;add_child(env)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-38,-28,0);light.light_energy=1.1;light.shadow_enabled=true;add_child(light)

func _build_ui() -> void:
	ui=CanvasLayer.new();add_child(ui)
	var panel:=PanelContainer.new();panel.position=Vector2(20,20);panel.custom_minimum_size=Vector2(300,0);ui.add_child(panel)
	var margin:=MarginContainer.new()
	for key: String in ["margin_left","margin_top","margin_right","margin_bottom"]:margin.add_theme_constant_override(key,16)
	panel.add_child(margin)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);margin.add_child(column)
	var heading:=Label.new();heading.text="建筑贴图 · 独立预览";heading.add_theme_font_size_override("font_size",23);column.add_child(heading)
	var check:=CheckBox.new();check.text="结构接缝与细裂纹";check.button_pressed=true;check.toggled.connect(set_joints);column.add_child(check)
	check=CheckBox.new();check.text="纯色叶片 · 无茎";check.button_pressed=true;check.toggled.connect(set_plants);column.add_child(check)
	var paint_label:=Label.new();paint_label.text="叶片涂色";column.add_child(paint_label)
	var paint:=ColorPickerButton.new();paint.color=FOLIAGE_STYLE.GREEN_VALUES.species_mid_color;paint.edit_alpha=false
	paint.color_changed.connect(func(color):decorated.set_shader_parameter("plant_color",color));column.add_child(paint)
	var text:=Label.new();text.text="接缝强度";column.add_child(text)
	var strength:=HSlider.new();strength.min_value=.1;strength.max_value=.9;strength.step=.01;strength.value=.48
	strength.value_changed.connect(func(v):decorated.set_shader_parameter("joint_strength",v));column.add_child(strength)
	text=Label.new();text.text="接缝宽度";column.add_child(text)
	var width:=HSlider.new();width.min_value=.004;width.max_value=.025;width.step=.001;width.value=.010
	width.value_changed.connect(func(v):decorated.set_shader_parameter("joint_width",v));column.add_child(width)
	var selector:=OptionButton.new()
	for name: String in ["总览对比","近看接缝与攀援","近看墙顶植物","透明边缘：深浅底色"]:selector.add_item(name)
	selector.item_selected.connect(set_view);column.add_child(selector)
	text=Label.new();text.text="墙体未提供 UV / UV2\n右键拖动 · 滚轮缩放\nH 隐藏界面 · R 恢复总览";text.add_theme_font_size_override("font_size",16);column.add_child(text)

func set_joints(enabled: bool) -> void:
	joints=enabled;decorated.set_shader_parameter("joints_enabled",enabled)
func set_plants(enabled: bool) -> void:
	plants=enabled;decorated.set_shader_parameter("plants_enabled",enabled)
func set_view(which: int) -> void:
	decorated.set_shader_parameter("diagnostic_background",which==3)
	yaw=0.;pitch=-.12
	match which:
		0:target=Vector3(0,2.8,0);distance=14.
		1:target=Vector3(3.35,2.15,.0);distance=5.6
		2:target=Vector3(6.8,4.1,.0);distance=5.1
		3:target=Vector3(4.8,2.8,.0);distance=8.4;pitch=0.
	_update_camera()
func _update_camera() -> void:
	camera.position=target+Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)*Vector3(0,0,distance)
	camera.look_at(target)
func _unhandled_input(event: InputEvent) -> void:
	if automation_enabled:return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT:dragging=event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			distance=clampf(distance+(-.6 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .6),2.,35.);_update_camera()
	elif event is InputEventMouseMotion and dragging:
		yaw-=event.relative.x*.004;pitch=clampf(pitch-event.relative.y*.004,-.8,.55);_update_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_H:ui.visible=not ui.visible
		elif event.physical_keycode==KEY_R:set_view(0)
