extends CanvasLayer

signal panel_closed

const Client := preload("res://scripts/ai/game_llm_client.gd")
const Style := preload("res://scenes/combat/encounter_ui_style.gd")
const Card := preload("res://scenes/combat/encounter_card.gd")

var client := Client.new()
var palette: Style.Palette = Style.DEFAULT_PALETTE

var _surface := Control.new()
var _title := Label.new()
var _transcript := RichTextLabel.new()
var _draft := TextEdit.new()
var _status := Label.new()
var _settings := VBoxContainer.new()
var _url := LineEdit.new()
var _model := LineEdit.new()
var _key := LineEdit.new()
var _remember := CheckButton.new()
var _send: Button
var _retry: Button
var _continue: Button
var _undo: Button
var _previous: Button
var _next: Button
var _teleport: Button
var _drafts := {}
var _thread_id := ""
var _expanded_reports := {}

func _ready() -> void:
	layer = 25
	hide()
	add_child(client)
	add_to_group("world_input_blockers")
	_build_ui()
	client.changed.connect(_refresh)

func open_panel(route: String, scope: String, context: Dictionary = {}) -> void:
	if visible:
		return
	_thread_id = route + "/" + scope
	_draft.text = _drafts.get(_thread_id, "")
	_expanded_reports.clear()
	client.open(route, scope, context)
	_title.text = str(context.get("char", "自由对话")) + "  ·  自由对话" if route == Client.DIALOGUE else "游戏助手"
	_load_settings()
	_settings.visible = not client.configured()
	show()
	if _settings.visible:
		_url.grab_focus()
	else:
		_draft.grab_focus()

func close_panel() -> void:
	if not visible:
		return
	client.stop()
	_drafts[_thread_id] = _draft.text
	get_viewport().gui_release_focus()
	hide()
	panel_closed.emit()

func is_world_input_locked() -> bool:
	return visible

func _build_ui() -> void:
	add_child(_surface)
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	var fade := Style.bottom_fade(palette)
	fade.offset_top = -680.0
	_surface.add_child(fade)
	var dock := Style.column(8)
	dock.anchor_left = .168
	dock.anchor_right = .832
	dock.anchor_top = 1.0
	dock.anchor_bottom = 1.0
	dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dock.offset_bottom = -38.0
	dock.offset_top = -38.0
	_surface.add_child(dock)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	dock.add_child(top)
	_title.add_theme_font_override("font", Style.command_font())
	_title.add_theme_font_size_override("font_size", 25)
	_title.add_theme_color_override("font_color", palette.speaker)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	_button(top, "连接设置", _toggle_settings)
	_button(top, "关闭", close_panel)

	_transcript.custom_minimum_size.y = 246
	_transcript.selection_enabled = true
	_transcript.scroll_following = true
	_transcript.add_theme_color_override("default_color", palette.text)
	_transcript.add_theme_font_override("normal_font", Style.command_font())
	_transcript.add_theme_font_size_override("normal_font_size", 21)
	_transcript.add_theme_color_override("font_outline_color", palette.shade)
	_transcript.add_theme_constant_override("outline_size", 3)
	_transcript.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_transcript.meta_clicked.connect(_toggle_report)
	dock.add_child(_transcript)

	dock.add_child(_settings)
	for field in [_url, _model, _key]:
		field.custom_minimum_size.y = 34
		_settings.add_child(field)
	_url.placeholder_text = "接口地址，例如 https://服务地址/v1"
	_model.placeholder_text = "模型 ID"
	_key.placeholder_text = "API 密钥"
	_key.secret = true
	var save_row := HBoxContainer.new()
	_settings.add_child(save_row)
	_remember.text = "在本机记住密钥（明文保存）"
	save_row.add_child(_remember)
	_button(save_row, "保存", _save_settings)

	_status.add_theme_color_override("font_color", palette.accent)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(_status)
	var prompt := HBoxContainer.new()
	prompt.add_theme_constant_override("separation", 8)
	dock.add_child(prompt)
	_draft.custom_minimum_size.y = 66
	_draft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_draft.placeholder_text = "输入消息 · Ctrl+Enter 发送"
	_draft.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	prompt.add_child(_draft)
	_send = _button(prompt, "发送", _send_or_stop)
	_send.custom_minimum_size.x = 112

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 7)
	dock.add_child(actions)
	_undo = _button(actions, "倒回", _undo_turn)
	_retry = _button(actions, "重新生成", client.retry)
	_continue = _button(actions, "续写", client.continue_reply)
	_previous = _button(actions, "上一版", func(): client.swipe(-1))
	_next = _button(actions, "下一版", func(): client.swipe(1))
	_teleport = _button(actions, "确认传送", client.confirm_teleport)

func _button(parent: Container, label: String, callback: Callable) -> Button:
	var button := Card.new()
	button.configure(label, palette, Card.Kind.CONTINUE)
	button.custom_minimum_size = Vector2(82, 36)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _toggle_settings() -> void:
	if client.pending:
		return
	_settings.visible = not _settings.visible
	if _settings.visible:
		_load_settings()
		_url.grab_focus()
	else:
		_draft.grab_focus()

func _load_settings() -> void:
	var profile: Dictionary = client.profiles[client.route]
	_url.text = profile.url
	_model.text = profile.model
	_key.text = profile.key
	var config := ConfigFile.new()
	_remember.button_pressed = config.load(Client.SETTINGS_PATH) == OK and not str(config.get_value(client.route, "key", "")).is_empty()

func _save_settings() -> void:
	if client.pending:
		return
	client.status = client.save_profile(client.route, _url.text, _model.text, _key.text, _remember.button_pressed)
	if client.status.is_empty():
		_settings.hide()
		_draft.grab_focus()
	_refresh()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if client.pending:
			client.stop()
		else:
			close_panel()
	elif event.keycode == KEY_ENTER and event.ctrl_pressed:
		get_viewport().set_input_as_handled()
		_send_or_stop()

func _send_or_stop() -> void:
	if client.pending:
		client.stop()
	elif not _settings.visible and client.send(_draft.text):
		_draft.clear()
		_draft.grab_focus()

func _undo_turn() -> void:
	var text: Variant = client.undo()
	if text is String:
		for key: Vector2i in _expanded_reports.keys():
			if key.x >= client.history.size():
				_expanded_reports.erase(key)
		_draft.text = text
		_draft.set_caret_line(_draft.get_line_count() - 1)
		_draft.set_caret_column(_draft.get_line(_draft.get_caret_line()).length())
		_draft.grab_focus()

func _refresh() -> void:
	var turns: Array = client.history
	var last: Dictionary = turns.back() if not turns.is_empty() else {}
	_transcript.clear()
	var speaker := str(client.context.get("char", "游戏助手"))
	for i in turns.size():
		var turn: Dictionary = turns[i]
		_line("你", turn.user, palette.accent)
		if turn.active >= 0:
			var response: Dictionary = turn.replies[turn.active]
			var raw: String = response.text
			var growing := i == turns.size() - 1 and client.is_continuing()
			if growing:
				raw += client.partial
			_reply_line(speaker, raw, "" if growing else response.note, Vector2i(i, turn.active), growing)
	if client.pending and not client.partial.is_empty() and not client.is_continuing():
		_reply_line(speaker, client.partial, "", Vector2i(turns.size() - 1, last.replies.size()), true)
	_status.text = client.status
	_send.text = "停止" if client.pending else "发送"
	_undo.disabled = last.is_empty() or client.pending
	_retry.disabled = not client.can_retry()
	_continue.visible = client.route == Client.DIALOGUE
	_continue.disabled = not client.can_continue_reply()
	var has_versions: bool = last.get("replies", []).size() > 1
	_previous.visible = has_versions
	_next.visible = has_versions
	_previous.disabled = client.pending
	_next.disabled = client.pending
	var destination: String = client.teleport_offer()
	_teleport.visible = not destination.is_empty()
	_teleport.disabled = client.pending
	_teleport.text = "确认传送"
	if _teleport.visible and client.world_status.is_valid():
		var state: Dictionary = client.world_status.call()
		for row: Dictionary in state.get("destinations", []):
			if row.id == destination:
				_teleport.text = "确认传送 · " + row.name
				break

func _line(speaker: String, text: String, color: Color) -> void:
	_transcript.push_color(color)
	_transcript.add_text(speaker + "  ")
	_transcript.pop()
	_transcript.add_text(text + "\n\n")

func _reply_line(speaker: String, raw: String, note: String, key: Vector2i, streaming: bool) -> void:
	var sections := Client.dialogue_sections(raw, streaming) if client.route == Client.DIALOGUE else {"body": raw, "report": ""}
	var body: String = sections.body
	if not note.is_empty():
		body += (" " if not body.is_empty() else "") + "〔%s〕" % note
	if not body.is_empty():
		_line(speaker, body, palette.speaker)
	var report: String = sections.report
	if report.is_empty():
		return
	var expanded := _expanded_reports.has(key)
	_transcript.push_color(palette.secondary)
	_transcript.push_meta(key, RichTextLabel.META_UNDERLINE_ON_HOVER)
	_transcript.add_text("▾ 收起报告" if expanded else "▸ 查看报告")
	_transcript.pop()
	_transcript.add_text("\n")
	if expanded:
		_transcript.add_text(report + "\n")
	_transcript.pop()
	_transcript.add_text("\n")

func _toggle_report(key: Variant) -> void:
	if not key is Vector2i:
		return
	var scroll_bar := _transcript.get_v_scroll_bar()
	var offset := scroll_bar.value
	if _expanded_reports.has(key):
		_expanded_reports.erase(key)
	else:
		_expanded_reports[key] = true
	_refresh()
	scroll_bar.set_value.call_deferred(offset)
