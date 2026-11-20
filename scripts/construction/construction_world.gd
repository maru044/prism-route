extends Node3D
const DATA:=preload("res://scripts/construction/building_data.gd")
const KIT:=preload("res://scripts/construction/basic_kit.gd")
const CONTROL:=preload("res://scripts/world/world_control_context.gd")
const HUD := preload("res://scripts/construction/home_hud.gd")
const RESIDENT_MANAGER := preload("res://scripts/construction/home_resident_manager.gd")
const RESIDENT_ACTOR_SCENE := preload("res://scripts/construction/home_resident_actor.gd")
const ROOM_ASSIGNMENT_PANEL := preload("res://scripts/ui/home_room_assignment_panel.gd")
const HOME_INTERACTION_PANEL := preload("res://scripts/narrative/home_interaction_panel.gd")
const CATALOG := preload("res://scripts/construction/home_intimacy_catalog.gd")
const SHARED_HUMANOID_ACTOR := preload("res://scenes/characters/shared_humanoid_actor.tscn")
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
var resident_manager: HomeResidentManager
var room_assignment_panel: HomeRoomAssignmentPanel
var home_interaction_panel: HomeInteractionPanel
var resident_actors: Dictionary = {}
var is_intimacy_active := false
var current_intimacy_actor: HomeResidentActor = null
var intimacy_staging_root: Node3D = null
var intimacy_npc_actor: Node3D = null
var intimacy_master_actor: Node3D = null
var intimacy_camera: Camera3D = null
var intimacy_focal_point := Vector3.ZERO
var intimacy_cam_dist := 2.4
var intimacy_cam_yaw := 0.0
var intimacy_cam_pitch := 0.25
var intimacy_dragging := false
var _previous_camera_instance: Camera3D = null
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	name="ConstructionSandbox";kit.initialize()
	add_to_group(CONTROL.GROUP_INPUT_BLOCKERS)
	resident_manager = RESIDENT_MANAGER.new()
	room_assignment_panel = ROOM_ASSIGNMENT_PANEL.new()
	room_assignment_panel.home = self
	room_assignment_panel.resident_manager = resident_manager
	room_assignment_panel.game_progress = world.get("game_progress") if (world != null and "game_progress" in world) else null
	room_assignment_panel.closed.connect(func():
		if world != null and world.has_method("_sync_actor_controls"):
			world._sync_actor_controls()
	)
	add_child(room_assignment_panel)
	home_interaction_panel = HOME_INTERACTION_PANEL.new()
	home_interaction_panel.intimacy_requested.connect(_on_home_intimacy_requested)
	home_interaction_panel.intimacy_motion_selected.connect(_on_home_intimacy_motion_selected)
	home_interaction_panel.closed.connect(func():
		if world != null and world.has_method("_sync_actor_controls"):
			world._sync_actor_controls()
	)
	add_child(home_interaction_panel)
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
	refresh_residents()
	for id: String in plots:
		var p: Node3D=plots[id].root
		var entry_pos: Vector3 = p.to_global(ENTRY) if p.is_inside_tree() else (p.transform * ENTRY)
		if world != null and "metadata" in world and world.metadata is Dictionary:
			if not world.metadata.has("spawns") or not (world.metadata.spawns is Array):
				world.metadata["spawns"] = []
			world.metadata.spawns.append({"name":"建造地块 · "+str(plots[id].spec.name),"key":"home_"+id,"position":_array(entry_pos),"look_direction":_array(p.basis*Vector3.FORWARD),"required_floor_kind":"Terrain","maximum_search_distance_m":4.,"character_only":true})
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
	refresh_residents()

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
	var housing_data := resident_manager.to_dict() if resident_manager != null else {"version": 1, "assignments": {}}
	return {"version":1,"catalog_sha":FileAccess.get_sha256("res://assets/construction/basic_kit/catalog.json"),"plots":states,"lowland_example_placed":_lowland_example_placed,"housing":housing_data}

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
			if row.x<0 or row.x>60 or row.z<0 or row.z>60 or row.story<0 or row.story>=DATA.MAX_STORIES:
				load_error="建造存档超出范围";return false
		pending[id]=state
	for id: String in pending:
		plots[id].data.restore(pending[id]);plots[id].data.undo_stack.clear();plots[id].data.redo_stack.clear()
		if update_scene:refresh(id)
	_lowland_example_placed = parsed.get("lowland_example_placed", false) == true or not plots.lowland.data.pieces.is_empty()
	if parsed is Dictionary and parsed.has("housing") and parsed["housing"] is Dictionary and resident_manager != null:
		resident_manager.from_dict(parsed["housing"])
	elif resident_manager != null:
		resident_manager.clear_all()
	if update_scene:
		refresh_residents()
	load_error = ""
	if active:
		_update_editor_state()
	return true

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(value)

func is_world_input_locked() -> bool:
	return active or is_intimacy_active or (is_instance_valid(room_assignment_panel) and room_assignment_panel.visible) or (is_instance_valid(home_interaction_panel) and home_interaction_panel.visible)

func is_service_staging_active() -> bool:
	return is_intimacy_active

func get_active_custom_camera() -> Camera3D:
	if is_intimacy_active and is_instance_valid(intimacy_camera):
		return intimacy_camera
	return null

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
		if outside.length() > APPROACH_MARGIN or local.y < -.65 or local.y > DATA.STORY * DATA.MAX_STORIES + .85:
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
	selected_story = clampi(roundi((plot.root.to_local(actor.global_position).y - .2) / DATA.STORY), 0, DATA.MAX_STORIES - 1)
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
	selected_story = clampi(story, 0, DATA.MAX_STORIES - 1)
	_place_grid()
	_update_floor_visibility()
	if is_instance_valid(hud):
		hud.update_story(selected_story)

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
	if is_intimacy_active:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				intimacy_dragging = event.pressed
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				intimacy_cam_dist = clampf(intimacy_cam_dist - 0.25, 0.8, 5.0)
				_update_intimacy_camera()
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				intimacy_cam_dist = clampf(intimacy_cam_dist + 0.25, 0.8, 5.0)
				_update_intimacy_camera()
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
				intimacy_cam_dist = 2.4
				_update_intimacy_camera()
				get_viewport().set_input_as_handled()
				return
		elif event is InputEventMouseMotion and intimacy_dragging:
			intimacy_cam_yaw -= event.relative.x * 0.008
			intimacy_cam_pitch = clampf(intimacy_cam_pitch + event.relative.y * 0.008, -0.6, 1.2)
			_update_intimacy_camera()
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventKey and event.pressed and not event.echo:
			var intimacy_key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if intimacy_key in [KEY_E, KEY_ESCAPE, KEY_SPACE]:
				finish_intimacy_staging()
				get_viewport().set_input_as_handled()
				return
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
		if world.character_mode and not world.free_mode and world.is_world_input_allowed():
			if key == KEY_F:
				_open_nearest_door()
			elif key == KEY_G:
				_handle_room_management_input()
			elif key == KEY_E:
				_handle_resident_interaction_input()
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
		KEY_PAGEUP:
			select_story(selected_story + 1)
		KEY_PAGEDOWN:
			select_story(selected_story - 1)
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
			hud.set_room_prompt("")
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
		var nearest_actor := _find_nearest_resident(2.5)
		var cur_room := get_current_room()
		if is_instance_valid(nearest_actor):
			hud.set_room_prompt("【E】与 %s 互动 · 【G】管理房间住客" % nearest_actor.get_display_name())
		elif not cur_room.is_empty():
			hud.set_room_prompt("【G】管理本房间住客")
		else:
			hud.set_room_prompt("")

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

func get_current_room() -> Dictionary:
	if not is_instance_valid(world) or not is_instance_valid(world.character):
		return {}
	var char_pos: Vector3 = world.character.global_position
	for id: String in plots:
		var plot: Dictionary = plots[id]
		var local: Vector3 = plot.root.to_local(char_pos)
		var plot_size := float(plot.spec.size)
		if local.x < -0.5 or local.x > plot_size + 0.5 or local.z < -0.5 or local.z > plot_size + 0.5:
			continue
		var story := clampi(roundi((local.y - 0.2) / DATA.STORY), 0, DATA.MAX_STORIES - 1)
		if absf(local.y - (0.2 + story * DATA.STORY)) > 2.8:
			continue
		var cell_x := floori(local.x / 2.0)
		var cell_z := floori(local.z / 2.0)
		var target_key := DATA.cell_key(story, cell_x, cell_z)
		for room: Dictionary in plot.data.rooms:
			if target_key in room.get("cells", []):
				var res := room.duplicate(true)
				res["plot_id"] = id
				return res
	return {}

func _find_nearest_resident(max_dist: float = 2.5) -> HomeResidentActor:
	if not is_instance_valid(world) or not is_instance_valid(world.character):
		return null
	var player_pos: Vector3 = world.character.global_position
	var nearest: HomeResidentActor = null
	var min_d := max_dist
	for r_id: String in resident_actors:
		var actor: HomeResidentActor = resident_actors[r_id] as HomeResidentActor
		if is_instance_valid(actor):
			var d := actor.global_position.distance_to(player_pos)
			if d < min_d:
				min_d = d
				nearest = actor
	return nearest

func open_room_assignment_panel(plot_id: String, room: Dictionary) -> void:
	if is_instance_valid(room_assignment_panel):
		room_assignment_panel.open(plot_id, room)
		if world != null:
			if "character" in world and is_instance_valid(world.character) and world.character.has_method("set_control_enabled"):
				world.character.set_control_enabled(false)
			if world.has_method("_sync_actor_controls"):
				world._sync_actor_controls()

func _handle_room_management_input() -> void:
	var cur_room := get_current_room()
	if cur_room.is_empty():
		hud.show_notice("请先进入已建成的房间内，再按【G】管理住客")
		return
	var plot_id: String = str(cur_room.get("plot_id", ""))
	open_room_assignment_panel(plot_id, cur_room)
	get_viewport().set_input_as_handled()

func _handle_resident_interaction_input() -> void:
	var actor := _find_nearest_resident(2.5)
	if is_instance_valid(actor):
		_on_resident_interacted(actor)
		get_viewport().set_input_as_handled()

func _on_resident_interacted(actor: HomeResidentActor) -> void:
	if is_instance_valid(actor) and is_instance_valid(home_interaction_panel):
		home_interaction_panel.open(actor)
		if world != null:
			if "character" in world and is_instance_valid(world.character) and world.character.has_method("set_control_enabled"):
				world.character.set_control_enabled(false)
			if world.has_method("_sync_actor_controls"):
				world._sync_actor_controls()

func _on_home_intimacy_requested(tier: String, resident_actor: HomeResidentActor) -> void:
	if not is_instance_valid(resident_actor):
		return
	var tier_name := "日常侍奉" if tier == "service" else "深度温存"
	var motion_category := "ground_service"
	var chosen_piece_desc := "地席"

	var has_bed := false
	var has_chair := false
	var has_desk := false
	if plots.has(resident_actor.plot_id):
		var p_data = plots[resident_actor.plot_id].data
		for f_id in resident_actor.room_data.get("furniture", []):
			if p_data.pieces.has(f_id):
				var def: String = str(p_data.pieces[f_id].definition)
				if def == "bed":
					has_bed = true
				elif def in ["chair", "bench"]:
					has_chair = true
				elif def == "desk":
					has_desk = true

	if tier == "service":
		if has_bed:
			motion_category = "bed_service"
			chosen_piece_desc = "床榻"
		elif has_chair:
			motion_category = "seat_service"
			chosen_piece_desc = "座椅"
		elif has_desk:
			motion_category = "desk_service"
			chosen_piece_desc = "长案"
		else:
			motion_category = "ground_service"
			chosen_piece_desc = "地席"
	else:
		if has_bed:
			motion_category = "honban"
			chosen_piece_desc = "床榻本番"
		elif has_chair:
			motion_category = "seat_service"
			chosen_piece_desc = "座椅深度温存"
		elif has_desk:
			motion_category = "desk_service"
			chosen_piece_desc = "长案深度温存"
		else:
			motion_category = "ground_service"
			chosen_piece_desc = "地席深度温存"

	if is_instance_valid(hud):
		hud.show_notice("【家园亲密互动 · %s】与 %s 在 %s 进行互动（动作套组：%s）" % [tier_name, resident_actor.get_display_name(), chosen_piece_desc, motion_category])

func _on_home_intimacy_motion_selected(motion: Dictionary, resident_actor: HomeResidentActor) -> void:
	if not is_instance_valid(resident_actor):
		return
	_start_intimacy_staging(motion, resident_actor)

func _start_intimacy_staging(motion: Dictionary, resident_actor: HomeResidentActor) -> void:
	if is_intimacy_active:
		finish_intimacy_staging()

	_previous_camera_instance = get_viewport().get_camera_3d()
	_previous_mouse_mode = Input.mouse_mode

	var npc_id := resident_actor.character_id
	var npc_model := "res://assets/characters/roster/" + npc_id + "/" + npc_id + ".vrm"
	var avatar_file := "res://assets/npc/avatars/" + npc_id + ".json"
	if FileAccess.file_exists(avatar_file):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(avatar_file))
		if raw is Dictionary and raw.has("model_resource"):
			npc_model = str(raw["model_resource"])

	var master_model := "res://assets/characters/roster/lumine/lumine.vrm"
	if world != null and "character" in world and is_instance_valid(world.character):
		var active_id: String = str(world.character.get("active_character_id"))
		if not active_id.is_empty() and active_id != "lumine":
			var custom_model := "res://assets/characters/roster/" + active_id + "/" + active_id + ".vrm"
			if ResourceLoader.exists(custom_model):
				master_model = custom_model

	var role_a_motion_path := str(motion.get("role_a_motion", ""))
	var role_b_motion_path := str(motion.get("role_b_motion", ""))

	# Strict resource pre-check
	if not ResourceLoader.exists(npc_model):
		if ResourceLoader.exists("res://assets/characters/roster/ganyu/ganyu.vrm"):
			npc_model = "res://assets/characters/roster/ganyu/ganyu.vrm"
		elif ResourceLoader.exists("res://assets/characters/roster/lumine/lumine.vrm"):
			npc_model = "res://assets/characters/roster/lumine/lumine.vrm"
		else:
			hud.show_notice("无法启动互动：缺少角色模型资源 %s" % npc_model)
			return

	if not ResourceLoader.exists(master_model):
		hud.show_notice("无法启动互动：缺少主角模型资源 %s" % master_model)
		return
	if not ResourceLoader.exists(role_a_motion_path):
		hud.show_notice("无法启动互动：缺少动作资源 %s" % role_a_motion_path)
		return
	if not ResourceLoader.exists(role_b_motion_path):
		hud.show_notice("无法启动互动：缺少动作资源 %s" % role_b_motion_path)
		return

	# Target furniture and anchor resolution
	var target_transform := resident_actor.global_transform
	var req_furn := str(motion.get("furniture", "ground"))
	var anchor_name := str(motion.get("anchor", ""))

	if req_furn != "ground":
		var found_anchor := false
		if plots.has(resident_actor.plot_id):
			var p_data = plots[resident_actor.plot_id].data
			var p_nodes: Dictionary = plots[resident_actor.plot_id].nodes
			var f_ids: Array = resident_actor.room_data.get("furniture", [])
			for f_id in f_ids:
				if p_data.pieces.has(f_id):
					var def: String = str(p_data.pieces[f_id].definition)
					var match_found := false
					if req_furn == "bed" and def == "bed":
						match_found = true
					elif req_furn == "chair" and def in ["chair", "bench"]:
						match_found = true
					elif req_furn == "desk" and def == "desk":
						match_found = true

					if match_found and p_nodes.has(f_id) and is_instance_valid(p_nodes[f_id]):
						var furn_node: Node3D = p_nodes[f_id] as Node3D
						var anchor_node: Node3D = furn_node.find_child(anchor_name, true, false) as Node3D if not anchor_name.is_empty() else null
						if is_instance_valid(anchor_node):
							target_transform = anchor_node.global_transform
							found_anchor = true
						else:
							target_transform = furn_node.global_transform
							found_anchor = true
						break
		if not found_anchor:
			hud.show_notice("无法启动互动：房间内未找到所需家具或定位点 (%s)" % req_furn)
			return
	else:
		var w3d := get_world_3d()
		if w3d != null and w3d.direct_space_state != null:
			var space := w3d.direct_space_state
			var g_ray := PhysicsRayQueryParameters3D.create(target_transform.origin + Vector3.UP * 0.8, target_transform.origin - Vector3.UP * 1.5, 32 | 1)
			var g_hit := space.intersect_ray(g_ray)
			if not g_hit.is_empty():
				target_transform.origin.y = g_hit.position.y + 0.02

	target_transform = target_transform.orthonormalized()

	# Compute accurate production offsets using CATALOG.calculate_role_targets
	var role_targets := CATALOG.calculate_role_targets(target_transform, motion)
	var role_a_target: Transform3D = role_targets.get("role_a_target", target_transform).orthonormalized()
	var role_b_target: Transform3D = role_targets.get("role_b_target", target_transform).orthonormalized()

	is_intimacy_active = true
	current_intimacy_actor = resident_actor
	if resident_actor.has_method("enter_interaction"):
		resident_actor.enter_interaction()
	else:
		resident_actor.state = HomeResidentActor.State.INTERACTING
	resident_actor.visible = false

	if world != null:
		if "character" in world and is_instance_valid(world.character):
			world.character.visible = false
			world.character.process_mode = Node.PROCESS_MODE_DISABLED
			if world.character.has_method("set_control_enabled"):
				world.character.set_control_enabled(false)
		if world.has_method("_sync_actor_controls"):
			world._sync_actor_controls()

	intimacy_staging_root = Node3D.new()
	intimacy_staging_root.name = "HomeIntimacyStaging"
	add_child(intimacy_staging_root)

	intimacy_npc_actor = SHARED_HUMANOID_ACTOR.instantiate()
	intimacy_npc_actor.name = "RoleA_Resident"
	intimacy_npc_actor.model_resource = npc_model
	intimacy_npc_actor.motion_resource = role_a_motion_path
	intimacy_npc_actor.auto_play = true
	intimacy_npc_actor.translation_policy = "height_scaled"
	intimacy_npc_actor.environment_collision_enabled = false
	intimacy_staging_root.add_child(intimacy_npc_actor)
	intimacy_npc_actor.global_transform = role_a_target

	intimacy_master_actor = SHARED_HUMANOID_ACTOR.instantiate()
	intimacy_master_actor.name = "RoleB_Master"
	intimacy_master_actor.model_resource = master_model
	intimacy_master_actor.motion_resource = role_b_motion_path
	intimacy_master_actor.auto_play = true
	intimacy_master_actor.translation_policy = "height_scaled"
	intimacy_master_actor.environment_collision_enabled = false
	intimacy_staging_root.add_child(intimacy_master_actor)
	intimacy_master_actor.global_transform = role_b_target

	intimacy_camera = Camera3D.new()
	intimacy_camera.name = "IntimacyStagingCamera"
	intimacy_camera.fov = 50.0
	add_child(intimacy_camera)

	intimacy_focal_point = target_transform.origin + Vector3(0.0, 0.75, 0.0)
	intimacy_cam_dist = 2.4
	intimacy_cam_yaw = target_transform.basis.get_euler().y + PI
	intimacy_cam_pitch = 0.25
	intimacy_dragging = false
	_update_intimacy_camera()
	intimacy_camera.current = true

	if is_instance_valid(hud):
		var m_name: String = str(motion.get("name", "互动"))
		var m_tier: String = "日常侍奉" if str(motion.get("tier", "service")) == "service" else "深度温存"
		var f_name: String = CATALOG.get_furniture_label(req_furn)
		hud.show_notice("【家园亲密互动 · %s】与 %s 在 %s 进行互动（动作：%s）\n按住右键拖动环绕视角 · 滚轮缩放视距 · 按【E】或【ESC】结束互动" % [
			m_tier, resident_actor.get_display_name(), f_name, m_name
		])

func finish_intimacy_staging() -> void:
	if not is_intimacy_active:
		return
	is_intimacy_active = false
	if is_instance_valid(intimacy_staging_root):
		intimacy_staging_root.queue_free()
		intimacy_staging_root = null
	intimacy_npc_actor = null
	intimacy_master_actor = null
	if is_instance_valid(intimacy_camera):
		intimacy_camera.current = false
		intimacy_camera.queue_free()
		intimacy_camera = null

	if is_instance_valid(_previous_camera_instance):
		_previous_camera_instance.make_current()
	elif world != null and world.has_method("active_camera"):
		world.active_camera().make_current()
	elif world != null and "character" in world and is_instance_valid(world.character) and "camera" in world.character and is_instance_valid(world.character.camera):
		world.character.camera.make_current()
	elif world != null and "camera" in world and is_instance_valid(world.camera):
		world.camera.make_current()
	_previous_camera_instance = null

	Input.mouse_mode = _previous_mouse_mode

	if is_instance_valid(current_intimacy_actor):
		current_intimacy_actor.visible = true
		if current_intimacy_actor.has_method("exit_interaction"):
			current_intimacy_actor.exit_interaction()
		else:
			current_intimacy_actor.state = HomeResidentActor.State.IDLE
		current_intimacy_actor = null

	if world != null:
		if "character" in world and is_instance_valid(world.character):
			world.character.visible = true
			world.character.process_mode = Node.PROCESS_MODE_INHERIT
			if world.character.has_method("set_control_enabled"):
				world.character.set_control_enabled(true)
		if world.has_method("_sync_actor_controls"):
			world._sync_actor_controls()

	if is_instance_valid(hud):
		hud.show_notice("已结束家园亲密互动。")

func _update_intimacy_camera() -> void:
	if not is_instance_valid(intimacy_camera):
		return
	var dir := Vector3(
		sin(intimacy_cam_yaw) * cos(intimacy_cam_pitch),
		sin(intimacy_cam_pitch),
		cos(intimacy_cam_yaw) * cos(intimacy_cam_pitch)
	).normalized()
	var max_dist := intimacy_cam_dist
	var target_pos := intimacy_focal_point + dir * max_dist
	var w3d := get_world_3d()
	if w3d != null and w3d.direct_space_state != null:
		var space := w3d.direct_space_state
		var ray := PhysicsRayQueryParameters3D.create(intimacy_focal_point, target_pos, 1 | 32)
		var hit := space.intersect_ray(ray)
		if not hit.is_empty():
			var hit_dist: float = intimacy_focal_point.distance_to(hit.position)
			var safe_dist := maxf(0.5, hit_dist - 0.25)
			target_pos = intimacy_focal_point + dir * safe_dist
	intimacy_camera.global_position = target_pos
	intimacy_camera.look_at(intimacy_focal_point, Vector3.UP)

func _get_room_spawn_position(plot_id: String, room: Dictionary) -> Vector3:
	if not plots.has(plot_id):
		return Vector3.ZERO
	var plot: Dictionary = plots[plot_id]
	var cells: Array = room.get("cells", [])
	if cells.is_empty():
		return plot.root.to_global(ENTRY)

	var target_cell_str: String = str(cells[cells.size() / 2])
	var parts: PackedStringArray = target_cell_str.split(":")
	var story: int = int(room.get("story", 0))
	var cx: int = 15
	var cz: int = 15
	if parts.size() == 3:
		story = parts[0].to_int()
		cx = parts[1].to_int()
		cz = parts[2].to_int()

	var local_pos := Vector3(cx * 2.0 + 1.0, 0.2 + story * DATA.STORY, cz * 2.0 + 1.0)
	var global_pos: Vector3 = plot.root.to_global(local_pos)
	var w3d := get_world_3d()
	if w3d != null and w3d.direct_space_state != null:
		var space := w3d.direct_space_state
		var ray := PhysicsRayQueryParameters3D.create(global_pos + Vector3.UP * 0.8, global_pos - Vector3.UP * 1.5, WALKABLE_MASK)
		var hit := space.intersect_ray(ray)
		if not hit.is_empty():
			return hit.position + Vector3.UP * 0.02
	return global_pos

func refresh_residents() -> void:
	if not initialized or resident_manager == null:
		return

	var valid_room_ids: Dictionary = {}
	for id: String in plots:
		var plot: Dictionary = plots[id]
		for room: Dictionary in plot.data.rooms:
			var r_id: String = str(room.get("id", ""))
			if not r_id.is_empty():
				valid_room_ids[r_id] = {"plot_id": id, "room": room}

	var assignments: Dictionary = resident_manager.get_all_assignments()
	for r_id: String in assignments.keys():
		if not valid_room_ids.has(r_id):
			resident_manager.unassign_room(r_id)

	var current_assigned_rooms: Dictionary = resident_manager.get_all_assignments()

	for r_id: String in resident_actors.keys():
		var actor = resident_actors.get(r_id)
		var expected_char: String = str(current_assigned_rooms.get(r_id, ""))
		if expected_char.is_empty() or not is_instance_valid(actor) or actor.character_id != expected_char:
			if is_instance_valid(actor):
				actor.queue_free()
			resident_actors.erase(r_id)

	for r_id: String in current_assigned_rooms:
		var char_id: String = str(current_assigned_rooms[r_id])
		if char_id.is_empty() or not valid_room_ids.has(r_id):
			continue
		if resident_actors.has(r_id) and is_instance_valid(resident_actors[r_id]):
			var existing_actor = resident_actors[r_id]
			if existing_actor.has_method("update_room_data"):
				existing_actor.update_room_data(valid_room_ids[r_id].room)
			else:
				existing_actor.room_data = valid_room_ids[r_id].room
			continue

		var room_info: Dictionary = valid_room_ids[r_id]
		var plot_id: String = str(room_info.plot_id)
		var room: Dictionary = room_info.room

		var actor_node: HomeResidentActor = RESIDENT_ACTOR_SCENE.new()
		actor_node.character_id = char_id
		actor_node.plot_id = plot_id
		actor_node.room_id = r_id
		actor_node.room_data = room
		actor_node.home = self
		actor_node.interaction_requested.connect(_on_resident_interacted)

		var spawn_pos: Vector3 = _get_room_spawn_position(plot_id, room)
		actor_node.position = spawn_pos
		add_child(actor_node)
		resident_actors[r_id] = actor_node
