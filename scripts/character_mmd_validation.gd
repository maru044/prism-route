extends Node3D
## Independent F6 scene for the full PMX mesh and its matching baked skeleton.
const MODEL := "res://assets/characters/mmd_validation/keqing_loop03.glb"
const FPS := 30.0
var duration := 16.0
var character: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var clip_name: StringName
var camera: Camera3D
var timeline := HSlider.new()
var status := Label.new()
var play_button := Button.new()
var playing := true
var time := 0.0
var yaw := 0.35
var pitch := 0.15
var distance := 3.0
var camera_target := Vector3.ZERO
var dragging := false
var overlay := MeshInstance3D.new()
var overlay_lines := ImmediateMesh.new()
var overlay_material := StandardMaterial3D.new()
var body_bones := ["下半身", "上半身", "上半身2", "首", "頭", "肩.L", "腕.L", "ひじ.L", "手首.L", "肩.R", "腕.R", "ひじ.R", "手首.R", "足.L", "ひざ.L", "足首.L", "つま先.L", "足.R", "ひざ.R", "足首.R", "つま先.R"]
var title_text := "刻晴 · MMD 动作烘焙验证"
var description_text := "Loop 03 · 30 FPS · 16 秒\n身体骨骼动画；表情、头发与服饰物理未启用"

func _ready() -> void:
	character = load(MODEL).instantiate()
	character.name = "KeqingCharacter"
	add_child(character)
	skeleton = character.find_children("*", "Skeleton3D", true, false)[0]
	player = character.find_children("*", "AnimationPlayer", true, false)[0]
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for name in player.get_animation_list():
		if name != "RESET": clip_name = name
	player.get_animation(clip_name).loop_mode = Animation.LOOP_NONE
	player.play(clip_name)
	var bounds := AABB()
	var first := true
	for frame in [0, 120, 240, 360, 480]:
		seek_frame(frame)
		for name in body_bones:
			var p := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(name)).origin
			if first:
				bounds = AABB(p, Vector3.ZERO)
				first = false
			else: bounds = bounds.expand(p)
	camera_target = bounds.get_center() + Vector3(0, 0.05, 0)
	distance = maxf(2.5, bounds.size.length() * 1.9)
	_build_stage(bounds)
	_build_ui()
	overlay.mesh = overlay_lines
	overlay.visible = false
	overlay_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay_material.albedo_color = Color("53ddf5")
	overlay_material.no_depth_test = true
	add_child(overlay)
	seek_frame(0)
	if "--capture-mmd" in OS.get_cmdline_user_args():
		playing = false
		_capture_sequence.call_deferred()

func _build_stage(bounds: AABB) -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("192431")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dce6f5")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 145, 0)
	fill.light_energy = 0.4
	add_child(fill)
	var floor_node := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(8, 8)
	floor_node.mesh = floor_mesh
	floor_node.position = Vector3(camera_target.x, minf(0, bounds.position.y - 0.02), camera_target.z)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("384650")
	material.roughness = 1.0
	floor_node.material_override = material
	add_child(floor_node)
	camera = Camera3D.new()
	camera.fov = 38
	camera.near = 0.02
	camera.current = true
	add_child(camera)
	_update_camera()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := VBoxContainer.new()
	panel.position = Vector2(24, 20)
	panel.custom_minimum_size.x = 580
	layer.add_child(panel)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 24)
	panel.add_child(title)
	var note := Label.new()
	note.text = description_text
	panel.add_child(note)
	panel.add_child(status)
	timeline.min_value = 0.0
	timeline.max_value = duration
	timeline.step = 1.0 / FPS
	panel.add_child(timeline)
	timeline.drag_started.connect(func(): playing = false; _refresh_ui())
	timeline.value_changed.connect(func(value):
		playing = false
		seek_frame(roundi(value * FPS)))
	var row := HBoxContainer.new()
	panel.add_child(row)
	play_button.text = "暂停"
	row.add_child(play_button)
	play_button.pressed.connect(func():
		if time >= duration: seek_frame(0)
		playing = not playing
		_refresh_ui())
	for view in [{"label": "正面", "yaw": 0.0}, {"label": "侧面", "yaw": PI / 2}, {"label": "背面", "yaw": PI}]:
		var button := Button.new()
		button.text = view.label
		row.add_child(button)
		button.pressed.connect(func(): yaw = view.yaw; _update_camera())
	var toggle := CheckButton.new()
	toggle.text = "显示骨架"
	row.add_child(toggle)
	toggle.toggled.connect(func(value): overlay.visible = value)
	var help := Label.new()
	help.text = "右键拖动旋转视角 · 滚轮缩放 · 空格播放/暂停"
	panel.add_child(help)

func seek_frame(frame: int) -> void:
	time = clampf(float(frame) / FPS, 0.0, duration)
	_seek_animation(time)
	timeline.set_value_no_signal(time)
	_refresh_ui()

func _refresh_ui() -> void:
	status.text = "帧 %03d / %d  |  %.2f s" % [roundi(time * FPS), roundi(duration * FPS), time]
	play_button.text = "暂停" if playing else "播放"

func _process(delta: float) -> void:
	if playing:
		_advance_animation(delta)
		timeline.set_value_no_signal(time)
		if time >= duration: playing = false
		_refresh_ui()
	if overlay.visible:
		skeleton.force_update_all_bone_transforms()
		overlay_lines.clear_surfaces()
		overlay_lines.surface_begin(Mesh.PRIMITIVE_LINES, overlay_material)
		for name in body_bones:
			var index := skeleton.find_bone(name)
			var parent := skeleton.get_bone_parent(index)
			if parent < 0: continue
			overlay_lines.surface_add_vertex(skeleton.global_transform * skeleton.get_bone_global_pose(parent).origin)
			overlay_lines.surface_add_vertex(skeleton.global_transform * skeleton.get_bone_global_pose(index).origin)
		overlay_lines.surface_end()

func _seek_animation(value: float) -> void:
	player.seek(value, true)
	skeleton.force_update_all_bone_transforms()

func _advance_animation(delta: float) -> void:
	time = minf(time + delta, duration)
	player.seek(time, true)

func _update_camera() -> void:
	camera.position = camera_target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(camera_target)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: dragging = event.pressed
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			distance = clampf(distance * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 0.8, 8.0)
			_update_camera()
	elif event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.008
		pitch = clampf(pitch + event.relative.y * 0.008, -0.7, 1.1)
		_update_camera()
	elif event.is_action_pressed("ui_accept"):
		playing = not playing
		_refresh_ui()

func _capture_sequence() -> void:
	var directory := "res://.godot/mmd_character_validation"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): directory = argument.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for frame in [0, 60, 240, 480]:
		seek_frame(frame)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory + "/keqing_frame_%03d.png" % frame)
	yaw = PI / 2
	_update_camera()
	seek_frame(60)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory + "/keqing_side_060.png")
	get_tree().quit()
