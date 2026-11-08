class_name DialoguePanel
extends Control
## Renders rich-text dialogues and multi-choice button lists with keyboard/mouse support.

signal option_selected(index: int)
signal next_pressed()

var speaker_label: Label
var text_label: RichTextLabel
var choices_container: VBoxContainer
var prompt_label: Label

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()

func _build_ui() -> void:
	var box := PanelContainer.new()
	box.anchor_left = 0.1
	box.anchor_right = 0.9
	box.anchor_top = 0.65
	box.anchor_bottom = 0.95
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.12, 0.88)
	style.border_color = Color(0.85, 0.45, 0.65, 0.9) # Sparkle pink border
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	box.add_theme_stylebox_override("panel", style)
	add_child(box)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	box.add_child(vbox)
	
	speaker_label = Label.new()
	speaker_label.text = "说话人"
	speaker_label.add_theme_font_size_override("font_size", 20)
	speaker_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.85))
	vbox.add_child(speaker_label)
	
	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.text = "这里是对白内容"
	text_label.fit_content = false
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.add_theme_font_size_override("normal_font_size", 17)
	vbox.add_child(text_label)
	
	choices_container = VBoxContainer.new()
	choices_container.add_theme_constant_override("separation", 6)
	choices_container.visible = false
	vbox.add_child(choices_container)
	
	prompt_label = Label.new()
	prompt_label.text = "[点击或按空格继续]"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt_label.add_theme_font_size_override("font_size", 13)
	prompt_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(prompt_label)

func display_text(speaker: String, content: String, emotion: String = "") -> void:
	speaker_label.text = speaker
	if speaker == "花火":
		speaker_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.65))
	elif speaker == "主人" or speaker == "荧":
		speaker_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	else:
		speaker_label.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
		
	text_label.text = content
	choices_container.visible = false
	prompt_label.visible = true

func display_choices(choices: Array) -> void:
	for child in choices_container.get_children():
		child.queue_free()
		
	choices_container.visible = true
	prompt_label.visible = false
	
	for i in range(choices.size()):
		var choice_data: Dictionary = choices[i]
		var btn := Button.new()
		btn.text = "%d. %s" % [i + 1, choice_data.get("text", "选项")]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 15)
		
		var bstyle := StyleBoxFlat.new()
		bstyle.bg_color = Color(0.15, 0.15, 0.22, 0.9)
		bstyle.border_color = Color(0.6, 0.6, 0.8, 0.5)
		bstyle.border_width_left = 1
		bstyle.border_width_right = 1
		bstyle.border_width_top = 1
		bstyle.border_width_bottom = 1
		bstyle.corner_radius_bottom_left = 4
		bstyle.corner_radius_bottom_right = 4
		bstyle.corner_radius_top_left = 4
		bstyle.corner_radius_top_right = 4
		bstyle.content_margin_left = 12.0
		bstyle.content_margin_right = 12.0
		bstyle.content_margin_top = 6.0
		bstyle.content_margin_bottom = 6.0
		btn.add_theme_stylebox_override("normal", bstyle)
		
		var idx := i
		btn.pressed.connect(func(): option_selected.emit(idx))
		choices_container.add_child(btn)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not choices_container.visible:
			next_pressed.emit()
	elif event is InputEventKey and event.pressed:
		if not choices_container.visible and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
			next_pressed.emit()
		elif choices_container.visible:
			if event.keycode >= KEY_1 and event.keycode <= KEY_9:
				var chosen_idx: int = event.keycode - KEY_1
				if chosen_idx < choices_container.get_child_count():
					option_selected.emit(chosen_idx)
