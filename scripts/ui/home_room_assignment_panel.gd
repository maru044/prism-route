class_name HomeRoomAssignmentPanel
extends CanvasLayer
## Modal UI for assigning, switching, and vacating residents in home rooms.

signal closed
signal resident_assigned(room_id: String, character_id: String)
signal resident_removed(room_id: String)

const UI := preload("res://scenes/combat/encounter_ui_style.gd")
const PALETTE := preload("res://scenes/combat/temple_paper_palette.tres")
const ROSTER := preload("res://scripts/characters/character_roster_database.gd")

var home = null
var resident_manager: HomeResidentManager = null
var game_progress = null

var target_plot_id: String = ""
var target_room_id: String = ""
var target_room_data: Dictionary = {}
var _built: bool = false

var _screen := Control.new()
var _sheet: PanelContainer
var _title_label: Label
var _info_label: Label
var _current_resident_label: Label
var _scroll: ScrollContainer
var _cards_container: VBoxContainer
var _empty_hint: Label
var _close_btn: Button

func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_built()
	hide()

func _ensure_built() -> void:
	if _built:
		return
	_built = true
	_build_ui()

func _build_ui() -> void:
	add_child(_screen)
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP

	# Backdrop
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.09, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.add_child(dim)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(center)

	_sheet = PanelContainer.new()
	_sheet.custom_minimum_size = Vector2(780, 560)
	var sheet_style := StyleBoxFlat.new()
	sheet_style.bg_color = PALETTE.paper_wash
	sheet_style.border_color = PALETTE.paper_ink
	sheet_style.set_border_width_all(2)
	sheet_style.set_corner_radius_all(8)
	sheet_style.content_margin_left = 24
	sheet_style.content_margin_right = 24
	sheet_style.content_margin_top = 20
	sheet_style.content_margin_bottom = 20
	_sheet.add_theme_stylebox_override("panel", sheet_style)
	center.add_child(_sheet)

	var main_col := UI.column(12)
	_sheet.add_child(main_col)

	# 1. Header
	var header := UI.row(8)
	main_col.add_child(header)

	_title_label = UI.text_label("房间住客管理", 26, PALETTE.text, PALETTE)
	_title_label.add_theme_font_override("font", UI.command_font())
	header.add_child(_title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)

	_close_btn = Button.new()
	_close_btn.text = "关闭  ESC"
	_close_btn.custom_minimum_size = Vector2(110, 34)
	_style_button(_close_btn)
	_close_btn.pressed.connect(close)
	header.add_child(_close_btn)

	# 2. Room Information banner
	var info_box := PanelContainer.new()
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color(PALETTE.accent, 0.12)
	info_style.border_color = Color(PALETTE.accent, 0.45)
	info_style.set_border_width_all(1)
	info_style.set_corner_radius_all(6)
	info_style.content_margin_left = 14
	info_style.content_margin_right = 14
	info_style.content_margin_top = 8
	info_style.content_margin_bottom = 8
	info_box.add_theme_stylebox_override("panel", info_style)
	main_col.add_child(info_box)

	var info_col := UI.column(4)
	info_box.add_child(info_col)

	_info_label = UI.text_label("", 16, PALETTE.text, PALETTE)
	info_col.add_child(_info_label)

	_current_resident_label = UI.text_label("", 17, PALETTE.accent, PALETTE)
	info_col.add_child(_current_resident_label)

	# 3. Companion cards scroll list
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size.y = 320
	main_col.add_child(_scroll)

	_cards_container = UI.column(8)
	_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_cards_container)

	_empty_hint = UI.text_label("暂无已收服/解锁的角色，请在大世界或主线中探寻结识新伙伴！", 17, PALETTE.secondary, PALETTE)
	_empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_col.add_child(_empty_hint)

func open(plot_id: String, room: Dictionary) -> void:
	_ensure_built()
	if game_progress == null and is_instance_valid(home) and is_instance_valid(home.world):
		game_progress = home.world.get("game_progress")
	target_plot_id = plot_id
	target_room_id = str(room.get("id", ""))
	target_room_data = room.duplicate(true)
	show()
	_refresh_content()

func close() -> void:
	hide()
	closed.emit()

func _refresh_content() -> void:
	if target_room_id.is_empty():
		return

	# Setup Title and Info
	var kind_str := "室内"
	var kind: String = str(target_room_data.get("kind", "indoor"))
	if kind == "courtyard":
		kind_str = "中庭"
	elif kind == "open":
		kind_str = "开敞露台"

	var func_str := "普通空间"
	var function: String = str(target_room_data.get("function", "generic"))
	if function == "bedroom":
		func_str = "温馨卧室 (配有床铺)"
	elif function == "work":
		func_str = "雅致书房 (配有桌椅)"

	var area: float = float(target_room_data.get("area", 0.0))
	var story: int = int(target_room_data.get("story", 0))

	_title_label.text = "房间住客管理 · %s" % target_room_id
	_info_label.text = "【%s】%s | 楼层: 第 %d 层 | 面积: %.1f ㎡" % [kind_str, func_str, story + 1, area]

	var current_char_id := ""
	if resident_manager != null:
		current_char_id = resident_manager.get_resident(target_room_id)

	if current_char_id.is_empty():
		_current_resident_label.text = "当前住客状态：空置中（尚未安排住客）"
	else:
		var char_entry := ROSTER.get_entry(current_char_id)
		var char_name := str(char_entry.get("name", current_char_id))
		_current_resident_label.text = "当前住客状态：已由【%s】入住" % char_name

	# Clear previous cards
	for child in _cards_container.get_children():
		child.queue_free()

	# Retrieve unlocked companions
	var unlocked: Array[String] = []
	if game_progress != null and "companion_unlocks" in game_progress:
		unlocked.assign(game_progress.companion_unlocks)

	# If sparkle or default companions are not yet in array, fallback to available entries
	if unlocked.is_empty():
		_scroll.hide()
		_empty_hint.show()
		return

	_scroll.show()
	_empty_hint.hide()

	for char_id: String in unlocked:
		var card := _build_character_row(char_id, current_char_id)
		_cards_container.add_child(card)

func _build_character_row(char_id: String, current_resident_id: String) -> Control:
	var entry := ROSTER.get_entry(char_id)
	var char_name := str(entry.get("name", char_id))
	var char_title := str(entry.get("title", ""))
	var char_game := str(entry.get("game", ""))

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PALETTE.paper_wash, 0.95)
	style.border_color = Color(PALETTE.paper_ink, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var row := UI.row(12)
	panel.add_child(row)

	# Portrait thumbnail
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(50, 50)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var tex := ROSTER.load_portrait(char_id)
	if tex != null:
		portrait.texture = tex
	row.add_child(portrait)

	# Info column
	var info_col := UI.column(2)
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_col)

	var name_lbl := UI.text_label("%s  ·  %s" % [char_name, char_title], 17, PALETTE.text, PALETTE)
	name_lbl.add_theme_font_override("font", UI.command_font())
	info_col.add_child(name_lbl)

	var desc_lbl := UI.text_label("出处: %s" % char_game, 14, PALETTE.secondary, PALETTE)
	info_col.add_child(desc_lbl)

	# Housing status & action button
	var assigned_room := ""
	if resident_manager != null:
		assigned_room = resident_manager.get_room_for_character(char_id)

	var action_btn := Button.new()
	action_btn.custom_minimum_size = Vector2(130, 36)
	_style_button(action_btn)
	row.add_child(action_btn)

	if char_id == current_resident_id:
		# Already living in THIS room -> can vacate
		var status_lbl := UI.text_label("【当前住客】", 15, PALETTE.accent, PALETTE)
		row.add_child(status_lbl)
		action_btn.text = "撤出房间"
		action_btn.pressed.connect(_on_vacate_pressed.bind(target_room_id))
	elif not assigned_room.is_empty():
		# Living in ANOTHER room -> can transfer
		var status_lbl := UI.text_label("已入住: %s" % assigned_room, 14, PALETTE.secondary, PALETTE)
		row.add_child(status_lbl)
		action_btn.text = "转移至本房间"
		action_btn.pressed.connect(_on_assign_pressed.bind(target_room_id, char_id))
	else:
		# Free / Unassigned -> can assign
		var status_lbl := UI.text_label("未入住", 14, Color("#4c7c59"), PALETTE)
		row.add_child(status_lbl)
		action_btn.text = "安排入住"
		action_btn.pressed.connect(_on_assign_pressed.bind(target_room_id, char_id))

	return panel

func _on_assign_pressed(room_id: String, character_id: String) -> void:
	if resident_manager != null:
		resident_manager.assign_resident(room_id, character_id)
	resident_assigned.emit(room_id, character_id)
	if home != null and home.has_method("_queue_save"):
		home._queue_save()
	if home != null and home.has_method("refresh_residents"):
		home.refresh_residents()
	_refresh_content()

func _on_vacate_pressed(room_id: String) -> void:
	if resident_manager != null:
		resident_manager.unassign_room(room_id)
	resident_removed.emit(room_id)
	if home != null and home.has_method("_queue_save"):
		home._queue_save()
	if home != null and home.has_method("refresh_residents"):
		home.refresh_residents()
	_refresh_content()

func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = PALETTE.paper_wash
	normal.border_color = PALETTE.paper_ink
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	button.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(PALETTE.paper_wash, 0.8)
	hover.border_color = PALETTE.accent
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(4)
	button.add_theme_stylebox_override("hover", hover)

	button.add_theme_color_override("font_color", PALETTE.text)
	button.add_theme_color_override("font_hover_color", PALETTE.accent)
	button.add_theme_font_override("font", UI.interface_font())
	button.add_theme_font_size_override("font_size", 16)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key in [KEY_ESCAPE, KEY_G]:
			close()
			get_viewport().set_input_as_handled()
