extends Node
## Isolated grove A/B controls. No instance buffers or production grass are edited.

enum Mode { BREEZE, STRONG, AUTO }
enum Motion { CURRENT = 0, BODY_TIP = 2 }
const SETTINGS := preload("res://scripts/grass_wind_settings.gd")
const TRANSITION_SECONDS := SETTINGS.TRANSITION_SECONDS
const CYCLE_SECONDS := SETTINGS.CYCLE_SECONDS
var material: ShaderMaterial
var mode := Mode.AUTO
var motion := Motion.BODY_TIP
var elapsed := 0.0
var blend := 0.0
var running := true
var paused := false
var playback_speed := 1.0
var auto_epoch := 0.0
var ui_clock := 0.0
var menu: OptionButton
var motion_menu: OptionButton
var status: Label
var panel: PanelContainer
var controls: Dictionary = {}
var parameters := SETTINGS.DEFAULT_PARAMETERS.duplicate()

func initialize(value: ShaderMaterial) -> void:
	material = value
	var layer := CanvasLayer.new()
	layer.name = "GrassWindControls"
	add_child(layer)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -400
	panel.offset_top = 20
	panel.offset_right = -20
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.10, 0.12, 0.78)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "草风对照 · 无空间传播"
	box.add_child(title)
	menu = OptionButton.new()
	menu.name = "WindMode"
	for text: String in ["微风", "大风", "自动 · 微风 / 大风"]:
		menu.add_item(text)
	menu.select(mode)
	menu.item_selected.connect(set_mode)
	box.add_child(menu)
	motion_menu = OptionButton.new()
	motion_menu.name = "MotionModel"
	motion_menu.add_item("基线 · 同步正弦", Motion.CURRENT)
	motion_menu.add_item("B · 受压草身 + 草尖", Motion.BODY_TIP)
	motion_menu.select(motion_menu.get_item_index(motion))
	motion_menu.item_selected.connect(func(index: int): set_motion(motion_menu.get_item_id(index)))
	box.add_child(motion_menu)
	var playback := HBoxContainer.new()
	box.add_child(playback)
	var freeze := CheckButton.new()
	freeze.text = "冻结草风"
	freeze.toggled.connect(func(on: bool): paused = on)
	playback.add_child(freeze)
	var speed := OptionButton.new()
	speed.add_item("正常速度")
	speed.add_item("0.25 倍慢放")
	speed.item_selected.connect(func(index: int): playback_speed = 1.0 if index == 0 else 0.25)
	playback.add_child(speed)
	var settings := CheckButton.new()
	settings.text = "参数 / 画质诊断"
	box.add_child(settings)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(350, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.visible = false
	settings.toggled.connect(func(on: bool):
		scroll.visible = on
		panel.call_deferred("reset_size"))
	box.add_child(scroll)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(details)
	var grid := GridContainer.new()
	grid.columns = 2
	details.add_child(grid)
	add_parameter(grid, "旧基线频率 · Hz", "frequency", 1.0, 2.5, 0.1)
	add_parameter(grid, "回弹间隔 · 秒", "event_interval", 2.5, 6.0, 0.1)
	add_parameter(grid, "回弹最小角 · 度", "min_angle", 20.0, 65.0, 1.0)
	add_parameter(grid, "持续弯折角 · 度", "max_angle", 65.0, 95.0, 1.0)
	add_parameter(grid, "加压占比", "press", 0.05, 0.6, 0.01)
	add_parameter(grid, "承压占比", "hold", 0.01, 0.4, 0.01)
	add_parameter(grid, "释放占比", "release", 0.05, 0.7, 0.01)
	add_parameter(grid, "回弹占比", "rebound", 0.05, 0.5, 0.01)
	add_parameter(grid, "B 回弹响应 · Hz", "body_hz", 0.7, 2.5, 0.05)
	add_parameter(grid, "B 草尖 · Hz", "tip_hz", 1.8, 3.0, 0.1)
	add_parameter(grid, "B 草尖幅度 · 度", "tip_angle", 0.0, 6.0, 0.5)
	add_parameter(grid, "B 梢端后随 · 秒", "tip_lag", 0.0, 0.1, 0.005)
	add_toggle(details, "B 少量草尖幅度差异（无错峰）", "gust_tip_variation")
	add_toggle(details, "固定草法线", "gust_fixed_normal")
	add_toggle(details, "关闭风的明暗色带", "gust_freeze_tone")
	add_toggle(details, "仅一张草卡", "gust_single_card")
	var debug := OptionButton.new()
	for text: String in ["正常材质", "纯白 · 保留贴图裁剪", "纯白 · 不透明草卡"]:
		debug.add_item(text)
	debug.item_selected.connect(func(index: int): material.set_shader_parameter("gust_debug_view", index))
	details.add_child(debug)
	var reset := Button.new()
	reset.text = "恢复运动默认参数"
	reset.pressed.connect(reset_parameters)
	details.add_child(reset)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 13)
	box.add_child(status)
	apply_parameters()
	advance(0.0)

func add_parameter(parent: Control, text: String, key: String, low: float, high: float, step: float) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	parent.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.value = parameters[key]
	spin.custom_minimum_size.x = 110
	spin.value_changed.connect(func(value: float):
		parameters[key] = value
		apply_parameters())
	parent.add_child(spin)
	controls[key] = spin

func add_toggle(parent: Control, text: String, parameter: String) -> void:
	var button := CheckButton.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 13)
	button.toggled.connect(func(on: bool):
		material.set_shader_parameter(parameter, (1.0 if on else 0.0) if parameter == "gust_tip_variation" else on))
	parent.add_child(button)

func set_mode(value: int) -> void:
	mode = clampi(value, Mode.BREEZE, Mode.AUTO)
	menu.select(mode)
	if mode == Mode.AUTO:
		auto_epoch = elapsed

func set_motion(value: int) -> void:
	motion = Motion.CURRENT if value == Motion.CURRENT else Motion.BODY_TIP
	motion_menu.select(motion_menu.get_item_index(motion))
	material.set_shader_parameter("gust_motion", motion)
	# Clock is continuous across A/B switches; freeze to compare one instant.
	apply_parameters()

func reset_parameters() -> void:
	parameters = SETTINGS.DEFAULT_PARAMETERS.duplicate()
	for key: String in controls:
		controls[key].set_value_no_signal(parameters[key])
	apply_parameters()

func apply_parameters() -> void:
	SETTINGS.apply(material, parameters, motion)
	for key: String in controls:
		var is_tip: bool = key in ["body_hz", "tip_hz", "tip_angle", "tip_lag"]
		controls[key].editable = motion == Motion.BODY_TIP if is_tip else motion != Motion.BODY_TIP if key == "frequency" else motion != Motion.CURRENT

func _process(delta: float) -> void:
	if running:
		advance(delta)

func advance(delta: float) -> void:
	var dt := 0.0 if paused else delta * playback_speed
	elapsed += dt
	var phase := fposmod(elapsed - auto_epoch, CYCLE_SECONDS)
	var strong := mode == Mode.STRONG or (mode == Mode.AUTO and phase >= 8.0 and phase < 19.0)
	blend = move_toward(blend, 1.0 if strong else 0.0, dt / TRANSITION_SECONDS)
	material.set_shader_parameter("gust_mix", blend)
	material.set_shader_parameter("gust_time", elapsed)
	ui_clock += delta
	if ui_clock >= 0.1 or delta == 0.0:
		ui_clock = 0.0
		var rhythm := "基线 %.2f Hz" % parameters.frequency if motion == Motion.CURRENT else "压弯为主 · 回弹间隔 %.1fs" % parameters.event_interval
		status.text = "%s · %s · %d%%" % ["已冻结" if paused else "微风" if not strong and blend == 0.0 else "大风对照", rhythm, roundi(blend * 100)]
