class_name TurnCombatHUD
extends Control

signal action_chosen(action: Resource)
signal meta_dialogue_requested()

enum CommandPage { ROOT, CATEGORIES, SKILLS }

const UI := preload("res://scenes/combat/encounter_ui_style.gd")
const Card := preload("res://scenes/combat/encounter_card.gd")
const EDGE_BACKDROP := preload("res://scenes/combat/encounter_edge_backdrop.gdshader")
const PleasureComponentClass := preload("res://scripts/combat/pleasure_component.gd")
const ZONE_NAMES := {
	"mouth": ["口腔", "柔嫩口腔"],
	"nipples": ["双乳", "敏感双乳"],
	"anal": ["菊部", "紧致菊部"],
	"clitoris": ["花核", "私密花核"],
}
const ACTIONS := {
	"caress": preload("res://assets/combat/actions/action_caress.tres"),
	"nipples": preload("res://assets/combat/actions/action_nipples.tres"),
	"toy_vibe": preload("res://assets/combat/actions/action_toy_vibe.tres"),
	"endure": preload("res://assets/combat/actions/action_endure.tres"),
}
const GROUPS := {
	"tease": ["caress", "nipples"],
	"toy": ["toy_vibe"],
	"endure": ["endure"],
}

@export var palette: UI.Palette = UI.DEFAULT_PALETTE
@export var opponent_name := "对手"

var player_pleasure_bar: ProgressBar
var player_pleasure_label: Label
var npc_pleasure_bar: ProgressBar
var npc_pleasure_label: Label
var round_label: Label
var phase_label: Label
var log_box: RichTextLabel
var koujou_box: RichTextLabel

var _root_menu: HBoxContainer
var _categories: HBoxContainer
var _skills: VBoxContainer
var _back_button: Card
var _command_page := CommandPage.ROOT
var _current_group := ""
var _description: Label
var _action_tags: Label
var _bottom: Control
var _opponent_pleasure: Node
var _input_enabled := false
var _chat_open := false
var _player_tween: Tween
var _npc_tween: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_edge_backdrop()
	_build_bottom()
	_build_commands()
	_build_gauges()
	set_input_enabled(false, "等待开始")

func _build_edge_backdrop() -> void:
	var filter := ColorRect.new()
	filter.name = "BattleEdgeBackdrop"
	filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = EDGE_BACKDROP
	shader_material.set_shader_parameter("upper_color", palette.edge_upper)
	shader_material.set_shader_parameter("lower_color", palette.edge_lower)
	shader_material.set_shader_parameter("motif_color", palette.edge_motif)
	shader_material.set_shader_parameter("strength", palette.edge_strength)
	filter.material = shader_material
	add_child(filter)
	filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _build_commands() -> void:
	var command_area := UI.column(8)
	command_area.name = "Commands"
	command_area.position = Vector2(128, 30)
	command_area.custom_minimum_size.x = 386
	add_child(command_area)

	var status := UI.row(14)
	command_area.add_child(status)
	round_label = UI.text_label("第 01 回合", 21, palette.text, palette)
	status.add_child(round_label)
	phase_label = UI.text_label("", 18, palette.accent, palette)
	status.add_child(phase_label)

	_back_button = Card.new()
	_back_button.name = "Back"
	_back_button.configure("‹  返回", palette, Card.Kind.CONTINUE)
	_back_button.custom_minimum_size = Vector2(122, 42)
	_back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_back_button.pressed.connect(_go_back)
	command_area.add_child(_back_button)

	_root_menu = UI.row(8)
	_root_menu.name = "RootMenu"
	command_area.add_child(_root_menu)
	var battle := Card.new()
	battle.name = "BattleTab"
	battle.configure("战斗", palette, Card.Kind.TAB)
	battle.custom_minimum_size.y = 54
	battle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle.pressed.connect(_open_battle)
	_root_menu.add_child(battle)

	var chat := Card.new()
	chat.name = "ChatTab"
	chat.configure("对话", palette, Card.Kind.TAB)
	chat.custom_minimum_size.y = 54
	chat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat.pressed.connect(_request_chat)
	_root_menu.add_child(chat)

	_categories = UI.row(8)
	_categories.name = "Categories"
	command_area.add_child(_categories)
	var category_names := {"tease": "挑逗", "toy": "道具", "endure": "忍耐"}
	for id: String in category_names:
		var button := Card.new()
		button.name = id.capitalize()
		button.custom_minimum_size.y = 42
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.configure(category_names[id], palette, Card.Kind.CATEGORY)
		button.pressed.connect(_show_group.bind(id))
		_categories.add_child(button)
	_skills = UI.column(6)
	_skills.name = "Skills"
	command_area.add_child(_skills)
	_refresh_command_page()

func _build_gauges() -> void:
	player_pleasure_bar = _gauge("PlayerGauge", false, palette.player_low, palette.player_high)
	npc_pleasure_bar = _gauge("OpponentGauge", true, palette.opponent_low, palette.opponent_high)
	player_pleasure_label = _gauge_caption(player_pleasure_bar, "我方", "♥", palette.player_low)
	npc_pleasure_label = _gauge_caption(npc_pleasure_bar, opponent_name, "♥", palette.opponent_high)

func _gauge(node_name: String, right: bool, low: Color, high: Color) -> ProgressBar:
	var gauge := ProgressBar.new()
	gauge.name = node_name
	gauge.anchor_left = float(right)
	gauge.anchor_right = float(right)
	gauge.anchor_top = .023
	gauge.anchor_bottom = .55
	var inset := -79.0 if right else 79.0
	gauge.offset_left = inset - 7
	gauge.offset_right = inset + 7
	gauge.max_value = 100.0
	gauge.step = 0.01
	gauge.show_percentage = false
	gauge.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.add_theme_stylebox_override("background", _rail_style(palette.rail, palette.rail))
	gauge.add_theme_stylebox_override("fill", _rail_style(high, low))
	add_child(gauge)
	return gauge

func _rail_style(top: Color, bottom: Color) -> StyleBoxTexture:
	# A nine-slice capsule retains rounded ends at any fill height.
	var image := Image.create_empty(14, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		var tint := top.lerp(bottom, y / 127.0)
		for x in 14:
			var from_cap := Vector2(x + .5 - 7.0, y + .5 - clampf(y + .5, 7.0, 121.0))
			image.set_pixel(x, y, Color(tint, tint.a * clampf(7.4 - from_cap.length(), 0.0, 1.0)))
	var style := StyleBoxTexture.new()
	style.texture = ImageTexture.create_from_image(image)
	style.texture_margin_top = 7
	style.texture_margin_bottom = 7
	return style

func _gauge_caption(gauge: ProgressBar, title: String, icon: String, tint: Color) -> Label:
	var caption := UI.column(0)
	caption.anchor_left = .5
	caption.anchor_right = .5
	caption.anchor_top = 1.0
	caption.anchor_bottom = 1.0
	caption.offset_left = -52
	caption.offset_right = 52
	caption.offset_top = 9
	gauge.add_child(caption)
	for item in [[icon, 22, tint], ["0.0%", 19, palette.text], [title, 20, tint]]:
		var label := UI.text_label(item[0], item[1], item[2], palette)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_child(label)
	return caption.get_child(1) as Label

func _build_bottom() -> void:
	_bottom = Control.new()
	_bottom.name = "BattleDetails"
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bottom)
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bottom.add_child(UI.bottom_fade(palette))
	var dock := UI.column(5)
	dock.anchor_left = .168
	dock.anchor_right = .832
	dock.anchor_top = 1.0
	dock.anchor_bottom = 1.0
	dock.offset_top = -208
	dock.offset_bottom = -38
	dock.alignment = BoxContainer.ALIGNMENT_END
	_bottom.add_child(dock)
	_description = UI.text_label("", 26, palette.text, palette)
	_description.add_theme_font_override("font", UI.command_font())
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dock.add_child(_description)

	_action_tags = UI.text_label("", 18, palette.accent, palette)
	_action_tags.add_theme_font_override("font", UI.interface_font())
	_action_tags.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_tags.hide()
	dock.add_child(_action_tags)

	koujou_box = RichTextLabel.new()
	koujou_box.name = "CombatKoujouBox"
	koujou_box.bbcode_enabled = true
	koujou_box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	koujou_box.add_theme_font_override("normal_font", UI.command_font())
	koujou_box.add_theme_font_size_override("normal_font_size", 24)
	koujou_box.add_theme_color_override("default_color", palette.text)
	koujou_box.add_theme_color_override("font_outline_color", palette.shade)
	koujou_box.add_theme_constant_override("outline_size", 4)
	koujou_box.custom_minimum_size.y = 80
	dock.add_child(koujou_box)
	koujou_box.hide()

	log_box = RichTextLabel.new()
	log_box.name = "BattleLog"
	log_box.custom_minimum_size.y = 35
	log_box.scroll_following = true
	log_box.add_theme_font_size_override("normal_font_size", 18)
	log_box.add_theme_color_override("default_color", palette.secondary)
	log_box.add_theme_color_override("font_outline_color", palette.shade)
	log_box.add_theme_constant_override("outline_size", 3)
	dock.add_child(log_box)
	log_box.get_v_scroll_bar().self_modulate.a = 0.0
	log_box.get_v_scroll_bar().mouse_filter = Control.MOUSE_FILTER_IGNORE
	log_box.hide()

func _open_battle() -> void:
	if _input_enabled and not _chat_open and _command_page == CommandPage.ROOT:
		_command_page = CommandPage.CATEGORIES
		_refresh_command_page()

func _go_back() -> void:
	if not _input_enabled or _chat_open:
		return
	_command_page = CommandPage.CATEGORIES if _command_page == CommandPage.SKILLS else CommandPage.ROOT
	_refresh_command_page()

func _refresh_command_page() -> void:
	_root_menu.visible = not _chat_open and _command_page == CommandPage.ROOT
	_categories.visible = not _chat_open and _command_page == CommandPage.CATEGORIES
	_skills.visible = not _chat_open and _command_page == CommandPage.SKILLS
	_back_button.visible = not _chat_open and _command_page != CommandPage.ROOT
	_description.visible = _skills.visible
	_action_tags.visible = _skills.visible

func set_opponent_pleasure(comp: Node) -> void:
	_opponent_pleasure = comp

func _get_zone_multiplier(zone: String) -> float:
	if _opponent_pleasure != null and is_instance_valid(_opponent_pleasure) and _opponent_pleasure.has_method("get_zone_multiplier"):
		return _opponent_pleasure.get_zone_multiplier(zone)
	return float(PleasureComponentClass.DEFAULT_ZONE_MULTIPLIERS.get(zone, 1.0))

func _get_extra_multiplier() -> float:
	if _opponent_pleasure != null and is_instance_valid(_opponent_pleasure) and "damage_taken_multiplier" in _opponent_pleasure:
		return float(_opponent_pleasure.damage_taken_multiplier)
	return 1.0

func _format_multiplier(mult: float) -> String:
	var rounded := snappedf(mult, 0.01)
	if is_equal_approx(rounded, snappedf(rounded, 0.1)):
		return "×%.1f" % rounded
	return "×%.2f" % rounded

func _format_action_badges(action: TurnActionResource) -> Dictionary:
	if action.self_pleasure_defense > 0.0:
		var def_pct := action.self_pleasure_defense * 100.0
		return {
			"card_detail": "减免 %.0f%%" % def_pct,
			"card_sub": "防反姿态",
			"bottom_tags": "《防御姿态》  《本回合受击快感 -%.0f%%》" % def_pct,
		}
	var names: Array = ZONE_NAMES.get(action.target_zone, ["全身", "全身感官"])
	var zone_mult := _get_zone_multiplier(action.target_zone)
	var extra_mult := _get_extra_multiplier()
	var mult_str := _format_multiplier(zone_mult)
	var expected_gain := action.base_pleasure * zone_mult * extra_mult
	var bottom := "《部位: %s》  《敏感倍率 %s》  《预计快感 +%.1f%%》" % [names[1], mult_str, expected_gain]
	if extra_mult > 1.01:
		bottom += "  《识趣加成 %s》" % _format_multiplier(extra_mult)
	return {
		"card_detail": "♥  +%.0f%%" % action.base_pleasure,
		"card_sub": "%s %s" % [names[0], mult_str],
		"bottom_tags": bottom,
	}

func _show_group(id: String) -> void:
	if not _input_enabled or _chat_open or _command_page != CommandPage.CATEGORIES:
		return
	if koujou_box:
		koujou_box.hide()
	_current_group = id
	_populate_skills(id)
	_command_page = CommandPage.SKILLS
	_refresh_command_page()

func _populate_skills(id: String) -> void:
	if not GROUPS.has(id):
		return
	for child in _skills.get_children():
		_skills.remove_child(child)
		child.queue_free()
	for action_id: String in GROUPS[id]:
		var action: TurnActionResource = ACTIONS[action_id]
		var badges := _format_action_badges(action)
		var button := Card.new()
		button.name = action_id.capitalize()
		button.configure(action.action_name, palette, Card.Kind.SKILL, badges["card_detail"], badges["card_sub"])
		button.custom_minimum_size.y = 84
		button.pressed.connect(_choose_action.bind(action))
		button.mouse_entered.connect(_feature_action.bind(button, action))
		button.focus_entered.connect(_feature_action.bind(button, action))
		_skills.add_child(button)
	_feature_action(_skills.get_child(0) as Card, ACTIONS[GROUPS[id][0]])

func _feature_action(featured: Card, action: TurnActionResource) -> void:
	for button: Card in _skills.get_children():
		button.set_featured(button == featured)
	if koujou_box:
		koujou_box.hide()
	_description.text = action.description if not action.description.is_empty() else action.action_name
	_action_tags.text = _format_action_badges(action)["bottom_tags"]
	_description.show()
	_action_tags.show()

func _choose_action(action: Resource) -> void:
	if _input_enabled and not _chat_open and _command_page == CommandPage.SKILLS:
		_description.hide()
		_action_tags.hide()
		action_chosen.emit(action)

func _request_chat() -> void:
	if _input_enabled and not _chat_open and _command_page == CommandPage.ROOT:
		meta_dialogue_requested.emit()

func reset_battle() -> void:
	_command_page = CommandPage.ROOT
	_current_group = ""
	set_chat_open(false)
	if koujou_box:
		koujou_box.clear()
		koujou_box.hide()
	log_box.clear()
	log_box.hide()
	update_player_pleasure(0.0, 100.0, 0.0)
	update_npc_pleasure(0.0, 100.0, 0.0)

func set_chat_open(open: bool) -> void:
	_chat_open = open
	_bottom.visible = not open
	if not open and _command_page == CommandPage.SKILLS and not _current_group.is_empty():
		_populate_skills(_current_group)
	_refresh_command_page()
	_sync_input()

func update_player_pleasure(_current: float, _max_val: float, percentage: float) -> void:
	_player_tween = _set_gauge(player_pleasure_bar, player_pleasure_label, percentage, _player_tween)

func update_npc_pleasure(_current: float, _max_val: float, percentage: float) -> void:
	_npc_tween = _set_gauge(npc_pleasure_bar, npc_pleasure_label, percentage, _npc_tween)

func _set_gauge(gauge: ProgressBar, label: Label, percentage: float, previous: Tween) -> Tween:
	if previous and previous.is_valid():
		previous.kill()
	label.text = "%.1f%%" % percentage
	if percentage <= 0.0 or not is_visible_in_tree():
		gauge.value = percentage
		return null
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(gauge, "value", percentage, .26)
	return tween

func update_round(round_num: int) -> void:
	round_label.text = "第 %02d 回合" % round_num

func display_koujou(speaker: String, text: String, extra_log: String = "") -> void:
	_description.hide()
	_action_tags.hide()
	if koujou_box:
		var formatted := "[color=#ff99bb][b]【%s】[/b][/color] %s" % [speaker, text]
		if not extra_log.is_empty():
			formatted += "\n[color=#b8e4ff][font_size=19]%s[/font_size][/color]" % extra_log
		koujou_box.text = formatted
		koujou_box.show()
	if log_box:
		log_box.hide()

func append_log(message: String) -> void:
	if message.begins_with("===") or message.begins_with("---") or message.begins_with("【玩家回合】"):
		return
	if not log_box.get_parsed_text().is_empty():
		log_box.add_text("\n")
	log_box.add_text(message)
	log_box.show()

func set_input_enabled(enabled: bool, phase_text: String = "") -> void:
	_input_enabled = enabled
	if not phase_text.is_empty():
		phase_label.text = phase_text
	if enabled and not _chat_open and _command_page == CommandPage.SKILLS and not _current_group.is_empty():
		_populate_skills(_current_group)
	_sync_input()

func _sync_input() -> void:
	var disabled := not _input_enabled or _chat_open
	_back_button.disabled = disabled
	for menu in [_root_menu, _categories, _skills]:
		for button: Button in menu.get_children():
			button.disabled = disabled
