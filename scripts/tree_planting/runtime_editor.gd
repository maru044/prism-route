extends CanvasLayer
## Standalone authoring UI: no EditorInterface, editor plugin, or engine changes.
const TREE := preload("res://scripts/tree_planting/editable_tree.gd")
var scene
var selected: Node3D
var mode := "select"
var panel: PanelContainer
var region: OptionButton
var species: OptionButton
var palette: OptionButton
var regions: Array[Vector3]=[]
var status: Label
var selection_label: Label
var count_label: Label
var values: Dictionary={}
var mode_buttons: Dictionary={}
var history: Array[Dictionary]=[]
var cursor := 0
var syncing := false
var looking := false
var marker: MeshInstance3D
var undo_button: Button
var redo_button: Button
var close_dialog: ConfirmationDialog

func _ready() -> void:
	DisplayServer.window_set_title("Prism Route · 种植测试")
	build_ui()
	build_marker()
	scene.status_changed.connect(show_status)
	get_tree().auto_accept_quit=false
	get_tree().root.close_requested.connect(request_close)
	refresh_ui()
	show_status("左键选树；先选“新增”或“移动”，再点击地面。\n只显示当前区域的局部树木。")

func label_into(parent: Node,text: String) -> Label:
	var item:=Label.new();item.text=text;item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item);return item

func button_into(parent: Node,text: String,callback: Callable) -> Button:
	var item:=Button.new();item.text=text;item.pressed.connect(callback);parent.add_child(item);return item

func build_ui() -> void:
	var margin:=MarginContainer.new();margin.offset_left=16;margin.offset_top=16
	margin.anchor_bottom=1.0;margin.offset_bottom=-16;margin.offset_right=354;add_child(margin)
	panel=PanelContainer.new();margin.add_child(panel)
	var style:=StyleBoxFlat.new();style.bg_color=Color(0.035,0.065,0.08,0.9)
	style.set_corner_radius_all(10);style.set_content_margin_all(14);panel.add_theme_stylebox_override("panel",style)
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",8);scroll.add_child(column)
	var title:=label_into(column,"树木种植 · 游戏内测试");title.add_theme_font_size_override("font_size",23)
	count_label=label_into(column,"")
	region=OptionButton.new();column.add_child(region)
	region.add_item("南部屋顶 · 起始区域");regions.append(scene.profile.initial_center)
	for row: Dictionary in scene.metadata.get("spawns",[]):
		region.add_item(row.name);regions.append(Vector3(row.position[0],row.position[1],row.position[2]))
	button_into(column,"载入区域并定位",load_region)
	button_into(column,"载入镜头中心附近",load_from_view)
	var modes:=HBoxContainer.new();column.add_child(modes)
	for pair: Array in [["select","选择"],["place","新增"],["move","移动"]]:
		var item:=button_into(modes,pair[1],set_mode.bind(pair[0]));item.toggle_mode=true
		item.size_flags_horizontal=Control.SIZE_EXPAND_FILL;mode_buttons[pair[0]]=item
	selection_label=label_into(column,"未选择树木")
	species=OptionButton.new();column.add_child(species)
	for resource: Resource in scene.profile.species:species.add_item(resource.display_name)
	palette=OptionButton.new();column.add_child(palette)
	for resource: Resource in scene.profile.palettes:palette.add_item(resource.display_name)
	button_into(column,"应用树种 / 颜色",apply_assets)
	var grid:=GridContainer.new();grid.columns=2;column.add_child(grid)
	for key: String in ["X","高度 Y","Z","旋转 °","大小"]:
		var caption:=label_into(grid,key);caption.autowrap_mode=TextServer.AUTOWRAP_OFF
		caption.custom_minimum_size.x=68
		var spin:=SpinBox.new();spin.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		spin.custom_minimum_size.x=150
		spin.min_value=0.05 if key=="大小" else -100000
		spin.max_value=10 if key=="大小" else 100000;spin.step=0.05 if key=="大小" else 0.1
		spin.value_changed.connect(change_value.bind(key));grid.add_child(spin);values[key]=spin
	var row:=HBoxContainer.new();column.add_child(row)
	button_into(row,"复制",duplicate_tree);button_into(row,"删除",delete_tree)
	button_into(row,"贴地",snap_tree);button_into(row,"定位",focus_selected)
	row=HBoxContainer.new();column.add_child(row)
	undo_button=button_into(row,"撤销",undo);redo_button=button_into(row,"重做",redo)
	button_into(column,"保存测试布局",save_layout)
	status=label_into(column,"");status.add_theme_color_override("font_color",Color("b8e8b6"))
	label_into(column,"右键拖动：转向\n按住右键 + WASD / Q E：飞行\n滚轮：前后移动 · Shift：加速\nCtrl+Z / Ctrl+Y：撤销 / 重做\nEsc：取消新增或移动\n独立测试，不改 F5 主地图。")
	close_dialog=ConfirmationDialog.new();close_dialog.title="尚未保存测试布局"
	close_dialog.dialog_text="保存当前种植改动后退出？";close_dialog.ok_button_text="保存并退出"
	close_dialog.cancel_button_text="继续编辑";close_dialog.add_button("不保存退出",false,"discard")
	close_dialog.confirmed.connect(func():
		if scene.save_test()==OK:get_tree().quit())
	close_dialog.custom_action.connect(func(action: StringName):
		if action=="discard":get_tree().quit())
	add_child(close_dialog)
	set_mode("select")

func build_marker() -> void:
	marker=MeshInstance3D.new();var mesh:=CylinderMesh.new()
	mesh.top_radius=1;mesh.bottom_radius=1;mesh.height=0.08;mesh.radial_segments=48
	marker.mesh=mesh
	var material:=StandardMaterial3D.new();material.albedo_color=Color(0.3,1,0.8,0.55)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override=material;marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(marker);marker.visible=false

func show_status(message: String) -> void:
	if status!=null:status.text=message
	if count_label!=null:count_label.text="局部 %d 棵 · 总树位 %d\n%s"%[scene.trees().size(),scene.store.all_records().size(),"有未保存修改" if scene.dirty_session else "已保存 / 未修改"]

func set_mode(value: String) -> void:
	mode=value
	for key: String in mode_buttons:mode_buttons[key].set_pressed_no_signal(key==value)
	if status!=null:show_status({"select":"左键点击树冠选择树木。","place":"选择树种与颜色，然后点击地面新增。","move":"点击目标地面移动选中树；保持原有大小和朝向。"}[mode])

func refresh_ui() -> void:
	syncing=true
	var valid:=is_instance_valid(selected)
	selection_label.text=selected.tree_id if valid else "未选择树木"
	for key: String in values:values[key].editable=valid
	if valid:
		species.select(scene.profile.species.find(selected.species));palette.select(scene.profile.palettes.find(selected.palette))
		values.X.value=selected.position.x;values["高度 Y"].value=selected.position.y;values.Z.value=selected.position.z
		values["旋转 °"].value=selected.rotation_degrees.y;values["大小"].value=selected.scale.x
	undo_button.disabled=cursor==0;redo_button.disabled=cursor==history.size()
	syncing=false;show_status(scene.last_status)

func select_tree(tree: Node3D) -> void:
	selected=tree;refresh_ui()

func snapshot() -> Dictionary:
	scene.capture_active()
	var rows: Array[Dictionary]=[]
	for tree: Node3D in scene.trees():rows.append(tree.to_record())
	return {"rows":rows,"active_ids":scene.active_ids.duplicate(),"edits":scene.store.edits.duplicate(true),
		"removed":scene.store.removed.duplicate(true),"selected":selected.tree_id if is_instance_valid(selected) else ""}

func record_change(before: Dictionary) -> void:
	var after:=snapshot()
	if before.rows==after.rows:return
	history.resize(cursor);history.append({"before":before,"after":after});cursor=history.size()
	if history.size()>100:history.pop_front();cursor-=1
	scene.dirty_session=true;refresh_ui()

func restore(state: Dictionary) -> void:
	selected=null
	for tree: Node3D in scene.trees():scene.editable_parent.remove_child(tree);tree.queue_free()
	scene.store.edits=state.edits.duplicate(true);scene.store.removed=state.removed.duplicate(true)
	scene.active_ids.assign(state.active_ids)
	for row: Dictionary in state.rows:
		var tree:=TREE.new();tree.load_record(row,scene.profile);scene.editable_parent.add_child(tree)
		if row.id==state.selected:selected=tree
	scene.dirty_session=true;refresh_ui()

func undo() -> void:
	if cursor==0:return
	cursor-=1;restore(history[cursor].before)

func redo() -> void:
	if cursor>=history.size():return
	restore(history[cursor].after);cursor+=1;refresh_ui()

func change_value(value: float,key: String) -> void:
	if syncing or not is_instance_valid(selected):return
	var before:=snapshot()
	match key:
		"X":selected.position.x=value
		"高度 Y":selected.position.y=value
		"Z":selected.position.z=value
		"旋转 °":selected.rotation_degrees.y=value
		"大小":selected.scale=Vector3.ONE*value
	record_change(before)

func apply_assets() -> void:
	if not is_instance_valid(selected):show_status("先选中树木；新增时直接使用这两个选项。");return
	var before:=snapshot();selected.species=scene.profile.species[species.selected];selected.palette=scene.profile.palettes[palette.selected]
	record_change(before)

func duplicate_tree() -> void:
	if not is_instance_valid(selected):show_status("请先选中树木。");return
	var before:=snapshot()
	var tree: Node3D=scene.make_tree(selected.position+Vector3(5,0,0),selected.species,selected.palette,selected.surface_id)
	tree.rotation=selected.rotation;tree.scale=selected.scale
	scene.editable_parent.add_child(tree);scene.active_ids.append(tree.tree_id);selected=tree
	record_change(before);set_mode("move")

func delete_tree() -> void:
	if not is_instance_valid(selected):return
	var before:=snapshot();scene.editable_parent.remove_child(selected);selected.queue_free();selected=null
	record_change(before);set_mode("select")

func snap_tree() -> void:
	if not is_instance_valid(selected):return
	var hit: Dictionary=scene.snap_position(selected)
	if hit.is_empty():show_status("附近高度没有合适地面，不会跳到其他楼层。");return
	move_to_hit(hit)

func move_to_hit(hit: Dictionary) -> void:
	if not is_instance_valid(selected):show_status("先选择需要移动的树。");return
	var before:=snapshot();selected.position=scene.editable_parent.to_local(hit.position)
	selected.surface_id=hit.collider.get_meta("source_id","");record_change(before);set_mode("select")

func place_at_hit(hit: Dictionary) -> void:
	var before:=snapshot()
	var tree: Node3D=scene.make_tree(scene.editable_parent.to_local(hit.position),scene.profile.species[species.selected],scene.profile.palettes[palette.selected],hit.collider.get_meta("source_id",""))
	scene.editable_parent.add_child(tree);scene.active_ids.append(tree.tree_id);selected=tree
	record_change(before)
	# Stay in place mode for repeated planting; switching colour does not change old trees.
	set_mode("place")

func load_region() -> void:change_region(regions[maxi(region.selected,0)])

func change_region(center: Vector3) -> void:
	if not scene.capture_active():return
	selected=null;history.clear();cursor=0;scene.load_nearby(center)
	refresh_ui();set_mode("select");focus_point(center)

func load_from_view() -> void:
	var camera: Camera3D=scene.camera
	var hit: Dictionary=scene.ray(camera.global_position,camera.global_position-camera.global_basis.z*10000)
	if hit.is_empty():show_status("镜头中心没有命中地形，请先对准目标平台。");return
	change_region(hit.position)

func focus_point(point: Vector3) -> void:
	scene.camera.global_position=point+Vector3(50,28,55)
	scene.camera.look_at(point+Vector3.UP*5)

func focus_selected() -> void:
	if not is_instance_valid(selected):focus_point(scene.edit_center);return
	var height:=maxf(selected.canopy_bounds.size.y*selected.scale.y,6)
	var target: Vector3=selected.global_position+Vector3.UP*height*0.4
	scene.camera.global_position=target+Vector3(1,0.45,1).normalized()*maxf(15,height*2)
	scene.camera.look_at(target)

func save_layout() -> void:
	scene.save_test();refresh_ui()

func request_close() -> void:
	if scene.dirty_session:close_dialog.popup_centered()
	else:get_tree().quit()

func terrain_hit(screen: Vector2) -> Dictionary:
	var camera: Camera3D=scene.camera
	var origin:=camera.project_ray_origin(screen)
	return scene.ray(origin,origin+camera.project_ray_normal(screen)*10000)

func pick_tree(screen: Vector2) -> Node3D:
	var camera: Camera3D=scene.camera
	var origin:=camera.project_ray_origin(screen);var direction:=camera.project_ray_normal(screen)
	var query:=PhysicsRayQueryParameters3D.create(origin,origin+direction*10000,2)
	var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():return null
	var ground: Dictionary=scene.ray(origin,hit.position)
	if not ground.is_empty() and origin.distance_to(ground.position)+0.05<origin.distance_to(hit.position):return null
	return hit.collider.get_meta("editable_tree",null)

func mouse_on_panel() -> bool:
	return panel.get_global_rect().has_point(get_viewport().get_mouse_position()) or close_dialog.visible

func _process(delta: float) -> void:
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):looking=false
	if looking and not close_dialog.visible:
		var direction:=Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q)),
			float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		scene.camera.position+=scene.camera.basis*direction.normalized()*delta*(100 if Input.is_physical_key_pressed(KEY_SHIFT) else 24)
	marker.visible=is_instance_valid(selected)
	if marker.visible:
		marker.global_position=selected.global_position+Vector3.UP*0.15
		var radius: float=maxf(1.3,maxf(selected.canopy_bounds.size.x,selected.canopy_bounds.size.z)*selected.scale.x*0.52)
		marker.scale=Vector3(radius,1,radius)

func _unhandled_input(event: InputEvent) -> void:
	if close_dialog.visible:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:set_mode("select");return
		if event.ctrl_pressed and event.keycode==KEY_Z:undo();get_viewport().set_input_as_handled();return
		if event.ctrl_pressed and event.keycode==KEY_Y:redo();get_viewport().set_input_as_handled();return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT:looking=event.pressed and not mouse_on_panel()
		if mouse_on_panel():return
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			scene.camera.position-=scene.camera.basis.z*(5 if event.button_index==MOUSE_BUTTON_WHEEL_UP else -5)
		if event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			if mode=="select":select_tree(pick_tree(event.position));return
			var hit:=terrain_hit(event.position)
			if not scene.planting_hit(hit):show_status("请点击可种植的平坦顶面；道路、水面和陡面不能种树。");return
			if mode=="place":place_at_hit(hit)
			elif mode=="move":move_to_hit(hit)
	if event is InputEventMouseMotion and looking:
		scene.camera.rotation.y-=event.relative.x*0.003
		scene.camera.rotation.x=clampf(scene.camera.rotation.x-event.relative.y*0.003,-1.5,1.5)
