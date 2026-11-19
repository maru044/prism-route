extends Node3D
const DATA:=preload("res://scripts/construction/building_data.gd")
const KIT:=preload("res://scripts/construction/basic_kit.gd")
const CONTROL:=preload("res://scripts/world/world_control_context.gd")
const HUD := preload("res://scripts/construction/home_hud.gd")
const MASK_SIZE:=256
const SAVE_PATH:="user://construction/home_v1.json"
const WALKABLE_MASK := 32
const APPROACH_MARGIN := 3.0
const ENTRY := Vector3(27, .04, 35)
var world
var kit=KIT.new()
var plots: Dictionary={}
var active:=false
var selected_plot:="coastal"
var selected_definition:="floor"
var selected_story:=0
var placement_rotation:=0
var hud: HUD
var erase_mode := false
var ghost: Node3D
var ghost_material: StandardMaterial3D
var grid: MeshInstance3D
var load_error:=""
var previous_camera:=Transform3D.IDENTITY
var _previous_review_visibility := true
var _previous_roster_visibility := true
var look_drag:=false
var save_path:=SAVE_PATH
var initialized:=false
var _save_timer: Timer
const GAME_SAVES := preload("res://scripts/progress/game_save_store.gd")
var _dirty := false
var _lowland_example_placed := false
var _home_markers: Array[Dictionary] = []

func _ready() -> void:
	name="ConstructionSandbox";kit.initialize()
	add_to_group(CONTROL.GROUP_INPUT_BLOCKERS)
	for spec: Dictionary in kit.catalog.plots:
		var node:=Node3D.new();node.name=spec.id;node.transform=Transform3D(Basis(KIT.v(spec.axis_x),Vector3.UP,KIT.v(spec.axis_z)),KIT.v(spec.origin));add_child(node)
		var data=DATA.new();data.initialize(spec.id,kit.catalog.definitions)
		if spec.id == "coastal":
			data.example()
		if spec.id == "lowland":
			_lowland_example_placed = data.lowland_example()
			if not _lowland_example_placed:
				push_error("Lowland example placement failed")
		var image:=Image.create(MASK_SIZE,MASK_SIZE,false,Image.FORMAT_R8);image.fill(Color.BLACK)
		plots[spec.id]={"spec":spec,"root":node,"data":data,"nodes":{},"image":image,"texture":ImageTexture.create_from_image(image)}
	# Verification never touches a real player's save.
	var session: Node = world.get("save_session") if "save_session" in world else null
	if session != null and session.sections.has("construction"):
		restore_snapshot(session.read_section("construction"), false)
	elif not world.automation_enabled and FileAccess.file_exists(save_path):
		if session == null or GAME_SAVES.latest().is_empty():
			load_file(save_path, false)
	for id: String in plots:refresh(id)
	_setup_editor()
	initialized=true
	for id: String in plots:
		var p: Node3D=plots[id].root
		world.metadata.spawns.append({"name":"建造地块 · "+str(plots[id].spec.name),"key":"home_"+id,"position":_array(p.to_global(ENTRY)),"look_direction":_array(p.basis*Vector3.FORWARD),"required_floor_kind":"Terrain","maximum_search_distance_m":4.,"character_only":true})
	print("CONSTRUCTION_KIT_READY definitions=",kit.catalog.definitions.size()," coastal_pieces=",plots.coastal.data.pieces.size())

func _array(p: Vector3) -> Array:return [p.x,p.y,p.z]

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
		if plot.nodes.has(row.id) and plot.nodes[row.id].get_meta("definition") != row.definition:
			plot.nodes[row.id].free()
			plot.nodes.erase(row.id)
		if not plot.nodes.has(row.id):
			var node:=kit.make(row.definition);node.name=row.id;plot.root.add_child(node);plot.nodes[row.id]=node
			for body: StaticBody3D in node.find_children("*","StaticBody3D",true,false):body.set_meta("construction_id",row.id);body.set_meta("plot_id",id)
		var node: Node3D=plot.nodes[row.id];node.position=DATA.local_position(row);node.rotation.y=DATA.yaw(row,kind)
		if row.definition=="door":kit.set_door(node,row.get("open",false),1. if int(row.rotation)>=2 else -1.)
	_rebuild_mask(id)
	if active and selected_plot == id:
		_update_floor_visibility()
		_update_editor_state()

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

func save_snapshot() -> Dictionary:
	var states: Dictionary={}
	for id: String in plots:states[id]=plots[id].data.snapshot()
	return {"version":1,"catalog_sha":FileAccess.get_sha256("res://assets/construction/basic_kit/catalog.json"),"plots":states,"lowland_example_placed":_lowland_example_placed}

func save_file(path: String) -> Error:
	if not load_error.is_empty():return ERR_INVALID_DATA
	var error:=DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if error!=OK:return error
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:return FileAccess.get_open_error()
	file.store_string(JSON.stringify(save_snapshot()))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return write_error
	# rename replaces only this save, never planting data or the Rhino source.
	return DirAccess.rename_absolute(path+".tmp",path)

func load_file(path: String,update_scene:=true) -> bool:
	return restore_snapshot(JSON.parse_string(FileAccess.get_file_as_string(path)), update_scene)

func restore_snapshot(parsed: Variant, update_scene:=true) -> bool:
	if not parsed is Dictionary or parsed.get("version",0)!=1 or parsed.get("catalog_sha","")!=FileAccess.get_sha256("res://assets/construction/basic_kit/catalog.json"):
		load_error="建造存档版本或组件规格不匹配，原文件保留";return false
	if not parsed.get("plots") is Dictionary:
		load_error="建造存档结构损坏，原文件保留";return false
	var pending: Dictionary={}
	for id: String in plots:
		var state: Variant=parsed.get("plots",{}).get(id)
		if not state is Dictionary or not state.get("pieces") is Dictionary or not state.get("rooms") is Array or not _number(state.get("serial")) or not _number(state.get("room_serial")):
			load_error="建造存档结构损坏，原文件保留";return false
		if not state.rooms.all(func(room: Variant): return room is Dictionary and room.get("id") is String and room.get("cells") is Array):
			load_error="建造存档房间损坏，原文件保留";return false
		for key: String in state.pieces:
			var row: Variant=state.pieces[key]
			if not row is Dictionary or row.get("id","")!=key or not kit.catalog.definitions.has(row.get("definition","")):
				load_error="建造存档组件损坏";return false
			for field in ["x","z","story","rotation"]:
				if not _number(row.get(field)):load_error="建造存档坐标损坏";return false
			if row.x<0 or row.x>60 or row.z<0 or row.z>60 or row.story<0 or row.story>1:
				load_error="建造存档超出范围";return false
		pending[id]=state
	for id: String in pending:
		plots[id].data.restore(pending[id]);plots[id].data.undo_stack.clear();plots[id].data.redo_stack.clear()
		if update_scene:refresh(id)
	_lowland_example_placed = parsed.get("lowland_example_placed", false) == true or not plots.lowland.data.pieces.is_empty()
	load_error = ""
	if active:
		_update_editor_state()
	return true

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(value)

func is_world_input_locked() -> bool:
	return active

func eligible_plot() -> String:
	if not initialized or not world.test_ready or not world.character_mode or world.free_mode \
			or world.switching_actor or world.encounter_ui_active or not world.is_world_input_allowed():
		return ""
	var actor = world.character
	if not actor.is_on_floor():
		return ""
	for id: String in plots:
		var plot: Dictionary = plots[id]
		var local: Vector3 = plot.root.to_local(actor.global_position)
		var plot_size := float(plot.spec.size)
		var outside := Vector2(local.x - clampf(local.x, 0, plot_size), local.z - clampf(local.z, 0, plot_size))
		if outside.length() > APPROACH_MARGIN or local.y < -.65 or local.y > DATA.STORY + .85:
			continue
		var hit := _floor_at(actor.global_position, .24, .45)
		if hit.is_empty():
			continue
		var body: CollisionObject3D = hit.collider
		var terrain: bool = body.get_meta("surface_kind", "") == "Terrain" and absf(local.y) <= .65
		if terrain or body.get_meta("plot_id", "") == id:
			return id
	return ""

func _floor_at(point: Vector3, above: float, below: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * above, point - Vector3.UP * below, WALKABLE_MASK)
	query.exclude = [world.character.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit if not hit.is_empty() and hit.normal.y > .65 else {}

func toggle() -> void:
	if active:
		_close_editor()
		return
	var site := eligible_plot()
	if site.is_empty():
		return
	selected_plot = site
	var plot: Dictionary = plots[site]
	var actor = world.character
	selected_story = clampi(roundi((plot.root.to_local(actor.global_position).y - .2) / DATA.STORY), 0, 1)
	active = true
	erase_mode = false
	previous_camera = world.camera.global_transform
	_previous_review_visibility = world.review_ui_visible
	if is_instance_valid(actor.switch_wheel):
		_previous_roster_visibility = actor.switch_wheel.visible
		actor.switch_wheel.hide()
	get_viewport().gui_release_focus()
	world.set_review_ui_visible(false)
	world.set_free(true)
	_view_plot()
	hud.set_editing(true, plot.spec.name, selected_story)
	_update_editor_state()
	hud.show_status(load_error if not load_error.is_empty() else "更改将自动保存")
	_place_grid()
	_update_floor_visibility()

func _close_editor() -> void:
	var actor = world.character
	if not _standing_clear(actor.global_position) or _floor_at(actor.global_position, .24, .45).is_empty():
		var plot: Dictionary = plots[selected_plot]
		var safe := false
		for offset: Vector3 in [Vector3.ZERO, Vector3(2,0,0), Vector3(-2,0,0), Vector3(0,0,3),
				Vector3(4,0,0), Vector3(-4,0,0), Vector3(0,0,8), Vector3(0,0,18)]:
			var floor_hit := _floor_at(plot.root.to_global(ENTRY + offset), .9, .75)
			if not floor_hit.is_empty() and _standing_clear(floor_hit.position):
				actor.global_position = floor_hit.position + Vector3.UP * .025
				safe = true
				break
		if not safe:
			hud.show_status("入口被挡住。请拆除入口附近的构件后退出。")
			return
	_save_timer.stop()
	var error := _flush_save()
	active = false
	look_drag = false
	ghost.hide()
	grid.hide()
	_update_floor_visibility()
	hud.set_editing(false)
	get_viewport().gui_release_focus()
	world.set_free(false)
	world.camera.global_transform = previous_camera
	world.set_review_ui_visible(_previous_review_visibility)
	if is_instance_valid(actor.switch_wheel):
		actor.switch_wheel.visible = _previous_roster_visibility
	if error != OK:
		hud.show_notice(_save_error(error))

func _standing_clear(position: Vector3) -> bool:
	var actor = world.character
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = actor.collision_shape.shape
	query.transform = actor.collision_shape.global_transform
	query.transform.origin += position - actor.global_position + Vector3.UP * .045
	query.collision_mask = actor.collision_mask
	query.exclude = [actor.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _view_plot() -> void:
	var plot: Dictionary = plots[selected_plot]
	world.camera.global_position = plot.root.to_global(Vector3(47, 24, 47))
	world.camera.look_at(plot.root.to_global(Vector3(27, 2, 25)))

func _setup_editor() -> void:
	hud = HUD.new()
	hud.home = self
	add_child(hud)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = .65
	_save_timer.timeout.connect(_autosave)
	add_child(_save_timer)

	ghost_material = StandardMaterial3D.new()
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_make_preview()

	var grid_mesh := ImmediateMesh.new()
	var grid_material := StandardMaterial3D.new()
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_material.vertex_color_use_as_albedo = true
	grid_mesh.surface_begin(Mesh.PRIMITIVE_LINES, grid_material)
	for index in range(31):
		var distance := index * DATA.CELL
		grid_mesh.surface_set_color(Color(.62, .84, .93, .72 if index in [0, 30] else .30))
		grid_mesh.surface_add_vertex(Vector3(distance, 0, 0))
		grid_mesh.surface_add_vertex(Vector3(distance, 0, 60))
		grid_mesh.surface_add_vertex(Vector3(0, 0, distance))
		grid_mesh.surface_add_vertex(Vector3(60, 0, distance))
	grid_mesh.surface_end()
	grid = MeshInstance3D.new()
	grid.mesh = grid_mesh
	grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grid)
	grid.hide()

func _make_preview() -> void:
	if is_instance_valid(ghost):
		ghost.queue_free()
		ghost.hide()
	ghost = kit.make(selected_definition)
	for body in ghost.find_children("*", "CollisionObject3D", true, false):
		body.collision_layer = 0
		body.collision_mask = 0
	for mesh: MeshInstance3D in ghost.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = ghost_material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ghost)
	ghost.hide()

func _place_grid() -> void:
	grid.global_transform = plots[selected_plot].root.global_transform * Transform3D(Basis.IDENTITY,
			Vector3(0, .225 + DATA.STORY * selected_story, 0))
	grid.show()

func select_piece(id: String) -> void:
	if selected_definition != id:
		selected_definition = id
		placement_rotation = 0
		_make_preview()
	set_erase(false)
	_update_floor_visibility()

func set_erase(enabled: bool) -> void:
	erase_mode = enabled
	hud.set_selection(selected_definition, erase_mode)
	hud.show_hint("点击构件拆除" if erase_mode else "")

func select_story(story: int) -> void:
	selected_story = story
	_place_grid()
	_update_floor_visibility()

func _update_floor_visibility() -> void:
	var plot: Dictionary = plots[selected_plot]
	for row: Dictionary in plot.data.pieces.values():
		var story := int(row.story)
		var below_roof: bool = row.definition == "roof" and story == selected_story and selected_definition != "roof"
		plot.nodes[row.id].visible = not active or (story <= selected_story and not below_roof)

func rotate_piece() -> void:
	placement_rotation = (placement_rotation + 1) % 4

func change_history(redo: bool) -> void:
	var data = plots[selected_plot].data
	var changed: bool = data.redo() if redo else data.undo()
	if changed:
		_after_edit(selected_plot)

func _can_place_example() -> bool:
	return selected_plot == "lowland" and not _lowland_example_placed \
			and load_error.is_empty() and plots.lowland.data.pieces.is_empty()

func place_lowland_example() -> void:
	if _can_place_example() and plots.lowland.data.lowland_example(true):
		_lowland_example_placed = true
		_after_edit("lowland")
		hud.show_hint("已放置湖畔示例屋")

func _update_editor_state() -> void:
	var data = plots[selected_plot].data
	hud.editing_state(not data.undo_stack.is_empty(), not data.redo_stack.is_empty(), _can_place_example())

func _after_edit(id: String) -> void:
	refresh(id)
	_queue_save()

func _queue_save() -> void:
	if not world.automation_enabled:
		_dirty = true
		hud.show_status("正在等待保存" if load_error.is_empty() else load_error)
		_save_timer.start()

func _flush_save() -> Error:
	if not _dirty:
		return OK
	var error: Error
	if "save_session" in world and world.save_session != null:
		error = world.save_session.save_game(GAME_SAVES.AUTO) if load_error.is_empty() else ERR_INVALID_DATA
	else:
		error = save_file(save_path)
	if error == OK:
		_dirty = false
	return error

func _save_error(error: Error) -> String:
	return load_error if not load_error.is_empty() else "家园保存失败 · " + error_string(error)

func _autosave() -> void:
	var error := _flush_save()
	if active:
		hud.show_status("家园已保存" if error == OK else _save_error(error))
	elif error != OK:
		hud.show_notice(_save_error(error))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and initialized and _dirty and (not "save_session" in world or world.save_session == null):
		_flush_save()

func _pointed_piece(mouse: Vector2) -> Dictionary:
	var camera: Camera3D = world.camera
	var start := camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(start, start + camera.project_ray_normal(mouse) * 175, WALKABLE_MASK)
	var excluded: Array[RID] = [world.character.get_rid()]
	var space := get_world_3d().direct_space_state
	var plot: Dictionary = plots[selected_plot]
	for attempt in range(8):
		query.exclude = excluded
		var hit := space.intersect_ray(query)
		if hit.is_empty() or hit.collider.get_meta("plot_id", "") != selected_plot:
			return {}
		var key: String = hit.collider.get_meta("construction_id", "")
		if plot.nodes[key].visible:
			var row: Dictionary = plot.data.pieces[key]
			return row if int(row.story) == selected_story else {}
		excluded.append(hit.rid)
	return {}

func _remove_target(mouse: Vector2) -> void:
	var target := _pointed_piece(mouse)
	if target.is_empty():
		hud.show_hint("请选择当前楼层的构件")
		return
	var result: Dictionary = plots[selected_plot].data.remove(target.id)
	if result.ok:
		_after_edit(selected_plot)
		hud.show_hint("已拆除")
	else:
		hud.show_hint(result.error)

func _input(event: InputEvent) -> void:
	if not initialized or not world.test_ready:
		return
	if active and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		look_drag = false
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key == KEY_F5 and not event.ctrl_pressed and not event.alt_pressed:
		if active or not eligible_plot().is_empty():
			get_viewport().set_input_as_handled()
			toggle()
		return
	if not active:
		if key == KEY_F and world.character_mode and not world.free_mode and world.is_world_input_allowed():
			_open_nearest_door()
		return
	match key:
		KEY_ESCAPE: toggle()
		KEY_R: rotate_piece()
		KEY_Z:
			if event.ctrl_pressed: change_history(false)
		KEY_Y:
			if event.ctrl_pressed: change_history(true)
		KEY_DELETE:
			if not hud.panel.get_global_rect().has_point(get_viewport().get_mouse_position()):
				_remove_target(get_viewport().get_mouse_position())
		KEY_F:
			if not hud.panel.get_global_rect().has_point(get_viewport().get_mouse_position()):
				var target := _pointed_piece(get_viewport().get_mouse_position())
				if not target.is_empty(): toggle_door(selected_plot, target.id)
		_: return
	get_viewport().set_input_as_handled()

func _open_nearest_door() -> void:
	var nearest := {}
	var distance := 2.7
	for id: String in plots:
		if not plots[id].has("data") or not plots[id].has("nodes"):
			continue
		for row: Dictionary in plots[id].data.pieces.values():
			if row.definition != "door" or not plots[id].nodes.has(row.id):
				continue
			var node: Node3D = plots[id].nodes[row.id] as Node3D
			if not is_instance_valid(node):
				continue
			var center: Vector3 = node.to_global(Vector3(1, 0, 0))
			var meters: float = center.distance_to(world.character.global_position)
			if meters < distance:
				distance = meters
				nearest = {"plot": id, "id": row.id}
	if not nearest.is_empty():
		toggle_door(nearest.plot, nearest.id)
		get_viewport().set_input_as_handled()

func toggle_door(id: String, key: String) -> bool:
	var data = plots[id].data
	if not data.pieces.has(key) or data.pieces[key].definition != "door":
		return false
	var row: Dictionary = data.pieces[key]
	row.open = not row.get("open", false)
	kit.set_door(plots[id].nodes[key], row.open, 1.0 if int(row.rotation) >= 2 else -1.0)
	_queue_save()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			look_drag = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var direction := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			world.camera.position += world.camera.basis.z * 2.0 * direction
			_clamp_camera()
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if hud.panel.get_global_rect().has_point(event.position):
				return
			if erase_mode:
				_remove_target(event.position)
			else:
				var point := _placement_at(event.position)
				if not point.is_empty():
					var result: Dictionary = plots[selected_plot].data.place(selected_definition, selected_story,
							point.x, point.z, placement_rotation)
					if result.ok: _after_edit(selected_plot)
					else: hud.show_hint(result.error)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and look_drag:
		world.camera.rotation.y -= event.relative.x * .003
		world.camera.rotation.x = clampf(world.camera.rotation.x - event.relative.y * .003, -1.4, -.12)
		get_viewport().set_input_as_handled()

func _clamp_camera() -> void:
	var plot: Dictionary = plots[selected_plot]
	var local: Vector3 = plot.root.to_local(world.camera.global_position)
	var edge := float(plot.spec.size) + 12.0
	local = local.clamp(Vector3(-12, 3.5 + selected_story * DATA.STORY, -12), Vector3(edge, 58, edge))
	world.camera.global_position = plot.root.to_global(local)

func _placement_at(mouse: Vector2) -> Dictionary:
	var plot: Dictionary = plots[selected_plot]
	var camera: Camera3D = world.camera
	var height: float = plot.spec.ground_height + .2 + selected_story * DATA.STORY
	var hit: Variant = Plane(Vector3.UP, height).intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if hit == null:
		return {}
	var local: Vector3 = plot.root.to_local(hit)
	var step := .5 if kit.catalog.definitions[selected_definition].kind == "furniture" else DATA.CELL
	return {"x": snappedf(local.x, step), "z": snappedf(local.z, step)}

func _navigation() -> void:
	var visible_now: bool = world.test_ready and world.review_ui_visible and not world.encounter_ui_active \
			and world.is_world_input_allowed()
	if not visible_now:
		if is_instance_valid(hud):
			hud.set_navigation(false, Vector3.ZERO, Vector3.ZERO, _home_markers, "")
		return
	if _home_markers.is_empty():
		for row: Dictionary in world.resolved_spawns:
			var key := str(row.get("key", ""))
			if key.begins_with("home_") and plots.has(key.substr(5)):
				_home_markers.append({"position": row.floor_position, "name": plots[key.substr(5)].spec.name})
	var plot_id := eligible_plot()
	var label := str(plots[plot_id].spec.name) if not plot_id.is_empty() else ""
	if label.is_empty() and not plot_id.is_empty():
		label = "home"
	var camera: Camera3D = world.get_viewport().get_camera_3d()
	if camera and is_instance_valid(hud):
		hud.set_navigation(true, -camera.global_basis.z, world.active_actor().global_position, _home_markers, label)

func _process(delta: float) -> void:
	if not active:
		_navigation()
		return
	if not world.automation_enabled:
		var motion := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		motion += Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
				float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		var movement: Vector3 = world.camera.basis * Vector3(motion.x, 0, motion.y)
		movement.y = 0
		world.camera.position += movement.limit_length() * delta * 12.0
		_clamp_camera()
	ghost.hide()
	var mouse := get_viewport().get_mouse_position()
	if hud.panel.get_global_rect().has_point(mouse):
		return
	if erase_mode:
		hud.show_hint("点击构件拆除" if not _pointed_piece(mouse).is_empty() else "指向当前楼层的构件")
		return
	var point := _placement_at(mouse)
	if point.is_empty():
		return
	var plot: Dictionary = plots[selected_plot]
	var definition: Dictionary = kit.catalog.definitions[selected_definition]
	var row := {"definition": selected_definition, "story": selected_story, "x": point.x,
			"z": point.z, "rotation": placement_rotation}
	var error: String = plot.data.validate(row)
	ghost_material.albedo_color = Color(.35, .82, .91, .43) if error.is_empty() else Color(1, .41, .33, .40)
	hud.show_hint("左键放置 · 右键转动视角" if error.is_empty() else error)
	ghost.global_transform = plot.root.global_transform * Transform3D(
			Basis(Vector3.UP, DATA.yaw(row, definition.kind)), DATA.local_position(row))
	ghost.show()
