extends Node3D
## One world and one effective population, with a sparse persistent edit layer.
signal status_changed(message: String)
const STORE=preload("res://scripts/tree_planting/layout_store.gd")
const TREE=preload("res://scripts/tree_planting/world_editable_tree.gd")
const UI=preload("res://scripts/tree_planting/runtime_editor.gd")
const PROFILE="res://assets/world/tree_planting_test/current_map.tres"
const DEFAULT_SAVE="res://assets/world/tree_planting/world_edits.json"
var world
var profile: Resource
var metadata: Dictionary
var store=STORE.new()
var ring_ids: Dictionary={}
var bindings: Dictionary={}
var rendered_records: Dictionary={}
var overrides: Dictionary={}
var hidden: Dictionary={}
var editable_parent: Node3D
var active_ids: Array[String]=[]
var edit_center:=Vector3.ZERO
var camera: Camera3D
var runtime_editor
var active:=false
var dirty_session:=false
var last_status:=""
var load_error:=""
var play_camera_transform: Transform3D
var editor_camera_transform: Transform3D
var has_editor_camera:=false
var previous_free:=false
var previous_ui:=true
var remembered_selection:=""

func initialize(scene) -> void:
	world=scene;metadata=world.metadata;camera=world.camera
	profile=load(PROFILE).duplicate();profile.terrain_material=world.terrain_material
	profile.initial_center=world.active_actor().global_position;profile.edit_radius=110.;profile.height_band=16.;profile.editable_limit=120
	var requested: String=world.planting_edits_path
	profile.test_edits_path=requested
	if not OS.has_feature("editor") and requested==DEFAULT_SAVE:
		profile.test_edits_path="user://world_planting/world_edits.json"
		if not FileAccess.file_exists(profile.test_edits_path) and FileAccess.file_exists(requested):
			var packed=profile.duplicate();packed.test_edits_path=requested
			if not store.open(packed):load_error=store.last_error
		else:
			if not store.open(profile):load_error=store.last_error
	elif not store.open(profile):load_error=store.last_error
	# Failed/incompatible edits are preserved on disk and never overwritten.
	if not load_error.is_empty():
		var clean=profile.duplicate();clean.test_edits_path="user://world_planting/nonexistent_baseline_only.json";store.open(clean)
		push_warning("Planting edits not loaded: "+load_error)
	for id: String in store.baseline.keys():
		var row: Dictionary=store.baseline[id];var p:=Vector3(row.position[0],row.position[1],row.position[2])
		p=world.upper_ring.adjusted_tree_position(p)
		if world.initial_ruin.planting_mask.blocks(p,3.) or world.upper_ring.planting_mask.excludes_tree(p):store.baseline.erase(id)
		else:row.position=[p.x,p.y,p.z]
	for row: Dictionary in world.upper_ring.manifest.trees:
		var id:=ring_id(row);ring_ids[id]=true
		store.baseline[id]={"id":id,"position":row.position.duplicate(),"yaw":row.yaw,"scale":row.scale,"species":["small","broad","upright"][int(row.model)],"palette":"green","surface":"upper_ring_bed_"+str(row.bed)}
	for id: String in store.edits.keys():
		var row: Dictionary=store.edits[id]
		if profile.find_species(row.species)==null or profile.find_palette(row.palette)==null:
			load_error="保存布局含有未知树种或色板，暂未加载该记录";store.edits.erase(id)
	rendered_records=store.all_records().duplicate(true)
	editable_parent=Node3D.new();editable_parent.name="EditableTrees";add_child(editable_parent)
	print("WORLD_PLANTING_READY baseline=",store.baseline.size()," edits=",store.edits.size()," removed=",store.removed.size())

func finish() -> void:
	runtime_editor=UI.new();runtime_editor.scene=self;runtime_editor.integrated=true;add_child(runtime_editor)
	set_editor_ui(false)
	get_tree().auto_accept_quit=false
	get_tree().root.close_requested.connect(runtime_editor.request_close)
	if not load_error.is_empty():say(load_error+"；原保存文件保留，修复前禁止覆盖")

static func ring_id(row: Dictionary) -> String:return "ring_"+str(row.name)
static func model_index(id: String) -> int:return maxi(["small","broad","upright","birch"].find(id),0)
static func palette_index(id: String) -> int:return maxi(["green","cherry","gold","orange","red"].find(id),0)

func bind_bucket(ids: Array,parent: Node3D) -> void:
	for node: Node in parent.get_children():
		if not node is MultiMeshInstance3D:continue
		for i in ids.size():
			if not bindings.has(ids[i]):bindings[ids[i]]=[]
			bindings[ids[i]].append({"node":node,"index":i,"transform":node.multimesh.get_instance_transform(i)})

func live_override(id: String) -> Node3D:
	# Check the Variant before assigning to a typed Node variable: a freed
	# object in a Dictionary raises at the assignment itself in GDScript.
	var node: Variant=overrides.get(id)
	if is_instance_valid(node) and node is Node3D and not node.is_queued_for_deletion() and node.get_parent()==self:return node
	overrides.erase(id)
	return null

func set_source_visible(id: String,enabled: bool) -> void:
	var override_node:=live_override(id)
	if override_node!=null:
		override_node.visible=enabled
		for body: StaticBody3D in override_node.find_children("TrunkCollision","StaticBody3D",true,false):body.collision_layer=32 if enabled else 0
	else:
		set_base_visible(id,enabled)
	if enabled:hidden.erase(id)
	else:hidden[id]=true

func set_base_visible(id: String,enabled: bool) -> void:
	for binding: Dictionary in bindings.get(id,[]):
		if is_instance_valid(binding.node):binding.node.multimesh.set_instance_transform(binding.index,binding.transform if enabled else Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*.000001),Vector3(0,-100000,0)))
	if ring_ids.has(id):
		for body: StaticBody3D in world.upper_ring.find_children("*","StaticBody3D",true,false):
			if body.get_meta("planting_id","")==id:body.collision_layer=32 if enabled else 0

func create_tree(row: Dictionary) -> Node3D:
	var tree=TREE.new();tree.context=self;tree.load_record(row,profile);return tree

func build_visual(tree: Node3D,parent: Node3D) -> AABB:
	var streamer=world.vegetation;var transforms: Array[Transform3D]=[Transform3D.IDENTITY]
	for level in 3:streamer._add_tree_lod_level(parent,model_index(tree.species.id),transforms,palette_index(tree.palette.id),level,0.)
	var bounds:=AABB();var have:=false
	for node: MultiMeshInstance3D in parent.get_children():
		# Handles own these nodes, so remove them from global presentation lists.
		streamer.tree_lod0_nodes.erase(node);streamer.tree_lod1_nodes.erase(node);streamer.tree_lod2_nodes.erase(node)
		if "LOD2" in str(node.name):node.visibility_range_end=6000.
		if "LOD0_Leaves" in str(node.name):bounds=node.multimesh.mesh.get_aabb();have=true
		world.foliage_style._register(node)
	if world.water_manager!=null:world.water_manager.register_tree_nodes(parent.get_children(),true)
	assert(have)
	return bounds

func trees() -> Array[Node3D]:
	var result: Array[Node3D]=[]
	for node: Node3D in editable_parent.get_children():result.append(node)
	return result

func say(message: String) -> void:last_status=message;status_changed.emit(message)

func capture_active() -> bool:
	var rows: Array[Dictionary]=[]
	for tree: Node3D in trees():
		var row: Dictionary=tree.to_record()
		if not STORE.valid_record(row):say("树位参数无效，未应用");return false
		rows.append(row)
	store.capture(rows,active_ids);return true

func clear_handles() -> void:
	for id: String in active_ids:set_source_visible(id,true)
	for tree: Node3D in trees():editable_parent.remove_child(tree);tree.queue_free()
	active_ids.clear()
	prune_style.call_deferred()

func prune_style() -> void:
	# Style caches share materials, but must not accumulate dead handle entries.
	await get_tree().process_frame
	if world.foliage_style==null:return
	for row: Dictionary in world.foliage_style.records:
		row.nodes=row.nodes.filter(func(node):return is_instance_valid(node) and node.is_inside_tree())
		if not row.node_parameters.is_empty():
			var alive: Dictionary={}
			for node: Node in row.nodes:alive[node.get_instance_id()]=true
			for id: int in row.node_parameters.keys():
				if not alive.has(id):row.node_parameters.erase(id)

func apply_world() -> void:
	for id: String in hidden.keys():set_base_visible(id,true)
	for id: String in overrides.keys():
		set_base_visible(id,true)
		var node:=live_override(id)
		if node!=null:remove_child(node);node.queue_free()
	overrides.clear();hidden.clear()
	var effective: Dictionary=store.all_records()
	for id: String in rendered_records:
		if not effective.has(id) or not STORE.same_tree(rendered_records[id],effective[id]):set_source_visible(id,false)
	for id: String in effective:
		if rendered_records.has(id) and STORE.same_tree(rendered_records[id],effective[id]):continue
		var tree:=create_tree(effective[id]);add_child(tree);overrides[id]=tree
	world.vegetation.tree_instance_count=effective.size()
	world.vegetation.large_tree_instance_count=effective.values().filter(func(row: Dictionary):return row.species!="small").size()
	if world.world_audio!=null and world.world_audio.ready_audio:world.world_audio.rebuild_tree_grid()
	refresh_probe()

func load_nearby(center: Vector3) -> void:
	if not capture_active():return
	clear_handles();apply_world();edit_center=center
	var candidates: Array=[]
	for row: Dictionary in store.all_records().values():
		var p:=Vector3(row.position[0],row.position[1],row.position[2])
		if Vector2(p.x-center.x,p.z-center.z).length()<=profile.edit_radius and absf(p.y-center.y)<=profile.height_band:candidates.append(row)
	candidates.sort_custom(func(a,b):return Vector3(a.position[0],a.position[1],a.position[2]).distance_squared_to(center)<Vector3(b.position[0],b.position[1],b.position[2]).distance_squared_to(center))
	for i in mini(candidates.size(),profile.editable_limit):
		var row: Dictionary=candidates[i];set_source_visible(row.id,false)
		var tree:=create_tree(row);editable_parent.add_child(tree);active_ids.append(row.id)
	say("附近 %d 棵可编辑 / 范围内 %d 棵；其余保持原分布"%[trees().size(),candidates.size()])

func make_tree(point: Vector3,species: Resource,color: Resource,surface:="") -> Node3D:
	return create_tree({"id":store.new_id(),"position":[point.x,point.y,point.z],"yaw":0.,"scale":1.,"species":species.id,"palette":color.id,"surface":surface})

func save_test() -> Error:
	if runtime_editor!=null:runtime_editor.finish_pending()
	if not load_error.is_empty():say(load_error+"；为保留原文件，本次未保存");return ERR_INVALID_DATA
	if not capture_active():return ERR_INVALID_DATA
	var error: Error=store.save(profile.test_edits_path,profile)
	if error==OK:
		dirty_session=false
		if active:
			# Keep the selection/history while refreshing the same world's sources.
			apply_world()
			for id: String in active_ids:set_source_visible(id,false)
		else:apply_world()
		say("已保存并应用。\n下次 F5 自动载入；再次保存保留上一版备份。")
	else:say(store.last_error)
	return error

func restore_selected() -> void:
	runtime_editor.finish_pending()
	var selected=runtime_editor.selected
	if not is_instance_valid(selected) or not store.baseline.has(selected.tree_id):say("新增树没有原始状态；可以删除或撤销");return
	var before: Dictionary=runtime_editor.snapshot();selected.load_record(store.baseline[selected.tree_id],profile);runtime_editor.record_change(before)

func set_editor_ui(enabled: bool) -> void:
	runtime_editor.visible=enabled;runtime_editor.set_process(enabled);runtime_editor.set_process_unhandled_input(enabled)
	if runtime_editor.marker!=null:runtime_editor.marker.visible=false
	if runtime_editor.foot_preview!=null:runtime_editor.foot_preview.visible=false

func toggle() -> void:
	if not world.test_ready:return
	if active:leave()
	else:enter()

func enter() -> void:
	previous_free=world.free_mode;previous_ui=world.review_ui_visible
	play_camera_transform=get_viewport().get_camera_3d().global_transform
	world.free_mode=true;world.overview_mode=false;active=true;world.dragging=false
	world._sync_actor_controls();world.set_review_ui_visible(false)
	world.initial_ruin.set_process_input(false)
	camera.global_transform=editor_camera_transform if has_editor_camera else play_camera_transform
	profile.initial_center=world.active_actor().global_position
	runtime_editor.regions[0]=profile.initial_center
	var center: Vector3=edit_center if has_editor_camera else profile.initial_center
	if previous_free and not has_editor_camera:
		var hit:=ray(camera.global_position,camera.global_position-camera.global_basis.z*800.)
		if not hit.is_empty():center=hit.position
	load_nearby(center)
	runtime_editor.selected=null
	for tree: Node3D in trees():
		if tree.tree_id==remembered_selection:runtime_editor.selected=tree;break
	runtime_editor.refresh_ui();set_editor_ui(true)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func leave() -> void:
	runtime_editor.finish_pending();runtime_editor.stop_navigation()
	if not capture_active():return
	remembered_selection=runtime_editor.selected.tree_id if is_instance_valid(runtime_editor.selected) else ""
	editor_camera_transform=camera.global_transform;has_editor_camera=true
	clear_handles();apply_world();runtime_editor.selected=null;runtime_editor.looking=false
	active=false;set_editor_ui(false);world.initial_ruin.set_process_input(true)
	world.free_mode=previous_free;world._sync_actor_controls()
	if previous_free:camera.global_transform=play_camera_transform
	world.set_review_ui_visible(previous_ui)
	DisplayServer.window_set_title("Prism Route")

func play_here() -> void:
	var hit:=ray(camera.global_position,camera.global_position-camera.global_basis.z*5000.)
	if not planting_hit(hit):say("先将镜头中心对准可站立地面");return
	var floor: Dictionary=world._find_actor_floor(hit.position,0.,true)
	if floor.is_empty():say("此处空间不足，无法放置角色");return
	previous_free=false;world.character_mode=true
	world.character.set_spawn(floor.position+Vector3.UP*.1,camera.rotation.y)
	leave()

func ray(from: Vector3,to: Vector3) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(from,to,1);query.hit_back_faces=true
	return get_world_3d().direct_space_state.intersect_ray(query)

func planting_hit(hit: Dictionary) -> bool:
	if not hit.is_empty() and hit.collider.get_parent().get_meta("upper_ring_material","")=="water":return false
	return not hit.is_empty() and hit.normal.y>=.72 and hit.collider.get_meta("surface_kind","") not in ["Road","Water","Sand"] and not hit.collider.get_meta("nonblocking_road_marking",false)

func snap_position(tree: Node3D) -> Dictionary:
	var hit:=ray(tree.global_position+Vector3.UP*2,tree.global_position-Vector3.UP*6)
	return hit if planting_hit(hit) else {}

func refresh_probe() -> void:
	if world.upper_ring.material_set.probe==null:return
	var probe: ReflectionProbe=world.upper_ring.material_set.probe
	probe.update_mode=ReflectionProbe.UPDATE_ALWAYS
	await get_tree().create_timer(.25).timeout
	if is_instance_valid(probe):probe.update_mode=ReflectionProbe.UPDATE_ONCE
