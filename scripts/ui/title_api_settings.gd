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
var _stream_usage := CheckBox.new()
var _model_transport := Client.Transport.new()
var _model_menu := PopupMenu.new()
var _fetch_button: Button
var _status: Label
var _source_container: VBoxContainer
var _source_cloud_btn: Button
var _source_local_btn: Button
var _selected_source := Client.SOURCE_LOCAL_AIRP


func _ready() -> void:
	add_child(_client)
	add_child(_model_transport)
	_model_transport.finished.connect(_models_received)
	add_child(_model_menu)
	_model_menu.max_size.y = 360
	var menu_paper := StyleBoxFlat.new()
	menu_paper.bg_color = PALETTE.paper_face
	menu_paper.border_color = PALETTE.paper_ink
	menu_paper.set_border_width_all(1)
	var menu_hover := StyleBoxFlat.new()
	menu_hover.bg_color = PALETTE.paper_active
	_model_menu.add_theme_stylebox_override("panel", menu_paper)
	_model_menu.add_theme_stylebox_override("hover", menu_hover)
	_model_menu.add_theme_color_override("font_color", PALETTE.text)
	_model_menu.add_theme_color_override("font_hover_color", PALETTE.text)
	_model_menu.add_theme_font_size_override("font_size", 20)
	_model_menu.index_pressed.connect(_choose_model)
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

	var title := UI.text_label("API 配置", 36, PALETTE.text, PALETTE)
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

	_source_container = UI.column(6)
	content.add_child(_source_container)
	_source_container.add_child(UI.text_label("自由对话来源", 20, PALETTE.text, PALETTE))
	var source_row := UI.row(10)
	_source_container.add_child(source_row)
	var source_group := ButtonGroup.new()
	_source_local_btn = _button(source_row, "本地口上（脱机游玩）", _on_source_selected.bind(Client.SOURCE_LOCAL_AIRP))
	_source_local_btn.toggle_mode = true
	_source_local_btn.button_group = source_group
	_source_local_btn.size_flags_horizontal = SIZE_EXPAND_FILL

	_source_cloud_btn = _button(source_row, "云端 API（大模型生成）", _on_source_selected.bind(Client.SOURCE_CLOUD_API))
	_source_cloud_btn.toggle_mode = true
	_source_cloud_btn.button_group = source_group
	_source_cloud_btn.size_flags_horizontal = SIZE_EXPAND_FILL

	_add_field(content, "API 基础地址", _url, "https://服务域名")
	_url.drag_and_drop_selection_enabled = false
	_url.tooltip_text = "可直接粘贴酒馆的自定义 OpenAI 端点。服务地址自带 /v1 或其他路径时，请一并填入。"
	content.add_child(UI.text_label("模型 ID", 20, PALETTE.text, PALETTE))
	var model_row := UI.row(10)
	content.add_child(model_row)
	_style_field(_model, "从接口选择，或填写模型 ID")
	_model.size_flags_horizontal = SIZE_EXPAND_FILL
	model_row.add_child(_model)
	_fetch_button = _button(model_row, "获取模型", _fetch_models)
	_add_field(content, "API 密钥", _key)
	_key.secret = true
	_stream_usage.text = "请求流式用量统计"
	_stream_usage.tooltip_text = "用于区分推理和正文的 token 用量。仅在服务支持流式用量统计时开启。"
	_stream_usage.add_theme_font_override("font", UI.interface_font())
	_stream_usage.add_theme_font_size_override("font_size", 20)
	_stream_usage.add_theme_color_override("font_color", PALETTE.text)
	content.add_child(_stream_usage)
	_url.text_changed.connect(_connection_edited)
	_key.text_changed.connect(_connection_edited)
	_status = UI.text_label("", 20, PALETTE.accent, PALETTE)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 27
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
	_style_field(field, hint)
	parent.add_child(field)


func _style_field(field: LineEdit, hint: String) -> void:
	field.placeholder_text = hint
	field.editable = true
	field.selecting_enabled = true
	field.shortcut_keys_enabled = true
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


func _button(parent: Container, caption: String, callback: Callable) -> Button:
	var button := Card.new()
	button.configure(caption, PALETTE, Card.Kind.CONTINUE)
	button.custom_minimum_size = Vector2(130, 44)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _on_source_selected(source_val: String) -> void:
	_selected_source = source_val
	_update_source_ui_state()


func _update_source_ui_state() -> void:
	var is_local_offline := (_channel == Client.DIALOGUE and _selected_source == Client.SOURCE_LOCAL_AIRP)
	_url.editable = not is_local_offline
	_model.editable = not is_local_offline
	_key.editable = not is_local_offline
	_fetch_button.disabled = is_local_offline
	_stream_usage.disabled = is_local_offline
	if is_local_offline:
		var readiness: Dictionary = _client.check_local_airp_readiness()
		if readiness.get("ready", false):
			_status.text = "已选择本地口上 · 全岛 49 位角色词库就绪 · 离线可用"
		else:
			_status.text = "本地组件缺失 · " + str(readiness.get("error", "未就绪"))
	elif _status.text.contains("本地口上") or _status.text.contains("本地组件缺失"):
		_status.text = ""


func _load_route(channel: String) -> void:
	_connection_edited()
	_channel = channel
	_routes[channel].set_pressed_no_signal(true)
	var is_dialogue := channel == Client.DIALOGUE
	_source_container.visible = is_dialogue
	if is_dialogue:
		_selected_source = _client.get_dialogue_source()
		if _selected_source == Client.SOURCE_LOCAL_AIRP:
			_source_local_btn.set_pressed_no_signal(true)
		else:
			_source_cloud_btn.set_pressed_no_signal(true)
	var profile: Dictionary = _client.profiles[channel]
	_url.text = profile.url
	_model.text = profile.model
	_key.text = profile.key
	_stream_usage.visible = is_dialogue
	_stream_usage.set_pressed_no_signal(profile.get("include_stream_usage", false))
	_update_source_ui_state()


func _connection_edited(_text := "") -> void:
	_model_transport.cancel()
	_model_menu.hide()
	_model_menu.clear()
	_fetch_button.disabled = false
	_status.text = ""


func _fetch_models() -> void:
	_connection_edited()
	var error := _model_transport.fetch_models(_url.text.strip_edges(), _key.text.strip_edges())
	if not error.is_empty():
		_status.text = error
		print("[LLM 报错-获取模型] %sZ · %s" % [Time.get_datetime_string_from_system(true), error])
		push_error("[LLM 报错-获取模型] %sZ · %s" % [Time.get_datetime_string_from_system(true), error])
		return
	_fetch_button.disabled = true
	_status.text = "正在获取模型"


func _models_received(result: Dictionary, error: String) -> void:
	_fetch_button.disabled = false
	if not error.is_empty():
		_status.text = error
		print("[LLM 报错-获取模型] %sZ · %s" % [Time.get_datetime_string_from_system(true), error])
		push_error("[LLM 报错-获取模型] %sZ · %s" % [Time.get_datetime_string_from_system(true), error])
		return
	var ids: PackedStringArray = result.models
	for id: String in ids:
		_model_menu.add_item(id)
	_status.text = "找到 %d 个模型，请选择。" % ids.size()
	var field := _model.get_global_rect()
	_model_menu.popup(Rect2i(Vector2i(field.position + Vector2(0, field.size.y)), Vector2i(int(field.size.x), 0)))


func _choose_model(index: int) -> void:
	_model.text = _model_menu.get_item_text(index)
	_status.text = "已选择模型，点击「保存」应用。"


func _save() -> void:
	_connection_edited()
	var result := _client.save_profile(_channel, _url.text, _model.text, _key.text, _stream_usage.button_pressed, _selected_source)
	if result.is_empty():
		_status.text = "已保存设置。" + (" 本地口上已就绪。" if _channel == Client.DIALOGUE and _selected_source == Client.SOURCE_LOCAL_AIRP else " 已保存当前连接到本机。")
	else:
		_status.text = result


func _close() -> void:
	_connection_edited()
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _model_menu.visible:
			_model_menu.hide()
			return
		_close()
