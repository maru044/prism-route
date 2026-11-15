extends RefCounted

const Palette := preload("res://scenes/combat/encounter_ui_palette.gd")
const DEFAULT_PALETTE := preload("res://scenes/combat/sparkle_ui_palette.tres")
const PAPER_PLATE := preload("res://scenes/combat/encounter_paper.gdshader")
const InkMark := preload("res://scenes/combat/encounter_ink_mark.gd")

static func text_label(value: String, point_size: int, color: Color, palette: Palette) -> Label:
	var label := Label.new()
	label.text = value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(palette.shade, .88))
	label.add_theme_constant_override("outline_size", 0 if palette.paper else 4)
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

static func paper_material(palette: Palette, density: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PAPER_PLATE
	material.set_shader_parameter("face", palette.paper_face)
	material.set_shader_parameter("tint", palette.paper_wash)
	material.set_shader_parameter("light_color", palette.paper_active)
	material.set_shader_parameter("pencil", palette.paper_ink)
	material.set_shader_parameter("density", density)
	return material

static func ink_mark(parent: Control, mark_name: String, color: Color, rect: Rect2) -> Control:
	var mark := InkMark.new()
	mark.mark = mark_name
	mark.ink = color
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(mark)
	mark.position = rect.position
	mark.size = rect.size
	return mark

static func paper_backing(area: Control, palette: Palette, padding := Vector2.ZERO) -> ColorRect:
	var parent := area.get_parent()
	var surface := ColorRect.new()
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := paper_material(palette, .89)
	material.set_shader_parameter("sheet", 1.0)
	surface.material = material
	parent.add_child(surface)
	parent.move_child(surface, area.get_index())
	var fit := func():
		surface.position = area.position - padding
		surface.size = area.size + padding * 2.0
		surface.visible = area.visible
		material.set_shader_parameter("plate_size", surface.size)
	area.item_rect_changed.connect(fit)
	area.visibility_changed.connect(fit)
	fit.call()
	return surface

static func paper_dialogue_dock(parent: Control, palette: Palette, gap: int) -> VBoxContainer:
	var frame := MarginContainer.new()
	frame.anchor_left = .188
	frame.anchor_right = .812
	frame.anchor_top = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_top = -45
	frame.offset_bottom = -45
	frame.grow_vertical = Control.GROW_DIRECTION_BEGIN
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_constant_override("margin_left", 44)
	frame.add_theme_constant_override("margin_right", 40)
	frame.add_theme_constant_override("margin_top", 22)
	frame.add_theme_constant_override("margin_bottom", 23)
	parent.add_child(frame)
	var sheet := paper_backing(frame, palette)
	var sketch := ink_mark(sheet, "coast", Color(palette.paper_ink, .46), Rect2())
	sketch.anchor_left = 1.0
	sketch.anchor_right = 1.0
	sketch.anchor_top = 1.0
	sketch.anchor_bottom = 1.0
	sketch.offset_left = -230
	sketch.offset_right = -16
	sketch.offset_top = -102
	sketch.offset_bottom = -11
	var dock := column(gap)
	frame.add_child(dock)
	return dock

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
