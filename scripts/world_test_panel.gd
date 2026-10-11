extends CanvasLayer
## Compact world-test HUD with a modal, tabbed second-level menu.

const AA_NAMES := ["关闭", "MSAA · 清晰边缘"]
const SAMPLE_NAMES := ["2× · 轻量", "4× · 均衡", "8× · 高采样"]

var world
var menu_open := false
var preferences_path := "user://world_test_graphics.cfg"
var persist_graphics := true
var aa_mode := 1
var sample_level := 1
var show_statistics := true
var status: Label
var mode_label: Label
var controls_label: Label
var fly_button: Button
var actor_button: Button
var menu_button: Button
var menu_root: Control
var menu_panel: PanelContainer
var tabs: TabContainer
var aa_choice: OptionButton
var sample_choice: OptionButton
var aa_description: Label
var lod_switch: CheckButton
var vegetation_switch: CheckButton
var interaction_switch: CheckButton
var statistics_switch: CheckButton
var _previous_world_mode: int
var _previous_viewport := {}
var _refresh_timer := 0.0

func setup(test_world: Node3D) -> void:
	world = test_world
	process_mode = Node.PROCESS_MODE_ALWAYS
	persist_graphics = not world.automation_enabled
	var viewport := get_viewport()
	_previous_viewport = {"msaa": viewport.msaa_3d, "taa": viewport.use_taa,
		"screen": viewport.screen_space_aa, "scale_mode": viewport.scaling_3d_mode,
		"scale": viewport.scaling_3d_scale}
	aa_mode = 1
	sample_level = clampi(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 2)) - 1, 0, 2)
	if persist_graphics:
		load_graphics()
	_build()
	apply_graphics(false)
	viewport.size_changed.connect(_resize)
	_resize()
	refresh()

func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("45525e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _button(text: String, parent: Node, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 40
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _paragraph(text: String, parent: Node) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	return column

func _switch(text: String, parent: Node, callback: Callable) -> CheckButton:
	var control := CheckButton.new()
	control.text = text
	control.focus_mode = Control.FOCUS_NONE
	control.custom_minimum_size.y = 42
	control.toggled.connect(callback)
	parent.add_child(control)
	return control

func _build() -> void:
	var theme := Theme.new()
	theme.default_font_size = 18
	var bar := PanelContainer.new()
	bar.name = "CompactBar"
	bar.position = Vector2(20, 18)
	bar.theme = theme
	bar.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.12, 0.16, 0.88)))
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)
	mode_label = Label.new()
	row.add_child(mode_label)
	menu_button = _button("测试菜单  Esc", row, func(): set_menu_open(not menu_open))
	status = Label.new()
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_color_override("font_shadow_color", Color.BLACK)
	status.add_theme_constant_override("shadow_offset_x", 2)
	status.add_theme_constant_override("shadow_offset_y", 2)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status)
	menu_root = Control.new()
	menu_root.name = "TestMenu"
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.theme = theme
	add_child(menu_root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.18)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			set_menu_open(false))
	menu_root.add_child(shade)
	menu_panel = PanelContainer.new()
	menu_panel.name = "SettingsPanel"
	menu_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.10, 0.14, 0.97)))
	menu_root.add_child(menu_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	menu_panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "大地图测试菜单"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 23)
	header.add_child(title)
	_button("关闭  Esc", header, set_menu_open.bind(false))
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	var controls := _page("控制")
	_paragraph("选择控制对象与观察方式。", controls)
	actor_button = _button("C 切换为甘雨", controls, func(): world.set_character_mode(not world.character_mode))
	fly_button = _button("F 自由观景", controls, func():
		world.set_free_mode(not world.free_mode)
		set_menu_open(false))
	_button("Tab 全岛观景", controls, func():
		world.show_overview()
		set_menu_open(false))
	_button("R 回到当前定位点", controls, func():
		if world.character_mode:
			world.character.reset_to_respawn()
		else:
			world.camper.reset_to_respawn()
		set_menu_open(false))
	var places := _page("地点")
	_paragraph("跳转到测试地点；自由观景时同时切换观察镜头。", places)
	for index in world.VIEW_NAMES.size():
		_button("%d  %s" % [index + 1, world.VIEW_NAMES[index]], places, func():
			await world.select_spawn(index)
			set_menu_open(false))
	var graphics := _page("画面")
	_paragraph("抗锯齿方案", graphics)
	aa_choice = OptionButton.new()
	aa_choice.name = "AntialiasingMode"
	for text: String in AA_NAMES:
		aa_choice.add_item(text)
	aa_choice.item_selected.connect(func(index: int):
		aa_mode = index
		apply_graphics())
	graphics.add_child(aa_choice)
	_paragraph("MSAA 采样强度", graphics)
	sample_choice = OptionButton.new()
	sample_choice.name = "AntialiasingSamples"
	for text: String in SAMPLE_NAMES:
		sample_choice.add_item(text)
	sample_choice.item_selected.connect(func(index: int):
		sample_level = index
		apply_graphics())
	graphics.add_child(sample_choice)
	aa_description = _paragraph("", graphics)
	_button("恢复默认：4× MSAA", graphics, func():
		aa_mode = 1
		sample_level = 1
		apply_graphics())
	_paragraph("画面保持原生分辨率。调整立即生效，关闭菜单即可比较。", graphics)
	var plants := _page("植被")
	lod_switch = _switch("树木 LOD（L）", plants, world.set_lod_enabled)
	vegetation_switch = _switch("显示植被（V）", plants, world.set_vegetation_enabled)
	interaction_switch = _switch("角色 / 房车推开草地", plants, func(enabled: bool): world.vegetation.grass_interaction_enabled = enabled)
	statistics_switch = _switch("显示详细性能统计", plants, func(enabled: bool):
		show_statistics = enabled
		refresh())
	_paragraph("20,000 棵树，其中 2,000 棵大树。草地随当前控制对象加载。", plants)
	var help := _page("帮助")
	controls_label = _paragraph("", help)
	_paragraph("Esc：打开 / 关闭菜单\nC：房车 / 甘雨\nF：自由观景 / 返回控制\n1–4：测试地点\nTab：全岛观景\nL：树木 LOD · V：植被", help)
	_paragraph("打开菜单时暂停场景控制；关闭后恢复。画面选项会记住上次选择。", help)
	menu_root.hide()

func set_menu_open(enabled: bool) -> void:
	if menu_open == enabled:
		return
	menu_open = enabled
	menu_root.visible = enabled
	if enabled:
		_previous_world_mode = world.process_mode
		world.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		world.process_mode = _previous_world_mode
		# A mouse release can be consumed by the modal; don't retain a drag.
		world.character.dragging_camera = false
		world.camper.dragging_camera = false
	menu_button.text = "收起菜单  Esc" if enabled else "测试菜单  Esc"
	refresh()

func _input(event: InputEvent) -> void:
	if not world.test_ready:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		set_menu_open(not menu_open)
		get_viewport().set_input_as_handled()

func _resize() -> void:
	var size := get_viewport().get_visible_rect().size
	menu_panel.size = Vector2(minf(560, size.x - 40), minf(500, size.y - 100))
	menu_panel.position = Vector2(size.x - menu_panel.size.x - 20, 82)
	status.position = Vector2(22, size.y - status.get_combined_minimum_size().y - 18)

func _process(delta: float) -> void:
	if world == null or not world.test_ready:
		return
	_refresh_timer += delta
	if _refresh_timer >= 0.15:
		_refresh_timer = 0
		refresh()

func refresh() -> void:
	if world == null or status == null:
		return
	var place: String = "全岛" if world.overview_mode else world.VIEW_NAMES[world.viewpoint]
	var actor := "甘雨" if world.character_mode else "房车"
	mode_label.text = "1012 · %s · %s" % [actor, place]
	var mode: String = "自由观景" if world.free_mode else ("甘雨 · " + world.character.get_motion_label() if world.character_mode else "驾驶")
	status.text = "%s｜%.1f km/h｜FPS %d" % [mode, world.active_actor().get_speed_kph(), Engine.get_frames_per_second()]
	if show_statistics and world.test_ready:
		status.text += "｜Draws %d\n树木 %d / 大树 %d · 草地区块 %d · LOD %s" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), world.vegetation.tree_instance_count, world.vegetation.large_tree_instance_count, world.vegetation.get_active_grass_chunk_count(), "开启" if world.lod_enabled else "中距比较"]
	lod_switch.set_pressed_no_signal(world.lod_enabled)
	vegetation_switch.set_pressed_no_signal(world.vegetation_enabled)
	interaction_switch.set_pressed_no_signal(world.vegetation.grass_interaction_enabled)
	statistics_switch.set_pressed_no_signal(show_statistics)
	_resize()

func apply_graphics(save := true) -> void:
	aa_mode = _valid_index(aa_mode, AA_NAMES.size(), 1)
	sample_level = _valid_index(sample_level, SAMPLE_NAMES.size(), 1)
	var viewport := get_viewport()
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = 1.0
	viewport.use_taa = false
	viewport.msaa_3d = sample_level + 1 if aa_mode == 1 else Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	aa_choice.select(aa_mode)
	sample_choice.select(sample_level)
	sample_choice.disabled = aa_mode != 1
	aa_description.text = ["抗锯齿已关闭。", "保留角色与画面细节的清晰度；细叶移动时仍可能闪烁。"][aa_mode]
	if aa_mode == 1:
		aa_description.text += "\n采样强度越高，边缘越平滑，显卡开销越大。"
	if save and persist_graphics:
		save_graphics()

func _valid_index(value: Variant, count: int, fallback: int) -> int:
	return value if value is int and value >= 0 and value < count else fallback

func load_graphics() -> void:
	var config := ConfigFile.new()
	if config.load(preferences_path) == OK:
		var saved_mode: Variant = config.get_value("antialiasing", "mode", aa_mode)
		# Legacy mode IDs 2/3 were TAA/FXAA. Restore the original 4x MSAA
		# rather than silently re-enabling the rejected character postprocessing.
		if saved_mode is int and saved_mode in [2, 3]:
			aa_mode = 1
			sample_level = 1
			if persist_graphics:
				save_graphics()
		else:
			aa_mode = _valid_index(saved_mode, AA_NAMES.size(), aa_mode)
			sample_level = _valid_index(config.get_value("antialiasing", "samples", sample_level), SAMPLE_NAMES.size(), sample_level)

func save_graphics() -> void:
	var config := ConfigFile.new()
	config.set_value("antialiasing", "mode", aa_mode)
	config.set_value("antialiasing", "samples", sample_level)
	var error := config.save(preferences_path)
	if error != OK:
		push_warning("Could not save world-test graphics preferences: %s" % error_string(error))

func _exit_tree() -> void:
	if is_instance_valid(world) and menu_open:
		world.process_mode = _previous_world_mode
	var viewport := get_viewport()
	if viewport != null and not _previous_viewport.is_empty():
		viewport.msaa_3d = _previous_viewport.msaa
		viewport.use_taa = _previous_viewport.taa
		viewport.screen_space_aa = _previous_viewport.screen
		viewport.scaling_3d_mode = _previous_viewport.scale_mode
		viewport.scaling_3d_scale = _previous_viewport.scale
