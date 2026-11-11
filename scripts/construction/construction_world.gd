extends Node3D
## Small construction validation slice in the actual world, not a parallel map.
const DATA:=preload("res://scripts/construction/building_data.gd")
const KIT:=preload("res://scripts/construction/basic_kit.gd")
const CONTROL:=preload("res://scripts/world/world_control_context.gd")
const MASK_SIZE:=256
const SAVE_PATH:="user://construction/home_v1.json"
var world
var kit=KIT.new()
var plots: Dictionary={}
var active:=false
var selected_plot:="coastal"
var selected_definition:="floor"
var selected_story:=0
var placement_rotation:=0
var layer: CanvasLayer
var panel: PanelContainer
var message: Label
var ghost: MeshInstance3D
var ghost_material: StandardMaterial3D
var hover: Dictionary={}
var load_error:=""
var previous_free:=false
var previous_camera:=Transform3D.IDENTITY
var look_drag:=false
var save_path:=SAVE_PATH
var initialized:=false

func _ready() -> void:
	name="ConstructionSandbox";kit.initialize()
	for spec: Dictionary in kit.catalog.plots:
		var node:=Node3D.new();node.name=spec.id;node.transform=Transform3D(Basis(KIT.v(spec.axis_x),Vector3.UP,KIT.v(spec.axis_z)),KIT.v(spec.origin));add_child(node)
		var data=DATA.new();data.initialize(spec.id,kit.catalog.definitions)
		if spec.id=="coastal":data.example()
		var image:=Image.create(MASK_SIZE,MASK_SIZE,false,Image.FORMAT_R8);image.fill(Color.BLACK)
		plots[spec.id]={"spec":spec,"root":node,"data":data,"nodes":{},"image":image,"texture":ImageTexture.create_from_image(image)}
		_boundary(node)
	# Verification never touches a real player's save.
	if not world.automation_enabled and FileAccess.file_exists(save_path):load_file(save_path,false)
	for id: String in plots:refresh(id)
	_ui();initialized=true
	for id: String in plots:
		var p: Node3D=plots[id].root
		world.metadata.spawns.append({"name":"建造地块 · "+str(plots[id].spec.name),"key":"home_"+id,"position":_array(p.to_global(Vector3(27,.04,35))),"look_direction":_array(p.basis*Vector3(0,0,-1)),"required_floor_kind":"Terrain","maximum_search_distance_m":4.,"character_only":true})
	print("CONSTRUCTION_KIT_READY definitions=",kit.catalog.definitions.size()," coastal_pieces=",plots.coastal.data.pieces.size())

func _array(p: Vector3) -> Array:return [p.x,p.y,p.z]

func _boundary(parent: Node3D) -> void:
	var material:=StandardMaterial3D.new();material.albedo_color=Color("c0d5d5");material.roughness=.8
	for values: Array in [[Vector3(60,.025,.07),Vector3(30,.025,0)],[Vector3(60,.025,.07),Vector3(30,.025,60)],[Vector3(.07,.025,60),Vector3(0,.025,30)],[Vector3(.07,.025,60),Vector3(60,.025,30)]]:
		var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=values[0];mesh.mesh=box;mesh.position=values[1];mesh.material_override=material;parent.add_child(mesh)

func tree_excluded(point: Vector3) -> bool:
	for plot: Dictionary in plots.values():
		var local: Vector3=plot.root.to_local(point)
		if absf(local.y)<1. and local.x>=0 and local.x<=60 and local.z>=0 and local.z<=60:return true
	return false

func refresh(id: String) -> void:
	var plot: Dictionary=plots[id];var data=plot.data;data.analyze()
	for key: String in plot.nodes.keys():
		if not data.pieces.has(key):plot.nodes[key].free();plot.nodes.erase(key)
	for row: Dictionary in data.pieces.values():
		var kind: String=kit.catalog.definitions[row.definition].kind
		if not plot.nodes.has(row.id):
			var node:=kit.make(row.definition);node.name=row.id;plot.root.add_child(node);plot.nodes[row.id]=node
			for body: StaticBody3D in node.find_children("*","StaticBody3D",true,false):body.set_meta("construction_id",row.id);body.set_meta("plot_id",id)
		var node: Node3D=plot.nodes[row.id];node.position=DATA.local_position(row);node.rotation.y=DATA.yaw(row,kind)
		if row.definition=="door":kit.set_door(node,row.get("open",false),1. if int(row.rotation)>=2 else -1.)
	_rebuild_mask(id)
	if message!=null:_say("组件 %d · 空间 %d（室内 %d）"%[data.pieces.size(),data.rooms.size(),data.rooms.filter(func(r:Dictionary):return r.kind=="indoor").size()])

func _rebuild_mask(id: String) -> void:
	var plot: Dictionary=plots[id];var image: Image=plot.image;image.fill(Color.BLACK)
	for row: Dictionary in plot.data.pieces.values():
		if int(row.story)!=0 or not row.definition in ["floor","entry_ramp"]:continue
		var polygon: PackedVector2Array=plot.data.footprint(row)
		var lo:=polygon[0];var hi:=lo
		for p: Vector2 in polygon:lo=lo.min(p);hi=hi.max(p)
		# Confirmed pieces only. Rebuild from occupancy handles overlapping cuts,
		# undo/load and removal without accumulating stale mask pixels.
		for z in range(maxi(0,floori((lo.y-.35)/60.*MASK_SIZE)),mini(MASK_SIZE,ceili((hi.y+.35)/60.*MASK_SIZE))):
			for x in range(maxi(0,floori((lo.x-.35)/60.*MASK_SIZE)),mini(MASK_SIZE,ceili((hi.x+.35)/60.*MASK_SIZE))):image.set_pixel(x,z,Color.WHITE)
	(plot.texture as ImageTexture).update(image)

func grass_cut(point: Vector3) -> bool:
	for plot: Dictionary in plots.values():
		var p: Vector3=plot.root.to_local(point)
		if absf(p.y)>=.65 or p.x<0 or p.z<0 or p.x>=60 or p.z>=60:continue
		if plot.image.get_pixel(floori(p.x/60.*MASK_SIZE),floori(p.z/60.*MASK_SIZE)).r>.5:return true
	return false

func bind_grass(material: ShaderMaterial) -> void:
	material.set_shader_parameter("construction_grass_enabled",true)
	for pair: Array in [["a","lowland"],["b","coastal"]]:
		var plot: Dictionary=plots[pair[1]]
		material.set_shader_parameter("construction_mask_"+pair[0],plot.texture)
		material.set_shader_parameter("construction_inverse_"+pair[0],plot.root.global_transform.affine_inverse())

func save_file(path: String) -> Error:
	if not load_error.is_empty():return ERR_INVALID_DATA
	var states: Dictionary={}
	for id: String in plots:states[id]=plots[id].data.snapshot()
	var body: Dictionary={"version":1,"catalog_sha":FileAccess.get_sha256("res://assets/construction/basic_kit/catalog.json"),"plots":states}
	var error:=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if error!=OK:return error
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return FileAccess.get_open_error()
	file.store_string(JSON.stringify(body));file.close()
	# rename replaces only this save, never planting data or the Rhino source.
	return DirAccess.rename_absolute(path+".tmp",path)

func load_file(path: String,update_scene:=true) -> bool:
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("version",0)!=1 or parsed.get("catalog_sha","")!=FileAccess.get_sha256("res://assets/construction/basic_kit/catalog.json"):
		load_error="建造存档版本或组件规格不匹配，原文件保留";return false
	var pending: Dictionary={}
	for id: String in plots:
		var state: Variant=parsed.get("plots",{}).get(id)
		if not state is Dictionary or not state.get("pieces") is Dictionary or not state.get("rooms") is Array or not state.get("serial") is float or not state.get("room_serial") is float:
			load_error="建造存档结构损坏，原文件保留";return false
		for key: String in state.pieces:
			var row: Variant=state.pieces[key]
			if not row is Dictionary or row.get("id","")!=key or not kit.catalog.definitions.has(row.get("definition","")):
				load_error="建造存档组件损坏";return false
			for field in ["x","z","story","rotation"]:
				if not row.get(field) is float or not is_finite(row[field]):load_error="建造存档坐标损坏";return false
			if row.x<0 or row.x>60 or row.z<0 or row.z>60 or row.story<0 or row.story>1:
				load_error="建造存档超出范围";return false
		pending[id]=state
	for id: String in pending:
		plots[id].data.restore(pending[id]);plots[id].data.undo_stack.clear();plots[id].data.redo_stack.clear()
		if update_scene:refresh(id)
	load_error="";return true

func toggle() -> void:
	if not world.test_ready or CONTROL.is_world_input_blocked(get_tree()) or (world.planting!=null and world.planting.active):return
	active=not active;panel.visible=active;ghost.visible=false
	if active:
		previous_free=world.free_mode;previous_camera=world.camera.global_transform;world.set_free(true);_view_plot()
	else:
		look_drag=false;world.camera.global_transform=previous_camera;world.set_free(previous_free)

func _view_plot() -> void:
	var plot: Dictionary=plots[selected_plot]
	world.camera.global_position=plot.root.to_global(Vector3(46,25,48));world.camera.look_at(plot.root.to_global(Vector3(27,2,25)))

func _say(text: String) -> void:message.text=text

func _ui() -> void:
	layer=CanvasLayer.new();layer.layer=12;add_child(layer)
	panel=PanelContainer.new();panel.position=Vector2(365,18);panel.custom_minimum_size.x=370;layer.add_child(panel);panel.hide()
	var column:=VBoxContainer.new();panel.add_child(column)
	var title:=Label.new();title.text="建筑构件验证 · F7 进入 / 退出";column.add_child(title)
	var plots_menu:=OptionButton.new();plots_menu.add_item("青蓝平台");plots_menu.add_item("北侧低地");column.add_child(plots_menu)
	plots_menu.item_selected.connect(func(i:int):selected_plot="coastal" if i==0 else "lowland";_view_plot())
	var selector:=OptionButton.new();var keys: Array[String]=[]
	for key: String in kit.catalog.definitions:
		if key=="door_leaf":continue
		keys.append(key);selector.add_item(kit.catalog.definitions[key].label)
	selector.select(keys.find("floor"));column.add_child(selector)
	selector.item_selected.connect(func(i:int):selected_definition=keys[i])
	var story:=OptionButton.new();story.add_item("一层");story.add_item("二层");column.add_child(story);story.item_selected.connect(func(i:int):selected_story=i)
	var help:=Label.new();help.text="左键放置 · 右键拖动视角 · 滚轮缩放\nR 旋转 · Delete 拆除指向构件 · E 开关门\nCtrl+Z / Ctrl+Y 撤销 / 重做";column.add_child(help)
	var buttons:=HBoxContainer.new();column.add_child(buttons)
	for action: String in ["保存","读取","走到入口"]:
		var button:=Button.new();button.text=action;buttons.add_child(button)
		button.pressed.connect(_button.bind(action))
	message=Label.new();message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;message.custom_minimum_size.x=360;column.add_child(message)
	ghost=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(2,.08,2);ghost.mesh=box;ghost_material=StandardMaterial3D.new();ghost_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;ghost_material.no_depth_test=true;ghost_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ghost.material_override=ghost_material;ghost.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(ghost);ghost.hide()
	if not load_error.is_empty():_say(load_error)

func _button(action: String) -> void:
	if action=="保存":_say("保存完成" if save_file(save_path)==OK else "保存失败："+load_error)
	elif action=="读取":_say("读取完成" if load_file(save_path) else load_error)
	else:
		var p: Node3D=plots[selected_plot].root
		world.character.set_spawn(p.to_global(Vector3(27,.04,34)),atan2(-(p.basis*Vector3.FORWARD).x,-(p.basis*Vector3.FORWARD).z))
		for index in world.resolved_spawns.size():
			if world.resolved_spawns[index].get("key","")=="home_"+selected_plot:
				world.spawn_index=index;world.spawn_menu.select(index);world.status.text=str(world.resolved_spawns[index].name);break
		previous_free=false;toggle()

func _pointed_piece() -> Dictionary:
	var mouse:=get_viewport().get_mouse_position();var camera: Camera3D=world.camera if active else world.active_camera()
	var from:=camera.project_ray_origin(mouse);var to:=from+camera.project_ray_normal(mouse)*160.
	var query:=PhysicsRayQueryParameters3D.create(from,to,32);query.exclude=[world.character.get_rid()]
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_meta("construction_id"):return {"id":hit.collider.get_meta("construction_id"),"plot":hit.collider.get_meta("plot_id")}
	return {}

func _input(event: InputEvent) -> void:
	if not initialized or not world.test_ready:return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if key==KEY_F7:toggle();get_viewport().set_input_as_handled();return
		if key==KEY_E and not active and not world.free_mode and not CONTROL.is_world_input_blocked(get_tree()):
			var nearest: Dictionary={};var distance:=2.7
			for id: String in plots:
				for row: Dictionary in plots[id].data.pieces.values():
					if row.definition!="door":continue
					var center: Vector3=plots[id].nodes[row.id].to_global(Vector3(1,0,0))
					var d: float=center.distance_to(world.character.global_position)
					if d<distance:distance=d;nearest={"plot":id,"id":row.id}
			if not nearest.is_empty():toggle_door(nearest.plot,nearest.id);get_viewport().set_input_as_handled();return
		if not active:return
		var data=plots[selected_plot].data
		if key==KEY_ESCAPE:toggle()
		elif key==KEY_R:placement_rotation=(placement_rotation+1)%4
		elif key==KEY_Z and event.ctrl_pressed:data.undo();refresh(selected_plot)
		elif key==KEY_Y and event.ctrl_pressed:data.redo();refresh(selected_plot)
		elif key==KEY_DELETE:
			var target:=_pointed_piece()
			if not target.is_empty():var result: Dictionary=plots[target.plot].data.remove(target.id);refresh(target.plot);_say("已拆除" if result.ok else result.error)
		elif key==KEY_E:
			var target:=_pointed_piece()
			if not target.is_empty():toggle_door(target.plot,target.id)
		get_viewport().set_input_as_handled()

func toggle_door(id: String,key: String) -> bool:
	var data=plots[id].data
	if not data.pieces.has(key) or data.pieces[key].definition!="door":return false
	data.pieces[key].open=not data.pieces[key].get("open",false);kit.set_door(plots[id].nodes[key],data.pieces[key].open,1. if int(data.pieces[key].rotation)>=2 else -1.);return true

func _unhandled_input(event: InputEvent) -> void:
	if not active:return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT:look_drag=event.pressed
		elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:world.camera.position-=world.camera.basis.z*2.
		elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:world.camera.position+=world.camera.basis.z*2.
		elif event.pressed and event.button_index==MOUSE_BUTTON_LEFT and not hover.is_empty():
			var result: Dictionary=plots[selected_plot].data.place(selected_definition,selected_story,hover.x,hover.z,placement_rotation)
			if result.ok:refresh(selected_plot)
			else:_say(result.error)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and look_drag:
		world.camera.rotation.y-=event.relative.x*.003;world.camera.rotation.x=clampf(world.camera.rotation.x-event.relative.y*.003,-1.4,-.12);get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not active:return
	if not world.automation_enabled:
		var motion:=Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),0,float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		var movement: Vector3=world.camera.basis*motion;movement.y=0;world.camera.position+=movement*delta*12.
	hover={};ghost.hide()
	if panel.get_global_rect().has_point(get_viewport().get_mouse_position()):return
	var plot: Dictionary=plots[selected_plot];var height: float=plot.spec.ground_height+.2+selected_story*3.6
	var camera: Camera3D=world.camera;var mouse:=get_viewport().get_mouse_position()
	var point: Variant=Plane(Vector3.UP,height).intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
	if point==null:return
	var p: Vector3=plot.root.to_local(point);var kind: String=kit.catalog.definitions[selected_definition].kind;var step:=.5 if kind=="furniture" else 2.
	hover={"x":snappedf(p.x,step),"z":snappedf(p.z,step)}
	var row: Dictionary={"definition":selected_definition,"story":selected_story,"x":hover.x,"z":hover.z,"rotation":placement_rotation}
	var error: String=plot.data.validate(row);ghost_material.albedo_color=Color(.2,.8,.7,.35) if error.is_empty() else Color(1,.2,.2,.35)
	var size:=Vector3(2,.08,2);var center:=Vector3(1,.06,1)
	if kind=="edge":size=Vector3(2,1.15 if selected_definition=="railing" else 3.4,.18);center=Vector3(1,size.y*.5,0)
	elif kind in ["connector","ramp"]:size=Vector3(2,3.6 if kind=="connector" else .2,6 if kind=="connector" else 2);center=size*.5
	elif kind=="furniture":
		var d: Dictionary=kit.catalog.definitions[selected_definition];size=Vector3(d.footprint[0],float(d.surface)+.3,d.footprint[1]);center=Vector3(0,size.y*.5,0)
	var box:=ghost.mesh as BoxMesh
	if not box.size.is_equal_approx(size):box.size=size
	var basis:=Basis(Vector3.UP,DATA.yaw(row,kind))
	ghost.global_transform=plot.root.global_transform*Transform3D(basis,DATA.local_position(row)+basis*center);ghost.show()
