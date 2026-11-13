extends Button

const UI := preload("res://scenes/combat/encounter_ui_style.gd")
const PLATE := preload("res://scenes/combat/encounter_card.gdshader")

enum Kind { SKILL, TAB, CATEGORY, CHOICE, CONTINUE }

var _plate: ShaderMaterial
var _featured := false
var _response := 0.0
var _response_target := 0.0
var _response_tween: Tween

func configure(title: String, palette: UI.Palette, kind: Kind, detail := "", sub_detail := "") -> void:
	text = title
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_font_override("font", UI.interface_font())
	add_theme_color_override("font_color", palette.text)
	add_theme_color_override("font_hover_color", palette.text)
	add_theme_color_override("font_focus_color", palette.text)
	add_theme_color_override("font_pressed_color", palette.text)
	add_theme_color_override("font_hover_pressed_color", palette.text)
	add_theme_color_override("font_disabled_color", Color(palette.secondary, .70))

	var empty := StyleBoxEmpty.new()
	var point_size := 24
	var density := .67
	match kind:
		Kind.SKILL:
			point_size = 29
			density = .84
			empty.content_margin_bottom = 22
		Kind.CATEGORY:
			point_size = 21
			density = .49
		Kind.CHOICE:
			point_size = 22
			density = .34
			alignment = HORIZONTAL_ALIGNMENT_LEFT
			empty.content_margin_left = 49
			empty.content_margin_right = 24
			empty.content_margin_top = 10
			empty.content_margin_bottom = 10
		Kind.CONTINUE:
			point_size = 19
			density = .50
	add_theme_font_size_override("font_size", point_size)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		add_theme_stylebox_override(state, empty)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	_plate = ShaderMaterial.new()
	_plate.shader = PLATE
	_plate.set_shader_parameter("face", palette.glass_top)
	_plate.set_shader_parameter("tint", palette.glass_bottom)
	_plate.set_shader_parameter("light_color", palette.glass_sheen)
	_plate.set_shader_parameter("density", density)

	var surface := ColorRect.new()
	surface.name = "Plate"
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.show_behind_parent = true
	surface.material = _plate
	add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if kind == Kind.SKILL:
		var stat_row := UI.row(10)
		stat_row.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(stat_row)
		stat_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stat_row.anchor_top = .5
		stat_row.offset_top = 3
		stat_row.offset_bottom = -6

		var stat := UI.text_label(detail, 19, palette.secondary, palette)
		stat.add_theme_font_override("font", UI.interface_font())
		stat.add_theme_constant_override("outline_size", 0)
		stat.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stat.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stat_row.add_child(stat)

		if not sub_detail.is_empty():
			var sep := UI.text_label("·", 18, Color(palette.secondary, 0.55), palette)
			sep.add_theme_font_override("font", UI.interface_font())
			sep.add_theme_constant_override("outline_size", 0)
			sep.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
			stat_row.add_child(sep)

			var sub_stat := UI.text_label(sub_detail, 18, palette.accent, palette)
			sub_stat.add_theme_font_override("font", UI.interface_font())
			sub_stat.add_theme_constant_override("outline_size", 0)
			sub_stat.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			sub_stat.size_flags_vertical = Control.SIZE_EXPAND_FILL
			stat_row.add_child(sub_stat)
	elif kind == Kind.CHOICE:
		var index := UI.text_label(detail, 19, palette.glass_sheen, palette)
		index.add_theme_font_override("font", UI.interface_font())
		index.add_theme_constant_override("outline_size", 0)
		index.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		index.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(index)
		index.anchor_bottom = 1.0
		index.offset_left = 13
		index.offset_right = 43

	ready.connect(_sync_size, CONNECT_ONE_SHOT)
	resized.connect(_sync_size)
	draw.connect(_sync_state)
	button_down.connect(func(): _plate.set_shader_parameter("depressed", 1.0))
	button_up.connect(func(): _plate.set_shader_parameter("depressed", 0.0))
	_sync_size()

func set_featured(featured: bool) -> void:
	_featured = featured
	queue_redraw()

func _sync_size() -> void:
	_plate.set_shader_parameter("plate_size", size)

func _sync_state() -> void:
	var selected := _featured or (toggle_mode and button_pressed)
	_plate.set_shader_parameter("selected", float(selected))
	_plate.set_shader_parameter("unavailable", float(disabled and not selected))
	var target := 0.0
	if not disabled:
		target = 1.0 if is_hovered() else (.32 if has_focus() else 0.0)
	if target == _response_target:
		return
	_response_target = target
	if _response_tween and _response_tween.is_valid():
		_response_tween.kill()
	_response_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_response_tween.tween_method(_set_response, _response, target, .17)

func _set_response(value: float) -> void:
	_response = value
	_plate.set_shader_parameter("interaction", value)
