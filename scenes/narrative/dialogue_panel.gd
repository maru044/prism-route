class_name DialoguePanel
extends Control

signal option_selected(index: int)
signal next_pressed()

const INPUT_GROUP := "dialogue_input_panels"
const UI := preload("res://scenes/combat/encounter_ui_style.gd")
const Card := preload("res://scenes/combat/encounter_card.gd")

@export var palette: UI.Palette = UI.DEFAULT_PALETTE
@export var opponent_name := "对手"

var speaker_label: Label
var text_label: RichTextLabel
var choices_container: GridContainer
var prompt_label: Button

var _dock: VBoxContainer
var _choices_scroll: ScrollContainer
var _scrim: TextureRect

func _ready() -> void:
	add_to_group(INPUT_GROUP)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()

func _build_ui() -> void:
	_scrim = UI.bottom_fade(palette)
	add_child(_scrim)

	_dock = UI.column(6)
	_dock.name = "DialogueDock"
	_dock.anchor_left = .168
	_dock.anchor_right = .832
	_dock.anchor_bottom = 1.0
	_dock.offset_bottom = -38
	_dock.alignment = BoxContainer.ALIGNMENT_END
	_dock.minimum_size_changed.connect(_update_fade_height)
	add_child(_dock)

	speaker_label = UI.text_label("", 28, palette.speaker, palette)
	speaker_label.add_theme_font_override("font", UI.command_font())
	_dock.add_child(speaker_label)

	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.mouse_filter = Control.MOUSE_FILTER_PASS
	text_label.add_theme_color_override("default_color", palette.text)
	text_label.add_theme_color_override("font_outline_color", palette.shade)
	text_label.add_theme_font_override("normal_font", UI.command_font())
	text_label.add_theme_font_size_override("normal_font_size", 28)
	text_label.add_theme_constant_override("outline_size", 3)
	text_label.add_theme_constant_override("line_separation", 6)
	text_label.resized.connect(_update_text_height)
	_dock.add_child(text_label)

	_choices_scroll = ScrollContainer.new()
	_choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_choices_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_choices_scroll.hide()
	_dock.add_child(_choices_scroll)
	choices_container = GridContainer.new()
	choices_container.columns = 2
	choices_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choices_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices_container.add_theme_constant_override("h_separation", 22)
	choices_container.add_theme_constant_override("v_separation", 5)
	choices_container.minimum_size_changed.connect(_update_choice_height)
	choices_container.hide()
	_choices_scroll.add_child(choices_container)

	var prompt := Card.new()
	prompt.configure("空格  ·  继续  ›", palette, Card.Kind.CONTINUE)
	prompt_label = prompt
	prompt_label.custom_minimum_size = Vector2(182, 44)
	prompt_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	prompt_label.pressed.connect(func(): next_pressed.emit())
	_dock.add_child(prompt_label)

func display_text(speaker: String, content: String, _emotion: String = "") -> void:
	speaker_label.text = speaker
	speaker_label.visible = not speaker.is_empty()
	speaker_label.add_theme_color_override("font_color", palette.speaker if speaker == opponent_name else palette.accent)
	text_label.text = content
	text_label.scroll_to_line(0)
	_update_text_height.call_deferred()
	_set_choices_visible(false)

func display_choices(choices: Array) -> void:
	for child in choices_container.get_children():
		choices_container.remove_child(child)
		child.queue_free()
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var button := Card.new()
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 55
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.configure(choice.get("text", "选项"), palette, Card.Kind.CHOICE, str(i + 1))
		button.pressed.connect(func(): option_selected.emit(i))
		choices_container.add_child(button)
	_set_choices_visible(not choices.is_empty())
	_choices_scroll.scroll_vertical = 0

func _set_choices_visible(enabled: bool) -> void:
	choices_container.visible = enabled
	_choices_scroll.visible = enabled
	prompt_label.visible = not enabled
	_update_choice_height()

func _update_choice_height() -> void:
	_choices_scroll.custom_minimum_size.y = minf(choices_container.get_combined_minimum_size().y, 224.0)

func _update_fade_height() -> void:
	_scrim.offset_top = -maxf(255.0, _dock.get_combined_minimum_size().y + 140.0)

func _update_text_height() -> void:
	if text_label.size.x > 0.0:
		text_label.custom_minimum_size.y = clampf(text_label.get_content_height() + 5.0, 40.0, 148.0)

static func has_active_dialogue(tree: SceneTree) -> bool:
	if tree == null:
		return false
	for panel in tree.get_nodes_in_group(INPUT_GROUP):
		if panel is Control and panel.is_visible_in_tree():
			return true
	return false

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key >= KEY_1 and key <= KEY_9:
		# Consume the event before a selection can close the dialogue.
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo and choices_container.visible:
			var index := key - KEY_1
			if index < choices_container.get_child_count():
				option_selected.emit(index)
	elif not choices_container.visible and key in [KEY_SPACE, KEY_ENTER]:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo:
			next_pressed.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not choices_container.visible:
			accept_event()
			next_pressed.emit()
