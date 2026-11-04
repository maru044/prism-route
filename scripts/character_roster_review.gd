extends Node3D
## Neutral, shared-motion review for all manifest-driven avatar batches.
const ACTOR=preload("res://scenes/characters/shared_humanoid_actor.tscn")
const CATALOG="res://assets/characters/roster/catalog.json"
@export_file("*.json") var catalog_resource: String=CATALOG
const CLIPS="res://assets/characters/roster/neutral_clips.json"
var profiles: Array=[]
var clips: Array=[]
var shared_clips: Dictionary={}
var actor
var camera: Camera3D
var model_select:=OptionButton.new()
var motion_select:=OptionButton.new()
var speed_select:=OptionButton.new()
var time_label:=Label.new()
var playback_speed:=1.
var timeline:=HSlider.new()
var status:=Label.new()
var pause:=Button.new()
var hair:=CheckButton.new()
var clothes:=CheckButton.new()
var grounding:=CheckButton.new()
var grounding_lift:=0.
var loading:=false
var playing:=true
var time:=0.
var yaw:=0.
var pitch:=.03
var distance:=3.5
var dragging:=false
var syncing:=false
var ui: CanvasLayer
var ready_for_review:=false

func _ready() -> void:
	profiles=JSON.parse_string(FileAccess.get_file_as_string(catalog_resource)).profiles
	clips=JSON.parse_string(FileAccess.get_file_as_string(CLIPS)).clips
	for clip: Dictionary in clips:shared_clips[clip.resource]=load(clip.resource)
	var environment:=WorldEnvironment.new();var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("313c4a")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("c2cde0");env.ambient_light_energy=.30
	env.tonemap_mode=Environment.TONE_MAPPER_ACES;env.tonemap_exposure=1.0;environment.environment=env;add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-25,0);sun.light_color=Color(1.0, 0.98, 0.95);sun.light_energy=.85;sun.shadow_enabled=true;sun.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL;sun.directional_shadow_max_distance=14.0;sun.shadow_bias=0.04;add_child(sun)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-15,135,0);fill.light_color=Color(0.92, 0.95, 1.0);fill.light_energy=.20;add_child(fill)
	var floor_mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(20,20);floor_mesh.mesh=plane
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color("65717c");mat.roughness=.9;floor_mesh.material_override=mat;floor_mesh.position.y=-.015;add_child(floor_mesh)
	var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;floor_mesh.add_child(body)
	var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(20,.1,20);collider.shape=box;collider.position.y=-.05;body.add_child(collider)
	camera=Camera3D.new();camera.fov=34;camera.near=.03;camera.far=100;add_child(camera);camera.current=true;_camera()
	_build_ui();await select_model(0)

func _build_ui() -> void:
	ui=CanvasLayer.new();add_child(ui)
	var panel:=PanelContainer.new();panel.position=Vector2(18,18);panel.custom_minimum_size=Vector2(270,0);ui.add_child(panel)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",10);panel.add_child(column)
	var title:=Label.new();title.text="角色入库 · 中性动作检查";column.add_child(title)
	var mmd_nav_btn := Button.new()
	mmd_nav_btn.text = "🔥 切换到 双人/色色MMD动作验证 →"
	mmd_nav_btn.custom_minimum_size.y = 34
	mmd_nav_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/character_mmd_vrm_validation.tscn")
	)
	column.add_child(mmd_nav_btn)
	for row: Dictionary in profiles:model_select.add_item(row.label)
	model_select.item_selected.connect(select_model);column.add_child(model_select)
	for row: Dictionary in clips:motion_select.add_item(row.label)
	motion_select.item_selected.connect(select_motion);column.add_child(motion_select)
	for value in [.5,.75,1.]:
		speed_select.add_item("播放速度：%.2f×"%value);speed_select.set_item_metadata(speed_select.item_count-1,value)
	speed_select.select(2);speed_select.item_selected.connect(_on_speed_selected);column.add_child(speed_select)
	column.add_child(time_label)
	pause.text="暂停";pause.pressed.connect(func():playing=not playing;pause.text="暂停" if playing else "播放");column.add_child(pause)
	timeline.min_value=0;timeline.max_value=1;timeline.step=.001;timeline.custom_minimum_size.x=250;column.add_child(timeline)
	timeline.value_changed.connect(func(value: float):
		if not syncing and is_instance_valid(actor) and not loading:time=value;actor.seek(time))
	hair.text="头发物理";hair.button_pressed=true;clothes.text="服饰物理";clothes.button_pressed=true
	for toggle in [hair,clothes]:column.add_child(toggle);toggle.toggled.connect(_physics)
	grounding.text="预览接地辅助（额外）";grounding.button_pressed=false;column.add_child(grounding)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.custom_minimum_size.x=250;column.add_child(status)
	var help:=Label.new();help.text="右键拖动旋转 · 滚轮缩放\n空格播放／暂停";column.add_child(help)

func select_model(index: int) -> void:
	if loading:return
	var saved_time:=time
	loading=true;ready_for_review=false;model_select.disabled=true;motion_select.disabled=true
	if is_instance_valid(actor):actor.free()
	actor=ACTOR.instantiate();actor.model_resource=profiles[index].model;actor.motion_resource=clips[motion_select.selected].resource
	actor.auto_play=false;actor.environment_mask=1;add_child(actor)
	while not actor.ready_for_review:await get_tree().process_frame
	time=minf(saved_time,actor.duration);actor.seek(time);timeline.max_value=actor.duration;actor.set_physics_enabled(hair.button_pressed,clothes.button_pressed)
	status.text="%s\n%d 根骨骼 · %d 条物理链"%[profiles[index].label,actor.skeleton.get_bone_count(),actor.all_springs.size()]
	loading=false;ready_for_review=true;model_select.select(index);model_select.disabled=false;motion_select.disabled=false

func select_motion(index: int) -> void:
	if loading or not is_instance_valid(actor):return
	actor.motion_resource=clips[index].resource;actor.motion=shared_clips[actor.motion_resource];actor.duration=actor.motion.length
	actor.rotation_tracks.clear();actor.translation_track=-1
	for track in actor.motion.get_track_count():
		var semantic:=String(actor.motion.track_get_path(track).get_subname(0))
		if actor.motion.track_get_type(track)==Animation.TYPE_ROTATION_3D:actor.rotation_tracks[semantic]=track
		elif actor.motion.track_get_type(track)==Animation.TYPE_POSITION_3D:actor.translation_track=track
	actor.translation_scale=actor.target_height/float(actor.motion.get_meta("reference_height"));time=0.;actor.seek(0.);timeline.max_value=actor.duration

func _physics(_value: bool) -> void:
	if is_instance_valid(actor) and not loading:actor.set_physics_enabled(hair.button_pressed,clothes.button_pressed)

func _on_speed_selected(index: int) -> void:
	playback_speed=float(speed_select.get_item_metadata(index))

func _process(delta: float) -> void:
	if loading or not is_instance_valid(actor) or not ready_for_review:return
	if playing:
		time+=delta*playback_speed
		if time>=actor.duration:time=fmod(time,actor.duration)
	# Formal locomotion is already in place. Its constant anchor was removed by
	# the world controller; cancelling every frame erases the balancing pelvis
	# sway AND the target pivot compensation. Keep a fixed presentation origin.
	# Automatic wraps only sample the next pose; seek() would reset the springs.
	actor.sample_time(time);actor.position=Vector3.ZERO
	# Preview-only root lift. Shared poses and exported VRM remain immutable;
	# this is not a foot IK solver or a gameplay contact-quality claim.
	grounding_lift=0.
	if grounding.button_pressed:
		var lowest:=INF
		for semantic in ["LeftFoot","RightFoot","LeftToes","RightToes"]:
			if not actor.semantic_bones.has(semantic):continue
			var index: int=actor.semantic_bones[semantic];var rest: Transform3D=actor.rest_world[index]
			var sole:=rest.affine_inverse()*Vector3(rest.origin.x,0.,rest.origin.z)
			var pose: Transform3D=actor.skeleton.get_bone_global_pose(index)
			lowest=minf(lowest,(actor.skeleton.global_transform*(pose*sole)).y)
		if is_finite(lowest):grounding_lift=clampf(.003-lowest,0.,.3);actor.position.y=grounding_lift
	syncing=true;timeline.value=time;syncing=false
	time_label.text="%.2f×  |  %.2f / %.2f 秒"%[playback_speed,time,actor.duration]

func _camera() -> void:
	var target:=Vector3(0,.98,0)
	camera.position=target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.look_at(target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_SPACE:pause.pressed.emit()
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT:dragging=event.pressed
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:distance=maxf(1.5,distance*.9);_camera()
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:distance=minf(7,distance*1.1);_camera()
	if event is InputEventMouseMotion and dragging:yaw-=event.relative.x*.008;pitch=clampf(pitch+event.relative.y*.005,-.5,.8);_camera()
