extends Node
## Reversible material and leaf-card trial; source geometry, collision and vegetation stay intact.
const SHADER=preload("res://shaders/environment/architecture_details_1029.gdshader")
const SEAM=preload("res://assets/world/architecture_details_1029/seam_wear_mask_v1.png")
const LEAVES=preload("res://assets/world/architecture_details_1029/foliage_leaf_mask_v2.png")
const CONFIG="res://assets/world/architecture_details_1029/trial_settings.json"
const CLUSTER_LAYER=preload("res://scripts/world/architecture_cluster_layer.gd")
var cluster_layer
var world
var settings: Dictionary={}
var records: Array[Dictionary]=[]
var materials: Dictionary={}
var menu: MenuButton
var controls: PopupPanel
var density: HSlider
var paint: ColorPickerButton
var enabled:=true
var look_baseline: Array[Dictionary]=[]

func initialize(scene: Node3D) -> void:
	world=scene;reload_settings(true)

func reload_settings(rebuild: bool=false) -> void:
	var value=JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	if not value is Dictionary:push_error("Invalid architecture trial settings");return
	if rebuild or not records.is_empty():
		if is_instance_valid(cluster_layer):cluster_layer.clear();cluster_layer.free()
		_restore_sources()
		# Removed hosts must also lose the old detail material in the mirror.
		sync_reflections()
	settings=value;enabled=bool(settings.get("enabled",true))
	if "--no-architecture-details" in OS.get_cmdline_user_args():enabled=false
	_collect()
	cluster_layer=CLUSTER_LAYER.new();cluster_layer.name="WorldLeafClustersV6";world.add_child(cluster_layer);cluster_layer.initialize(records,settings)
	world.get_window().title="Prism Route | 大世界 · 叶团 V6"
	apply()

func _collect() -> void:
	records.clear();materials.clear()
	for mesh: MeshInstance3D in world.model.find_children("*","MeshInstance3D",true,false):
		var id:=str(mesh.name).get_slice("_",1)
		if settings.main_hosts.has(id):_record(mesh,id,Vector3.ZERO,Vector3.RIGHT,Vector3.BACK,settings.main_hosts[id],"main")
	var rows: Dictionary={}
	for row: Dictionary in world.initial_ruin.planting_mask.manifest.objects:rows[row.id]=row
	var p: Dictionary=world.initial_ruin.planting_mask.manifest.placement
	var origin:=Vector3(float(p.front_center[0])-1450.,0.,1150.-float(p.front_center[1]))
	var right:=Vector3(p.right_axis[0],0.,-p.right_axis[1])
	var forward:=Vector3(p.long_axis[0],0.,-p.long_axis[1])
	for mesh: MeshInstance3D in world.initial_ruin.geometry.find_children("*","MeshInstance3D",true,false):
		var id:=str(mesh.name).get_slice("_",1)
		if rows[id].category in settings.ruin_categories:_record(mesh,id,origin,right,forward,{},"ruin")

func _record(mesh: MeshInstance3D,id: String,origin: Vector3,right: Vector3,forward: Vector3,options: Dictionary,group: String) -> void:
	var original:=mesh.material_override as ShaderMaterial
	if original==null:return
	var key: String=str(original.get_instance_id())+group+id+JSON.stringify(options)
	if not materials.has(key):
		var candidate:=ShaderMaterial.new();candidate.shader=SHADER
		for parameter: String in ["base_texture","micro_normal","roughness_texture","warm_white","detail_strength","normal_strength","texture_meters"]:
			candidate.set_shader_parameter(parameter,original.get_shader_parameter(parameter))
		candidate.set_shader_parameter("texture_meters",6.0)
		candidate.set_shader_parameter("detail_strength",.08)
		candidate.set_shader_parameter("normal_strength",.045)
		candidate.set_shader_parameter("warm_white",Color("ebe5d5"))
		candidate.set_shader_parameter("macro_strength",.10)
		candidate.set_shader_parameter("macro_meters",8.)
		candidate.set_shader_parameter("weather_strength",.30 if group=="ruin" else .16)
		candidate.set_shader_parameter("weather_top_y",(mesh.global_transform*mesh.get_aabb()).end.y)
		candidate.set_shader_parameter("seam_mask",SEAM);candidate.set_shader_parameter("foliage_atlas",LEAVES)
		candidate.set_shader_parameter("mapping_origin",origin);candidate.set_shader_parameter("mapping_right",right);candidate.set_shader_parameter("mapping_forward",forward)
		candidate.set_shader_parameter("plant_region_max",Vector3(100000,100000,float(options.get("plant_world_z_max",100000))))
		materials[key]=candidate
	records.append({"mesh":mesh,"baseline":original,"candidate":materials[key],"id":id,"group":group})

func apply() -> void:
	for material: ShaderMaterial in materials.values():
		material.set_shader_parameter("joints_enabled",bool(settings.joints_enabled))
		# The old alpha-only scatter is retired; V6 leaf clusters use separate cards.
		material.set_shader_parameter("plants_enabled",false)
		material.set_shader_parameter("procedural_plants",true)
		material.set_shader_parameter("panel_meters",Vector2(settings.panel_meters[0],settings.panel_meters[1]))
		material.set_shader_parameter("joint_width",float(settings.joint_width_m));material.set_shader_parameter("joint_strength",float(settings.joint_strength))
		material.set_shader_parameter("plant_density",clampf(float(settings.plant_density),0.,1.))
		material.set_shader_parameter("plant_seed",float(settings.plant_seed))
		material.set_shader_parameter("plant_tile_meters",Vector2(settings.plant_tile_meters[0],settings.plant_tile_meters[1]))
		material.set_shader_parameter("plant_cluster_meters",Vector2(settings.plant_cluster_meters[0],settings.plant_cluster_meters[1]))
		material.set_shader_parameter("plant_overlap",float(settings.get("plant_overlap",.65)))
		material.set_shader_parameter("plant_loose_leaves",float(settings.get("plant_loose_leaves",1.)))
		material.set_shader_parameter("plant_color",Color(str(settings.plant_color)))
		material.set_shader_parameter("plant_draw_distance",float(settings.plant_draw_distance_m))
	for row: Dictionary in records:
		var material: ShaderMaterial=row.candidate
		var styled: bool=bool(settings.get("surface_look_enabled",true))
		for parameter: String in ["texture_meters","detail_strength","normal_strength","warm_white"]:
			var value: Variant={"texture_meters":6.,"detail_strength":.08,"normal_strength":.045,"warm_white":Color("ebe5d5")}[parameter] if styled else row.baseline.get_shader_parameter(parameter)
			if value!=null:material.set_shader_parameter(parameter,value)
		material.set_shader_parameter("macro_strength",.10 if styled else 0.)
		material.set_shader_parameter("weather_strength",(.30 if row.group=="ruin" else .16) if styled else 0.)
		row.mesh.material_override=row.candidate if enabled else row.baseline
	if is_instance_valid(cluster_layer):cluster_layer.apply_settings(enabled,settings)
	sync_reflections();_sync_controls()

func set_enabled(value: bool) -> void:
	enabled=value;apply()
func set_layer(layer: String,value: bool) -> void:
	settings[layer+"_enabled"]=value;apply()
func _restore_sources() -> void:
	for row: Dictionary in records:
		if is_instance_valid(row.mesh):row.mesh.material_override=row.baseline
func sync_reflections() -> void:
	if world==null or not is_instance_valid(world.water_manager):return
	_apply_environment_look()
	if is_instance_valid(cluster_layer) and world.foliage_style!=null:cluster_layer.bind_environment(world.foliage_style.biome_source)
	for row: Dictionary in records:world.water_manager.refresh_reflector_material(row.mesh)

func _apply_environment_look() -> void:
	if world==null or not is_instance_valid(world.water_manager):return
	if look_baseline.is_empty():
		var environment: Environment=world.water_manager.main_environment
		look_baseline.append({"object":environment,"property":"tonemap_exposure","value":environment.tonemap_exposure})
		for node: Node in world.get_children():
			if node is DirectionalLight3D:
				look_baseline.append({"object":node,"property":"light_energy","value":node.light_energy})
				look_baseline.append({"object":node,"property":"light_color","value":node.light_color})
	var active: bool=enabled and bool(settings.get("environment_look_enabled",true))
	for row: Dictionary in look_baseline:
		var value: Variant=row.value
		if active:
			match row.property:
				"tonemap_exposure":value=float(settings.get("look_exposure",.74))
				"light_energy":value=.68
				"light_color":value=Color("fff4de")
		row.object.set(row.property,value)
func add_controls(box: VBoxContainer) -> void:
	menu=MenuButton.new();box.add_child(menu)
	var popup:=menu.get_popup()
	popup.add_check_item("启用试放",0);popup.add_check_item("结构接缝",1);popup.add_check_item("叶团面片 V6",2);popup.add_check_item("环境试调",3);popup.add_check_item("墙面材质",4);popup.add_separator()
	popup.add_item("临水巨构 · 实机机位",10);popup.add_item("初始遗迹 · 墙面近景",11);popup.add_item("洞窟外步道 · 角色视角",12);popup.add_item("初始遗迹 · 整体",13);popup.add_separator()
	popup.add_item("初始崖壁 · 叶团近景",14)
	popup.add_item("叶团尺度 · 1.00 ×",30);popup.add_item("叶团尺度 · 1.35 ×",31);popup.add_item("叶团尺度 · 1.60 ×",32);popup.add_separator()
	popup.add_item("调整叶片颜色与密度",20);popup.add_item("重新读取配置",21)
	popup.id_pressed.connect(_menu_action)
	controls=PopupPanel.new();controls.size=Vector2i(300,190);menu.add_child(controls)
	var margin:=MarginContainer.new()
	for key: String in ["margin_left","margin_top","margin_right","margin_bottom"]:margin.add_theme_constant_override(key,16)
	controls.add_child(margin);var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);margin.add_child(column)
	var label:=Label.new();label.text="叶团色调 · 白色保留默认配色";column.add_child(label)
	paint=ColorPickerButton.new();paint.edit_alpha=false;column.add_child(paint)
	paint.color_changed.connect(func(color):settings.plant_color=color.to_html(false);apply())
	label=Label.new();label.text="叶团密度";column.add_child(label)
	density=HSlider.new();density.min_value=0.;density.max_value=1.;density.step=.01;column.add_child(density)
	density.value_changed.connect(func(value):settings.plant_density=value;apply())
	_sync_controls()

func _sync_controls() -> void:
	if menu==null:return
	menu.text="表面贴图 · 叶团 V6" if enabled else "表面贴图 · 已关闭"
	var popup:=menu.get_popup()
	for id in [0,1,2]:popup.set_item_checked(popup.get_item_index(id),enabled if id==0 else bool(settings.joints_enabled if id==1 else settings.plants_enabled))
	popup.set_item_checked(popup.get_item_index(3),bool(settings.get("environment_look_enabled",true)))
	popup.set_item_checked(popup.get_item_index(4),bool(settings.get("surface_look_enabled",true)))
	density.set_block_signals(true);density.value=float(settings.plant_density);density.set_block_signals(false)
	paint.set_block_signals(true);paint.color=Color(str(settings.plant_color));paint.set_block_signals(false)

func _menu_action(id: int) -> void:
	match id:
		0:set_enabled(not enabled)
		1:set_layer("joints",not settings.joints_enabled)
		2:set_layer("plants",not settings.plants_enabled)
		3:settings.environment_look_enabled=not settings.get("environment_look_enabled",true);apply()
		4:settings.surface_look_enabled=not settings.get("surface_look_enabled",true);apply()
		10:show_view(0)
		11:show_view(1)
		12:show_view(2)
		13:show_view(3)
		14:show_view(4)
		20:controls.position=Vector2i(350,160);controls.popup()
		21:reload_settings()
		30:set_cluster_scale(1.)
		31:set_cluster_scale(1.35)
		32:set_cluster_scale(1.6)
func set_cluster_scale(value: float) -> void:
	settings.plant_scale=value;cluster_layer.set_cluster_scale(value)
func hide_settings() -> void:
	if controls!=null:controls.hide()

func show_view(which: int) -> void:
	if which==4:
		world.set_free(true)
		var best: Dictionary={};var score:=INF
		for row: Dictionary in cluster_layer.placements:
			if row.group!="main":continue
			var d: float=Vector2(row.top.x+870.,row.top.z-1420.).length_squared()
			if d<score:score=d;best=row
		if not best.is_empty():
			world.camera.position=best.top+best.normal*13.-Vector3.UP*1.8
			world.camera.look_at(best.top-Vector3.UP*1.4);world.camera.fov=58.
		if world.vegetation!=null:world.vegetation.target=world.camera;world.vegetation.volume_streamer.refresh()
		return
	if which==2:
		if not world.character_mode:await world.set_character_mode(true)
		world.set_free(false)
		var native:=Vector3(578,35.2,-276)
		var p:=Vector3(native.x-1450,native.y,1150.-native.z)
		var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*2.,p-Vector3.UP*3.,32)
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():world.character.set_spawn(hit.position+Vector3.UP*.04,.7)
	else:
		world.set_free(true)
		if which==0:
			world.camera.position=Vector3(1127.777-1450,2.4,1150-155.555)
			world.camera.look_at(Vector3(1350-1450,40,1150-250));world.camera.fov=58.
		else:
			var data: Dictionary=world.initial_ruin.planting_mask.manifest.placement
			var origin:=Vector3(data.front_center[0]-1450.,0.,1150.-data.front_center[1])
			var right:=Vector3(data.right_axis[0],0,-data.right_axis[1]);var axis:=Vector3(data.long_axis[0],0,-data.long_axis[1])
			if which==1:
				world.camera.position=origin+right*(-4.)+axis*15.+Vector3.UP*68.
				world.camera.look_at(origin+right*9.5+axis*21.+Vector3.UP*75.);world.camera.fov=55.
			else:
				world.camera.position=origin-right*24.-axis*22.+Vector3.UP*73.
				world.camera.look_at(origin+axis*16.+Vector3.UP*66.);world.camera.fov=58.
	if world.vegetation!=null:world.vegetation.target=world.active_actor() if not world.free_mode else world.camera;world.vegetation.volume_streamer.refresh()

func _exit_tree() -> void:
	for row: Dictionary in look_baseline:
		if is_instance_valid(row.object):row.object.set(row.property,row.value)
	if is_instance_valid(cluster_layer):cluster_layer.clear()
	_restore_sources()
