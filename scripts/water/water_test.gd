extends Node3D
## Small playable water comparison. F5's original world remains the baseline.
const MANAGER := preload("res://scripts/water/water_manager.gd")
const SKY := preload("res://assets/environment/sky/fresh_cumulus_sky.tres")
const TREE := preload("res://assets/vegetation/models/tree_small_broad_canopy.glb")
const LEAF := preload("res://assets/vegetation/textures/leaf_clusters_witness_sparse_flat_v11.png")
@onready var character: CharacterBody3D = $Character
var water
var environment: Environment
var camera: Camera3D
var free_mode := true
var dragging := false
var automation_enabled := false
var test_ready := false
var wind_mode := 0
var wind_blend := 0.0
var elapsed := 0.0
var hud: CanvasLayer
var status: Label
var water_mesh: MeshInstance3D
var reflectors: Array[Dictionary] = []
var timer := 0.0

func _ready() -> void:
	automation_enabled = "--water-verify" in OS.get_cmdline_user_args()
	character.automation_enabled = automation_enabled
	character.collision_mask = 32
	character.surface_step_height = .10
	character.set_control_enabled(false)
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_environment()
	_ground()
	_architecture()
	_trees()
	camera = Camera3D.new();camera.name = "ReviewCamera"
	camera.near = .08;camera.far = 3000;camera.fov = 58
	add_child(camera)
	water = MANAGER.new();water.name = "WaterManager";add_child(water)
	water.initialize(environment,func():return character,func():return get_viewport().get_camera_3d())
	water.reflection_radius = 160.0
	for row: Dictionary in reflectors:water.register_reflector(row.mesh,row.color,row.get("leaf"))
	water_mesh = _water_plane(Vector2(0,1),Vector2(48,56),"shallow_test","lagoon_south")
	_water_plane(Vector2(93,1),Vector2(138,56),"ocean_test","open_sea")
	character.set_spawn(Vector3(0,bed_height(1)+.04,1),PI)
	_hud()
	set_view(0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	test_ready = true
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	print("WATER_TEST_READY")

func _environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new();environment.sky.sky_material = SKY
	environment.sky_rotation.y = deg_to_rad(84.4)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = .38
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = .82
	var world := WorldEnvironment.new();world.environment = environment;add_child(world)
	var sun := DirectionalLight3D.new();sun.rotation_degrees = Vector3(-48,45,0)
	sun.light_energy = .72;sun.light_color = Color(1,.95,.86)
	sun.shadow_enabled = true;sun.directional_shadow_max_distance = 100
	add_child(sun)

func _material(color: Color, leaf: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new();m.albedo_color = color;m.roughness = .9
	if leaf != null:
		m.albedo_texture = leaf;m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = .45;m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _mesh(mesh: Mesh, position: Vector3, color: Color, solid := false, reflect := true) -> MeshInstance3D:
	var node := MeshInstance3D.new();node.mesh = mesh;node.position = position
	node.material_override = _material(color)
	add_child(node)
	if solid:
		var body := StaticBody3D.new();body.collision_layer = 32;body.collision_mask = 0;node.add_child(body)
		var shape := CollisionShape3D.new();shape.shape = mesh.create_trimesh_shape();body.add_child(shape)
	if reflect:reflectors.append({"mesh":node,"color":color})
	return node

func _box(position: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var box := BoxMesh.new();box.size = size
	return _mesh(box,position,color,solid)

func bed_height(z: float) -> float:
	return lerpf(.55,-.60,clampf((z+22.0)/42.0,0,1))

func _ground() -> void:
	var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A real gently sloping bottom, including an above-water bank. No overlay plane.
	for z in range(-27,30,2):
		for x in range(-24,24,2):
			var a := Vector3(x,bed_height(z),z)
			var b := Vector3(x+2,bed_height(z),z)
			var c := Vector3(x,bed_height(z+2),z+2)
			var d := Vector3(x+2,bed_height(z+2),z+2)
			for p: Vector3 in [a,b,c,b,d,c]:st.add_vertex(p)
	st.generate_normals()
	_mesh(st.commit(),Vector3.ZERO,Color("d1bd83"),true,false)
	_box(Vector3(0,.15,-28),Vector3(65,.8,8),Color("88b76b"),true)
	# Sand details make real bottom transmission measurable instead of a blue tint.
	for i in 7:
		_box(Vector3(-14+i*4,bed_height(7)-.008,7),Vector3(1.3,.025,3),Color("ada27e"))

func _architecture() -> void:
	_box(Vector3(0,3.25,-13),Vector3(39,.55,4),Color("e8e4da"),true)
	_box(Vector3(0,3.56,-13),Vector3(39,.04,2.8),Color("3b4248"))
	for x: float in [-15.,-5.,5.,15.]:
		var pillar := CylinderMesh.new();pillar.top_radius = .20;pillar.bottom_radius = .30;pillar.height = 4.1
		var node := _mesh(pillar,Vector3(x,1.35,-13),Color("e8e4da"),true)
		node.rotation.z = -.13
	var points := PackedVector3Array()
	for i in 49:
		var t := float(i)/48.0
		points.append(Vector3(-9+18*t,3.5+11*sin(t*PI),-13+1.4*sin(t*TAU)))
	var curve := Curve3D.new()
	for p: Vector3 in points:curve.add_point(p)
	var path := Path3D.new();path.curve = curve;add_child(path)
	# Tube using ParallelTransport via Curve3D frames is unnecessary for this test;
	# a stable circular section around the tangent forms a slender loop silhouette.
	var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()-1):
		var tangent := (points[i+1]-points[i]).normalized()
		var side := tangent.cross(Vector3.FORWARD).normalized()
		var other := tangent.cross(side).normalized()
		for j in 10:
			var a := TAU*j/10.;var b := TAU*(j+1)/10.
			var p := points[i]+(side*cos(a)+other*sin(a))*.22
			var q := points[i]+(side*cos(b)+other*sin(b))*.22
			var r := points[i+1]+(side*cos(a)+other*sin(a))*.22
			var s := points[i+1]+(side*cos(b)+other*sin(b))*.22
			for v: Vector3 in [p,r,q,q,r,s]:st.add_vertex(v)
	st.generate_normals();_mesh(st.commit(),Vector3.ZERO,Color("f3eee0"))
	# A submerged block is intentionally absent from reflection-only proxies.
	_box(Vector3(8,-.4,12),Vector3(3,.18,3),Color("a1a7a2"))

func _trees() -> void:
	var colors := [Color("81c784"),Color("a5ce76"),Color("efb5d6"),Color("75c09a")]
	for i in 10:
		var tree := TREE.instantiate() as Node3D;tree.position = Vector3(-21+i*4.6,.45,-25)
		tree.rotation.y = i*2.39;tree.scale = Vector3.ONE*(.75+(i%3)*.12)
		add_child(tree)
		for node: MeshInstance3D in tree.find_children("*","MeshInstance3D",true,false):
			var is_leaf := "foliage" in node.name.to_lower() or "leaf" in node.name.to_lower()
			var color: Color = colors[i%colors.size()] if is_leaf else Color("76513f")
			if is_leaf:
				var leaf_material := ShaderMaterial.new();leaf_material.shader = MANAGER.PROXY
				leaf_material.set_shader_parameter("base_color",color)
				leaf_material.set_shader_parameter("leaf_texture",LEAF)
				leaf_material.set_shader_parameter("leaf_cutout",true)
				leaf_material.set_shader_parameter("water_level",-10000.0)
				node.material_override = leaf_material
			else:node.material_override = _material(color)
			reflectors.append({"mesh":node,"color":color,"leaf":LEAF if is_leaf else null})

func _water_plane(center: Vector2, size: Vector2, id: String, profile: String) -> MeshInstance3D:
	var plane := PlaneMesh.new();plane.size = size
	var mesh := _mesh(plane,Vector3(center.x,0,center.y),Color.WHITE,false,false)
	mesh.name = id
	water.register_water(mesh,id,profile)
	var body := StaticBody3D.new();body.collision_layer = 4;body.collision_mask = 0
	body.set_meta("source_id",id);mesh.add_child(body)
	var shape := CollisionShape3D.new();shape.shape = plane.create_trimesh_shape();body.add_child(shape)
	return mesh

func _button(text: String, parent: Node, action: Callable) -> void:
	var b := Button.new();b.text = text;b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b);b.pressed.connect(action)

func _hud() -> void:
	hud = CanvasLayer.new();add_child(hud)
	var panel := PanelContainer.new();panel.position = Vector2(18,18);hud.add_child(panel)
	var style := StyleBoxFlat.new();style.bg_color = Color(.06,.11,.15,.76)
	style.set_content_margin_all(12);panel.add_theme_stylebox_override("panel",style)
	var box := VBoxContainer.new();box.add_theme_constant_override("separation",8);panel.add_child(box)
	var title := Label.new();title.text = "水面 1026 · 镜面 / 浅水 / 涉水对比";box.add_child(title)
	var styles := OptionButton.new()
	for name: String in ["原版水面","新水面 · 天空反射 + 浅水","新水面 · 局部建筑镜像 + 浅水","实验 · 原生 SSR（不透明）"]:styles.add_item(name)
	styles.select(MANAGER.Style.PLANAR);styles.item_selected.connect(water.apply_style);box.add_child(styles)
	var wind := OptionButton.new()
	for name: String in ["风力 · 平静","风力 · 微风","风力 · 大风","风力 · 自动 24 秒"]:wind.add_item(name)
	wind.item_selected.connect(func(value: int):wind_mode = value;elapsed = 0.0);box.add_child(wind)
	var views := HBoxContainer.new();box.add_child(views)
	for i in 4:_button(["镜面","浅水","海面","角色涉水"][i],views,set_view.bind(i))
	var ripples := CheckButton.new();ripples.text = "脚步波纹";ripples.button_pressed = true
	ripples.toggled.connect(func(value: bool):water.interactions_enabled = value;water.interaction.reset());box.add_child(ripples)
	var help := Label.new();help.text = "WASD 移动 · 右键转镜头 · Q/E 升降（观景）\nShift 加速 · 空格跳跃 · R 复位 · H 隐藏界面";box.add_child(help)
	_button("进入正式地图 · 局部镜像水面",box,func():get_tree().change_scene_to_file("res://scenes/map_1021.tscn"))
	status = Label.new();status.position = Vector2(20, -150);status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status.add_theme_color_override("font_shadow_color",Color.BLACK);status.add_theme_constant_override("shadow_offset_x",1)
	status.add_theme_constant_override("shadow_offset_y",1);hud.add_child(status)
	status.offset_left = 20;status.offset_top = -90;status.offset_bottom = -18;status.offset_right = 900

func set_view(which: int) -> void:
	free_mode = which != 3
	character.set_control_enabled(not free_mode)
	if free_mode:
		var eyes := [Vector3(20,2.1,25),Vector3(6,8,15),Vector3(59,2.4,20)]
		var targets := [Vector3(0,4,-13),Vector3(0,-.4,3),Vector3(83,0,-9)]
		camera.position = eyes[which];camera.look_at(targets[which]);camera.make_current()
	else:
		character.set_spawn(Vector3(0,bed_height(1)+.04,1),PI)
		character.camera.make_current()
	water.interaction.reset()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_H:
		hud.visible = not hud.visible;get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R and free_mode:set_view(0)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:dragging = event.pressed
	if event is InputEventMouseMotion and free_mode and dragging:
		camera.rotation.y -= event.relative.x*.003
		camera.rotation.x = clampf(camera.rotation.x-event.relative.y*.003,-1.5,1.5)

func _process(delta: float) -> void:
	if water == null:return
	elapsed += delta
	var target := 0.0
	if wind_mode == 1:target = .12
	elif wind_mode == 2:target = 1.0
	elif wind_mode == 3:target = 1.0 if fposmod(elapsed,24.0)>=8.0 and fposmod(elapsed,24.0)<19.0 else .0
	wind_blend = move_toward(wind_blend,target,delta/3.0)
	water.wind_override = wind_blend
	if free_mode and not automation_enabled:
		var direction := Vector3(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		camera.position += camera.global_basis * direction * delta * (18 if Input.is_physical_key_pressed(KEY_SHIFT) else 6)
	timer += delta
	if timer > .25 and status != null:
		timer = 0
		var m: Dictionary = water.metrics()
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
		status.text = "FPS %.0f · 主视口 GPU %.2f ms · 反射 GPU %.2f ms\n倒影 %d×%d · %d 个物件 · 波纹 %d / 16\n两个 GPU 计时独立显示，不直接相加" % [Engine.get_frames_per_second(),gpu,m.reflection_gpu_ms,m.reflection_size[0],m.reflection_size[1],m.reflection_objects,m.events]
