extends Node3D
## Independent CC0 motion review. No connection to the main character controller.

var catalog: Array = []
var visible_indices: Array[int] = []
var selected := 0
var character: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var camera: Camera3D
var chair: Node3D
var list: ItemList
var details: Label
var timeline: HSlider
var clock_label: Label
var pause_button: Button
var category: OptionButton
var search: LineEdit
var center_motion := true
var playing := true
var looping := true
var yaw := 0.22
var pitch := 0.12
var distance := 2.8
var camera_target := Vector3(0, 0.72, 0)
var dragging := false
var update_timeline := false
var initial_hips := Vector3.ZERO
var height_offset := 0.0
var compare_old_walk := false
var compare_old_loop := false

func _ready() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/motion_review/catalog.json"))
	_build_stage()
	character = load("res://scenes/characters/ganyu.tscn").instantiate()
	add_child(character)
	skeleton = character.find_child("GeneralSkeleton", true, false)
	# Baked translations already use this model's meters. AnimationPlayer would
	# otherwise multiply them by the imported humanoid motion_scale a second time.
	skeleton.motion_scale = 1.0
	var original: AnimationPlayer = character.find_child("AnimationPlayer", true, false)
	original.stop()
	skeleton.reset_bone_poses()
	_set_springs(false)
	player = AnimationPlayer.new()
	player.name = "MotionReviewPlayer"
	character.add_child(player)
	var library := AnimationLibrary.new()
	for action in catalog:
		var animation: Animation = load("res://assets/characters/motion_review/%s.tres" % action.id)
		library.add_animation(action.id, animation)
		if action.has("before_walk_fix_path"):
			library.add_animation(action.id+"_before_walk_fix", load(action.before_walk_fix_path))
		if action.has("before_loop_fix_path"):
			library.add_animation(action.id+"_before_loop_fix", load(action.before_loop_fix_path))
	player.add_animation_library("", library)
	_build_ui()
	var start_index:=0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--motion="):
			for i in catalog.size():
				if catalog[i].id==argument.trim_prefix("--motion="): start_index=i
	_select(start_index)
	if start_index==0: list.get_v_scroll_bar().set_deferred("value",0.0)

func _build_stage() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("202b36")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("dbe6ff")
	settings.ambient_light_energy = 0.65
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -28, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	_box(self, Vector3(8, 0.08, 8), Vector3(0, -0.04, 0), Color("586573"))
	for i in range(-8, 9):
		_box(self, Vector3(0.006,0.003,8), Vector3(i*0.5,0.002,0), Color("6b7884"))
		_box(self, Vector3(8,0.003,0.006), Vector3(0,0.002,i*0.5), Color("6b7884"))
	chair = Node3D.new()
	chair.name = "AdjustableChair"
	add_child(chair)
	_box(chair, Vector3(0.42,0.04,0.42), Vector3(0,0.38,0.10), Color("bd935e"))
	_box(chair, Vector3(0.42,0.40,0.035), Vector3(0,0.60,0.30), Color("bd935e"))
	for x in [-0.17,0.17]:
		for z in [-0.07,0.27]: _box(chair, Vector3(0.025,0.36,0.025),Vector3(x,0.18,z),Color("303d4b"))
	chair.visible = false
	camera = Camera3D.new()
	camera.fov = 38
	add_child(camera)
	camera.current = true
	_update_camera()

func _box(parent: Node, size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	parent.add_child(mesh)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 14
	panel.offset_right = 360
	panel.offset_top = 14
	panel.offset_bottom = -14
	layer.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	margin.add_child(column)
	var title := Label.new()
	title.text = "人物动作测试 · 42 段"
	title.add_theme_font_size_override("font_size",23)
	column.add_child(title)
	search = LineEdit.new()
	search.placeholder_text = "搜索编号、中文或动作名"
	search.text_changed.connect(func(_value): _filter())
	column.add_child(search)
	category = OptionButton.new()
	category.add_item("全部分类")
	for action in catalog:
		var exists := false
		for i in category.item_count:
			if category.get_item_text(i) == action.category: exists = true
		if not exists: category.add_item(action.category)
	category.item_selected.connect(func(_value): _filter())
	column.add_child(category)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(func(i): _select(visible_indices[i]))
	column.add_child(list)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.y = 78
	column.add_child(details)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	_button(buttons,"上一段",func(): _step(-1))
	_button(buttons,"下一段",func(): _step(1))
	_button(buttons,"重播",func(): _restart())
	pause_button = _button(buttons,"暂停",func(): _pause())
	timeline = HSlider.new()
	timeline.step = 0.001
	timeline.value_changed.connect(func(value):
		if not update_timeline:
			player.seek(value,true)
			_center_character())
	column.add_child(timeline)
	clock_label = Label.new()
	column.add_child(clock_label)
	var speed_label := Label.new()
	speed_label.text = "播放速度：1.00×"
	column.add_child(speed_label)
	var speed := HSlider.new()
	speed.min_value = 0.1
	speed.max_value = 2.0
	speed.step = 0.05
	speed.value = 1.0
	speed.value_changed.connect(func(value):
		player.speed_scale = value
		speed_label.text = "播放速度：%.2f×" % value)
	column.add_child(speed)
	_check(column,"循环播放（过渡片段接缝可能不连续）",true,func(value):
		looping=value
		_apply_loop())
	_check(column,"原地观察（保留上下运动）",true,func(value):
		center_motion=value
		_center_character())
	var comparison := OptionButton.new()
	comparison.add_item("步行对比：当前修正版")
	comparison.add_item("步行对比：横移修正前")
	comparison.add_item("步行对比：循环修正前")
	comparison.item_selected.connect(func(value):
		compare_old_walk=value==1
		compare_old_loop=value==2
		_select(selected))
	column.add_child(comparison)
	var height_row := HBoxContainer.new()
	column.add_child(height_row)
	var height_label := Label.new()
	height_label.text="角色高度偏移"
	height_row.add_child(height_label)
	var height := SpinBox.new()
	height.min_value=-0.5
	height.max_value=0.5
	height.step=0.01
	height.value=0.0
	height.value_changed.connect(func(value): height_offset=value)
	height_row.add_child(height)
	_check(column,"显示参考椅（需按动作调整）",false,func(value): chair.visible=value)
	var chair_row := HBoxContainer.new()
	column.add_child(chair_row)
	var chair_label := Label.new()
	chair_label.text = "椅位移 Y / Z"
	chair_row.add_child(chair_label)
	for axis in ["y","z"]:
		var adjust := SpinBox.new()
		adjust.min_value=-1
		adjust.max_value=1
		adjust.step=0.01
		adjust.value_changed.connect(func(value):
			if axis=="y": chair.position.y=value
			else: chair.position.z=value)
		chair_row.add_child(adjust)
	_check(column,"头发／服饰物理（切换时可能抖动）",false,func(value): _set_springs(value))
	_button(column,"恢复正面视角",func():
		yaw=0.22
		pitch=0.12
		distance=2.8
		_update_camera())
	var help := Label.new()
	help.text = "← → 切换 · 空格暂停 · R 重播\n右键拖动旋转 · 滚轮缩放\n仅动作评审；没有 IK / 地面碰撞修正。"
	column.add_child(help)
	_filter()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text=text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _check(parent: Node, text: String, value: bool, action: Callable) -> void:
	var check := CheckBox.new()
	check.text=text
	check.button_pressed=value
	check.toggled.connect(action)
	parent.add_child(check)

func _filter() -> void:
	visible_indices.clear()
	list.clear()
	var term := search.text.to_lower()
	for i in catalog.size():
		var a: Dictionary = catalog[i]
		if category.selected>0 and category.get_item_text(category.selected)!=a.category: continue
		if not term.is_empty() and not (a.id+" "+a.label_zh+" "+a.clip_name).to_lower().contains(term): continue
		visible_indices.append(i)
		list.add_item("%s  %s" % [a.id,a.label_zh])
		if i==selected: list.select(list.item_count-1)

func _select(index: int) -> void:
	selected=index
	var action: Dictionary=catalog[index]
	player.stop()
	skeleton.reset_bone_poses()
	character.position=Vector3.ZERO
	_apply_loop()
	player.play(_animation_key())
	player.advance(0)
	initial_hips=skeleton.get_bone_global_pose(skeleton.find_bone("Hips")).origin
	playing=true
	pause_button.text="暂停"
	timeline.max_value=action.duration
	details.text="%s · %s\n%s · %.2f 秒\n%s" % [action.id,action.label_zh,action.file_id,action.duration,action.clip_name if not action.clip_name.is_empty() else "VRMA 单动作"]
	if action.has("before_walk_fix_path"):
		details.text += " · 横移修正前" if compare_old_walk else (" · 循环修正前" if compare_old_loop else " · 循环修正后")
	if visible_indices.has(index):
		list.select(visible_indices.find(index))
		list.ensure_current_is_visible()
	_center_character()

func _apply_loop() -> void:
	var animation := player.get_animation(_animation_key())
	animation.loop_mode=Animation.LOOP_LINEAR if looping else Animation.LOOP_NONE

func _animation_key() -> String:
	var action: Dictionary=catalog[selected]
	if compare_old_loop and action.has("before_loop_fix_path"): return action.id+"_before_loop_fix"
	return action.id+"_before_walk_fix" if compare_old_walk and action.has("before_walk_fix_path") else action.id

func _step(direction: int) -> void:
	if visible_indices.is_empty(): return
	var index := visible_indices.find(selected)
	_select(visible_indices[posmod(index+direction,visible_indices.size())])

func _restart() -> void:
	_select(selected)

func _pause() -> void:
	playing=not playing
	if playing: player.play()
	else: player.pause()
	pause_button.text="暂停" if playing else "继续"

func _set_springs(enabled: bool) -> void:
	var controller=character.find_child("VRMSpringBoneController",true,false)
	if controller: controller.process_mode=Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED

func _center_character() -> void:
	var hips=skeleton.get_bone_global_pose(skeleton.find_bone("Hips")).origin
	var action: Dictionary=catalog[selected]
	if center_motion and not compare_old_walk and action.has("in_place_anchor_xz"):
		# These source walks already run in place. Keep their lateral pelvis
		# translation, which balances torso counter-rotation during each step.
		var anchor: Array=action.in_place_anchor_xz
		character.position=Vector3(-anchor[0],height_offset,-anchor[1])
	else:
		character.position=Vector3(-hips.x,height_offset,-hips.z) if center_motion else Vector3(-initial_hips.x,height_offset,-initial_hips.z)

func _process(_delta: float) -> void:
	if not is_instance_valid(player): return
	_center_character()
	update_timeline=true
	timeline.value=player.current_animation_position
	update_timeline=false
	clock_label.text="%.2f / %.2f 秒" % [player.current_animation_position,timeline.max_value]

func _update_camera() -> void:
	camera.position=camera_target+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
	camera.look_at(camera_target)
	# Shift the model into the free area to the right of the control panel.
	camera.frustum_offset=Vector2.ZERO
	camera.h_offset=-0.25

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit: return
		match event.keycode:
			KEY_LEFT: _step(-1)
			KEY_RIGHT: _step(1)
			KEY_SPACE: _pause()
			KEY_R: _restart()
			_: return
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT: dragging=event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			distance=clampf(distance+(0.2 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -0.2),1.1,7)
			_update_camera()
	if event is InputEventMouseMotion and dragging:
		yaw-=event.relative.x*0.008
		pitch=clampf(pitch+event.relative.y*0.006,-0.6,1.1)
		_update_camera()
