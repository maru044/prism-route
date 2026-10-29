extends Node3D
## Independent F6 scene. Source models, formal MToon and main entry are untouched.
const EFFECT = preload("res://scripts/characters/hologram_effect.gd")
const MODELS := [
	{"id":"ganyu","label":"甘雨","path":"res://scenes/characters/ganyu.tscn","motions":"res://assets/characters/motion_review"},
	{"id":"keqing","label":"刻晴","path":"res://assets/characters/import_tests_local/keqing/keqing_fixed.vrm","motions":"res://assets/characters/import_tests_local/keqing/motions"},
	{"id":"huahuo","label":"花火","path":"res://assets/characters/import_tests_local/huahuo/huahuo_fixed.vrm","motions":"res://assets/characters/import_tests_local/huahuo/motions"},
	{"id":"hutao","label":"胡桃","path":"res://assets/characters/import_tests_local/hutao/hutao_fixed.vrm","motions":"res://assets/characters/import_tests_local/hutao/motions"}]
var character: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var effect
var camera: Camera3D
var environment: Environment
var sun: DirectionalLight3D
var emitter_light: OmniLight3D
var ui: CanvasLayer
var status: Label
var model_menu: OptionButton
var background_menu: OptionButton
var hologram_toggle: CheckBox
var pause_toggle: CheckBox
var print_progress: ProgressBar
var print_state: Label
var occluder: MeshInstance3D
var particles: Array[MeshInstance3D]=[]
var current_model := 0
var current_animation := "A01"
var ready_for_review := false
var playing := true
var hologram_enabled := true
var yaw := 0.10
var pitch := 0.08
var distance := 4.2
var target := Vector3(0,.98,0)
var dragging := false
var stage_time := 0.0

func _ready() -> void:
	get_viewport().msaa_3d=Viewport.MSAA_4X
	_build_stage();effect=EFFECT.new();effect.name="HologramEffect";add_child(effect)
	_build_ui();select_model(0);set_background(0);_update_camera()
	ready_for_review=true

func _material(color: Color,emission: float=0.0) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.94
	if emission>0:
		m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=emission
	return m

func _mesh(mesh: Mesh,p: Vector3,material: Material,parent: Node3D=self) -> MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=mesh;node.position=p;node.material_override=material;parent.add_child(node)
	return node

func _box(size: Vector3,p: Vector3,color: Color) -> MeshInstance3D:
	var m:=BoxMesh.new();m.size=size;return _mesh(m,p,_material(color))

func _build_stage() -> void:
	environment=Environment.new();environment.background_mode=Environment.BG_COLOR
	environment.tonemap_mode=Environment.TONE_MAPPER_ACES;environment.tonemap_exposure=1.
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
	environment.glow_enabled=true;environment.glow_intensity=.45;environment.glow_bloom=.03
	var world:=WorldEnvironment.new();world.environment=environment;add_child(world)
	sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-35,0);sun.shadow_enabled=true;add_child(sun)
	_box(Vector3(16,.15,14),Vector3(0,-.17,0),Color("b7b4a9"))
	# A simple neutral alcove, not a new authored megastructure asset.
	_box(Vector3(6,3.7,.18),Vector3(0,1.65,-2.8),Color("d4cec0"))
	_box(Vector3(.25,3.7,3.8),Vector3(-3,1.65,-.9),Color("dfd6c6"))
	for x: float in [-2.2,-1.1,0.,1.1,2.2]:
		_box(Vector3(.045,3.3,.025),Vector3(x,1.5,-2.69),Color("888b86"))
	for y: float in [.35,.95,1.55,2.15,2.75]:
		_box(Vector3(5.5,.02,.025),Vector3(0,y,-2.68),Color("9c9e96"))
	var base:=CylinderMesh.new();base.top_radius=.95;base.bottom_radius=1.08;base.height=.20;base.radial_segments=96
	_mesh(base,Vector3(0,0,0),_material(Color("d4d0c4")))
	var top:=CylinderMesh.new();top.top_radius=.81;top.bottom_radius=.81;top.height=.025;top.radial_segments=96
	_mesh(top,Vector3(0,.112,0),_material(Color("23414a")))
	for radius: float in [.84,.96]:
		var ring:=TorusMesh.new();ring.inner_radius=radius-.008;ring.outer_radius=radius+.008;ring.rings=64;ring.ring_segments=8
		_mesh(ring,Vector3(0,.123,0),_material(Color("39cbef"),2.8))
	emitter_light=OmniLight3D.new();emitter_light.position=Vector3(0,.45,0);emitter_light.light_color=Color("51c9ed")
	emitter_light.light_energy=.6;emitter_light.omni_range=2.0;add_child(emitter_light)
	var particle_mesh:=SphereMesh.new();particle_mesh.radius=.004;particle_mesh.height=.008;particle_mesh.radial_segments=6;particle_mesh.rings=3
	var pm:=_material(Color("45d2ff"),1.6)
	for i in 36:
		var angle:=i*2.399963
		particles.append(_mesh(particle_mesh,Vector3(cos(angle)*.57,.2+fmod(i*.137,1.8),sin(angle)*.57),pm))
	occluder=_box(Vector3(.48,1.12,.08),Vector3(-.15,.68,.6),Color("c7ad81"));occluder.visible=false
	camera=Camera3D.new();camera.fov=38;camera.near=.04;camera.far=80;camera.current=true;add_child(camera)

func select_model(index: int) -> void:
	if is_instance_valid(effect):effect.restore()
	if is_instance_valid(character):character.free()
	current_model=index
	character=load(MODELS[index].path).instantiate();character.name="ProjectedCharacter";add_child(character)
	skeleton=character.find_child("GeneralSkeleton",true,false);skeleton.motion_scale=1.
	var original: AnimationPlayer=character.find_child("AnimationPlayer",true,false)
	if original:original.stop()
	skeleton.reset_bone_poses()
	var controller=character.find_child("VRMSpringBoneController",true,false)
	if controller:controller.process_mode=Node.PROCESS_MODE_DISABLED
	_disable_preview_physics(character)
	# VRM creates its native modifier deferred, after the model's _ready().
	_disable_preview_physics.call_deferred(character)
	player=AnimationPlayer.new();player.name="HologramMotion";player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	character.add_child(player)
	var library:=AnimationLibrary.new()
	for id: String in ["A01","A25"]:
		var clip: Animation=load(MODELS[index].motions+"/"+id+".tres").duplicate(true)
		clip.loop_mode=Animation.LOOP_LINEAR;library.add_animation(id,clip)
	player.add_animation_library("",library);set_animation(current_animation)
	effect.bind(character,MODELS[index].id);effect.playing=playing;effect.set_enabled(hologram_enabled)
	if is_instance_valid(model_menu):model_menu.select(index)
	_update_status()

func _disable_preview_physics(model: Node3D) -> void:
	if not is_instance_valid(model):return
	for modifier: SkeletonModifier3D in model.find_children("*","SkeletonModifier3D",true,false):modifier.active=false

func set_animation(id: String) -> void:
	current_animation=id;player.play(id);player.seek(.6,true);_center_character()

func _center_character() -> void:
	var hips:=skeleton.get_bone_global_pose(skeleton.find_bone("Hips")).origin
	character.position=Vector3(-hips.x,.145,-hips.z)

func set_background(index: int) -> void:
	var daylight: bool=index==1
	environment.background_color=Color("9fcddd") if daylight else Color("182a35")
	environment.ambient_light_color=Color("f2eddf") if daylight else Color("7794ac")
	environment.ambient_light_energy=.65 if daylight else .19
	sun.light_energy=1.0 if daylight else .24
	sun.light_color=Color("fff2da")
	if is_instance_valid(background_menu):background_menu.select(index)

func _build_ui() -> void:
	ui=CanvasLayer.new();add_child(ui)
	var panel:=PanelContainer.new();panel.position=Vector2(18,18);panel.custom_minimum_size=Vector2(280,0);ui.add_child(panel)
	var style:=StyleBoxFlat.new();style.bg_color=Color(.035,.065,.09,.94);style.set_corner_radius_all(12)
	for side: String in ["left","right","top","bottom"]:style.set("content_margin_"+side,16.)
	panel.add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",11);panel.add_child(column)
	var title:=Label.new();title.text="全息投影 · 独立预览";title.add_theme_font_size_override("font_size",22);column.add_child(title)
	model_menu=OptionButton.new()
	for m: Dictionary in MODELS:model_menu.add_item(m.label)
	model_menu.item_selected.connect(select_model);column.add_child(model_menu)
	background_menu=OptionButton.new();background_menu.add_item("遗迹内 · 阴影环境");background_menu.add_item("白天 · 明亮环境")
	background_menu.item_selected.connect(set_background);column.add_child(background_menu)
	var action:=OptionButton.new();action.add_item("放松站立");action.add_item("招呼")
	action.item_selected.connect(func(i):set_animation("A01" if i==0 else "A25"));column.add_child(action)
	hologram_toggle=CheckBox.new();hologram_toggle.text="全息效果";hologram_toggle.button_pressed=true
	hologram_toggle.toggled.connect(func(v):hologram_enabled=v;effect.set_enabled(v));column.add_child(hologram_toggle)
	var buttons:=HBoxContainer.new();column.add_child(buttons)
	var summon:=Button.new();summon.text="打印／召唤";summon.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	summon.pressed.connect(start_printing);buttons.add_child(summon)
	var reset:=Button.new();reset.text="重置全息"
	reset.pressed.connect(reset_projection);buttons.add_child(reset)
	_slider(column,"打印时长（秒）",1.,6.,effect.print_duration,func(v):effect.print_duration=v)
	print_progress=ProgressBar.new();print_progress.custom_minimum_size.y=12;print_progress.show_percentage=false;column.add_child(print_progress)
	print_state=Label.new();column.add_child(print_state)
	_slider(column,"青蓝混合",0.,.80,effect.opacity,func(v):effect.opacity=v;effect.apply_parameters())
	_slider(column,"发光强度",0.,2.5,effect.emission_strength,func(v):effect.emission_strength=v;effect.apply_parameters())
	_slider(column,"扫描线",0.,.8,effect.scan_strength,func(v):effect.scan_strength=v;effect.apply_parameters())
	pause_toggle=CheckBox.new();pause_toggle.text="暂停动作、打印与信号"
	pause_toggle.toggled.connect(func(v):playing=not v;effect.playing=playing);column.add_child(pause_toggle)
	var block:=CheckBox.new();block.text="显示前方遮挡物"
	block.toggled.connect(func(v):occluder.visible=v);column.add_child(block)
	status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.custom_minimum_size.x=245;column.add_child(status)
	var help:=Label.new();help.text="右键拖动旋转 · 滚轮缩放\nP 重播打印 · 空格暂停 · H 隐藏界面";column.add_child(help)

func start_printing() -> void:
	hologram_toggle.button_pressed=true;pause_toggle.button_pressed=false
	hologram_enabled=true;playing=true;effect.playing=true;effect.start_printing()

func reset_projection() -> void:
	hologram_toggle.button_pressed=true;hologram_enabled=true
	effect.set_enabled(true);effect.reset_projection()

func _slider(parent: Node,label: String,minimum: float,maximum: float,value: float,callback: Callable) -> void:
	var text:=Label.new();text.text=label;parent.add_child(text)
	var slider:=HSlider.new();slider.min_value=minimum;slider.max_value=maximum;slider.step=.01;slider.value=value
	slider.value_changed.connect(callback);parent.add_child(slider)

func _update_status() -> void:
	status.text="%s · %d 个材质表面\nMToon 本体 / 全息光效\n保留面容与表面遮挡"%[MODELS[current_model].label,effect.binding_report.get("converted",0)]

func _update_camera() -> void:
	camera.position=target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.look_at(target);camera.h_offset=-.28 if ui.visible else 0.

func set_ui_visible(value: bool) -> void:ui.visible=value;_update_camera()

func _process(delta: float) -> void:
	if not is_instance_valid(player):return
	if playing:
		player.advance(delta);stage_time+=delta
		for i in particles.size():particles[i].position.y=.2+fmod(stage_time*.12+i*.137,1.8)
	_center_character()
	if is_instance_valid(print_progress):
		print_progress.value=effect.materialization_progress*100.0
		print_state.text="实体完成 · 可重播" if effect.materialization_progress>=1.0 else ("头部 → 脚部 · %d%%"%int(effect.materialization_progress*100.0) if effect.printing else "全息待机 · 点击召唤")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_H:set_ui_visible(not ui.visible)
		elif event.keycode==KEY_SPACE:pause_toggle.button_pressed=not pause_toggle.button_pressed
		elif event.keycode==KEY_P:start_printing()
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT:dragging=event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			distance=clampf(distance+(.2 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -.2),1.1,7.);_update_camera()
	if event is InputEventMouseMotion and dragging:
		yaw-=event.relative.x*.008;pitch=clampf(pitch+event.relative.y*.006,-.25,.6);_update_camera()
