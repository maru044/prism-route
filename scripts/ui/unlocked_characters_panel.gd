extends Control
## Large-format unlocked character gallery displaying standing portraits and personas.

signal closed

const UI := preload("res://scenes/combat/encounter_ui_style.gd")
const PALETTE := preload("res://scenes/combat/temple_paper_palette.tres")
const ROSTER := preload("res://scripts/characters/character_roster_database.gd")

var game_progress: RefCounted = null
var is_preview_all: bool = false
var current_char_id: String = ""

var _char_list_box: VBoxContainer
var _counter_label: Label
var _preview_toggle_btn: Button
var _portrait_rect: TextureRect
var _portrait_button: Button
var _portrait_hint: Label
var _name_label: Label
var _title_label: Label
var _persona_text: RichTextLabel
var _persona_scroll: ScrollContainer
var _char_buttons: Dictionary = {}
var _feedback_label: Label

var _ui_built: bool = false

func _init() -> void:
	_ensure_ui()

func _ready() -> void:
	_ensure_ui()
	hide()

func _ensure_ui() -> void:
	if _ui_built:
		return
	_ui_built = true

	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP

	# Dimmed backdrop
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.08, 0.82)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.mouse_filter = MOUSE_FILTER_STOP
	add_child(dim)

	# Center sheet
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)

	var sheet := PanelContainer.new()
	sheet.custom_minimum_size = Vector2(1180, 700)
	var sheet_style := StyleBoxFlat.new()
	sheet_style.bg_color = PALETTE.paper_wash
	sheet_style.border_color = PALETTE.paper_ink
	sheet_style.set_border_width_all(2)
	sheet_style.set_corner_radius_all(10)
	sheet_style.content_margin_left = 22
	sheet_style.content_margin_right = 22
	sheet_style.content_margin_top = 18
	sheet_style.content_margin_bottom = 18
	sheet.add_theme_stylebox_override("panel", sheet_style)
	center.add_child(sheet)

	var main_col := UI.column(14)
	sheet.add_child(main_col)

	# 1. Top Header Bar
	var top_bar := UI.row(12)
	main_col.add_child(top_bar)

	var title := UI.text_label("已解锁角色 · 档案鉴赏", 30, PALETTE.text, PALETTE)
	title.add_theme_font_override("font", UI.command_font())
	top_bar.add_child(title)

	_counter_label = UI.text_label("", 18, PALETTE.secondary, PALETTE)
	top_bar.add_child(_counter_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	spacer.mouse_filter = MOUSE_FILTER_IGNORE
	top_bar.add_child(spacer)

	_preview_toggle_btn = Button.new()
	_preview_toggle_btn.text = "【浏览全员】"
	_preview_toggle_btn.custom_minimum_size = Vector2(120, 36)
	_style_tab_button(_preview_toggle_btn)
	_preview_toggle_btn.pressed.connect(_toggle_preview_all)
	top_bar.add_child(_preview_toggle_btn)

	var close_btn := Button.new()
	close_btn.text = "返回设置"
	close_btn.custom_minimum_size = Vector2(110, 36)
	_style_tab_button(close_btn)
	close_btn.pressed.connect(close)
	top_bar.add_child(close_btn)

	# 2. Main Body (3 Columns)
	var body_row := UI.row(16)
	body_row.size_flags_vertical = SIZE_EXPAND_FILL
	main_col.add_child(body_row)

	# --- Column 1: Character List (~260px) ---
	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size.x = 260
	list_panel.size_flags_vertical = SIZE_EXPAND_FILL
	var list_style := StyleBoxFlat.new()
	list_style.bg_color = Color(PALETTE.paper_active, 0.5)
	list_style.set_corner_radius_all(6)
	list_style.content_margin_left = 10
	list_style.content_margin_right = 10
	list_style.content_margin_top = 10
	list_style.content_margin_bottom = 10
	list_panel.add_theme_stylebox_override("panel", list_style)
	body_row.add_child(list_panel)

	var list_vbox := UI.column(8)
	list_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	list_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	list_panel.add_child(list_vbox)

	var list_header := UI.text_label("伙伴名录", 20, PALETTE.text, PALETTE)
	list_header.add_theme_font_override("font", UI.command_font())
	list_vbox.add_child(list_header)

	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	list_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_vbox.add_child(list_scroll)

	_char_list_box = UI.column(6)
	_char_list_box.size_flags_horizontal = SIZE_EXPAND_FILL
	list_scroll.add_child(_char_list_box)

	# --- Column 2: Standing Portrait Area (~380px) ---
	var portrait_panel := PanelContainer.new()
	portrait_panel.custom_minimum_size = Vector2(380, 600)
	portrait_panel.size_flags_vertical = SIZE_EXPAND_FILL
	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = Color(PALETTE.paper_active, 0.85)
	portrait_style.border_color = PALETTE.paper_ink
	portrait_style.set_border_width_all(1)
	portrait_style.set_corner_radius_all(8)
	portrait_style.content_margin_left = 8
	portrait_style.content_margin_right = 8
	portrait_style.content_margin_top = 8
	portrait_style.content_margin_bottom = 8
	portrait_panel.add_theme_stylebox_override("panel", portrait_style)
	body_row.add_child(portrait_panel)

	var portrait_vbox := UI.column(6)
	portrait_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	portrait_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	portrait_panel.add_child(portrait_vbox)

	# Clickable portrait container
	var portrait_frame := Control.new()
	portrait_frame.size_flags_horizontal = SIZE_EXPAND_FILL
	portrait_frame.size_flags_vertical = SIZE_EXPAND_FILL
	portrait_vbox.add_child(portrait_frame)

	_portrait_rect = TextureRect.new()
	_portrait_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.mouse_filter = MOUSE_FILTER_IGNORE
	portrait_frame.add_child(_portrait_rect)

	# Invisible overlay button to capture clicks on the portrait
	_portrait_button = Button.new()
	_portrait_button.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_portrait_button.flat = true
	_portrait_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty_sb := StyleBoxEmpty.new()
	_portrait_button.add_theme_stylebox_override("normal", empty_sb)
	_portrait_button.add_theme_stylebox_override("hover", empty_sb)
	_portrait_button.add_theme_stylebox_override("pressed", empty_sb)
	_portrait_button.add_theme_stylebox_override("focus", empty_sb)
	_portrait_button.pressed.connect(_on_portrait_clicked)
	portrait_frame.add_child(_portrait_button)

	_portrait_hint = UI.text_label("✦ 点击立绘展开角色设定 (Persona) ✦", 16, PALETTE.accent, PALETTE)
	_portrait_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_vbox.add_child(_portrait_hint)

	# --- Column 3: Persona Description Area (~480px) ---
	var persona_panel := PanelContainer.new()
	persona_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	persona_panel.size_flags_vertical = SIZE_EXPAND_FILL
	var persona_style := StyleBoxFlat.new()
	persona_style.bg_color = Color(PALETTE.paper_active, 0.5)
	persona_style.border_color = PALETTE.paper_ink
	persona_style.set_border_width_all(1)
	persona_style.set_corner_radius_all(8)
	persona_style.content_margin_left = 18
	persona_style.content_margin_right = 18
	persona_style.content_margin_top = 16
	persona_style.content_margin_bottom = 16
	persona_panel.add_theme_stylebox_override("panel", persona_style)
	body_row.add_child(persona_panel)

	var persona_vbox := UI.column(10)
	persona_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	persona_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	persona_panel.add_child(persona_vbox)

	# Header with character name and badge
	var persona_header := UI.row(10)
	persona_vbox.add_child(persona_header)

	_name_label = UI.text_label("", 26, PALETTE.text, PALETTE)
	_name_label.add_theme_font_override("font", UI.command_font())
	persona_header.add_child(_name_label)

	_title_label = UI.text_label("", 17, PALETTE.secondary, PALETTE)
	persona_header.add_child(_title_label)

	var header_spacer := Control.new()
	header_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	persona_header.add_child(header_spacer)

	_feedback_label = UI.text_label("", 16, Color(0.2, 0.65, 0.35), PALETTE)
	persona_header.add_child(_feedback_label)

	var divider := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = Color(PALETTE.paper_ink, 0.4)
	divider.add_theme_stylebox_override("separator", sep_style)
	persona_vbox.add_child(divider)

	# Scrollable persona text
	_persona_scroll = ScrollContainer.new()
	_persona_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	_persona_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_persona_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	persona_vbox.add_child(_persona_scroll)

	_persona_text = RichTextLabel.new()
	_persona_text.size_flags_horizontal = SIZE_EXPAND_FILL
	_persona_text.size_flags_vertical = SIZE_EXPAND_FILL
	_persona_text.bbcode_enabled = true
	_persona_text.fit_content = true
	_persona_text.add_theme_color_override("default_color", PALETTE.text)
	_persona_text.add_theme_font_size_override("normal_font_size", 17)
	_persona_scroll.add_child(_persona_text)

func open(p_progress: Variant = null) -> void:
	_ensure_ui()
	if p_progress != null:
		game_progress = p_progress
	_refresh_list()
	show()

func close() -> void:
	hide()
	closed.emit()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()

func _toggle_preview_all() -> void:
	is_preview_all = not is_preview_all
	_preview_toggle_btn.text = "【仅看已解锁】" if is_preview_all else "【浏览全员】"
	_refresh_list()

func _get_unlocked_ids() -> Array[String]:
	var result: Array[String] = []
	if game_progress != null and "companion_unlocks" in game_progress:
		var unlocks: Variant = game_progress.companion_unlocks
		if unlocks is Array:
			for id: Variant in unlocks:
				var sid: String = str(id).strip_edges()
				if not sid.is_empty() and not result.has(sid):
					result.append(sid)
	return result

func _refresh_list() -> void:
	for child in _char_list_box.get_children():
		child.queue_free()
	_char_buttons.clear()

	var unlocked_ids := _get_unlocked_ids()
	var all_entries := ROSTER.get_all_entries()

	var display_entries: Array[Dictionary] = []
	if is_preview_all:
		display_entries = all_entries
	else:
		for entry: Dictionary in all_entries:
			if unlocked_ids.has(entry.id):
				display_entries.append(entry)

	_counter_label.text = "（已结识伙伴：%d / %d）" % [unlocked_ids.size(), all_entries.size()]

	if display_entries.is_empty():
		var empty_lbl := UI.text_label("当前尚未结识任何角色。\n在大世界中完成对决或剧情互动，\n即可在此解锁立绘与档案！\n\n点击上方【浏览全员】\n可自由预览全部角色图鉴与设定✨", 17, PALETTE.secondary, PALETTE)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_char_list_box.add_child(empty_lbl)
		_clear_display()
		return

	for entry: Dictionary in display_entries:
		var char_id: String = entry.id
		var btn := Button.new()
		var is_unlocked := unlocked_ids.has(char_id)
		var badge := "★ " if is_unlocked else "☆ "
		btn.text = badge + entry.name + " · " + entry.game
		btn.custom_minimum_size.y = 38
		btn.size_flags_horizontal = SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_list_button(btn)
		btn.pressed.connect(_select_character.bind(char_id))
		_char_list_box.add_child(btn)
		_char_buttons[char_id] = btn

	# Select the first character or preserve selection
	if current_char_id.is_empty() or not _char_buttons.has(current_char_id):
		_select_character(display_entries[0].id)
	else:
		_select_character(current_char_id)

func _select_character(char_id: String) -> void:
	current_char_id = char_id

	# Update button highlights
	for cid in _char_buttons:
		var btn: Button = _char_buttons[cid]
		if cid == current_char_id:
			btn.add_theme_color_override("font_color", PALETTE.accent)
		else:
			btn.add_theme_color_override("font_color", PALETTE.text)

	# Load portrait texture
	var texture := ROSTER.load_portrait(char_id)
	_portrait_rect.texture = texture

	# Load persona details
	var persona_data := ROSTER.load_persona_data(char_id)
	_name_label.text = persona_data.name
	_title_label.text = "【%s】 · %s" % [persona_data.title, persona_data.game]

	var content: String = persona_data.content
	# Render content nicely in RichTextLabel
	_persona_text.text = _format_persona_bbcode(content)
	_persona_scroll.scroll_vertical = 0
	_feedback_label.text = ""

func _on_portrait_clicked() -> void:
	if current_char_id.is_empty():
		return
	# Re-display and emphasize persona
	_feedback_label.text = "✨ 角色设定已呈现！"
	_persona_scroll.scroll_vertical = 0

	# Brief visual pulse on portrait
	var tween := create_tween()
	tween.tween_property(_portrait_rect, "modulate", Color(1.2, 1.2, 1.3), 0.1)
	tween.tween_property(_portrait_rect, "modulate", Color(1.0, 1.0, 1.0), 0.2)

func _format_persona_bbcode(raw: String) -> String:
	var lines := raw.split("\n")
	var result := PackedStringArray()
	for line: String in lines:
		var trimmed := line.strip_edges()
		if trimmed.begins_with("◆"):
			result.append("\n[color=#3d6076][b]" + trimmed + "[/b][/color]")
		elif trimmed.begins_with("[NPC Profile:"):
			result.append("[color=#243f55][b]" + trimmed + "[/b][/color]")
		elif trimmed.begins_with("身份：") or trimmed.begins_with("当前对话对象：") or trimmed.begins_with("称呼玩家：") or trimmed.begins_with("所属作品：") or trimmed.begins_with("武器/属性："):
			result.append("[color=#4a6b82]" + trimmed + "[/color]")
		elif trimmed.begins_with("- “") or trimmed.begins_with("- “"):
			result.append("[color=#1f5b82][i]" + trimmed + "[/i][/color]")
		else:
			result.append(trimmed)
	return "\n".join(result)

func _clear_display() -> void:
	current_char_id = ""
	_portrait_rect.texture = null
	_name_label.text = ""
	_title_label.text = ""
	_persona_text.text = ""
	_feedback_label.text = ""

func _style_tab_button(button: Button) -> void:
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = PALETTE.paper_active
	sb_normal.border_color = PALETTE.paper_ink
	sb_normal.set_border_width_all(1)
	sb_normal.set_corner_radius_all(5)
	sb_normal.content_margin_left = 12
	sb_normal.content_margin_right = 12
	sb_normal.content_margin_top = 6
	sb_normal.content_margin_bottom = 6

	var sb_hover := sb_normal.duplicate() as StyleBoxFlat
	sb_hover.bg_color = Color(PALETTE.paper_ink, 0.2)

	button.add_theme_stylebox_override("normal", sb_normal)
	button.add_theme_stylebox_override("hover", sb_hover)
	button.add_theme_stylebox_override("pressed", sb_hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", PALETTE.text)
	button.add_theme_color_override("font_hover_color", PALETTE.text)
	button.add_theme_font_override("font", UI.interface_font())
	button.add_theme_font_size_override("font_size", 16)

func _style_list_button(button: Button) -> void:
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color(PALETTE.paper_wash, 0.7)
	sb_normal.border_color = Color(PALETTE.paper_ink, 0.3)
	sb_normal.set_border_width_all(1)
	sb_normal.set_corner_radius_all(4)
	sb_normal.content_margin_left = 8
	sb_normal.content_margin_right = 8
	sb_normal.content_margin_top = 4
	sb_normal.content_margin_bottom = 4

	var sb_hover := sb_normal.duplicate() as StyleBoxFlat
	sb_hover.bg_color = PALETTE.paper_active
	sb_hover.border_color = PALETTE.paper_ink

	button.add_theme_stylebox_override("normal", sb_normal)
	button.add_theme_stylebox_override("hover", sb_hover)
	button.add_theme_stylebox_override("pressed", sb_hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", PALETTE.text)
	button.add_theme_color_override("font_hover_color", PALETTE.accent)
	button.add_theme_font_override("font", UI.interface_font())
	button.add_theme_font_size_override("font_size", 15)
