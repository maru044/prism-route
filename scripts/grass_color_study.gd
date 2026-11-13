extends CanvasLayer
## Preview-only grass / large-tree recolors; production palettes stay untouched.
const PALETTE := preload("res://scripts/meadow_palette.gd")
const GRASS_VARIANTS := [
	{"label":"海风青蓝", "dry":Color("73bfb8"), "green":Color("4592a7"), "ground_dry":Color("407b7d"), "ground_green":Color("346574")},
	{"label":"浅青海岸", "dry":Color("afd9cf"), "green":Color("76b6c5"), "ground_dry":Color("578b86"), "ground_green":Color("477784")},
]
const TREE_VARIANTS := [
	{"label":"紫罗兰大树", "deep":Color("694394"), "shadow":Color("8757b3"), "middle":Color("b086df"), "light":Color("d4b1f1")},
	{"label":"浅薰衣草大树", "deep":Color("73638e"), "shadow":Color("9280b0"), "middle":Color("b9a5d5"), "light":Color("e0cfef")},
]
const TREE_PARAMETERS := ["use_species_palette","species_palette_stage","species_deep_color","species_shadow_color","species_mid_color","species_light_color","species_accent_color","species_accent_amount","species_seed"]
var fresh := PALETTE.GRASS.duplicate()
var fresh_ground := PALETTE.GROUND.duplicate()
var host: Node3D
var material: ShaderMaterial
var ground: ShaderMaterial
var baseline: Dictionary = {}
var ground_baseline: Dictionary = {}
var panel: PanelContainer
var menu: OptionButton
var tree_menu: OptionButton
var tree_baselines: Array[Dictionary]=[]

func initialize(scene: Node3D) -> void:
	host=scene
	material=scene.grass_material
	ground=scene.get_node("CircularGround").mesh.material as ShaderMaterial
	for key: String in fresh:baseline[key]=material.get_shader_parameter(key)
	if ground!=null:
		for key: String in fresh_ground:ground_baseline[key]=ground.get_shader_parameter(key)
	panel=PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left=24;panel.offset_right=350;panel.offset_top=-260;panel.offset_bottom=-20
	var style:=StyleBoxFlat.new();style.bg_color=Color(.05,.10,.12,.78)
	style.set_content_margin_all(10);style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel",style);add_child(panel)
	var box:=VBoxContainer.new();panel.add_child(box)
	var title:=Label.new();title.text="植被换色 · 小场景";box.add_child(title)
	menu=OptionButton.new();menu.add_item("原版 · 草黄 / 灰绿");menu.add_item("清亮 · 浅金 / 嫩绿")
	for row: Dictionary in GRASS_VARIANTS:menu.add_item(row.label)
	menu.item_selected.connect(set_fresh);box.add_child(menu)
	for path: String in ["LandscapeGrove/BroadClusteredFlowerTree","LandscapeGrove/UprightAsymmetricAutumnTree"]:
		var tree: Node3D=host.get_node(path)
		for leaf: MeshInstance3D in tree.find_children("*","MeshInstance3D",true,false):
			if not "foliage" in str(leaf.name).to_lower():continue
			var values: Dictionary={}
			for key: String in TREE_PARAMETERS:values[key]=leaf.get_instance_shader_parameter(key)
			tree_baselines.append({"node":leaf,"values":values})
	tree_menu=OptionButton.new();tree_menu.add_item("原版大树 · 樱粉 / 秋橙")
	for row: Dictionary in TREE_VARIANTS:tree_menu.add_item(row.label)
	tree_menu.item_selected.connect(set_tree_palette);box.add_child(tree_menu)
	var button:=Button.new();button.text="查看草地";button.pressed.connect(focus_meadow);box.add_child(button)
	var tree_button:=Button.new();tree_button.text="查看大树";tree_button.pressed.connect(focus_tree);box.add_child(tree_button)
	var overview:=Button.new();overview.text="查看组合";overview.pressed.connect(focus_palette);box.add_child(overview)
	set_fresh(1)
	if scene.coastal_palette_demo:
		DisplayServer.window_set_title("Prism Route · 青蓝海岸草 / 紫罗兰大树")
		show_grove();set_fresh(2);set_tree_palette(1);focus_palette()

func set_fresh(index: int) -> void:
	menu.select(index)
	var grass_values: Dictionary=baseline if index==0 else fresh.duplicate()
	var ground_values: Dictionary=ground_baseline if index==0 else fresh_ground.duplicate()
	if index>=2:
		var variant: Dictionary=GRASS_VARIANTS[index-2]
		grass_values.palette_dry=variant.dry;grass_values.palette_green=variant.green
		ground_values.ground_dry=variant.ground_dry;ground_values.ground_green=variant.ground_green
	for key: String in grass_values:material.set_shader_parameter(key,grass_values[key])
	if ground!=null:
		for key: String in ground_values:ground.set_shader_parameter(key,ground_values[key])

func show_grove() -> void:
	host.trunk_comparison.isolate_toggle.button_pressed=false
	host.trunk_comparison.wood_toggle.button_pressed=false

func set_tree_palette(index: int) -> void:
	tree_menu.select(index);show_grove()
	for row: Dictionary in tree_baselines:
		for key: String in row.values:row.node.set_instance_shader_parameter(key,row.values[key])
		if index==0:continue
		var variant: Dictionary=TREE_VARIANTS[index-1]
		for key: String in ["deep","shadow","light"]:row.node.set_instance_shader_parameter("species_"+key+"_color",variant[key])
		row.node.set_instance_shader_parameter("species_mid_color",variant.middle)
		row.node.set_instance_shader_parameter("species_accent_color",variant.middle)
		row.node.set_instance_shader_parameter("species_accent_amount",0.)

func _focus(eye: Vector3,target: Vector3,fov:=60.) -> void:
	var camera: Camera3D=host.get_node("OrbitCamera")
	camera.fov=fov;camera.global_position=eye;camera.look_at(target)
	var forward:=(target-eye).normalized()
	camera._look_yaw=atan2(-forward.x,-forward.z)
	camera._look_pitch=asin(clampf(forward.y,-1,1))

func focus_palette() -> void:
	show_grove();_focus(Vector3(-1,6.,33.),Vector3(-1,5.5,1.5))

func focus_tree() -> void:
	show_grove();_focus(Vector3(-27,6.,7.5),Vector3(-9,6.5,4.5),50.)

func capture_review() -> void:
	var folder:="res://.vegetation_art_build/palette_coast_violet/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var camera: Camera3D=host.get_node("OrbitCamera");camera.set_process(false)
	for view: String in ["combination","grass","violet_tree"]:
		match view:
			"combination":focus_palette()
			"grass":focus_meadow()
			"violet_tree":focus_tree()
		for frame in range(60):await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var error:=get_viewport().get_texture().get_image().save_png(folder+view+".png")
		if error!=OK:push_error("Could not save palette view: "+view);get_tree().quit(1);return
		print("COAST_VIOLET_CAPTURE ",view)
	get_tree().quit()

func focus_meadow() -> void:
	show_grove();_focus(Vector3(0,2.0,9.0),Vector3(0,1.6,0),60.)
