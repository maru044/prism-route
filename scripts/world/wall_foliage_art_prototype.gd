extends Node3D
## One deliberately composed wall. Leaf geometry is a visual prototype, not a
## replacement for the formal map's projection material or a baked target image.
const CONFIG="res://assets/world/wall_foliage_art_prototype_1029/layout.json"
const LEAF_PAINT=preload("res://assets/world/wall_foliage_art_prototype_1029/leaf_paint.gdshader")
const LEAF_TEXTURED=preload("res://assets/world/wall_foliage_art_prototype_1029/leaf_textured.gdshader")
const LEAF_ATLAS=preload("res://assets/world/wall_foliage_art_prototype_1029/leaf_volume_atlas_v3.png")
const ART="res://docs/wall_foliage_art_prototype_1029/art_target.png"
var settings: Dictionary
var leaves: Array[Dictionary]=[]
var camera: Camera3D
var foliage: MultiMeshInstance3D
var ui: CanvasLayer
var reference: TextureRect
var reference_button: Button
var ready_for_review:=false
var automation_enabled:=false
var dragging:=false
var yaw:=0.
var view_target:=Vector3(0,3.07,0)
var orbit_clock:=0.
var auto_orbit:=false
var paint: ShaderMaterial

func _ready() -> void:
	settings=JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	var environment:=Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("c4d1dc");environment.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color.WHITE;environment.ambient_light_energy=.75
	var env:=WorldEnvironment.new();env.environment=environment;add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-25,-28,0);sun.light_energy=.35;sun.shadow_enabled=true;sun.directional_shadow_max_distance=40.;add_child(sun)
	wall_box(Vector3(12,6.3,.16),Vector3(0,3.15,-.08),Color("f3eedf"))
	wall_box(Vector3(12.1,.10,.12),Vector3(0,6.3,-.07),Color("f7f1e4"))
	wall_box(Vector3(13.8,.04,3.),Vector3(0,-.04,0),Color("e8e3dc"))
	# Only two long construction joints; no periodic grid or intermediate line.
	wall_box(Vector3(12,.012,.002),Vector3(0,2.37,.003),Color("c6c0b4"))
	wall_box(Vector3(.012,6.3,.002),Vector3(2.82,3.15,.003),Color("c6c0b4"))
	build_leaves()
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=7.15;camera.near=.05;camera.far=100.;add_child(camera);set_view(0);camera.make_current()
	build_ui();ready_for_review=true
	print("WALL_FOLIAGE_ART_PROTOTYPE_READY leaves=",leaves.size())

func wall_box(size: Vector3,position_at: Vector3,color: Color) -> void:
	var primitive:=BoxMesh.new();primitive.size=size
	var arrays:=primitive.get_mesh_arrays();arrays[Mesh.ARRAY_TEX_UV]=null;arrays[Mesh.ARRAY_TEX_UV2]=null
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var material:=StandardMaterial3D.new();material.albedo_color=color;material.roughness=1.
	var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=material;node.position=position_at;add_child(node)

func blade_mesh() -> ArrayMesh:
	# Intersection-of-circles outline: a wide pointed oval with fixed proportions.
	var vertices:=PackedVector3Array([Vector3.ZERO]);var indices:=PackedInt32Array()
	var tip:=sqrt(1.22*1.22-.72*.72)
	var segments:=12
	for side in [1.,-1.]:
		for i in segments+1:
			var y: float=lerpf(-tip,tip,float(i)/segments) if side>0 else lerpf(tip,-tip,float(i)/segments)
			var x: float=maxf(0.,sqrt(maxf(0.,1.22*1.22-y*y))-.72)*side
			vertices.append(Vector3(x,y,0))
	for i in vertices.size()-1:
		indices.append_array([0,i+1,(i+1)%(vertices.size()-1)+1])
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh

func add_blade(rng: RandomNumberGenerator,x: float,depth: float,size: float,angle: float) -> void:
	var tone:=rng.randi_range(0,2)
	leaves.append({"x":x,"depth":depth,"size":size,"angle":angle,"tone":tone})

func build_leaves() -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=int(settings.seed)
	var spacing: float=settings.leaf_spacing
	var width: float=settings.wall_width
	# Connected top canopy with an uneven lower edge, never full-wall scatter.
	var row:=0
	while row*spacing<float(settings.canopy_depth)+.30:
		var x: float=-width*.5+.06
		while x<width*.5:
			var depth: float=.04+row*spacing+rng.randf_range(-.035,.035)
			var edge: float=float(settings.canopy_depth)+sin(x*1.9)*.13+sin(x*4.6)*.09
			if depth<edge:
				add_blade(rng,x+rng.randf_range(-.06,.06),depth,rng.randf_range(settings.leaf_size_range[0],settings.leaf_size_range[1]),rng.randf_range(-1.2,1.2))
			x+=spacing+rng.randf_range(-.025,.025)
		row+=1
	# Art-directed connected cascades, all rooted in the canopy. Their width,
	# leaf count and blade size taper downwards along the four reference guides.
	for guide: Dictionary in settings.cascades:
		var depth:=.55
		while depth<float(guide.depth):
			var t: float=(depth-.55)/(float(guide.depth)-.55)
			var half_width: float=float(guide.half_width)*pow(1.-t,.8)+.025
			var center: float=float(guide.center_x)+sin(depth*1.6+float(guide.phase))*.11*t
			var across:=maxi(1,ceili(half_width*2./spacing))
			for i in across:
				if i!=across/2 and rng.randf()<t*.18:continue
				var side: float=(float(i)+.5)/across*2.-1.
				var x: float=center+side*half_width+rng.randf_range(-.035,.035)
				var size: float=rng.randf_range(settings.leaf_size_range[0],settings.leaf_size_range[1])*(1.-t*.24)
				add_blade(rng,x,depth+rng.randf_range(-.025,.025),size,side*.45+rng.randf_range(-.4,.4))
			depth+=spacing*.90
	var quad:=QuadMesh.new();quad.size=Vector2(2.4,2.4);quad.subdivide_width=1
	var multimesh:=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_custom_data=true;multimesh.mesh=quad;multimesh.instance_count=leaves.size()
	for i in leaves.size():
		var leaf: Dictionary=leaves[i]
		var basis:=Basis(Vector3.BACK,float(leaf.angle)).scaled(Vector3.ONE*float(leaf.size))
		var layer: int=posmod(i*7+int(leaf.x*13.),3)
		var atlas: int=posmod(i*13+int(leaf.x*103.)+int(leaf.depth*59.),4)
		var virtual_depth: float=.15+float(layer)*.425
		multimesh.set_instance_transform(i,Transform3D(basis,Vector3(leaf.x,float(settings.wall_height)-float(leaf.depth),.018+float(layer)*float(settings.layer_separation_m)+i*.000006)))
		multimesh.set_instance_custom_data(i,Color(atlas,virtual_depth,leaf.tone,1))
	foliage=MultiMeshInstance3D.new();foliage.multimesh=multimesh
	paint=ShaderMaterial.new();paint.shader=LEAF_TEXTURED;paint.set_shader_parameter("leaf_atlas",LEAF_ATLAS)
	paint.set_shader_parameter("parallax_depth_m",float(settings.parallax_depth_m));paint.set_shader_parameter("fold_height",float(settings.fold_height))
	foliage.material_override=paint;foliage.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;add_child(foliage)

func build_ui() -> void:
	ui=CanvasLayer.new();add_child(ui)
	reference=TextureRect.new();reference.texture=ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(ART)))
	reference.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);reference.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;reference.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;reference.mouse_filter=Control.MOUSE_FILTER_IGNORE;reference.hide();ui.add_child(reference)
	var panel:=PanelContainer.new();ui.add_child(panel);panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left=16;panel.offset_top=-54;panel.offset_right=1300;panel.offset_bottom=-12
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);panel.add_child(row)
	reference_button=Button.new();reference_button.text="查看 AI 效果图（当前：实机）";reference_button.pressed.connect(func():set_reference_visible(not reference.visible));row.add_child(reference_button)
	var button:=Button.new();button.text="正视";button.pressed.connect(func():set_reference_visible(false);set_view(0));row.add_child(button)
	button=Button.new();button.text="斜看";button.pressed.connect(func():set_reference_visible(false);set_view(1));row.add_child(button)
	button=Button.new();button.text="近看叶片";button.pressed.connect(func():set_reference_visible(false);set_view(2));row.add_child(button)
	var texture_check:=CheckBox.new();texture_check.text="新贴图";texture_check.button_pressed=true;texture_check.toggled.connect(set_texture_color);row.add_child(texture_check)
	var parallax_check:=CheckBox.new();parallax_check.text="左右视差";parallax_check.button_pressed=true;parallax_check.toggled.connect(set_parallax);row.add_child(parallax_check)
	var orbit_check:=CheckBox.new();orbit_check.text="自动摆镜";orbit_check.toggled.connect(func(value):auto_orbit=value;orbit_clock=0.);row.add_child(orbit_check)
	var label:=Label.new();label.text="右键旋转 · H 隐藏界面";row.add_child(label)

func set_view(which: int) -> void:
	yaw=0. if which==0 else .42
	view_target=Vector3(-1.65,4.8,0) if which==2 else Vector3(0,3.07,0)
	camera.size=2.6 if which==2 else 7.15
	update_camera()
func set_texture_color(value: bool) -> void:paint.set_shader_parameter("texture_color_enabled",value)
func set_parallax(value: bool) -> void:paint.set_shader_parameter("parallax_enabled",value)
func set_reference_visible(value: bool) -> void:
	reference.visible=value
	reference_button.text="返回实机原型（当前：AI 效果图）" if value else "查看 AI 效果图（当前：实机）"
func update_camera() -> void:
	var center:=view_target
	camera.position=center+Basis(Vector3.UP,yaw)*Vector3(0,0,14);camera.look_at(center)
func _process(delta: float) -> void:
	if auto_orbit and not dragging and not automation_enabled:
		orbit_clock+=delta;yaw=sin(orbit_clock*.7)*.42;update_camera()
func _unhandled_input(event: InputEvent) -> void:
	if automation_enabled:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:dragging=event.pressed
	if event is InputEventMouseMotion and dragging:
		yaw=clampf(yaw-event.relative.x*.003,-.8,.8);update_camera()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_H:ui.visible=not ui.visible
		if event.physical_keycode==KEY_R:set_reference_visible(false);set_view(0)
