extends Control

signal closed

const Client := preload("res://scripts/ai/game_llm_client.gd")
const UI := preload("res://scenes/combat/encounter_ui_style.gd")
const Card := preload("res://scenes/combat/encounter_card.gd")
const PALETTE := preload("res://scenes/combat/temple_paper_palette.tres")

var _client := Client.new()
var _channel := Client.DIALOGUE
var _routes := {}
var _url := LineEdit.new()
var _model := LineEdit.new()
var _key := LineEdit.new()
var _remember := CheckButton.new()
var _status: Label


func _ready() -> void:
	add_child(_client)
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.custom_minimum_size.x = 680
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	center.add_child(margin)
	var page := Control.new()
	margin.add_child(page)
	var content := UI.column(13)
	page.add_child(content)
	content.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	content.minimum_size_changed.connect(func(): page.custom_minimum_size = content.get_combined_minimum_size())
	UI.paper_backing(content, PALETTE, Vector2(31, 29))

	var title := UI.text_label("API 连接", 36, PALETTE.text, PALETTE)
	title.add_theme_font_override("font", UI.command_font())
	content.add_child(title)
	var routes := UI.row(10)
	content.add_child(routes)
	var group := ButtonGroup.new()
	for entry in [[Client.DIALOGUE, "自由对话"], [Client.ASSISTANT, "游戏助手"]]:
		var button := _button(routes, entry[1], _load_route.bind(entry[0]))
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		_routes[entry[0]] = button

	_add_field(content, "接口地址", _url, "https://服务地址/v1")
	_add_field(content, "模型 ID", _model)
	_add_field(content, "API 密钥", _key)
	_key.secret = true
	_remember.text = "在本机记住密钥（明文保存）"
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_remember.add_theme_color_override(color, PALETTE.text)
	content.add_child(_remember)
	_status = UI.text_label("", 20, PALETTE.accent, PALETTE)
	content.add_child(_status)
	var actions := UI.row(12)
	content.add_child(actions)
	_button(actions, "保存", _save)
	_button(actions, "返回标题", _close)
	page.custom_minimum_size = content.get_combined_minimum_size()


func open() -> void:
	show()
	_load_route(_channel)
	_url.grab_focus()


func _add_field(parent: VBoxContainer, text: String, field: LineEdit, hint := "") -> void:
	parent.add_child(UI.text_label(text, 20, PALETTE.text, PALETTE))
	field.placeholder_text = hint
	field.custom_minimum_size.y = 45
	field.add_theme_font_size_override("font_size", 22)
	field.add_theme_color_override("font_color", PALETTE.text)
	field.add_theme_color_override("font_placeholder_color", PALETTE.secondary)
	field.add_theme_color_override("caret_color", PALETTE.text)
	field.add_theme_color_override("selection_color", PALETTE.paper_active)
	field.add_theme_color_override("font_selected_color", PALETTE.text)
	var paper := StyleBoxFlat.new()
	paper.bg_color = PALETTE.paper_face
	paper.border_color = PALETTE.paper_ink
	paper.set_border_width_all(1)
	paper.content_margin_left = 10
	paper.content_margin_right = 10
	field.add_theme_stylebox_override("normal", paper)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = PALETTE.paper_ink
	focus.set_border_width_all(2)
	field.add_theme_stylebox_override("focus", focus)
	parent.add_child(field)


func _button(parent: Container, caption: String, callback: Callable) -> Button:
	var button := Card.new()
	button.configure(caption, PALETTE, Card.Kind.CONTINUE)
	button.custom_minimum_size = Vector2(130, 44)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _load_route(channel: String) -> void:
	_channel = channel
	_routes[channel].set_pressed_no_signal(true)
	var profile: Dictionary = _client.profiles[channel]
	_url.text = profile.url
	_model.text = profile.model
	_key.text = profile.key
	var config := ConfigFile.new()
	_remember.button_pressed = config.load(Client.SETTINGS_PATH) == OK and not str(config.get_value(channel, "key", "")).is_empty()
	_status.text = ""


func _save() -> void:
	var result := _client.save_profile(_channel, _url.text, _model.text, _key.text, _remember.button_pressed)
	_status.text = "已保存当前连接" if result.is_empty() else result


func _close() -> void:
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()
