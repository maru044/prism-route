extends CanvasLayer

signal panel_closed

const Client := preload("res://scripts/ai/game_llm_client.gd")
const Style := preload("res://scenes/combat/encounter_ui_style.gd")
const Card := preload("res://scenes/combat/encounter_card.gd")
const PAPER_PALETTE := preload("res://scenes/combat/temple_paper_palette.tres")

var client := Client.new()
var palette: Style.Palette = PAPER_PALETTE

var _surface := Control.new()
var _title := Label.new()
var _scroll := ScrollContainer.new()
var _messages := Style.column(15)
var _turn_views: Array[Dictionary] = []
var _empty: Label
var _draft := TextEdit.new()
var _status := Label.new()
var _status_row: HBoxContainer
var _actions: HBoxContainer
var _send: Button
var _retry: Button
var _continue: Button
var _undo: Button
var _previous: Button
var _next: Button
var _version: Label
var _confirm: Button
var _action_turn := -1
var _copy_diagnostic: Button
var _drafts := {}
var _thread_id := ""
var _expanded_reports := {}
var _follow_latest := true
var _follow_queued := false

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
	_reset_transcript()
	var speaker := str(context.get("npc_name", ""))
	_title.text = "游戏助手" if route == Client.ASSISTANT else ("自由对话" if speaker.is_empty() else speaker + "  ·  自由对话")
	client.open(route, scope, context)
	if not client.configured():
		client.status = "请在标题界面的「API 配置」中填写连接。"
		_refresh()
	show()
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

func save_snapshot() -> Dictionary:
	var drafts := _drafts.duplicate()
	if visible and not _thread_id.is_empty():
		drafts[_thread_id] = _draft.text if not _draft.text.is_empty() else client.pending_draft()
	return {"threads": client.save_threads(), "drafts": drafts}

func restore_snapshot(snapshot: Dictionary) -> void:
	client.restore_threads(snapshot.get("threads", {}))
	var drafts: Variant = snapshot.get("drafts", {})
	if drafts is Dictionary:
		for id: Variant in drafts:
			if id is String and drafts[id] is String:
				_drafts[id] = drafts[id]

func _build_ui() -> void:
	add_child(_surface)
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	var frame := MarginContainer.new()
	_surface.add_child(frame)
	frame.anchor_left = .15
	frame.anchor_right = .85
	frame.anchor_top = .10
	frame.anchor_bottom = .90
	frame.add_theme_constant_override("margin_left", 37)
	frame.add_theme_constant_override("margin_right", 37)
	frame.add_theme_constant_override("margin_top", 25)
	frame.add_theme_constant_override("margin_bottom", 26)
	var paper := Style.paper_backing(frame, palette)
	var shadow := ColorRect.new()
	shadow.color = Color("#233e5430")
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.add_child(shadow)
	paper.move_child(shadow, 0)
	shadow.show_behind_parent = true
	shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shadow.offset_top = 6
	shadow.offset_left = 5
	shadow.offset_right = 5
	shadow.offset_bottom = 7
	var dock := Style.column(12)
	frame.add_child(dock)

	var top := Style.row(12)
	dock.add_child(top)
	_title.add_theme_font_override("font", Style.command_font())
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", palette.speaker)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	_button(top, "关闭", close_panel).tooltip_text = "Esc"
	_add_rule(dock)

	var transcript_frame := PanelContainer.new()
	transcript_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	transcript_frame.add_theme_stylebox_override("panel", _paper_box(Color(palette.paper_face, .52), 24, 18))
	dock.add_child(transcript_frame)
	_scroll.name = "ChatHistory"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size.y = 130
	transcript_frame.add_child(_scroll)
	var scrollbar := _scroll.get_v_scroll_bar()
	scrollbar.add_theme_stylebox_override("scroll", _paper_box(Color(palette.paper_ink, .12), 4, 0))
	scrollbar.add_theme_stylebox_override("grabber", _paper_box(Color(palette.paper_ink, .47), 4, 4))
	scrollbar.add_theme_stylebox_override("grabber_highlight", _paper_box(Color(palette.paper_ink, .62), 4, 4))
	scrollbar.add_theme_stylebox_override("grabber_pressed", _paper_box(Color(palette.paper_ink, .80), 4, 4))
	scrollbar.value_changed.connect(_on_scroll_moved)
	scrollbar.changed.connect(_queue_follow_latest)
	_messages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_messages)
	_empty = Style.text_label("输入消息开始对话", 21, palette.secondary, palette)
	_empty.add_theme_font_override("font", Style.interface_font())
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.custom_minimum_size.y = 62
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_messages.add_child(_empty)

	_status.add_theme_color_override("font_color", palette.accent)
	_status.add_theme_font_override("font", Style.interface_font())
	_status.add_theme_font_size_override("font_size", 17)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_row = Style.row(12)
	dock.add_child(_status_row)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_row.add_child(_status)
	_copy_diagnostic = _button(_status_row, "复制诊断", func(): DisplayServer.clipboard_set(client.diagnostic))
	_copy_diagnostic.hide()
	_status_row.hide()

	_actions = Style.row(10)
	dock.add_child(_actions)
	_undo = _button(_actions, "倒回", _undo_turn)
	_retry = _button(_actions, "重新生成", client.retry)
	_continue = _button(_actions, "续写", client.continue_reply)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_actions.add_child(spacer)
	_previous = _button(_actions, "上一版", func(): client.swipe(-1))
	_version = Style.text_label("", 17, palette.secondary, palette)
	_version.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_actions.add_child(_version)
	_next = _button(_actions, "下一版", func(): client.swipe(1))
	_confirm = _button(_actions, "确认", client.confirm_action)
	_confirm.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_confirm.hide()

	var prompt := Style.row(12)
	dock.add_child(prompt)
	_draft.custom_minimum_size.y = 82
	_draft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_draft.placeholder_text = "输入消息 · Ctrl+Enter 发送"
	_draft.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_draft.add_theme_font_override("font", Style.interface_font())
	_draft.add_theme_font_size_override("font_size", 22)
	_draft.add_theme_color_override("font_color", palette.text)
	_draft.add_theme_color_override("font_placeholder_color", palette.secondary)
	_draft.add_theme_color_override("caret_color", palette.speaker)
	_draft.add_theme_color_override("selection_color", palette.paper_active)
	_draft.add_theme_stylebox_override("normal", _paper_box(palette.paper_face, 15, 12, .36))
	var focus := _paper_box(Color.TRANSPARENT, 15, 12, .90)
	focus.draw_center = false
	_draft.add_theme_stylebox_override("focus", focus)
	prompt.add_child(_draft)
	_send = _button(prompt, "发送", _send_or_stop)
	_send.custom_minimum_size.x = 132
	_send.add_theme_font_size_override("font_size", 24)
	_send.set_featured(true)

func _add_rule(parent: Container) -> void:
	var divider := ColorRect.new()
	divider.color = Color(palette.paper_ink, .44)
	divider.custom_minimum_size.y = 1
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(divider)

func _paper_box(color: Color, x_padding: float, y_padding: float, ink := 0.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = x_padding
	box.content_margin_right = x_padding
	box.content_margin_top = y_padding
	box.content_margin_bottom = y_padding
	box.set_corner_radius_all(3)
	if ink > 0:
		box.border_color = Color(palette.paper_ink, ink)
		box.set_border_width_all(1)
	return box

func _button(parent: Container, label: String, callback: Callable) -> Button:
	var button := Card.new()
	button.configure(label, palette, Card.Kind.CONTINUE)
	button.custom_minimum_size = Vector2(maxf(76, float(label.length()) * 19 + 24), 38)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

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
		if not client.pending:
			_send_or_stop()

func _send_or_stop() -> void:
	if client.pending:
		client.stop()
	elif not client.configured():
		client.status = "请在标题界面的「API 配置」中填写连接。"
		_refresh()
	elif client.send(_draft.text):
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
	var last: Dictionary = client.history.back() if not client.history.is_empty() else {}
	_refresh_transcript()
	_status.text = client.status
	if client.omitted_turns > 0:
		_status.text += ("\n" if not _status.text.is_empty() else "") + "本次上下文省略了 %d 个较早回合。" % client.omitted_turns
	if client.incomplete_turns > 0:
		_status.text += ("\n" if not _status.text.is_empty() else "") + "%d 个未完成回合未纳入本次上下文。" % client.incomplete_turns
	_copy_diagnostic.visible = not client.diagnostic.is_empty()
	_status_row.visible = not _status.text.is_empty() or _copy_diagnostic.visible
	_send.text = "停止" if client.pending else "发送"
	_draft.placeholder_text = "生成中，可先输入下一条消息" if client.pending else "输入消息 · Ctrl+Enter 发送"
	_undo.disabled = last.is_empty() or client.pending
	_retry.disabled = not client.can_retry()
	_continue.visible = client.route == Client.DIALOGUE
	_continue.disabled = not client.can_continue_reply()
	var has_versions: bool = last.get("replies", []).size() > 1
	_previous.visible = has_versions
	_next.visible = has_versions
	_version.visible = has_versions
	if has_versions:
		_version.text = "%d / %d" % [last.active + 1, last.replies.size()]
	_previous.disabled = client.pending
	_next.disabled = client.pending

func _refresh_transcript() -> void:
	var count := client.history.size()
	if _action_turn >= count:
		_detach_action()
	while _turn_views.size() > count:
		_remove_last_turn()
	while _turn_views.size() < count:
		var index := _turn_views.size()
		_add_turn(index)
		_update_reply(index)
	if count > 0:
		_update_reply(count - 1)
	_empty.visible = count == 0
	_refresh_action()
	_queue_follow_latest()

func _reset_transcript() -> void:
	_detach_action()
	while not _turn_views.is_empty():
		_remove_last_turn()
	_follow_latest = true
	_scroll.scroll_vertical = 0

func _remove_last_turn() -> void:
	var view: Dictionary = _turn_views.pop_back()
	var row: Control = view.root
	_messages.remove_child(row)
	row.queue_free()

func _add_turn(index: int) -> void:
	var turn: Dictionary = client.history[index]
	var row := Style.column(10)
	_messages.add_child(row)
	var player := _message_card(row, "你", true)
	var question := _message_text(22, palette.text)
	question.text = turn.user
	player.add_child(question)
	var speaker := str(client.context.get("npc_name", "自由对话")) if client.route == Client.DIALOGUE else "游戏助手"
	var reply_box := _message_card(row, speaker, false)
	var body := _message_text(22, palette.text)
	reply_box.add_child(body)
	var report_button := _button(reply_box, "▸ 查看报告", _toggle_report.bind(index))
	report_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var report := _message_text(18, palette.secondary)
	reply_box.add_child(report)
	var notice := _message_text(18, palette.secondary)
	reply_box.add_child(notice)
	_turn_views.append({
		"root": row, "reply_lane": reply_box.get_parent().get_parent(), "reply_box": reply_box,
		"body": body, "report_button": report_button, "report": report, "notice": notice, "reply_key": Vector2i(index, -1),
	})

func _message_card(row: VBoxContainer, speaker: String, is_player: bool) -> VBoxContainer:
	var lane := Style.row(0)
	row.add_child(lane)
	var inset := Control.new()
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_player:
		lane.add_child(inset)
	var card := PanelContainer.new()
	var tint := palette.paper_face.lerp(palette.paper_wash, .87 if is_player else .15)
	card.add_theme_stylebox_override("panel", _paper_box(tint, 20, 13, .28))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 8.0
	lane.add_child(card)
	if not is_player:
		lane.add_child(inset)
	var content := Style.column(6)
	card.add_child(content)
	var name_label := Style.text_label(speaker, 18, palette.accent if is_player else palette.speaker, palette)
	name_label.add_theme_font_override("font", Style.interface_font())
	content.add_child(name_label)
	return content

func _message_text(point_size: int, color: Color) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.fit_content = true
	text.scroll_active = false
	text.mouse_force_pass_scroll_events = true
	text.selection_enabled = true
	text.context_menu_enabled = true
	text.add_theme_color_override("default_color", color)
	text.add_theme_font_override("normal_font", Style.interface_font())
	text.add_theme_font_size_override("normal_font_size", point_size)
	text.add_theme_constant_override("line_separation", 5)
	return text

func _update_reply(index: int) -> void:
	var view := _turn_views[index]
	var turn: Dictionary = client.history[index]
	var shown: Dictionary = turn.replies[turn.active] if turn.active >= 0 else {}
	var reply_index: int = turn.active
	var streaming := index == client.history.size() - 1 and client.pending and (client.is_continuing() or not client.partial.is_empty())
	if streaming and not client.is_continuing():
		shown = {}
		reply_index = turn.replies.size()
	var fragment := client.partial if streaming else ""
	var sections := Client.reply_sections(shown, fragment, streaming) if client.route == Client.DIALOGUE \
		else {"body": shown.get("text", "") + fragment, "report": ""}
	var body: String = sections.body
	var note: String = "" if streaming else shown.get("note", "")
	if not note.is_empty():
		body += ("\n" if not body.is_empty() else "") + "〔%s〕" % note
	var notice: String = turn.get("result", {}).get("notice", "")
	_set_message(view.body, body)
	_set_message(view.notice, notice)
	view.reply_key = Vector2i(index, reply_index)
	var has_report: bool = not sections.report.is_empty()
	var expanded := has_report and _expanded_reports.has(view.reply_key)
	view.report_button.visible = has_report
	view.report_button.text = "▾ 收起报告" if expanded else "▸ 查看报告"
	_set_message(view.report, sections.report if expanded else "")
	view.reply_lane.visible = not body.is_empty() or not notice.is_empty() or has_report or _action_turn == index

func _set_message(label: RichTextLabel, value: String) -> void:
	if label.text != value:
		label.text = value
	label.visible = not value.is_empty()

func _toggle_report(index: int) -> void:
	var key: Vector2i = _turn_views[index].reply_key
	_follow_latest = false
	if _expanded_reports.has(key):
		_expanded_reports.erase(key)
	else:
		_expanded_reports[key] = true
	_update_reply(index)

func _detach_action() -> void:
	_confirm.hide()
	if _confirm.get_parent() != _actions:
		_confirm.reparent(_actions, false)
	_action_turn = -1

func _refresh_action() -> void:
	var offer := client.action_offer()
	var index: int = offer.get("turn", -1)
	if index != _action_turn:
		var previous := _action_turn
		_detach_action()
		if previous >= 0 and previous < _turn_views.size():
			_update_reply(previous)
		if index >= 0 and index < _turn_views.size():
			_action_turn = index
			_confirm.reparent(_turn_views[index].reply_box, false)
			_turn_views[index].reply_lane.show()
			_confirm.show()
	if _action_turn >= 0:
		_confirm.text = offer.label
		_confirm.custom_minimum_size.x = float(_confirm.text.length()) * 19 + 24
	_confirm.disabled = client.pending

func _on_scroll_moved(value: float) -> void:
	var bar := _scroll.get_v_scroll_bar()
	_follow_latest = value >= bar.max_value - bar.page - 24.0

func _queue_follow_latest() -> void:
	if _follow_latest and not _follow_queued:
		_follow_queued = true
		_scroll_to_latest.call_deferred()

func _scroll_to_latest() -> void:
	_follow_queued = false
	if _follow_latest:
		var bar := _scroll.get_v_scroll_bar()
		_scroll.scroll_vertical = ceili(bar.max_value - bar.page)
