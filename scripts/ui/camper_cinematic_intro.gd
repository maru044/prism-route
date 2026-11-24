class_name CamperCinematicIntro
extends CanvasLayer
## First-boarding credits drawn over the live game without taking input.

signal intro_finished()
signal act_changed(act_index: int)

const LEAD_IN := 2.0
const FADE_IN := 0.6
const TITLE_HOLD := 2.15
const CREDIT_HOLD := 1.95
const FADE_OUT := 0.85
const BETWEEN_ACTS := 0.25
const REFERENCE_SIZE := Vector2(1920.0, 1080.0)
const BAR_HEIGHT := 72.0
const EXIT_TRAVEL := 50.0
const TITLE_COLOR := Color("#fff7e9")
const CREDIT_COLOR := Color("#f1ece2")

var is_running := false
var _root: Control
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _act1: CenterContainer
var _act2: CenterContainer
var _label_act1: Label
var _label_act2: Label
var _credit_caption: Label
var _credit_layout: VBoxContainer
var _active_tween: Tween
var _exit_travel := EXIT_TRAVEL

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	start_intro()

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "CinematicRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_bar_top = _make_bar(0.0)
	_bar_bottom = _make_bar(1.0)

	var display_font := SystemFont.new()
	display_font.font_names = PackedStringArray(["Georgia", "Noto Serif", "Liberation Serif", "Times New Roman"])
	display_font.font_weight = 700
	var headline := FontVariation.new()
	headline.base_font = display_font

	var caption_font := SystemFont.new()
	caption_font.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "Liberation Sans"])
	caption_font.font_weight = 600
	var caption := FontVariation.new()
	caption.base_font = caption_font

	_act1 = _make_act("GameTitle")
	_label_act1 = _make_label("PRISM ROUTE", headline, TITLE_COLOR)
	_act1.add_child(_label_act1)

	_act2 = _make_act("StudioCredit")
	_credit_layout = VBoxContainer.new()
	_credit_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_act2.add_child(_credit_layout)
	_credit_caption = _make_label("PRESENTED BY", caption, CREDIT_COLOR)
	_label_act2 = _make_label("ARCHAEA", headline, TITLE_COLOR)
	_credit_layout.add_child(_credit_caption)
	_credit_layout.add_child(_label_act2)

	_root.resized.connect(_layout)
	_layout()

func _make_bar(edge: float) -> ColorRect:
	var bar := ColorRect.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.color = Color(0.025, 0.035, 0.052, 0.88)
	_root.add_child(bar)
	bar.anchor_right = 1.0
	bar.anchor_top = edge
	bar.anchor_bottom = edge
	return bar

func _make_act(act_name: String) -> CenterContainer:
	var act := CenterContainer.new()
	act.name = act_name
	act.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(act)
	act.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return act

func _make_label(caption: String, font: Font, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = caption
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.035, 0.044, 0.064, 0.5))
	label.add_theme_color_override("font_shadow_color", Color(0.022, 0.031, 0.052, 0.52))
	label.add_theme_constant_override("shadow_offset_x", 0)
	return label

func _layout() -> void:
	var size := _root.size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var scale := minf(size.x / REFERENCE_SIZE.x, size.y / REFERENCE_SIZE.y)
	_bar_top.offset_bottom = roundf(size.y / REFERENCE_SIZE.y * BAR_HEIGHT)
	_bar_bottom.offset_top = -_bar_top.offset_bottom
	_exit_travel = size.y / REFERENCE_SIZE.y * EXIT_TRAVEL
	_credit_layout.add_theme_constant_override("separation", roundi(13.0 * scale))

	var headline := _label_act1.get_theme_font("font") as FontVariation
	headline.spacing_glyph = roundi(6.0 * scale)
	var caption := _credit_caption.get_theme_font("font") as FontVariation
	caption.spacing_glyph = roundi(4.0 * scale)
	_fit_label(_label_act1, 138.0 * scale, size.x * 0.52)
	_fit_label(_label_act2, 91.0 * scale, size.x * 0.44)
	_fit_label(_credit_caption, 27.0 * scale, size.x * 0.44)

func _fit_label(label: Label, preferred: float, max_width: float) -> void:
	var font := label.get_theme_font("font")
	var font_size := maxi(1, roundi(preferred))
	var text_width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if text_width > max_width:
		font_size = maxi(1, floori(font_size * max_width / text_width))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", maxi(1, roundi(font_size * 0.016)))
	label.add_theme_constant_override("shadow_offset_y", maxi(1, roundi(font_size * 0.025)))
	label.add_theme_constant_override("shadow_outline_size", maxi(1, roundi(font_size * 0.031)))

func start_intro() -> void:
	if not is_inside_tree():
		return
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	is_running = true
	_root.modulate.a = 1.0
	_bar_top.modulate.a = 0.0
	_bar_bottom.modulate.a = 0.0
	_act1.modulate.a = 0.0
	_act2.modulate.a = 0.0
	_act1.position.y = 0.0
	_act2.position.y = 0.0

	_active_tween = create_tween()
	_active_tween.tween_interval(LEAD_IN)
	_active_tween.tween_callback(act_changed.emit.bind(1))
	_fade_in(_act1)
	_active_tween.parallel().tween_property(_bar_top, "modulate:a", 1.0, FADE_IN)
	_active_tween.parallel().tween_property(_bar_bottom, "modulate:a", 1.0, FADE_IN)
	_active_tween.tween_interval(TITLE_HOLD)
	_fade_out(_act1)

	_active_tween.tween_interval(BETWEEN_ACTS)
	_active_tween.tween_callback(act_changed.emit.bind(2))
	_fade_in(_act2)
	_active_tween.tween_interval(CREDIT_HOLD)
	_fade_out(_act2)
	_active_tween.parallel().tween_property(_bar_top, "modulate:a", 0.0, FADE_OUT)
	_active_tween.parallel().tween_property(_bar_bottom, "modulate:a", 0.0, FADE_OUT)
	_active_tween.tween_callback(_on_sequence_completed)

func _fade_in(act: Control) -> void:
	_active_tween.tween_property(act, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _fade_out(act: Control) -> void:
	_active_tween.tween_property(act, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_active_tween.parallel().tween_method(func(progress: float):
		act.position.y = -_exit_travel * progress
	, 0.0, 1.0, FADE_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func interrupt() -> void:
	if not is_running:
		return
	is_running = false
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.tween_property(_root, "modulate:a", 0.0, 0.35)
	_active_tween.tween_callback(_on_sequence_completed)

func _on_sequence_completed() -> void:
	is_running = false
	intro_finished.emit()
	queue_free()
