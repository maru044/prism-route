extends CanvasLayer

const UI := preload("res://scenes/combat/encounter_ui_style.gd")
const CARD := preload("res://scenes/combat/encounter_card.gd")
const PAPER := preload("res://scenes/combat/temple_paper_palette.tres")
const THUMBNAILS := "res://assets/construction/basic_kit/component_photos.png"
const PHOTO_SIZE := Vector2i(200, 132)
const PHOTO_COLUMNS := 4
const CATEGORIES := {
	"结构": ["floor", "wall", "roof"],
	"门窗": ["door", "arch", "window"],
	"楼梯与栏杆": ["stairs", "entry_ramp", "railing"],
	"家具": ["bed", "chair", "desk"],
}
const COMPASS_SPAN := 62.0
const MAX_STORIES := 5
const STORY_NAMES: Array[String] = ["一层", "二层", "三层", "四层", "五层"]

var home
var _screen := Control.new()
var _compass := Control.new()
var _prompt: Button
var _title: Label
var _hint: Label
var _status: Label
var _notice: Label
var _room_prompt: Label
var _catalog: GridContainer
var _category_buttons: ButtonGroup
var _story_buttons: ButtonGroup
var _current_story := 0
var _prev_story_btn: Button
var _next_story_btn: Button
var _story_label: Label
var _cards := {}
var _tools := {}
var _example: Button
var _confirm_example := false
var _thumbnail_atlas: Texture2D
var _heading := 0.0
var _markers: Array[Dictionary] = []
var _notice_left := 0.0
var panel: PanelContainer


static func photo_ids() -> Array[String]:
	var ids: Array[String] = []
	for category: Array in CATEGORIES.values():
		ids.assign(ids + category)
	return ids


func _ready() -> void:
	layer = 14
	_thumbnail_atlas = load(THUMBNAILS) as Texture2D if ResourceLoader.exists(THUMBNAILS) else null
	add_child(_screen)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(_compass)
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_compass.offset_left = -338
	_compass.offset_right = 338
	_compass.offset_top = 22
	_compass.offset_bottom = 95
	_compass.draw.connect(_draw_compass)

	_prompt = _button(_screen, "F5  建造家园", home.toggle)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -162
	_prompt.offset_right = 162
	_prompt.offset_top = -114
	_prompt.offset_bottom = -64
	_notice = UI.text_label("", 18, Color("#f5fafb"), UI.DEFAULT_PALETTE)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen.add_child(_notice)
	_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_notice.offset_left = -456
	_notice.offset_right = 456
	_notice.offset_top = -59
	_notice.offset_bottom = -28
	_room_prompt = UI.text_label("", 19, Color("#ffe899"), UI.DEFAULT_PALETTE)
	_room_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen.add_child(_room_prompt)
	_room_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_room_prompt.offset_left = -380
	_room_prompt.offset_right = 380
	_room_prompt.offset_top = -155
	_room_prompt.offset_bottom = -118
	_room_prompt.hide()
	_make_builder()
	_prompt.hide()
	_compass.hide()
	set_editing(false)


func _make_builder() -> void:
	panel = PanelContainer.new()
	panel.name = "HomeBuilder"
	_screen.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 26
	panel.offset_right = 448
	panel.offset_top = 106
	panel.offset_bottom = 800
	var padding := StyleBoxEmpty.new()
	padding.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", padding)
	UI.paper_backing(panel, PAPER)
	var column := UI.column(8)
	panel.add_child(column)
	_title = UI.text_label("", 31, PAPER.text, PAPER)
	_title.add_theme_font_override("font", UI.command_font())
	column.add_child(_title)

	# Floor pagination switcher (可翻页楼层控制器)
	var story_pager := UI.row(6)
	column.add_child(story_pager)

	_prev_story_btn = _button(story_pager, "◀ 降层", _on_prev_story_pressed)
	_prev_story_btn.custom_minimum_size = Vector2(76, 36)

	_story_label = UI.text_label("", 18, PAPER.text, PAPER)
	_story_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_story_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_story_label.custom_minimum_size.y = 36
	story_pager.add_child(_story_label)

	_next_story_btn = _button(story_pager, "升层 ▶", _on_next_story_pressed)
	_next_story_btn.custom_minimum_size = Vector2(76, 36)

	var page_tabs := UI.row(4)
	column.add_child(page_tabs)
	_story_buttons = ButtonGroup.new()
	for story in range(MAX_STORIES):
		var button := _button(page_tabs, STORY_NAMES[story], _select_story.bind(story))
		button.toggle_mode = true
		button.button_group = _story_buttons
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 30
		button.tooltip_text = "切换至%s" % STORY_NAMES[story]
		button.set_pressed_no_signal(story == 0)

	_category_buttons = ButtonGroup.new()
	var tabs := GridContainer.new()
	tabs.columns = 2
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	column.add_child(tabs)
	for category: String in CATEGORIES:
		var tab := _button(tabs, category, _show_category.bind(category))
		tab.toggle_mode = true
		tab.button_group = _category_buttons
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.set_pressed_no_signal(category == "结构")

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 236
	column.add_child(scroll)
	_catalog = GridContainer.new()
	_catalog.columns = 2
	_catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog.add_theme_constant_override("h_separation", 8)
	_catalog.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_catalog)
	_show_category("结构")

	var tools := GridContainer.new()
	tools.columns = 2
	tools.add_theme_constant_override("h_separation", 6)
	tools.add_theme_constant_override("v_separation", 5)
	column.add_child(tools)
	_tools.place = _button(tools, "放置", home.set_erase.bind(false))
	_tools.erase = _button(tools, "拆除", home.set_erase.bind(true))
	var modes := ButtonGroup.new()
	for button: Button in _tools.values():
		button.toggle_mode = true
		button.button_group = modes
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tools.rotate = _button(tools, "旋转  R", home.rotate_piece)
	_tools.rotate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tools.exit = _button(tools, "退出  F5", home.toggle)
	_tools.undo = _button(tools, "撤销", home.change_history.bind(false))
	_tools.redo = _button(tools, "重做", home.change_history.bind(true))
	_example = _button(column, "放置示例屋", _offer_example)
	_status = UI.text_label("", 17, PAPER.accent, PAPER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	_hint = UI.text_label("", 17, PAPER.text, PAPER)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.y = 47
	column.add_child(_hint)


func _button(parent: Control, caption: String, action: Callable) -> Button:
	var button := CARD.new()
	button.configure(caption, PAPER, CARD.Kind.CONTINUE)
	button.custom_minimum_size.y = 37
	parent.add_child(button)
	button.pressed.connect(action)
	return button


func _show_category(category: String) -> void:
	for node: Node in _catalog.get_children():
		_catalog.remove_child(node)
		node.queue_free()
	_cards.clear()
	var group := ButtonGroup.new()
	for id: String in CATEGORIES[category]:
		var card := _button(_catalog, "", home.select_piece.bind(id))
		card.toggle_mode = true
		card.button_group = group
		card.custom_minimum_size.y = 134
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var picture := TextureRect.new()
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if _thumbnail_atlas != null:
			var index := photo_ids().find(id)
			var tile := AtlasTexture.new()
			tile.atlas = _thumbnail_atlas
			tile.region = Rect2(Vector2i(index % PHOTO_COLUMNS, floori(float(index) / PHOTO_COLUMNS)) * PHOTO_SIZE, PHOTO_SIZE)
			tile.filter_clip = true
			picture.texture = tile
		card.add_child(picture)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.offset_left = 8
		picture.offset_right = -8
		picture.offset_top = 7
		picture.offset_bottom = -31
		var caption := UI.text_label(home.kit.catalog.definitions[id].label, 17, PAPER.text, PAPER)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.tooltip_text = caption.text
		card.add_child(caption)
		caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		caption.offset_top = -31
		caption.offset_bottom = -3
		_cards[id] = card
	set_selection(home.selected_definition, home.erase_mode)


func _offer_example() -> void:
	if not _confirm_example:
		_confirm_example = true
		_example.text = "确认放置示例屋"
		return
	home.place_lowland_example()


func _select_story(story: int) -> void:
	if home != null and home.has_method("select_story"):
		home.select_story(story)
	update_story(story)


func _on_prev_story_pressed() -> void:
	if _current_story > 0:
		_select_story(_current_story - 1)


func _on_next_story_pressed() -> void:
	if _current_story < MAX_STORIES - 1:
		_select_story(_current_story + 1)


func update_story(story: int) -> void:
	_current_story = clampi(story, 0, MAX_STORIES - 1)
	if is_instance_valid(_story_label):
		var name_str: String = STORY_NAMES[_current_story] if _current_story < STORY_NAMES.size() else ("%d层" % (_current_story + 1))
		_story_label.text = "第 %d 层 (共 %d 层) · %s" % [_current_story + 1, MAX_STORIES, name_str]
	if is_instance_valid(_prev_story_btn):
		_prev_story_btn.disabled = (_current_story <= 0)
	if is_instance_valid(_next_story_btn):
		_next_story_btn.disabled = (_current_story >= MAX_STORIES - 1)
	if _story_buttons != null:
		var buttons := _story_buttons.get_buttons()
		if _current_story < buttons.size():
			buttons[_current_story].set_pressed_no_signal(true)


func set_editing(editing: bool, plot_name := "", story := 0) -> void:
	panel.visible = editing
	_confirm_example = false
	_example.text = "放置示例屋"
	_title.text = plot_name
	update_story(story)
	if editing:
		_compass.hide()
		_prompt.hide()
		_room_prompt.hide()
		set_selection(home.selected_definition, home.erase_mode)


func set_selection(id: String, erasing: bool) -> void:
	for key: String in _cards:
		_cards[key].set_pressed_no_signal(key == id and not erasing)
	if not _tools.is_empty():
		_tools.place.set_pressed_no_signal(not erasing)
		_tools.erase.set_pressed_no_signal(erasing)


func editing_state(can_undo: bool, can_redo: bool, show_example: bool) -> void:
	_tools.undo.disabled = not can_undo
	_tools.redo.disabled = not can_redo
	_example.visible = show_example


func show_hint(note: String) -> void:
	_hint.text = note


func show_status(note: String) -> void:
	_status.text = note


func show_notice(note: String) -> void:
	_notice.text = note
	_notice_left = 5.0


func set_room_prompt(prompt_text: String) -> void:
	if is_instance_valid(_room_prompt):
		if prompt_text.is_empty():
			_room_prompt.hide()
		else:
			_room_prompt.text = prompt_text
			_room_prompt.show()


func set_navigation(enabled: bool, forward: Vector3, origin: Vector3, homes: Array[Dictionary], eligible: String) -> void:
	_compass.visible = enabled
	_prompt.visible = enabled and not eligible.is_empty()
	if not enabled:
		return
	if _prompt.visible:
		_prompt.text = "F5  建造家园" if eligible == "home" else "F5  建造家园  ·  " + eligible
	if Vector2(forward.x, forward.z).length_squared() > .0001:
		_heading = rad_to_deg(atan2(forward.x, -forward.z))
	_markers.clear()
	for entry: Dictionary in homes:
		var direction: Vector3 = entry.position - origin
		var meters := Vector2(direction.x, direction.z).length()
		var angle := _heading if meters < .5 else rad_to_deg(atan2(direction.x, -direction.z))
		_markers.append({"delta": wrapf(angle - _heading, -180, 180), "meters": meters, "name": entry.name})
	_markers.sort_custom(func(a: Dictionary, b: Dictionary): return a.meters < b.meters)
	_compass.queue_redraw()


func _process(delta: float) -> void:
	if _notice_left > 0:
		_notice_left = maxf(0, _notice_left - delta)
		if _notice_left == 0:
			_notice.text = ""


func _draw_compass() -> void:
	var half := _compass.size.x * .5
	var font := UI.interface_font()
	var ink := Color("#edf7fa")
	_compass.draw_line(Vector2(half, 1), Vector2(half, 9), Color(ink, .85), 2)
	var cardinals := ["N", "E", "S", "W"]
	for angle in range(0, 360, 15):
		var delta := wrapf(float(angle) - _heading, -180, 180)
		if absf(delta) > COMPASS_SPAN:
			continue
		var x := half + delta * half / COMPASS_SPAN
		var alpha := .30 + .42 * (1.0 - absf(delta) / COMPASS_SPAN)
		if angle % 90 == 0:
			_draw_text(font, cardinals[angle / 90], Vector2(x, 26), 23, Color(ink, alpha))
		else:
			_compass.draw_line(Vector2(x, 16), Vector2(x, 22), Color("#182d41"), 3)
			_compass.draw_line(Vector2(x, 16), Vector2(x, 22), Color(ink, alpha), 1)
	var last_x := -100.0
	for marker: Dictionary in _markers:
		var x := half + clampf(marker.delta, -COMPASS_SPAN + 3, COMPASS_SPAN - 3) * half / COMPASS_SPAN
		if absf(x - last_x) < 27.0:
			continue
		last_x = x
		var bright: bool = absf(marker.delta) < 11.0
		var color := Color(ink, .92 if bright else .66)
		var house := PackedVector2Array([Vector2(x - 9, 46), Vector2(x, 37), Vector2(x + 9, 46),
			Vector2(x + 6, 46), Vector2(x + 6, 55), Vector2(x - 6, 55), Vector2(x - 6, 46), Vector2(x - 9, 46)])
		_compass.draw_polyline(house, Color("#192c40"), 4, true)
		_compass.draw_polyline(house, color, 2, true)
		if bright and not marker.name.is_empty():
			_draw_text(font, "%s  %d m" % [marker.name, roundi(marker.meters)], Vector2(x, 75), 16, color)


func _draw_text(font: Font, value: String, center: Vector2, font_size: int, color: Color) -> void:
	var start := center - Vector2(font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * .5, 0)
	_compass.draw_string_outline(font, start, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color("#16293e"))
	_compass.draw_string(font, start, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
