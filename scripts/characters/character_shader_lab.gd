extends Node3D
## Isolated A / B / C0 / C1 review. Formal F5 and imported assets stay untouched.
const MODES := ["standard", "mtoon", "custom", "genshin"]
const APPEARANCE = preload("res://scripts/characters/character_appearance.gd")
const CHARACTER = preload("res://scenes/characters/ganyu.tscn")
const SKY = preload("res://assets/environment/sky/fresh_cumulus_sky.tres")
var character: Node3D
var appearance
var skeleton: Skeleton3D
var player: AnimationPlayer
var camera: Camera3D
var sun: DirectionalLight3D
var local_light: OmniLight3D
var environment: Environment
var occluder: Node3D
var ui: CanvasLayer
var status: Label
var timeline: HSlider
var mode_buttons: Array[Button] = []
var pause_button: Button
var playing := false
var animation_id := "A01"
var yaw := 0.15
var pitch := 0.08
var distance := 2.8
var target := Vector3(0, 0.85, 0)
var dragging := false
var updating_timeline := false
var sun_azimuth := -28.0
var sun_elevation := -38.0
var island_lighting := false
var ready_for_review := false

func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_build_stage()
	character = CHARACTER.instantiate()
	add_child(character)
	skeleton = character.find_child("GeneralSkeleton", true, false)
	skeleton.motion_scale = 1.0
	var original: AnimationPlayer = character.find_child("AnimationPlayer", true, false)
	if original: original.stop()
	skeleton.reset_bone_poses()
	set_springs(false)
	player = AnimationPlayer.new()
	player.name = "ShaderLabMotion"
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	character.add_child(player)
	var library := AnimationLibrary.new()
	for id in ["A01", "A05", "A06", "A25"]:
		var clip: Animation = load("res://assets/characters/motion_review/%s.tres" % id).duplicate(true)
		clip.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(id, clip)
	player.add_animation_library("", library)
	appearance = APPEARANCE.new()
	add_child(appearance)
	appearance.bind(character)
	_build_ui()
	set_animation("A01", 0.6)
	set_mode("genshin")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--character-shader="): set_mode(argument.trim_prefix("--character-shader="))
	_update_camera()
	ready_for_review = true

func _build_stage() -> void:
	environment = Environment.new()
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	set_lighting(false)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 25.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.rotation_degrees = Vector3(sun_elevation, sun_azimuth, 0)
	sun.light_energy = 1.0
	add_child(sun)
	local_light = OmniLight3D.new()
	local_light.position = Vector3(-1.3, 1.5, 1.5)
	local_light.omni_range = 4.0
	local_light.light_color = Color("ffba83")
	local_light.light_energy = 1.0
	local_light.shadow_enabled = true
	local_light.visible = false
	add_child(local_light)
	_box(Vector3(200, 0.08, 200), Vector3(0, -0.045, 0), Color("687b83"))
	_box(Vector3(2.3, 0.015, 2.3), Vector3(0, 0, 0), Color("71868d"))
	# A real opaque light blocker, behind the subject from the front camera.
	occluder = _box(Vector3(3.8, 0.12, 3.8), Vector3(0.1, 2.15, 0.3), Color("a6afa8"))
	occluder.visible = false
	camera = Camera3D.new()
	camera.fov = 38.0
	camera.near = 0.03
	camera.far = 200.0
	add_child(camera)
	camera.current = true

func _box(size: Vector3, position_value: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	node.material_override = material
	node.position = position_value
	add_child(node)
	return node

func set_lighting(island: bool) -> void:
	island_lighting = island
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.82 if island else 1.0
	if island:
		var sky := Sky.new()
		sky.sky_material = SKY
		environment.sky = sky
		environment.sky_rotation.y = deg_to_rad(219.4 - 135.0)
		environment.background_mode = Environment.BG_SKY
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
		environment.ambient_light_energy = 0.38
	else:
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color("26343c")
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color("d2dce7")
		environment.ambient_light_energy = 0.32
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.ssao_enabled = island
	environment.ssao_radius = 1.1
	environment.ssao_intensity = 0.85
	if is_instance_valid(sun):
		sun.light_energy = 0.72 if island else 1.0
		sun.light_color = Color(1.0, 0.95, 0.86) if island else Color.WHITE
		sun.rotation_degrees = Vector3(-48, 45, 0) if island else Vector3(sun_elevation, sun_azimuth, 0)

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 18
	panel.offset_right = 334
	panel.offset_top = 18
	panel.offset_bottom = -18
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.085, 0.10, 0.96)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	_label(column, "人物材质实验室", 25)
	var subtitle := _label(column, "甘雨  /  原神式 C1 对照", 15)
	subtitle.modulate = Color("aec5c6")
	for i in MODES.size():
		var key: String = MODES[i]
		var button := _button(column, ["1 · A   原始 PBR", "2 · B   MToon", "3 · C0   基础 Toon", "4 · C1   原神式 NPR"][i], func(): set_mode(key))
		button.toggle_mode = true
		mode_buttons.append(button)
	_label(column, "观察", 18)
	var views := HBoxContainer.new()
	column.add_child(views)
	for i in 3:
		_button(views, ["全身", "半身", "脸部"][i], func(): set_view(i))
	var lighting := OptionButton.new()
	lighting.add_item("中性棚光")
	lighting.add_item("主地图天空与曝光")
	lighting.item_selected.connect(func(i): set_lighting(i == 1))
	column.add_child(lighting)
	var side := HBoxContainer.new()
	column.add_child(side)
	for i in 3:
		_button(side, ["正光", "侧光", "背光"][i], func():
			sun.rotation_degrees = Vector3(-30, [0.0, 90.0, 180.0][i], 0))
	_slider(column, "太阳方位", -180, 180, sun_azimuth, func(v): sun.rotation_degrees.y = v)
	_check(column, "真实屋檐遮挡", false, func(v): occluder.visible = v)
	_check(column, "暖色局部灯", false, func(v): local_light.visible = v)
	_label(column, "C1 脸部与轮廓", 18)
	_check(column, "脸部 SDF 阴影", appearance.profile.sdf_enabled, func(v): appearance.profile.sdf_enabled = v; appearance.update_parameters())
	_check(column, "彩色细描边", appearance.profile.outline_enabled, func(v): appearance.profile.outline_enabled = v; appearance.update_parameters())
	_slider(column, "轮廓宽度", 0, 2, appearance.profile.outline_pixels, func(v): appearance.profile.outline_pixels = v; appearance.update_parameters())
	_slider(column, "环境光响应", 0.15, 1.0, appearance.profile.ambient_weight, func(v): appearance.profile.ambient_weight = v; appearance.update_parameters())
	_slider(column, "C1 发丝高光", 0, 0.6, appearance.profile.c1_hair_highlight, func(v): appearance.profile.c1_hair_highlight = v; appearance.update_parameters())
	_label(column, "C0 基础参数 / 共用色阶", 18)
	var bands := OptionButton.new()
	bands.add_item("两段明暗")
	bands.add_item("三段明暗")
	bands.item_selected.connect(func(i): appearance.profile.tone_bands = i + 2; appearance.update_parameters())
	column.add_child(bands)
	_slider(column, "脸部柔化", 0, 0.95, appearance.profile.face_softness, func(v): appearance.profile.face_softness = v; appearance.update_parameters())
	_slider(column, "发丝高光", 0, 0.5, appearance.profile.hair_highlight, func(v): appearance.profile.hair_highlight = v; appearance.update_parameters())
	_slider(column, "眼部高光", 0, 0.5, appearance.profile.eye_highlight, func(v): appearance.profile.eye_highlight = v; appearance.update_parameters())
	_label(column, "动作与时间", 18)
	var motions := OptionButton.new()
	for text_value in ["A01 待机", "A05 步行", "A06 奔跑", "A25 招呼"]: motions.add_item(text_value)
	motions.item_selected.connect(func(i): set_animation(["A01", "A05", "A06", "A25"][i], 0))
	column.add_child(motions)
	pause_button = _button(column, "播放动作", func():
		playing = not playing
		pause_button.text = "暂停动作" if playing else "播放动作")
	timeline = HSlider.new()
	timeline.step = 0.001
	timeline.value_changed.connect(func(v):
		if not updating_timeline: seek(v))
	column.add_child(timeline)
	_check(column, "头发 / 服饰弹簧骨", false, set_springs)
	var samples := OptionButton.new()
	samples.add_item("4× MSAA · 当前默认")
	samples.add_item("2× MSAA · 边缘对照")
	samples.item_selected.connect(func(i): get_viewport().msaa_3d = Viewport.MSAA_4X if i == 0 else Viewport.MSAA_2X)
	column.add_child(samples)
	_button(column, "进入真实地图对照", func(): get_tree().change_scene_to_file("res://scenes/character_shader_world_lab.tscn"))
	_label(column, "右键旋转 · 滚轮缩放\n1 / 2 / 3 / 4 切换材质 · 空格播放", 14)
	status = _label(column, "", 14)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	set_mode("standard")

func _label(parent: Node, text_value: String, size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _button(parent: Node, text_value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 34
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _check(parent: Node, text_value: String, enabled: bool, action: Callable) -> void:
	var check := CheckBox.new()
	check.text = text_value
	check.button_pressed = enabled
	check.toggled.connect(action)
	parent.add_child(check)

func _slider(parent: Node, text_value: String, minimum: float, maximum: float, value: float, action: Callable) -> void:
	var label := _label(parent, "%s  %.2f" % [text_value, value], 14)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 1.0 if maximum > 10.0 else 0.01
	slider.value = value
	slider.value_changed.connect(func(v): label.text = "%s  %.2f" % [text_value, v]; action.call(v))
	parent.add_child(slider)

func set_mode(value: String) -> void:
	if not appearance.set_mode(value): return
	for i in mode_buttons.size(): mode_buttons[i].set_pressed_no_signal(MODES[i] == value)
	if status:
		status.text = "%s · %d 个部位\n%s" % [value, appearance.entries.size(), "原贴图与透明方式保留" if appearance.warnings.is_empty() else "\n".join(appearance.warnings)]

func set_view(index: int) -> void:
	distance = [2.8, 1.65, 0.85][index]
	target = Vector3(0, [0.85, 1.15, 1.36][index], 0)
	yaw = 0.15
	pitch = 0.08
	_update_camera()

func _update_camera() -> void:
	camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(target)
	camera.h_offset = -distance * 0.095 if ui == null or ui.visible else 0.0

func set_animation(id: String, time_value: float) -> void:
	animation_id = id
	player.play(id)
	player.advance(0)
	seek(time_value)
	if timeline: timeline.max_value = player.current_animation_length

func seek(value: float) -> void:
	player.seek(value, true)
	skeleton.force_update_all_bone_transforms()
	var hips := skeleton.get_bone_global_pose(skeleton.find_bone("Hips")).origin
	character.position = Vector3(-hips.x, 0, -hips.z)
	if appearance: appearance.update_head()

func set_springs(enabled: bool) -> void:
	if not is_instance_valid(character): return
	var controller = character.find_child("VRMSpringBoneController", true, false)
	if controller: controller.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	_apply_springs.call_deferred(enabled)

func _apply_springs(enabled: bool) -> void:
	var modifier = skeleton.get_node_or_null("VRMSpringBoneSimulation")
	if modifier: modifier.active = enabled

func _process(delta: float) -> void:
	if not ready_for_review: return
	if playing:
		player.advance(delta)
		seek(player.current_animation_position)
	updating_timeline = true
	timeline.value = player.current_animation_position
	updating_timeline = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			distance = clampf(distance + (0.15 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -0.15), 0.45, 6.0)
			_update_camera()
	if event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.008
		pitch = clampf(pitch + event.relative.y * 0.006, -0.6, 1.1)
		_update_camera()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: set_mode("standard")
			KEY_2: set_mode("mtoon")
			KEY_3: set_mode("custom")
			KEY_4: set_mode("genshin")
			KEY_SPACE: pause_button.pressed.emit()
