extends "res://scripts/map_1021.gd"
## Opt-in real-map review wrapper; formal scene and its environment are unchanged.
const APPEARANCE = preload("res://scripts/characters/character_appearance.gd")
var appearance

func _ready() -> void:
	await super._ready()
	appearance = APPEARANCE.new()
	add_child(appearance)
	appearance.bind(character.character)
	appearance.set_mode("genshin")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--character-shader="): appearance.set_mode(argument.trim_prefix("--character-shader="))
	var layer := CanvasLayer.new()
	add_child(layer)
	review_ui_layers.append(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -300
	panel.offset_top = -145
	panel.offset_right = -20
	panel.offset_bottom = -20
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var label := Label.new()
	label.text = "人物材质实景对照 · 测试入口"
	box.add_child(label)
	var options := OptionButton.new()
	for text_value in ["A · 原始 PBR", "B · MToon", "C0 · 基础 Toon", "C1 · 原神式 NPR"]: options.add_item(text_value)
	options.select(["standard", "mtoon", "custom", "genshin"].find(appearance.mode))
	options.item_selected.connect(func(i): appearance.set_mode(["standard", "mtoon", "custom", "genshin"][i]))
	box.add_child(options)
	var back := Button.new()
	back.text = "返回人物实验室"
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/character_shader_lab.tscn"))
	box.add_child(back)
	layer.visible = review_ui_visible
