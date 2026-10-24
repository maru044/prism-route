extends Node3D
## In-game test authoring. Production map and procedural layout are read-only.
signal status_changed(message: String)
const STORE := preload("res://scripts/tree_planting/layout_store.gd")
const TREE := preload("res://scripts/tree_planting/editable_tree.gd")
@export var profile: Resource
@export_storage var active_ids: Array[String] = []
@export_storage var edit_center := Vector3(-450,63,1050)
var store=STORE.new()
var preview: Node3D
var metadata: Dictionary={}
var last_status := "正在载入种植测试…"
var ready_for_editing := false
var editable_parent: Node3D
var surface_rows: Dictionary={}
var camera: Camera3D
var dirty_session := false
var runtime_editor: CanvasLayer

func _ready() -> void:
	call_deferred("initialize")

func say(message: String) -> void:
	last_status=message;status_changed.emit(message)

func initialize() -> void:
	if profile==null or profile.terrain==null:say("请在 Inspector 指定种植配置和地形");return
	# Exported games cannot write into their resource pack.
	if not OS.has_feature("editor") and profile.test_edits_path.begins_with("res://"):
		profile=profile.duplicate()
		profile.test_edits_path="user://tree_planting_test/"+profile.test_edits_path.get_file()
	if not store.open(profile):say(store.last_error);return
	if not profile.terrain_metadata.is_empty():
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(profile.terrain_metadata))
		if parsed is Dictionary:metadata=parsed
	for row: Dictionary in metadata.get("object_records",[]):surface_rows[str(row.id)]=row
	editable_parent=get_node_or_null("EditableTrees")
	if editable_parent==null:
		editable_parent=Node3D.new();editable_parent.name="EditableTrees";add_child(editable_parent);editable_parent.owner=self
	build_terrain()
	build_environment()
	ready_for_editing=true
	if editable_parent.get_child_count()==0:
		edit_center=profile.initial_center
		load_nearby(edit_center)
	else:say("已恢复测试树位")
	build_runtime_preview()

func build_terrain() -> void:
	preview=profile.terrain.instantiate();preview.name="TerrainPreview";add_child(preview)
	var road:=StandardMaterial3D.new();road.albedo_color=Color(0.13,0.145,0.15);road.roughness=0.93
	var water:=StandardMaterial3D.new();water.albedo_color=Color("71c4d8");water.roughness=0.3
	for mesh: MeshInstance3D in preview.find_children("*","MeshInstance3D",true,false):
		var id:=str(mesh.name).get_slice("_",1)
		var row: Dictionary=surface_rows.get(id,{})
		var kind: String=row.get("kind",str(mesh.name).get_slice("_",0))
		if profile.terrain_material!=null and kind=="Terrain":mesh.material_override=profile.terrain_material
		elif kind=="Road":mesh.material_override=road
		elif kind=="Water":mesh.material_override=water
		elif profile.architecture!=null:mesh.material_override=profile.architecture
		if kind=="Water":continue
		var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0
		body.set_meta("kind",kind);body.set_meta("source_id",id)
		var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape()
		body.add_child(shape);mesh.add_child(body)
	preview.set_meta("_edit_lock_",true)

func build_environment() -> void:
	var environment:=Environment.new()
	if profile.sky!=null:
		var sky:=Sky.new();sky.sky_material=profile.sky
		environment.sky=sky;environment.background_mode=Environment.BG_SKY
		environment.sky_rotation.y=deg_to_rad(84.4)
	else:environment.background_color=Color("8dcde4")
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_SKY;environment.ambient_light_energy=0.38
	environment.tonemap_mode=Environment.TONE_MAPPER_ACES;environment.tonemap_exposure=0.82
	var world:=WorldEnvironment.new();world.environment=environment;add_child(world)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,45,0);sun.light_energy=0.72
	sun.light_color=Color(1,0.95,0.86);sun.shadow_enabled=true;sun.directional_shadow_max_distance=180;add_child(sun)

func trees() -> Array[Node3D]:
	var result: Array[Node3D]=[]
	if editable_parent!=null:
		for node: Node in editable_parent.get_children():
			if node.get_script()==TREE:result.append(node)
	return result

func capture_active() -> bool:
	var rows: Array[Dictionary]=[];var seen: Dictionary={}
	for tree: Node3D in trees():
		if tree.tree_id.is_empty() or seen.has(tree.tree_id):tree.tree_id=store.new_id()
		seen[tree.tree_id]=true
		if tree.species==null or tree.palette==null:
			say("有树缺少树种或色板，请先在面板中指定");return false
		if tree.scale.x<=0 or absf(tree.scale.x-tree.scale.y)>0.001 or absf(tree.scale.x-tree.scale.z)>0.001:
			say("请使用正值、均匀缩放（X/Y/Z 相同）");return false
		if absf(tree.rotation.x)>0.001 or absf(tree.rotation.z)>0.001:
			say("当前测试只支持绕 Y 轴旋转；请将 X/Z 旋转设为 0");return false
		var row: Dictionary=tree.to_record()
		if not STORE.valid_record(row):say("树位参数无效");return false
		rows.append(row)
	store.capture(rows,active_ids)
	return true

func load_nearby(center: Vector3) -> void:
	if not ready_for_editing or not capture_active():return
	edit_center=center
	for tree: Node3D in trees():editable_parent.remove_child(tree);tree.queue_free()
	active_ids.clear()
	var candidates: Array[Dictionary]=[]
	var all: Dictionary=store.all_records()
	for row: Dictionary in all.values():
		var point:=Vector3(row.position[0],row.position[1],row.position[2])
		if Vector2(point.x-center.x,point.z-center.z).length()>profile.edit_radius or absf(point.y-center.y)>profile.height_band:continue
		candidates.append(row)
	candidates.sort_custom(func(a,b):return Vector3(a.position[0],a.position[1],a.position[2]).distance_squared_to(center)<Vector3(b.position[0],b.position[1],b.position[2]).distance_squared_to(center))
	for i in mini(candidates.size(),profile.editable_limit):
		var row: Dictionary=candidates[i]
		if profile.find_species(row.species)==null or profile.find_palette(row.palette)==null:continue
		var tree:=TREE.new();tree.load_record(row,profile)
		editable_parent.add_child(tree);tree.owner=self;active_ids.append(row.id)
	say("当前 %d 棵可编辑树 / 总计 %d 棵；仅显示附近区域"%[trees().size(),all.size()])

func make_tree(point: Vector3,species: Resource,color: Resource, surface:="") -> Node3D:
	var tree:=TREE.new();tree.biome_source=profile.terrain_material;tree.tree_id=store.new_id();tree.name="Tree_"+tree.tree_id
	tree.species=species;tree.palette=color;tree.position=point;tree.surface_id=surface
	return tree

func save_test() -> Error:
	if not capture_active():return ERR_INVALID_DATA
	var error: Error=store.save(profile.test_edits_path,profile)
	if error==OK:say("已保存测试布局：%s（F5 主地图不受影响）"%profile.test_edits_path);dirty_session=false
	else:say(store.last_error)
	return error

func ray(from: Vector3,to: Vector3) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(from,to,1)
	query.hit_back_faces=false
	return get_world_3d().direct_space_state.intersect_ray(query)

func planting_hit(hit: Dictionary) -> bool:
	if hit.is_empty() or (hit.normal as Vector3).dot(Vector3.UP)<0.72:return false
	return hit.collider.get_meta("kind","") not in ["Road","Water","Sand"]

func snap_position(tree: Node3D) -> Dictionary:
	# Stay close to the current storey; never search down from the sky.
	var hit:=ray(tree.global_position+Vector3.UP*2,tree.global_position-Vector3.UP*6)
	return hit if planting_hit(hit) else {}

func build_runtime_preview() -> void:
	camera=Camera3D.new();camera.far=10000;camera.near=0.1;camera.fov=58
	add_child(camera);camera.current=true
	camera.position=edit_center+Vector3(50,28,55);camera.look_at(edit_center+Vector3.UP*5)
	runtime_editor=preload("res://scripts/tree_planting/runtime_editor.gd").new()
	runtime_editor.scene=self;add_child(runtime_editor)
