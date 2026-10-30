extends CanvasLayer
## Shared in-world authoring UI, with persistent tools and transactional gestures.
const TREE := preload("res://scripts/tree_planting/editable_tree.gd")
const GESTURE=preload("res://scripts/tree_planting/editor_interaction.gd")
const GIZMO=preload("res://scripts/tree_planting/editor_gizmo.gd")
const STORE=preload("res://scripts/tree_planting/layout_store.gd")
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
var integrated:=false
var gesture=GESTURE.new()
var gizmo
var numeric_before: Dictionary={}
var numeric_key:=""
var numeric_idle:=0.
var navigation:=""
var navigation_mouse:=Vector2.ZERO
var fly_speed:=24.
var fly_velocity:=Vector3.ZERO
var placement_scale:=1.
var placement_yaw:=0.
var foot_preview: MeshInstance3D
var hint: Label

func _ready() -> void:
	gesture.ui=self
	if not integrated:DisplayServer.window_set_title("Prism Route · 种植测试")
	build_ui()
	build_marker()
	gizmo=GIZMO.new();gizmo.ui=self;add_child(gizmo)
	scene.status_changed.connect(show_status)
	if not integrated:
		get_tree().auto_accept_quit=false
		get_tree().root.close_requested.connect(request_close)
	refresh_ui()
	show_status("拖动树木调整位置；Q/W/E/R 切换工具，F 定位。")

func label_into(parent: Node,text: String) -> Label:
	var item:=Label.new();item.text=text;item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item);return item

func button_into(parent: Node,text: String,callback: Callable) -> Button:
	var item:=Button.new();item.text=text;item.focus_mode=Control.FOCUS_NONE;item.pressed.connect(callback);parent.add_child(item);return item

func build_ui() -> void:
	var margin:=MarginContainer.new();margin.offset_left=16;margin.offset_top=16
	margin.anchor_bottom=1.0;margin.offset_bottom=-16;margin.offset_right=354;add_child(margin)
	panel=PanelContainer.new();margin.add_child(panel)
	var style:=StyleBoxFlat.new();style.bg_color=Color(0.035,0.065,0.08,0.9)
	style.set_corner_radius_all(10);style.set_content_margin_all(14);panel.add_theme_stylebox_override("panel",style)
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;panel.add_child(scroll)
	var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",8);scroll.add_child(column)
	var title:=label_into(column,"植物编辑 · 正式大世界" if integrated else "树木种植 · 游戏内测试");title.add_theme_font_size_override("font_size",23)
	if integrated:
		button_into(column,"游玩模式 · F4",scene.leave)
		button_into(column,"在镜头指向处游玩",scene.play_here)
	count_label=label_into(column,"")
	region=OptionButton.new();column.add_child(region)
	region.add_item("进入编辑时的位置" if integrated else "南部屋顶 · 起始区域");regions.append(scene.profile.initial_center)
	for row: Dictionary in scene.metadata.get("spawns",[]):
		region.add_item(row.name);regions.append(Vector3(row.position[0],row.position[1],row.position[2]))
	if integrated:
		region.add_item("湖畔 · 白桦缓坡");regions.append(Vector3(-1200.4,13.3,19.7))
	region.item_selected.connect(func(index: int):change_region(regions[index]))
	button_into(column,"载入镜头中心附近",load_from_view)
	var modes:=GridContainer.new();modes.columns=3;column.add_child(modes)
	for pair: Array in [["select","选择 Q"],["move","移动 W"],["rotate","旋转 E"],["scale","缩放 R"],["place","新增 I"]]:
		var item:=button_into(modes,pair[1],set_mode.bind(pair[0]));item.toggle_mode=true
		item.size_flags_horizontal=Control.SIZE_EXPAND_FILL;mode_buttons[pair[0]]=item
	selection_label=label_into(column,"未选择树木")
	species=OptionButton.new();column.add_child(species)
	for resource: Resource in scene.profile.species:species.add_item(resource.display_name)
	palette=OptionButton.new();column.add_child(palette)
	for resource: Resource in scene.profile.palettes:
		if integrated and resource.id=="legacy":continue
		palette.add_item(resource.display_name)
	species.item_selected.connect(asset_selected);palette.item_selected.connect(asset_selected)
	var grid:=GridContainer.new();grid.columns=2;column.add_child(grid)
	for key: String in ["X","高度 Y","Z","旋转 °","大小"]:
		var caption:=label_into(grid,key);caption.autowrap_mode=TextServer.AUTOWRAP_OFF
		caption.custom_minimum_size.x=68
		var spin:=SpinBox.new();spin.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		spin.custom_minimum_size.x=150
		spin.min_value=0.05 if key=="大小" else -100000
		spin.max_value=10 if key=="大小" else 100000;spin.step=0.05 if key=="大小" else 0.1
		spin.value_changed.connect(change_value.bind(key));grid.add_child(spin);values[key]=spin
		spin.get_line_edit().text_submitted.connect(func(_text):finish_numeric())
		spin.get_line_edit().focus_exited.connect(finish_numeric)
	var row:=HBoxContainer.new();column.add_child(row)
	button_into(row,"复制",duplicate_tree).tooltip_text="Ctrl+D；Alt+拖动复制并移动"
	button_into(row,"删除",delete_tree).tooltip_text="Delete；不会改变当前工具"
	button_into(row,"贴地",snap_tree);button_into(row,"定位",focus_selected)
	row=HBoxContainer.new();column.add_child(row)
	undo_button=button_into(row,"撤销",undo);redo_button=button_into(row,"重做",redo)
	button_into(column,"保存并应用 · Ctrl+S" if integrated else "保存测试布局",save_layout)
	if integrated:button_into(column,"恢复选中树的原始状态",scene.restore_selected)
	status=label_into(column,"");status.add_theme_color_override("font_color",Color("b8e8b6"))
	hint=label_into(column,"右键 + WASD/QE：飞行\n右键 + 滚轮：调速；Shift 加速\n中键平移；Alt+中键绕所选树旋转\n拖动树或坐标轴；Shift 精调 / Ctrl 吸附\nAlt+拖动复制；F 定位；Delete 删除\nCtrl+Z 撤销 / Ctrl+Shift+Z 重做\nEsc / 右键：取消正在进行的变换\n"+("F4 切换游玩；Ctrl+S 保存并应用" if integrated else "独立测试，不改 F5 主地图。"))
	close_dialog=ConfirmationDialog.new();close_dialog.title="尚未保存植物布局" if integrated else "尚未保存测试布局"
	close_dialog.dialog_text="保存当前种植改动后退出？";close_dialog.ok_button_text="保存并退出"
	close_dialog.cancel_button_text="继续编辑";close_dialog.add_button("不保存退出",false,"discard")
	close_dialog.confirmed.connect(func():
		if scene.save_test()==OK:get_tree().quit())
	close_dialog.custom_action.connect(func(action: StringName):
		if action=="discard":get_tree().quit())
	add_child(close_dialog)
	if integrated:close_dialog.canceled.connect(func():visible=scene.active)
	set_mode("select")

func build_marker() -> void:
	marker=MeshInstance3D.new();var mesh:=TorusMesh.new()
	mesh.inner_radius=.965;mesh.outer_radius=1.;mesh.rings=48;mesh.ring_segments=8
	marker.mesh=mesh
	var material:=StandardMaterial3D.new();material.albedo_color=Color(0.3,1,0.8,0.55)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override=material;marker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(marker);marker.visible=false
	foot_preview=MeshInstance3D.new();foot_preview.mesh=mesh;foot_preview.material_override=material.duplicate()
	foot_preview.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;scene.add_child(foot_preview);foot_preview.visible=false

func show_status(message: String) -> void:
	if status!=null:status.text=message
	if count_label!=null:count_label.text="局部 %d 棵 · 总树位 %d\n%s"%[scene.trees().size(),scene.store.all_records().size(),"有未保存修改" if scene.dirty_session else "已保存 / 未修改"]

func set_mode(value: String) -> void:
	finish_pending()
	if value=="place" and mode!="place" and is_instance_valid(selected):placement_scale=selected.scale.x;placement_yaw=selected.rotation.y
	mode=value
	for key: String in mode_buttons:mode_buttons[key].set_pressed_no_signal(key==value)
	refresh_ui()
	if status!=null:show_status({"select":"点击选择；直接拖动也能移动。双击或 F 定位。","place":"点击连续种植；当前大小与朝向用于下一棵。","move":"拖动树或坐标轴；也可点击地面连续移动。","rotate":"拖动树左右旋转；Ctrl 按 15° 吸附，Shift 精调。","scale":"拖动树调整大小；Ctrl 按 0.1 吸附，Shift 精调。"}[mode])

func refresh_ui() -> void:
	syncing=true
	var valid:=is_instance_valid(selected)
	selection_label.text=(selected.species.display_name+" · 已选中") if valid else "未选择树木"
	for key: String in values:values[key].editable=(key in ["旋转 °","大小"]) if mode=="place" else valid
	if valid and mode!="place":
		species.select(scene.profile.species.find(selected.species));palette.select(scene.profile.palettes.find(selected.palette))
	sync_transform_fields()
	undo_button.disabled=cursor==0;redo_button.disabled=cursor==history.size()
	syncing=false;show_status(scene.last_status)

func owns_tree(tree: Variant) -> bool:
	return is_instance_valid(tree) and tree is Node3D and not tree.is_queued_for_deletion() and tree.get_parent()==scene.editable_parent

func select_tree(tree: Variant) -> void:
	finish_numeric()
	selected=tree if owns_tree(tree) else null;refresh_ui()

func sync_transform_fields() -> void:
	var previous:=syncing;syncing=true
	if is_instance_valid(selected):
		values.X.value=selected.position.x;values["高度 Y"].value=selected.position.y;values.Z.value=selected.position.z
		values["旋转 °"].value=selected.rotation_degrees.y;values["大小"].value=selected.scale.x
	if mode=="place":values["旋转 °"].value=rad_to_deg(placement_yaw);values["大小"].value=placement_scale
	syncing=previous

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
	var existing: Dictionary={};var desired: Dictionary={}
	for tree: Node3D in scene.trees():existing[tree.tree_id]=tree
	for row: Dictionary in state.rows:desired[row.id]=row
	for id: String in existing.keys():
		if desired.has(id):continue
		var tree: Node3D=existing[id];scene.editable_parent.remove_child(tree);tree.queue_free();existing.erase(id)
	if integrated:
		for id: String in scene.active_ids:
			if not state.active_ids.has(id):scene.set_source_visible(id,true)
	scene.store.edits=state.edits.duplicate(true);scene.store.removed=state.removed.duplicate(true)
	scene.active_ids.assign(state.active_ids)
	for row: Dictionary in state.rows:
		var tree: Node3D
		if existing.has(row.id):
			tree=existing[row.id]
			if not STORE.same_tree(tree.to_record(),row):
				if tree.species.id!=row.species:tree.species=scene.profile.find_species(row.species)
				if tree.palette.id!=row.palette:tree.palette=scene.profile.find_palette(row.palette)
				tree.position=Vector3(row.position[0],row.position[1],row.position[2]);tree.rotation.y=float(row.yaw);tree.scale=Vector3.ONE*float(row.scale);tree.surface_id=row.get("surface","")
		else:
			if integrated:tree=scene.create_tree(row)
			else:tree=TREE.new();tree.load_record(row,scene.profile)
			scene.editable_parent.add_child(tree)
		if integrated:scene.set_source_visible(row.id,false)
		if row.id==state.selected:selected=tree
	scene.dirty_session=true;refresh_ui()

func undo() -> void:
	finish_pending()
	if cursor==0:return
	cursor-=1;restore(history[cursor].before)

func redo() -> void:
	finish_pending()
	if cursor>=history.size():return
	restore(history[cursor].after);cursor+=1;refresh_ui()

func change_value(value: float,key: String) -> void:
	if syncing:return
	if mode=="place":
		if key=="大小":placement_scale=value
		elif key=="旋转 °":placement_yaw=deg_to_rad(value)
		show_status("新增预设已更新；只影响下一棵，不修改已有树。")
		return
	if not is_instance_valid(selected):return
	if numeric_key!=key:finish_numeric()
	if numeric_before.is_empty():numeric_before=snapshot();numeric_key=key
	numeric_idle=0.
	match key:
		"X":selected.position.x=value
		"高度 Y":selected.position.y=value
		"Z":selected.position.z=value
		"旋转 °":selected.rotation_degrees.y=value
		"大小":selected.scale=Vector3.ONE*value
	scene.dirty_session=true;undo_button.disabled=false;redo_button.disabled=true
	show_status("调整中；整次连续数值修改可一次撤销。")

func finish_numeric() -> void:
	if numeric_before.is_empty():return
	var before:=numeric_before;numeric_before={};numeric_key="";record_change(before)

func finish_pending(commit:=true) -> void:
	# Commit text still being typed before save, a mode switch or another tool.
	for spin: SpinBox in values.values():
		if spin.get_line_edit().has_focus():spin.apply()
	finish_numeric()
	if gesture.dragging:gesture.finish(commit)

func asset_selected(_index: int) -> void:
	if syncing:return
	if mode!="place" and is_instance_valid(selected):apply_assets()
	else:show_status("下一棵将使用当前树种与颜色。")

func apply_assets() -> void:
	var next_species: Resource=scene.profile.species[species.selected]
	var next_palette: Resource=scene.profile.palettes[palette.selected]
	finish_pending()
	if not is_instance_valid(selected):show_status("先选中树木；新增时直接使用这两个选项。");return
	var before:=snapshot();selected.species=next_species;selected.palette=next_palette
	record_change(before)

func duplicate_tree() -> void:
	finish_pending()
	if not is_instance_valid(selected):show_status("请先选中树木。");return
	var before:=snapshot()
	var offset: Vector3=scene.camera.global_basis.x*maxf(1.,selected.scale.x*1.5);offset.y=0
	var tree: Node3D=scene.make_tree(selected.position+offset,selected.species,selected.palette,selected.surface_id)
	tree.rotation=selected.rotation;tree.scale=selected.scale
	scene.editable_parent.add_child(tree);scene.active_ids.append(tree.tree_id);selected=tree
	record_change(before)

func delete_tree() -> void:
	finish_pending()
	if not owns_tree(selected):selected=null;refresh_ui();return
	var before:=snapshot();scene.editable_parent.remove_child(selected);selected.queue_free();selected=null
	record_change(before)

func snap_tree() -> void:
	finish_pending()
	if not is_instance_valid(selected):return
	var hit: Dictionary=scene.snap_position(selected)
	if hit.is_empty():show_status("附近高度没有合适地面，不会跳到其他楼层。");return
	move_to_hit(hit)

func move_to_hit(hit: Dictionary) -> void:
	finish_pending()
	if not is_instance_valid(selected):show_status("先选择需要移动的树。");return
	var before:=snapshot();selected.position=scene.editable_parent.to_local(hit.position)
	selected.surface_id=hit.collider.get_meta("source_id","");record_change(before)

func place_at_hit(hit: Dictionary) -> void:
	finish_pending()
	var before:=snapshot()
	var tree: Node3D=scene.make_tree(scene.editable_parent.to_local(hit.position),scene.profile.species[species.selected],scene.profile.palettes[palette.selected],hit.collider.get_meta("source_id",""))
	tree.scale=Vector3.ONE*placement_scale;tree.rotation.y=placement_yaw
	scene.editable_parent.add_child(tree);scene.active_ids.append(tree.tree_id);selected=tree
	record_change(before)
	# Stay in place mode for repeated planting; switching colour does not change old trees.
	set_mode("place")

func load_region() -> void:change_region(regions[maxi(region.selected,0)])

func change_region(center: Vector3,reposition:=true) -> void:
	finish_pending();stop_navigation()
	if not scene.capture_active():return
	selected=null;history.clear();cursor=0;scene.load_nearby(center)
	refresh_ui()
	if reposition:focus_point(center)

func load_from_view() -> void:
	var camera: Camera3D=scene.camera
	var hit: Dictionary=scene.ray(camera.global_position,camera.global_position-camera.global_basis.z*10000)
	if hit.is_empty():show_status("镜头中心没有命中地形，请先对准目标平台。");return
	change_region(hit.position,false)

func focus_point(point: Vector3) -> void:
	scene.camera.global_position=point+Vector3(50,28,55)
	scene.camera.look_at(point+Vector3.UP*5)

func focus_selected() -> void:
	finish_pending()
	if not is_instance_valid(selected):focus_point(scene.edit_center);return
	var height:=maxf(selected.canopy_bounds.size.y*selected.scale.y,6)
	var target: Vector3=selected.global_transform*selected.canopy_bounds.get_center()
	var width: float=maxf(selected.canopy_bounds.size.x,selected.canopy_bounds.size.z)*selected.scale.x
	var distance: float=maxf(height,width)/(2.*tan(deg_to_rad(scene.camera.fov)*.5))*1.3
	scene.camera.global_position=target+scene.camera.global_basis.z*maxf(8,distance)
	scene.camera.look_at(target)

func save_layout() -> void:
	finish_pending()
	scene.save_test();refresh_ui()

func request_close() -> void:
	finish_pending();stop_navigation()
	if scene.dirty_session:
		if integrated:visible=true
		close_dialog.popup_centered()
	else:get_tree().quit()

func terrain_hit(screen: Vector2) -> Dictionary:
	var camera: Camera3D=scene.camera
	var origin:=camera.project_ray_origin(screen)
	return scene.ray(origin,origin+camera.project_ray_normal(screen)*10000)

func pick_tree(screen: Vector2) -> Node3D:
	var camera: Camera3D=scene.camera
	var origin:=camera.project_ray_origin(screen);var direction:=camera.project_ray_normal(screen)
	var query:=PhysicsRayQueryParameters3D.create(origin,origin+direction*10000,2)
	if integrated:query.exclude=[scene.world.character.get_rid(),scene.world.camper.get_rid()]
	var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():return null
	var ground: Dictionary=scene.ray(origin,hit.position)
	if not ground.is_empty() and origin.distance_to(ground.position)+0.05<origin.distance_to(hit.position):return null
	var tree: Variant=hit.collider.get_meta("editable_tree",null)
	return tree if owns_tree(tree) else null

func mouse_on_panel() -> bool:
	return panel.get_global_rect().has_point(get_viewport().get_mouse_position()) or close_dialog.visible

func _process(delta: float) -> void:
	if not numeric_before.is_empty():
		numeric_idle+=delta
		if numeric_idle>.55:finish_numeric()
	if looking and not close_dialog.visible:
		var direction: Vector3=scene.camera.basis.x*(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)))
		direction+=scene.camera.basis.z*(float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		direction+=Vector3.UP*(float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q)))
		var speed: float=fly_speed*(3. if Input.is_physical_key_pressed(KEY_SHIFT) else (.2 if Input.is_physical_key_pressed(KEY_CTRL) else 1.))
		fly_velocity=fly_velocity.lerp(direction.normalized()*speed,1.-exp(-delta*18.))
		scene.camera.position+=fly_velocity*delta
	else:fly_velocity=Vector3.ZERO
	marker.visible=is_instance_valid(selected)
	if marker.visible:
		marker.material_override.albedo_color=Color(1,.3,.2,.8) if gesture.dragging and not gesture.valid_target else Color(.3,1,.8,.8)
		marker.global_position=selected.global_position+Vector3.UP*0.08
		var radius: float=maxf(1.3,maxf(selected.canopy_bounds.size.x,selected.canopy_bounds.size.z)*selected.scale.x*0.52)
		marker.scale=Vector3(radius,1,radius)
	foot_preview.visible=false
	if mode=="place" and navigation.is_empty() and not mouse_on_panel():
		var hit:=terrain_hit(get_viewport().get_mouse_position())
		if not hit.is_empty():
			foot_preview.visible=true;foot_preview.global_position=hit.position+Vector3.UP*.08
			foot_preview.scale=Vector3.ONE*maxf(1.,placement_scale*2.)
			foot_preview.material_override.albedo_color=Color(.25,1,.65,.8) if scene.planting_hit(hit) else Color(1,.3,.2,.8)
	if gizmo!=null:gizmo.queue_redraw()

func typing() -> bool:
	var focus:=get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit

func start_navigation(kind: String) -> void:
	finish_pending();get_viewport().gui_release_focus()
	navigation=kind;looking=kind=="look";navigation_mouse=get_viewport().get_mouse_position()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func stop_navigation(warp:=true) -> void:
	if navigation.is_empty():return
	navigation="";looking=false;fly_velocity=Vector3.ZERO
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if warp:get_viewport().warp_mouse(navigation_mouse)

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		stop_navigation(false)
		if gesture.dragging:gesture.finish(false)

func _input(event: InputEvent) -> void:
	if integrated and not scene.active:return
	if close_dialog.visible:return
	# Releases must work over the sidebar too; GUI consumes unhandled releases.
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT and gesture.dragging:
			gesture.finish();get_viewport().set_input_as_handled();return
		if event.button_index in [MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:stop_navigation();return
	if not event is InputEventKey or not event.pressed or event.echo:return
	var key: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if key==KEY_ESCAPE:
		if gesture.dragging:gesture.finish(false)
		elif not navigation.is_empty():stop_navigation()
		elif typing():
			for spin: SpinBox in values.values():
				if spin.get_line_edit().has_focus():spin.get_line_edit().text=String.num(spin.value,3)
			get_viewport().gui_release_focus()
		elif mode!="select":set_mode("select")
		else:select_tree(null)
		get_viewport().set_input_as_handled();return
	if typing() or not navigation.is_empty():return
	var handled:=true
	if event.ctrl_pressed:
		match key:
			KEY_Z:
				if event.shift_pressed:redo()
				else:undo()
			KEY_Y:redo()
			KEY_D:duplicate_tree()
			KEY_S:save_layout()
			_:handled=false
	else:
		match key:
			KEY_Q:set_mode("select")
			KEY_W:set_mode("move")
			KEY_E:set_mode("rotate")
			KEY_R:set_mode("scale")
			KEY_I:set_mode("place")
			KEY_F:focus_selected()
			KEY_DELETE:delete_tree()
			KEY_X,KEY_Y,KEY_Z:
				if gesture.dragging and gesture.kind=="move":gesture.axis=OS.get_keycode_string(key)
			_:handled=false
	if handled:get_viewport().set_input_as_handled()

func navigate_motion(relative: Vector2) -> void:
	var camera: Camera3D=scene.camera
	if navigation=="look":
		camera.rotation.y-=relative.x*.003;camera.rotation.x=clampf(camera.rotation.x-relative.y*.003,-1.5,1.5)
	elif navigation=="pan":
		var distance: float=camera.global_position.distance_to(selected.global_position) if is_instance_valid(selected) else 30.
		camera.global_position+=(-camera.global_basis.x*relative.x+camera.global_basis.y*relative.y)*maxf(.003,distance*.0012)
	elif navigation=="orbit" and is_instance_valid(selected):
		var target: Vector3=selected.global_transform*selected.canopy_bounds.get_center()
		var offset: Vector3=camera.global_position-target
		var yaw:=atan2(offset.x,offset.z)-relative.x*.006
		var pitch:=clampf(asin(clampf(offset.normalized().y,-1.,1.))+relative.y*.006,-1.45,1.45)
		camera.global_position=target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*offset.length();camera.look_at(target)

func dolly(screen: Vector2,sign: float) -> void:
	var camera: Camera3D=scene.camera
	var distance:=30.
	var hit:=terrain_hit(screen)
	if not hit.is_empty():distance=camera.global_position.distance_to(hit.position)
	elif is_instance_valid(selected):distance=camera.global_position.distance_to(selected.global_position)
	var amount:=clampf(distance*.12,.25,40.)
	camera.global_position+=camera.project_ray_normal(screen)*amount*sign

func _unhandled_input(event: InputEvent) -> void:
	if close_dialog.visible:return
	if event is InputEventMouseButton:
		if not event.pressed or (mouse_on_panel() and navigation.is_empty()):return
		if event.button_index==MOUSE_BUTTON_RIGHT:
			if gesture.dragging:gesture.finish(false)
			else:start_navigation("look")
			get_viewport().set_input_as_handled();return
		if event.button_index==MOUSE_BUTTON_MIDDLE:
			start_navigation("orbit" if event.alt_pressed and is_instance_valid(selected) else "pan");return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var sign:=1. if event.button_index==MOUSE_BUTTON_WHEEL_UP else -1.
			if not navigation.is_empty():fly_speed=clampf(fly_speed*pow(1.25,sign),2.,256.);show_status("飞行速度 %.0f m/s · Shift 加速 / Ctrl 慢速"%fly_speed)
			elif not gesture.dragging:dolly(event.position,sign)
			return
		if event.button_index==MOUSE_BUTTON_LEFT and navigation.is_empty():
			finish_numeric()
			var axis: String=gizmo.pick(event.position)
			if axis=="ROTATE":gesture.begin(selected,event.position,"rotate","Y");return
			if axis=="SCALE":gesture.begin(selected,event.position,"scale");return
			if not axis.is_empty():gesture.begin(selected,event.position,"move",axis,event.alt_pressed);return
			if mode=="place":
				var hit:=terrain_hit(event.position)
				if scene.planting_hit(hit):place_at_hit(hit)
				else:show_status("此处不能种植；绿色圆环表示可放置的位置。")
				return
			var tree:=pick_tree(event.position)
			if tree!=null:
				if event.double_click:select_tree(tree);focus_selected()
				else:gesture.begin(tree,event.position,"move" if mode=="select" else mode,"",event.alt_pressed)
			elif mode=="move" and is_instance_valid(selected):
				var hit:=terrain_hit(event.position)
				if scene.planting_hit(hit):move_to_hit(hit)
			elif mode=="select":select_tree(null)
	if event is InputEventMouseMotion:
		if not navigation.is_empty():navigate_motion(event.relative)
		elif gesture.dragging:gesture.update(event.position,event.shift_pressed,event.ctrl_pressed)
