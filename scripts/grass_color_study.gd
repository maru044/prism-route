extends CanvasLayer
## The grove comparison uses the same accepted palette as the main world.
const PALETTE := preload("res://scripts/meadow_palette.gd")
var fresh := PALETTE.GRASS.duplicate()
var fresh_ground := PALETTE.GROUND.duplicate()
var host: Node3D
var material: ShaderMaterial
var ground: ShaderMaterial
var baseline: Dictionary = {}
var ground_baseline: Dictionary = {}
var panel: PanelContainer
var menu: OptionButton

func initialize(scene: Node3D) -> void:
	host=scene
	material=scene.grass_material
	ground=scene.get_node("CircularGround").mesh.material as ShaderMaterial
	for key: String in fresh:baseline[key]=material.get_shader_parameter(key)
	if ground!=null:
		for key: String in fresh_ground:ground_baseline[key]=ground.get_shader_parameter(key)
	panel=PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left=24;panel.offset_right=325;panel.offset_top=-152;panel.offset_bottom=-20
	var style:=StyleBoxFlat.new();style.bg_color=Color(.05,.10,.12,.78)
	style.set_content_margin_all(10);style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel",style);add_child(panel)
	var box:=VBoxContainer.new();panel.add_child(box)
	var title:=Label.new();title.text="草色对照 · 小场景";box.add_child(title)
	menu=OptionButton.new();menu.add_item("原版 · 草黄 / 灰绿");menu.add_item("清亮 · 浅金 / 嫩绿")
	menu.item_selected.connect(set_fresh);box.add_child(menu)
	var button:=Button.new();button.text="查看草地";button.pressed.connect(focus_meadow);box.add_child(button)
	set_fresh(1)

func set_fresh(index: int) -> void:
	menu.select(index)
	for key: String in fresh:material.set_shader_parameter(key,fresh[key] if index==1 else baseline[key])
	if ground!=null:
		for key: String in fresh_ground:ground.set_shader_parameter(key,fresh_ground[key] if index==1 else ground_baseline[key])

func focus_meadow() -> void:
	var camera: Camera3D=host.get_node("OrbitCamera")
	var target:=Vector3(0,1.6,0)
	camera.global_position=Vector3(0,2.0,9.0)
	camera.look_at(target)
	var forward: Vector3=(target-camera.global_position).normalized()
	camera._look_yaw=atan2(-forward.x,-forward.z)
	camera._look_pitch=asin(clampf(forward.y,-1,1))
