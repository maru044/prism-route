extends Control

signal selected(slot: String)
signal discard_requested
signal closed

const UI := preload("res://scenes/combat/encounter_ui_style.gd")
const CARD := preload("res://scenes/combat/encounter_card.gd")
const PALETTE := preload("res://scenes/combat/temple_paper_palette.tres")
const STORE := preload("res://scripts/progress/game_save_store.gd")

var mode := ""
var _content: VBoxContainer
var _status: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var paper := Control.new()
	center.add_child(paper)
	_content = UI.column(12)
	_content.custom_minimum_size.x = 620
	paper.add_child(_content)
	_content.minimum_size_changed.connect(func(): paper.custom_minimum_size = _content.get_combined_minimum_size())
	UI.paper_backing(_content, PALETTE, Vector2(26, 24))
	add_to_group("world_input_blockers")
	hide()

func open(kind: String) -> void:
	mode = kind
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	var title_map := {
		"save": "保存游戏",
		"load": "读取存档",
		"quit": "返回标题页面",
		"title": "返回标题页面",
		"confirm_load": "读取存档",
		"confirm_save": "覆盖存档"
	}
	var title: String = title_map.get(mode, "存档/读档")
	var heading := UI.text_label(title, 34, PALETTE.text, PALETTE)
	heading.add_theme_font_override("font", UI.command_font())
	_content.add_child(heading)
	if mode == "quit" or mode == "title":
		_content.add_child(UI.text_label("返回标题前要保存当前进度和对话吗？", 23, PALETTE.text, PALETTE))
		var choices := UI.row(8)
		_content.add_child(choices)
		_button(choices, "保存并返回", func(): selected.emit(STORE.AUTO))
		_button(choices, "不保存返回", func(): discard_requested.emit())
	elif mode == "confirm_load":
		_content.add_child(UI.text_label("读取存档会替换当前进度，未保存的改动会丢失。", 23, PALETTE.text, PALETTE))
		_button(_content, "确认读取", func(): selected.emit(""))
	elif mode == "confirm_save":
		_content.add_child(UI.text_label("要用当前进度覆盖所选存档吗？", 23, PALETTE.text, PALETTE))
		_button(_content, "确认覆盖", func(): selected.emit(""))
	else:
		var slots: Array = STORE.MANUAL if mode == "save" else STORE.SLOTS
		for slot: String in slots:
			var snapshot := STORE.read(slot)
			var summary := "空存档"
			if not snapshot.is_empty():
				var timestamp := int(snapshot.saved_at)
				var local_delta := int(Time.get_time_zone_from_system().bias) * 60
				var date := Time.get_datetime_string_from_unix_time(timestamp + local_delta, true)
				var place := str(snapshot.sections.world.get("location", ""))
				summary = "%s  %s" % [date, place]
			var card := _button(_content, "%s    %s" % [STORE.label(slot), summary], func(): selected.emit(slot))
			card.disabled = mode == "load" and snapshot.is_empty()
	_status = UI.text_label("", 20, PALETTE.text, PALETTE)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_status)
	var cancel := _button(_content, "取消", close)
	show()
	if is_inside_tree():
		cancel.grab_focus()

func report(message: String) -> void:
	_status.text = message

func close() -> void:
	hide()
	closed.emit()

func is_world_input_locked() -> bool:
	return visible

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		close()

func _button(parent: Container, caption: String, action: Callable) -> Button:
	var button := CARD.new()
	button.configure(caption, PALETTE, CARD.Kind.TAB)
	button.custom_minimum_size.y = 50
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(button)
	button.pressed.connect(action)
	return button
