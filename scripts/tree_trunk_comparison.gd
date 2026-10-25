extends CanvasLayer
## Wood-only studies in the small grove; keep accepted source trees intact.
const TARGET := "res://assets/vegetation/models/tree_medium_broad_clustered_canopy.glb"
const CANDIDATE := "res://assets/vegetation/models/tree_broad_trunk_thin_comparison_v1.glb"
const SPECIES := [
	{"key":"broad", "label":"大型圆冠树", "model":TARGET,
	 "normal":Vector3(-10.5,3.1,1), "normal_target":3.8,
	 "wood":Vector3(-13,4.5,1), "wood_target":4.5,
	 "whole":Vector3(-22,6.8,4), "whole_target":5.8},
	{"key":"small", "label":"普通小圆冠树（含各色花树）", "model":"res://assets/vegetation/models/tree_small_broad_canopy.glb",
	 "normal":Vector3(-5,1.8,-5), "normal_target":2.0,
	 "wood":Vector3(-6,2.4,-6), "wood_target":2.4,
	 "whole":Vector3(-8,3.2,-8), "whole_target":2.6},
	{"key":"upright", "label":"竖冠大树", "model":"res://assets/vegetation/models/tree_medium_upright_asymmetric_canopy.glb",
	 "normal":Vector3(-10,3.1,4), "normal_target":3.8,
	 "wood":Vector3(-14,4.7,2), "wood_target":4.7,
	 "whole":Vector3(-24,7.5,4), "whole_target":7.5},
	{"key":"birch", "label":"白桦 · 保留树皮纹理", "model":"res://assets/vegetation/models/tree_medium_birch_upright_canopy.glb",
	 "normal":Vector3(6,2.6,6), "normal_target":3.5,
	 "wood":Vector3(10,5.2,10), "wood_target":5.2,
	 "whole":Vector3(11,6,11), "whole_target":6.0},
	{"key":"cypress", "label":"柱形柏树 · 短枝 / 轻弯", "model":"res://assets/vegetation/models/tree_medium_columnar_cypress.glb",
	 "normal":Vector3(6,3.3,6), "normal_target":3.5,
	 "wood":Vector3(10,5.6,10), "wood_target":5.6,
	 "whole":Vector3(11,6,11), "whole_target":6.0},
]
var records: Array[Dictionary] = []
var meshes: Array[Mesh] = []
var variants: Array[int] = [2,2,2,2,2]
var candidate_mesh: Mesh
var connected_mesh: Mesh
var selected_species := 0
var selected_variant := 2
var menu: OptionButton
var species_menu: OptionButton
var panel: PanelContainer
var host: Node3D
var use_candidate := true
var foliage_nodes: Array[MeshInstance3D] = []
var wood_toggle: CheckButton
var isolate_toggle: CheckButton

func _load_mesh(path: String) -> Mesh:
	var source: Node3D = load(path).instantiate()
	var nodes := source.find_children("*","MeshInstance3D",true,false)
	assert(nodes.size()==1, "Expected one wood mesh: "+path)
	var mesh: Mesh = nodes[0].mesh
	source.free()
	return mesh

func initialize(scene: Node3D) -> void:
	host = scene
	candidate_mesh = _load_mesh(CANDIDATE)
	var trees := host.find_children("*","Node3D",true,false)
	for index in SPECIES.size():
		var info: Dictionary = SPECIES[index]
		meshes.append(_load_mesh("res://assets/vegetation/models/tree_%s_trunk_connected_comparison_v2.glb" % info.key))
		for tree: Node3D in trees:
			if tree.scene_file_path!=info.model:continue
			var leaves: Array[Dictionary] = []
			var wood: Array[MeshInstance3D] = []
			for node: MeshInstance3D in tree.find_children("*","MeshInstance3D",true,false):
				if "trunk" in str(node.name).to_lower():wood.append(node)
				else:leaves.append({"node":node,"visible":node.visible})
			for node in wood:
				records.append({"node":node,"original":node.mesh,"material":node.material_override,
					"tree":tree,"species":index,"tree_visible":tree.visible,"leaves":leaves})
	panel = PanelContainer.new();panel.position = Vector2(24,112)
	var style := StyleBoxFlat.new();style.bg_color = Color(.05,.10,.12,.78)
	style.set_content_margin_all(10);style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel",style);add_child(panel)
	var box := VBoxContainer.new();panel.add_child(box)
	var title := Label.new();title.text = "树干检查 · 五种树型";box.add_child(title)
	species_menu = OptionButton.new()
	for info in SPECIES:species_menu.add_item(info.label)
	species_menu.item_selected.connect(select_species);box.add_child(species_menu)
	menu = OptionButton.new();menu.add_item("原版 · 直干");menu.add_item("上一版 · 相交细枝（大型圆冠）")
	menu.add_item("新版 · 连续分叉 / 细树干")
	menu.item_selected.connect(set_variant);box.add_child(menu)
	var buttons := HBoxContainer.new();box.add_child(buttons)
	var button := Button.new();button.text = "定位树干";button.pressed.connect(focus_trunk);buttons.add_child(button)
	var whole := Button.new();whole.text = "查看整树";whole.pressed.connect(focus_whole_tree);buttons.add_child(whole)
	wood_toggle = CheckButton.new();wood_toggle.text = "查看木质结构（临时隐藏树冠）"
	wood_toggle.toggled.connect(set_inspect_wood);box.add_child(wood_toggle)
	isolate_toggle = CheckButton.new();isolate_toggle.text = "隔离当前树（取消可看整片树林）"
	isolate_toggle.button_pressed = true
	isolate_toggle.toggled.connect(func(_enabled: bool):_apply_visibility());box.add_child(isolate_toggle)
	_apply_meshes()
	select_species(1)

func focused_record() -> Dictionary:
	for row: Dictionary in records:
		if row.species==selected_species:return row
	return {}

func select_species(index: int) -> void:
	selected_species = clampi(index,0,SPECIES.size()-1)
	selected_variant = variants[selected_species]
	use_candidate = selected_variant!=0
	connected_mesh = meshes[selected_species]
	species_menu.select(selected_species)
	menu.select(selected_variant)
	menu.set_item_text(2,"新版 · 轻弯单干 / 无分叉" if selected_species==1 else "新版 · 连续分叉 / 细树干")
	menu.set_item_disabled(1,selected_species!=0)
	foliage_nodes.clear()
	var row := focused_record()
	if not row.is_empty():
		for leaf: Dictionary in row.leaves:foliage_nodes.append(leaf.node)
	_apply_visibility()
	focus_trunk()

func _apply_meshes() -> void:
	for row: Dictionary in records:
		match variants[row.species]:
			0:row.node.mesh = row.original
			1:row.node.mesh = candidate_mesh if row.species==0 else row.original
			2:row.node.mesh = meshes[row.species]

func _apply_visibility() -> void:
	var selected := focused_record()
	for row: Dictionary in records:
		var focused: bool = not selected.is_empty() and row.tree==selected.tree
		row.tree.visible = row.tree_visible and (not isolate_toggle.button_pressed or focused)
		for leaf: Dictionary in row.leaves:
			leaf.node.visible = leaf.visible and not (focused and wood_toggle.button_pressed)

func set_inspect_wood(_enabled: bool) -> void:
	_apply_visibility()
	focus_trunk()

func set_candidate(enabled: bool) -> void:
	set_variant(1 if enabled and selected_species==0 else (2 if enabled else 0))

func set_variant(index: int) -> void:
	selected_variant = clampi(index,0,2)
	if selected_variant==1 and selected_species!=0:selected_variant=0
	variants[selected_species] = selected_variant
	use_candidate = selected_variant!=0
	menu.select(selected_variant)
	_apply_meshes()

func focus_trunk() -> void:
	var info: Dictionary = SPECIES[selected_species]
	if wood_toggle.button_pressed:_focus(info.wood,info.wood_target)
	else:_focus(info.normal,info.normal_target)

func focus_whole_tree() -> void:
	var info: Dictionary = SPECIES[selected_species]
	_focus(info.whole,info.whole_target)

func _focus(world_offset: Vector3, target_height: float) -> void:
	var row := focused_record()
	if row.is_empty():return
	var tree: Node3D = row.tree
	var camera: Camera3D = host.get_node("OrbitCamera")
	var target := tree.to_global(Vector3(0,target_height,0))
	camera.global_position = tree.global_position+world_offset*tree.scale.y
	camera.look_at(target)
	var forward: Vector3 = (target-camera.global_position).normalized()
	camera._look_yaw = atan2(-forward.x,-forward.z)
	camera._look_pitch = asin(clampf(forward.y,-1,1))
