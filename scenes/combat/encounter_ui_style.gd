extends RefCounted

const Palette := preload("res://scenes/combat/encounter_ui_palette.gd")
const DEFAULT_PALETTE := preload("res://scenes/combat/sparkle_ui_palette.tres")

static func text_label(value: String, point_size: int, color: Color, palette: Palette) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(palette.shade, .88))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", point_size)
	return label

static func command_font() -> FontVariation:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Serif CJK SC", "SimSun", "Songti SC"])
	var lettering := FontVariation.new()
	lettering.base_font = font
	lettering.variation_embolden = .24
	return lettering

static var _interface_font: SystemFont

static func interface_font() -> SystemFont:
	if _interface_font == null:
		_interface_font = SystemFont.new()
		_interface_font.font_names = PackedStringArray(["Noto Sans CJK SC", "Microsoft YaHei UI", "PingFang SC"])
		_interface_font.font_weight = 500
	return _interface_font

static func row(gap: int) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box

static func column(gap: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box

static func bottom_fade(palette: Palette) -> TextureRect:
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, .45, 1.0])
	colors.colors = PackedColorArray([Color(palette.shade, 0), Color(palette.shade, .61), Color(palette.shade, .91)])
	var texture := GradientTexture2D.new()
	texture.gradient = colors
	texture.fill_to = Vector2.DOWN
	texture.width = 1
	texture.height = 256
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.anchor_right = 1.0
	rect.anchor_top = 1.0
	rect.anchor_bottom = 1.0
	rect.offset_top = -270
	return rect
