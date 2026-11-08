class_name TurnCombatHUD
extends Control
## Turn-based RPG Combat HUD with dual pleasure gauges and 4-way action menu (no endurance bar).

signal action_chosen(action: Resource)
signal meta_dialogue_requested()

var player_pleasure_bar: ProgressBar
var player_pleasure_label: Label

var npc_pleasure_bar: ProgressBar
var npc_pleasure_label: Label

var round_label: Label
var log_box: RichTextLabel

var main_menu: HBoxContainer
var sub_menu: HBoxContainer

var actions_map: Dictionary = {}

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_PASS
	_load_actions()
	_build_ui()

func _load_actions() -> void:
	actions_map["caress"] = load("res://assets/combat/actions/action_caress.tres")
	actions_map["nipples"] = load("res://assets/combat/actions/action_nipples.tres")
	actions_map["toy_vibe"] = load("res://assets/combat/actions/action_toy_vibe.tres")
	actions_map["endure"] = load("res://assets/combat/actions/action_endure.tres")

func _build_ui() -> void:
	# Top bar: Gauges
	var top_panel := PanelContainer.new()
	top_panel.anchor_left = 0.05
	top_panel.anchor_right = 0.95
	top_panel.anchor_top = 0.03
	top_panel.anchor_bottom = 0.14
	
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.06, 0.06, 0.1, 0.88)
	top_style.border_color = Color(0.4, 0.4, 0.6, 0.8)
	top_style.border_width_bottom = 2
	top_style.corner_radius_bottom_left = 6
	top_style.corner_radius_bottom_right = 6
	top_style.content_margin_left = 24.0
	top_style.content_margin_right = 24.0
	top_style.content_margin_top = 10.0
	top_style.content_margin_bottom = 10.0
	top_panel.add_theme_stylebox_override("panel", top_style)
	add_child(top_panel)
	
	var top_hbox := HBoxContainer.new()
	top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.add_theme_constant_override("separation", 50)
	top_panel.add_child(top_hbox)
	
	# Master gauge section (Left)
	var player_box := VBoxContainer.new()
	player_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(player_box)
	
	player_pleasure_label = Label.new()
	player_pleasure_label.text = "主人 快感槽: 0.0% / 100%"
	player_pleasure_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	player_pleasure_label.add_theme_font_size_override("font_size", 15)
	player_box.add_child(player_pleasure_label)
	
	player_pleasure_bar = ProgressBar.new()
	player_pleasure_bar.max_value = 100.0
	player_pleasure_bar.value = 0.0
	player_pleasure_bar.show_percentage = false
	player_pleasure_bar.custom_minimum_size.y = 18
	player_box.add_child(player_pleasure_bar)
	
	# Center round info
	round_label = Label.new()
	round_label.text = "第 1 回合"
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.add_theme_font_size_override("font_size", 22)
	round_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	top_hbox.add_child(round_label)
	
	# Sparkle gauge section (Right)
	var npc_box := VBoxContainer.new()
	npc_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(npc_box)
	
	npc_pleasure_label = Label.new()
	npc_pleasure_label.text = "花火 快感槽: 0.0% / 100%"
	npc_pleasure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	npc_pleasure_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.65))
	npc_pleasure_label.add_theme_font_size_override("font_size", 15)
	npc_box.add_child(npc_pleasure_label)
	
	npc_pleasure_bar = ProgressBar.new()
	npc_pleasure_bar.max_value = 100.0
	npc_pleasure_bar.value = 0.0
	npc_pleasure_bar.show_percentage = false
	npc_pleasure_bar.custom_minimum_size.y = 18
	npc_box.add_child(npc_pleasure_bar)
	
	# Mid Log Box
	var log_panel := PanelContainer.new()
	log_panel.anchor_left = 0.2
	log_panel.anchor_right = 0.8
	log_panel.anchor_top = 0.18
	log_panel.anchor_bottom = 0.46
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(0.04, 0.04, 0.08, 0.65)
	log_style.border_color = Color(0.4, 0.4, 0.6, 0.4)
	log_style.border_width_left = 1
	log_style.border_width_right = 1
	log_style.border_width_top = 1
	log_style.border_width_bottom = 1
	log_style.corner_radius_bottom_left = 6
	log_style.corner_radius_bottom_right = 6
	log_style.corner_radius_top_left = 6
	log_style.corner_radius_top_right = 6
	log_style.content_margin_left = 16.0
	log_style.content_margin_right = 16.0
	log_style.content_margin_top = 10.0
	log_style.content_margin_bottom = 10.0
	log_panel.add_theme_stylebox_override("panel", log_style)
	add_child(log_panel)
	
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.add_theme_font_size_override("normal_font_size", 14)
	log_panel.add_child(log_box)
	
	# Bottom Command Menu
	var menu_panel := PanelContainer.new()
	menu_panel.anchor_left = 0.15
	menu_panel.anchor_right = 0.85
	menu_panel.anchor_top = 0.78
	menu_panel.anchor_bottom = 0.94
	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = Color(0.08, 0.08, 0.14, 0.92)
	menu_style.border_color = Color(0.85, 0.45, 0.65, 0.9)
	menu_style.border_width_top = 2
	menu_style.border_width_bottom = 2
	menu_style.border_width_left = 2
	menu_style.border_width_right = 2
	menu_style.corner_radius_bottom_left = 8
	menu_style.corner_radius_bottom_right = 8
	menu_style.corner_radius_top_left = 8
	menu_style.corner_radius_top_right = 8
	menu_style.content_margin_left = 20.0
	menu_style.content_margin_right = 20.0
	menu_style.content_margin_top = 10.0
	menu_style.content_margin_bottom = 10.0
	menu_panel.add_theme_stylebox_override("panel", menu_style)
	add_child(menu_panel)
	
	var menu_vbox := VBoxContainer.new()
	menu_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_panel.add_child(menu_vbox)
	
	main_menu = HBoxContainer.new()
	main_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	main_menu.add_theme_constant_override("separation", 24)
	menu_vbox.add_child(main_menu)
	
	sub_menu = HBoxContainer.new()
	sub_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	sub_menu.add_theme_constant_override("separation", 16)
	sub_menu.visible = false
	menu_vbox.add_child(sub_menu)
	
	_build_main_menu_buttons()

func _build_main_menu_buttons() -> void:
	var btn_tease := Button.new()
	btn_tease.text = "【挑逗】敏感爱抚"
	btn_tease.custom_minimum_size = Vector2(140, 42)
	btn_tease.pressed.connect(_show_tease_submenu)
	main_menu.add_child(btn_tease)
	
	var btn_toy := Button.new()
	btn_toy.text = "【道具】情趣跳蛋"
	btn_toy.custom_minimum_size = Vector2(140, 42)
	btn_toy.pressed.connect(_show_toy_submenu)
	main_menu.add_child(btn_toy)
	
	var btn_endure := Button.new()
	btn_endure.text = "【忍耐】咬牙防守"
	btn_endure.custom_minimum_size = Vector2(140, 42)
	btn_endure.pressed.connect(func(): _select_action("endure"))
	main_menu.add_child(btn_endure)
	
	var btn_meta := Button.new()
	btn_meta.text = "【识趣】战中交涉"
	btn_meta.custom_minimum_size = Vector2(140, 42)
	btn_meta.pressed.connect(func(): meta_dialogue_requested.emit())
	main_menu.add_child(btn_meta)

func _show_tease_submenu() -> void:
	main_menu.visible = false
	sub_menu.visible = true
	for c in sub_menu.get_children():
		c.queue_free()
		
	var b1 := Button.new()
	b1.text = "1. 柔情爱抚 (口腔/脸颊 +15%)"
	b1.pressed.connect(func(): _select_action("caress"))
	sub_menu.add_child(b1)
	
	var b2 := Button.new()
	b2.text = "2. 玩弄双乳 (敏感胸部 +18%)"
	b2.pressed.connect(func(): _select_action("nipples"))
	sub_menu.add_child(b2)
	
	var b_back := Button.new()
	b_back.text = "返回"
	b_back.pressed.connect(_back_to_main_menu)
	sub_menu.add_child(b_back)

func _show_toy_submenu() -> void:
	main_menu.visible = false
	sub_menu.visible = true
	for c in sub_menu.get_children():
		c.queue_free()
		
	var b1 := Button.new()
	b1.text = "1. 调频高频跳蛋 (私密花核 +20%)"
	b1.pressed.connect(func(): _select_action("toy_vibe"))
	sub_menu.add_child(b1)
	
	var b_back := Button.new()
	b_back.text = "返回"
	b_back.pressed.connect(_back_to_main_menu)
	sub_menu.add_child(b_back)

func _back_to_main_menu() -> void:
	sub_menu.visible = false
	main_menu.visible = true

func _select_action(action_id: String) -> void:
	_back_to_main_menu()
	if actions_map.has(action_id):
		action_chosen.emit(actions_map[action_id])

func update_player_pleasure(current: float, max_val: float, percentage: float) -> void:
	player_pleasure_bar.value = percentage
	player_pleasure_label.text = "主人 快感槽: %.1f%% / %.0f%%" % [percentage, max_val]

func update_npc_pleasure(current: float, max_val: float, percentage: float) -> void:
	npc_pleasure_bar.value = percentage
	npc_pleasure_label.text = "花火 快感槽: %.1f%% / %.0f%%" % [percentage, max_val]

func update_round(round_num: int) -> void:
	round_label.text = "第 %d 回合" % round_num

func append_log(message: String) -> void:
	log_box.append_text(message + "\n")

func set_input_enabled(enabled: bool) -> void:
	main_menu.visible = enabled
	if not enabled:
		sub_menu.visible = false
