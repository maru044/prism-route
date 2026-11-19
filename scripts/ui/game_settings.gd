extends Control

signal closed
signal quality_changed(index: int)
signal audio_changed(key: String, value: Variant)
signal monitor_changed(enabled: bool)
signal detail_changed(enabled: bool)
signal assistant_requested
signal dialogue_requested
signal save_menu_requested(kind: String)

const UI := preload("res://scenes/combat/encounter_ui_style.gd")
const CARD := preload("res://scenes/combat/encounter_card.gd")
const PALETTE := preload("res://scenes/combat/temple_paper_palette.tres")
const PREFS := preload("res://scripts/ui/game_preferences.gd")

var in_world := false
var show_save_menu := false
var allow_developer_tools := false
var game_progress: RefCounted = null
var _unlocked_panel: Control = null
var developer_options: VBoxContainer
var teleport_options: VBoxContainer
var _quality: Array[Button] = []
var _sliders: Dictionary = {}
var _audio_enabled: Button
var _show_monitor: Button
var _show_details: Button
var _status: Label
var _back: Button

var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _scroll: ScrollContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var sheet := Control.new()
	sheet.custom_minimum_size = Vector2(638, 638 if in_world else 520)
	center.add_child(sheet)
	var content := UI.column(10)
	sheet.add_child(content)
	content.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	UI.paper_backing(content, PALETTE, Vector2(30, 26))
	var title := UI.text_label("设置", 36, PALETTE.text, PALETTE)
	title.add_theme_font_override("font", UI.command_font())
	content.add_child(title)

	var tab_bar := UI.row(8)
	content.add_child(tab_bar)
	var tab_group := ButtonGroup.new()
	var tab_names := ["游戏设置", "存档/读档", "帮助"]
	for i in tab_names.size():
		var tab_button := add_button(tab_bar, tab_names[i], _select_tab.bind(i))
		tab_button.toggle_mode = true
		tab_button.button_group = tab_group
		_tab_buttons.append(tab_button)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	content.add_child(_scroll)

	var pages_box := UI.column(12)
	pages_box.size_flags_horizontal = SIZE_EXPAND_FILL
	_scroll.add_child(pages_box)

	# Page 0: 游戏设置
	var page_settings := UI.column(12)
	page_settings.size_flags_horizontal = SIZE_EXPAND_FILL
	pages_box.add_child(page_settings)
	_pages.append(page_settings)

	_section(page_settings, "画质")
	var quality_row := UI.row(8)
	page_settings.add_child(quality_row)
	var quality_group := ButtonGroup.new()
	for i in PREFS.QUALITY_NAMES.size():
		var button := add_button(quality_row, PREFS.QUALITY_NAMES[i], _set_quality.bind(i))
		button.toggle_mode = true
		button.button_group = quality_group
		_quality.append(button)

	_section(page_settings, "声音")
	_audio_enabled = add_button(page_settings, "游戏声音", Callable())
	_audio_enabled.toggle_mode = true
	_audio_enabled.toggled.connect(_set_audio.bind("enabled"))
	_add_slider(page_settings, "总音量", "master")
	_add_slider(page_settings, "环境音量", "ambience")
	_add_slider(page_settings, "动作音量", "actions")

	if in_world:
		add_to_group("world_input_blockers")
		_section(page_settings, "快捷传送")
		teleport_options = UI.column(8)
		page_settings.add_child(teleport_options)

		_section(page_settings, "性能监视")
		var monitors := UI.row(8)
		page_settings.add_child(monitors)
		_show_monitor = add_button(monitors, "显示性能面板", Callable())
		_show_monitor.toggle_mode = true
		_show_monitor.toggled.connect(_set_monitor)
		_show_details = add_button(monitors, "草加载细分计时", Callable())
		_show_details.toggle_mode = true
		_show_details.disabled = true
		_show_details.toggled.connect(func(enabled: bool): detail_changed.emit(enabled))
		if allow_developer_tools:
			add_button(page_settings, "开发工具", _toggle_developer_tools.bind(_scroll))
			developer_options = UI.column(8)
			page_settings.add_child(developer_options)
			developer_options.hide()

	# Page 1: 存档/读档
	var page_saves := UI.column(12)
	page_saves.size_flags_horizontal = SIZE_EXPAND_FILL
	pages_box.add_child(page_saves)
	_pages.append(page_saves)

	_section(page_saves, "进度管理")
	var save_hint := UI.text_label("保存或读取当前的探索进度与对话记录。", 18, PALETTE.text, PALETTE)
	page_saves.add_child(save_hint)
	var saves_list := UI.column(8)
	page_saves.add_child(saves_list)
	add_button(saves_list, "保存游戏", _open_save_menu.bind("save"))
	add_button(saves_list, "读取存档", _open_save_menu.bind("load"))
	add_button(saves_list, "返回标题页面", _open_save_menu.bind("quit"))
	add_button(saves_list, "【已解锁角色】", _open_unlocked_characters_panel)

	# Page 2: 帮助
	var page_help := UI.column(12)
	page_help.size_flags_horizontal = SIZE_EXPAND_FILL
	pages_box.add_child(page_help)
	_pages.append(page_help)

	_section(page_help, "AI 助手")
	var ai_row := UI.row(8)
	page_help.add_child(ai_row)
	if in_world:
		add_button(ai_row, "游戏助手", func():
			close()
			assistant_requested.emit()
		)
		add_button(ai_row, "自由对话", func():
			close()
			dialogue_requested.emit()
		)
	else:
		var ai_offline := UI.text_label("进入游戏世界后可在此与初音未来自由交谈或获取指引。", 18, PALETTE.text, PALETTE)
		page_help.add_child(ai_offline)

	_section(page_help, "操作指南")
	var guide_box := UI.column(6)
	page_help.add_child(guide_box)
	_add_guide_row(guide_box, "W / A / S / D", "角色移动 / 车辆驾驶")
	_add_guide_row(guide_box, "Shift", "疾跑加速 / 冲刺")
	_add_guide_row(guide_box, "Space", "跳跃 / 车辆刹车")
	_add_guide_row(guide_box, "E", "场景交互 / 对话")
	_add_guide_row(guide_box, "F", "家园开门 / 门交互")
	_add_guide_row(guide_box, "F5", "家园建造模式")
	_add_guide_row(guide_box, "C", "切换角色与车辆")
	_add_guide_row(guide_box, "ESC", "设置 / 暂停菜单")

	if not in_world and not show_save_menu:
		_tab_buttons[1].visible = false

	_status = UI.text_label("", 18, PALETTE.text, PALETTE)
	_status.custom_minimum_size.y = 22
	content.add_child(_status)

	var actions := UI.row(8)
	content.add_child(actions)
	_back = add_button(actions, "返回游戏" if in_world else "返回标题", close)

	_select_tab(0)
	hide()

func _add_guide_row(parent: VBoxContainer, key_text: String, desc_text: String) -> void:
	var row := UI.row(8)
	parent.add_child(row)
	var key_label := UI.text_label(key_text, 18, PALETTE.paper_ink, PALETTE)
	key_label.custom_minimum_size.x = 150
	row.add_child(key_label)
	var desc_label := UI.text_label(desc_text, 18, PALETTE.text, PALETTE)
	desc_label.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(desc_label)

func _select_tab(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = (i == index)
	for i in _tab_buttons.size():
		var active := (i == index)
		_tab_buttons[i].set_pressed_no_signal(active)
		_tab_buttons[i].queue_redraw()
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = 0

func _open_save_menu(kind: String) -> void:
	close()
	save_menu_requested.emit(kind)

func open(tab_index := 0) -> void:
	_select_tab(tab_index)
	_quality[PREFS.quality()].set_pressed_no_signal(true)
	var audio := PREFS.audio()
	_audio_enabled.set_pressed_no_signal(audio.enabled)
	_audio_enabled.text = "游戏声音 · 开启" if audio.enabled else "游戏声音 · 关闭"
	for key: String in _sliders:
		var row: Array = _sliders[key]
		row[0].set_value_no_signal(audio[key])
		row[1].text = "%d%%" % roundi(audio[key] * 100)
	_status.text = ""
	show()
	if is_inside_tree():
		_back.grab_focus()

func close() -> void:
	if _unlocked_panel != null and _unlocked_panel.visible:
		_unlocked_panel.close()
	if not visible:
		return
	hide()
	closed.emit()

func is_world_input_locked() -> bool:
	return visible or (_unlocked_panel != null and _unlocked_panel.visible)

func _open_unlocked_characters_panel() -> void:
	if _unlocked_panel == null:
		var panel_script := load("res://scripts/ui/unlocked_characters_panel.gd")
		_unlocked_panel = panel_script.new()
		add_child(_unlocked_panel)
		_unlocked_panel.closed.connect(func():
			_unlocked_panel.hide()
		)
	var progress: Variant = game_progress
	if progress == null:
		var tree := get_tree()
		if tree != null and tree.current_scene != null:
			if "game_progress" in tree.current_scene:
				progress = tree.current_scene.game_progress
			elif "progress" in tree.current_scene:
				progress = tree.current_scene.progress
	_unlocked_panel.open(progress)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()

func _section(parent: VBoxContainer, caption: String) -> void:
	parent.add_child(UI.text_label(caption, 22, PALETTE.text, PALETTE))

func add_button(parent: Container, caption: String, action: Callable) -> Button:
	var button := CARD.new()
	button.configure(caption, PALETTE, CARD.Kind.TAB)
	button.custom_minimum_size.y = 43
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(button)
	if action.is_valid():
		button.pressed.connect(action)
	return button

static func style_dropdown(button: Button) -> void:
	var paper := StyleBoxFlat.new()
	paper.bg_color = PALETTE.paper_wash
	paper.border_color = PALETTE.paper_ink
	paper.set_border_width_all(1)
	paper.content_margin_left = 14
	paper.content_margin_right = 12
	var hover := paper.duplicate() as StyleBoxFlat
	hover.bg_color = PALETTE.paper_active
	button.add_theme_stylebox_override("normal", paper)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state: String in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, PALETTE.text)
	button.add_theme_font_override("font", UI.interface_font())
	button.add_theme_font_size_override("font_size", 20)
	button.custom_minimum_size.y = 43
	var popup: PopupMenu = button.get_popup()
	popup.max_size.y = 440
	popup.add_theme_stylebox_override("panel", paper)
	popup.add_theme_stylebox_override("hover", hover)
	popup.add_theme_color_override("font_color", PALETTE.text)
	popup.add_theme_color_override("font_hover_color", PALETTE.text)

func _add_slider(parent: VBoxContainer, caption: String, key: String) -> void:
	var row := UI.row(15)
	parent.add_child(row)
	var label := UI.text_label(caption, 21, PALETTE.text, PALETTE)
	label.custom_minimum_size.x = 120
	row.add_child(label)
	var slider := HSlider.new()
	slider.custom_minimum_size.y = 31
	slider.size_flags_horizontal = SIZE_EXPAND_FILL
	slider.max_value = 1.0
	slider.step = .01
	var track := StyleBoxFlat.new()
	track.bg_color = PALETTE.paper_wash
	track.content_margin_top = 3.0
	track.content_margin_bottom = 3.0
	track.set_corner_radius_all(3)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = PALETTE.paper_ink
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	row.add_child(slider)
	var percent := UI.text_label("", 19, PALETTE.text, PALETTE)
	percent.custom_minimum_size.x = 67
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(percent)
	_sliders[key] = [slider, percent]
	var drag := {"active": false}
	slider.drag_started.connect(func(): drag.active = true)
	slider.value_changed.connect(func(value: float):
		percent.text = "%d%%" % roundi(value * 100)
		audio_changed.emit(key, value)
		if not drag.active:
			_show_save_status(PREFS.store("audio", key, value))
	)
	slider.drag_ended.connect(func(changed: bool):
		drag.active = false
		if changed:
			_show_save_status(PREFS.store("audio", key, slider.value))
	)

func _set_quality(index: int) -> void:
	_quality[index].set_pressed_no_signal(true)
	var result := PREFS.store("graphics", "preset", index)
	_show_save_status(result)
	quality_changed.emit(index)

func _set_audio(value: Variant, key: String) -> void:
	_audio_enabled.text = "游戏声音 · 开启" if value else "游戏声音 · 关闭"
	var result := PREFS.store("audio", key, value)
	_show_save_status(result)
	audio_changed.emit(key, value)

func _show_save_status(result: Error) -> void:
	_status.text = "设置已保存" if result == OK else "无法保存设置 · " + error_string(result)

func _set_monitor(enabled: bool) -> void:
	_show_details.disabled = not enabled
	if not enabled:
		_show_details.button_pressed = false
	monitor_changed.emit(enabled)

func _toggle_developer_tools(scroll: ScrollContainer) -> void:
	developer_options.visible = not developer_options.visible
	if developer_options.visible:
		await get_tree().process_frame
		if developer_options.visible:
			scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
