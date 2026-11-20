class_name HomeInteractionPanel
extends CanvasLayer
## Daily interaction dialogue and request panel for home residents.
## Supports chat, companion follow mode, and dual-tier intimacy (普通侍奉 vs 本番侍奉).

signal closed
signal intimacy_requested(tier: String, resident_actor: HomeResidentActor)
signal intimacy_motion_selected(motion_data: Dictionary, resident_actor: HomeResidentActor)
signal follow_mode_toggled(following: bool, resident_actor: HomeResidentActor)

const UI := preload("res://scenes/combat/encounter_ui_style.gd")
const PALETTE := preload("res://scenes/combat/temple_paper_palette.tres")
const ROSTER := preload("res://scripts/characters/character_roster_database.gd")
const CATALOG := preload("res://scripts/construction/home_intimacy_catalog.gd")

var current_actor: HomeResidentActor = null

var _screen := Control.new()
var _sheet: PanelContainer
var _portrait_rect: TextureRect
var _name_label: Label
var _title_label: Label
var _dialogue_label: RichTextLabel
var _options_container: VBoxContainer
var _intimacy_options_container: VBoxContainer
var _motion_scroll: ScrollContainer
var _motion_list_container: VBoxContainer
var _feedback_label: Label
var _mode_intimacy_selection := false
var _built := false

func _ready() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_built()
	hide()

func _ensure_built() -> void:
	if _built:
		return
	_built = true
	_build_ui()

func _build_ui() -> void:
	add_child(_screen)
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP

	# Backdrop
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.08, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.add_child(dim)

	# Center sheet
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(center)

	_sheet = PanelContainer.new()
	_sheet.custom_minimum_size = Vector2(860, 520)
	var sheet_style := StyleBoxFlat.new()
	sheet_style.bg_color = PALETTE.paper_wash
	sheet_style.border_color = PALETTE.paper_ink
	sheet_style.set_border_width_all(2)
	sheet_style.set_corner_radius_all(10)
	sheet_style.content_margin_left = 24
	sheet_style.content_margin_right = 24
	sheet_style.content_margin_top = 20
	sheet_style.content_margin_bottom = 20
	_sheet.add_theme_stylebox_override("panel", sheet_style)
	center.add_child(_sheet)

	var h_layout := UI.row(20)
	_sheet.add_child(h_layout)

	# Left Column: Portrait
	var portrait_col := UI.column(8)
	portrait_col.custom_minimum_size = Vector2(260, 480)
	h_layout.add_child(portrait_col)

	var portrait_box := PanelContainer.new()
	var p_style := StyleBoxFlat.new()
	p_style.bg_color = Color(0.12, 0.16, 0.22, 0.15)
	p_style.border_color = Color(PALETTE.paper_ink, 0.4)
	p_style.set_border_width_all(1)
	p_style.set_corner_radius_all(6)
	portrait_box.add_theme_stylebox_override("panel", p_style)
	portrait_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_col.add_child(portrait_box)

	_portrait_rect = TextureRect.new()
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_box.add_child(_portrait_rect)

	# Right Column: Dialogue and Actions
	var right_col := UI.column(14)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_layout.add_child(right_col)

	# Header info
	var header_col := UI.column(2)
	right_col.add_child(header_col)

	_name_label = UI.text_label("", 26, PALETTE.text, PALETTE)
	_name_label.add_theme_font_override("font", UI.command_font())
	header_col.add_child(_name_label)

	_title_label = UI.text_label("", 15, PALETTE.secondary, PALETTE)
	header_col.add_child(_title_label)

	# Speech bubble
	var bubble := PanelContainer.new()
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color(0.96, 0.94, 0.90, 0.95)
	b_style.border_color = Color(PALETTE.paper_ink, 0.3)
	b_style.set_border_width_all(1)
	b_style.set_corner_radius_all(6)
	b_style.content_margin_left = 16
	b_style.content_margin_right = 16
	b_style.content_margin_top = 12
	b_style.content_margin_bottom = 12
	bubble.add_theme_stylebox_override("panel", b_style)
	bubble.custom_minimum_size.y = 120
	right_col.add_child(bubble)

	_dialogue_label = RichTextLabel.new()
	_dialogue_label.bbcode_enabled = true
	_dialogue_label.fit_content = true
	_dialogue_label.scroll_active = false
	_dialogue_label.add_theme_color_override("default_color", PALETTE.text)
	_dialogue_label.add_theme_font_override("normal_font", UI.interface_font())
	_dialogue_label.add_theme_font_size_override("normal_font_size", 17)
	bubble.add_child(_dialogue_label)

	# Feedback notification
	_feedback_label = UI.text_label("", 15, PALETTE.accent, PALETTE)
	right_col.add_child(_feedback_label)

	# Actions container
	_options_container = UI.column(8)
	right_col.add_child(_options_container)

	_intimacy_options_container = UI.column(8)
	right_col.add_child(_intimacy_options_container)
	_intimacy_options_container.hide()

	# Scrollable motion list container
	_motion_scroll = ScrollContainer.new()
	_motion_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_motion_scroll.custom_minimum_size.y = 260
	_motion_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_col.add_child(_motion_scroll)
	_motion_scroll.hide()

	_motion_list_container = UI.column(6)
	_motion_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_motion_scroll.add_child(_motion_list_container)

func open(actor: HomeResidentActor) -> void:
	_ensure_built()
	current_actor = actor
	_mode_intimacy_selection = false
	_feedback_label.text = ""
	show()
	_load_character_data()
	_show_main_options()

func close() -> void:
	if is_instance_valid(current_actor) and current_actor.state == HomeResidentActor.State.INTERACTING:
		current_actor.state = HomeResidentActor.State.IDLE
	hide()
	closed.emit()

func _load_character_data() -> void:
	if not is_instance_valid(current_actor):
		return
	var char_id := current_actor.character_id
	var entry := ROSTER.get_entry(char_id)
	_name_label.text = str(entry.get("name", char_id))
	_title_label.text = "%s · 家园住客" % str(entry.get("title", ""))

	var portrait_tex := ROSTER.load_portrait(char_id)
	if portrait_tex != null:
		_portrait_rect.texture = portrait_tex

	_dialogue_label.text = _get_default_greeting(char_id)

func _get_default_greeting(char_id: String) -> String:
	match char_id:
		"ganyu":
			return "主人，您来房间看我了呀！今天的工作告一段落了吗？在这间房间里好好休息一下吧。"
		"keqing":
			return "主人，随时欢迎您来。这间房间已经被我打扫得干干净净了，有任何吩咐请尽管直说！"
		"sparkle":
			return "哎呀呀，亲爱的主人来看花火啦！今天是有什么好玩的心思，还是想让我做些特别的要求呢？"
		"raiden_shogun":
			return "主人。在此处休歇片刻，亦合于永恒之道。若有何所需，我自当配合。"
		"firefly":
			return "主人，能在这里和您一起生活，我感到非常安心。如果主人有什么需要，请随时告诉我！"
		_:
			return "主人，在这间属于我们的房间里，无论您有什么愿望与吩咐，我都会全力顺从您的心意。"

func _show_main_options() -> void:
	_options_container.show()
	_intimacy_options_container.hide()
	_motion_scroll.hide()
	for child in _options_container.get_children():
		child.queue_free()

	# Option 1: 聊天交谈
	var chat_btn := _create_option_button("【聊天交谈】 闲聊与倾听心情", _on_chat_pressed)
	_options_container.add_child(chat_btn)

	# Option 2: 要求亲密行为
	var intimacy_btn := _create_option_button("【要求亲密行为】 侍奉与深度温存", _on_intimacy_menu_pressed)
	_options_container.add_child(intimacy_btn)

	# Option 3: 要求跟我走 / 返回房间
	var is_following: bool = is_instance_valid(current_actor) and current_actor.state == HomeResidentActor.State.FOLLOWING
	var follow_caption := "【返回房间休息】 结束随行伴随" if is_following else "【要求跟我走】 随行伴随大世界"
	var follow_btn := _create_option_button(follow_caption, _on_follow_toggle_pressed.bind(not is_following))
	_options_container.add_child(follow_btn)

	# Option 4: 离开
	var exit_btn := _create_option_button("【稍后再见】 关闭交互面板", close)
	_options_container.add_child(exit_btn)

func _show_intimacy_options() -> void:
	_options_container.hide()
	_intimacy_options_container.show()
	_motion_scroll.hide()
	for child in _intimacy_options_container.get_children():
		child.queue_free()

	_dialogue_label.text = "主人，要我为您做些什么呢？只要是主人的心愿，无论何种要求，我都会顺从接受。"

	# Sub-option 1: 日常侍奉 (普通侍奉)
	var service_btn := _create_option_button("🔹【日常侍奉】 普通侍奉 / 前戏抚慰 / 局部互动", _show_motion_list.bind("service"))
	_intimacy_options_container.add_child(service_btn)

	# Sub-option 2: 深度温存 (本番侍奉)
	var honban_btn := _create_option_button("🔹【深度温存】 本番侍奉 / 结合交融 / 极致欢愉", _show_motion_list.bind("honban"))
	_intimacy_options_container.add_child(honban_btn)

	# Sub-option 3: 返回
	var back_btn := _create_option_button("◀ 返回上级菜单", _show_main_options)
	_intimacy_options_container.add_child(back_btn)

func _show_motion_list(tier: String) -> void:
	_options_container.hide()
	_intimacy_options_container.hide()
	_motion_scroll.show()
	for child in _motion_list_container.get_children():
		child.queue_free()

	if tier == "service":
		_dialogue_label.text = "主人，请挑选您希望我如何为您侍奉呢？房间里备好的家具设施，我都随时为您准备好。"
	else:
		_dialogue_label.text = "主人想要和我进行怎样深入的温存呢？无论主人挑选哪种方式，我都会全然接纳主人的爱意。"

	var available_furniture := _get_available_furniture()
	var furn_names: Array[String] = []
	for f: String in available_furniture:
		furn_names.append(CATALOG.get_furniture_label(f))
	var furn_summary := "、".join(furn_names) if not furn_names.is_empty() else "仅地面席位"
	var tier_label := "日常侍奉" if tier == "service" else "深度温存"
	_feedback_label.text = "【%s · 房间可用设施】%s" % [tier_label, furn_summary]

	var motions: Array[Dictionary] = CATALOG.get_motions(tier)
	for motion: Dictionary in motions:
		var can_play: bool = CATALOG.can_play_in_room(motion, available_furniture)
		var furn_lbl: String = CATALOG.get_furniture_label(str(motion.get("furniture", "ground")))
		var m_name: String = str(motion.get("name", motion.get("id", "")))
		var m_dur: float = float(motion.get("duration", 0.0))

		if can_play:
			var caption := "▶ %s  [%s]  (%.1f秒)" % [m_name, furn_lbl, m_dur]
			var btn := _create_option_button(caption, _on_motion_selected.bind(motion))
			_motion_list_container.add_child(btn)
		else:
			var caption := "🔒 %s  [缺少家具：%s]" % [m_name, furn_lbl]
			var btn := _create_disabled_motion_button(caption)
			_motion_list_container.add_child(btn)

	var back_btn := _create_option_button("◀ 返回选择侍奉类别", _show_intimacy_options)
	_motion_list_container.add_child(back_btn)

func _on_motion_selected(motion: Dictionary) -> void:
	if is_instance_valid(current_actor):
		intimacy_motion_selected.emit(motion, current_actor)
		intimacy_requested.emit(str(motion.get("tier", "service")), current_actor)
	close()

func _create_disabled_motion_button(caption: String) -> Button:
	var btn := Button.new()
	btn.text = caption
	btn.custom_minimum_size = Vector2(480, 38)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.disabled = true

	var disabled_style := StyleBoxFlat.new()
	disabled_style.bg_color = Color(PALETTE.paper_wash, 0.45)
	disabled_style.border_color = Color(PALETTE.paper_ink, 0.2)
	disabled_style.set_border_width_all(1)
	disabled_style.set_corner_radius_all(4)
	disabled_style.content_margin_left = 16
	disabled_style.content_margin_right = 16
	disabled_style.content_margin_top = 8
	disabled_style.content_margin_bottom = 8
	btn.add_theme_stylebox_override("disabled", disabled_style)

	btn.add_theme_color_override("font_disabled_color", Color(PALETTE.secondary, 0.6))
	btn.add_theme_font_override("font", UI.interface_font())
	btn.add_theme_font_size_override("font_size", 15)
	return btn

func _get_available_furniture() -> Array[String]:
	var kinds: Array[String] = []
	if not is_instance_valid(current_actor) or not is_instance_valid(current_actor.home):
		return kinds
	var plot_id: String = current_actor.plot_id
	if not current_actor.home.plots.has(plot_id):
		return kinds
	var p_data = current_actor.home.plots[plot_id].data
	var f_ids: Array = current_actor.room_data.get("furniture", [])
	for f_id in f_ids:
		if p_data.pieces.has(f_id):
			var def: String = str(p_data.pieces[f_id].definition)
			if not kinds.has(def):
				kinds.append(def)
	return kinds

func _on_chat_pressed() -> void:
	if not is_instance_valid(current_actor):
		return
	var char_id := current_actor.character_id
	var char_entry := ROSTER.get_entry(char_id)
	var char_name := str(char_entry.get("name", char_id))

	_feedback_label.text = "【互动反馈】好感度与信任度提升！"
	match char_id:
		"ganyu":
			_dialogue_label.text = "和主人这样坐下来聊天，感觉疲劳都烟消云散了呢。能一直守在主人身边，就是我最大的心愿。"
		"keqing":
			_dialogue_label.text = "既然是主人想聊聊，那我就暂时放下公务。您对目前的发展还有什么新想法吗？我都认真听着！"
		"sparkle":
			_dialogue_label.text = "哈哈，光是聊天怎么能够满足呢？不过看着主人认真的眼神，花火大人心情大好哦！"
		_:
			_dialogue_label.text = "能和主人静静度过这段日常时光，心里感到非常温暖。无论大世界怎样广阔，有主人的地方就是归宿。"

func _on_intimacy_menu_pressed() -> void:
	_show_intimacy_options()

func _on_intimacy_selected(tier: String) -> void:
	if is_instance_valid(current_actor):
		intimacy_requested.emit(tier, current_actor)
	close()

func _on_follow_toggle_pressed(following: bool) -> void:
	if is_instance_valid(current_actor):
		current_actor.set_following(following)
		follow_mode_toggled.emit(following, current_actor)
		if following:
			_feedback_label.text = "已启用伴随！角色将跟随主人一同行动。"
		else:
			_feedback_label.text = "已结束伴随，角色已返回房间中休息。"
	_show_main_options()

func _create_option_button(caption: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = caption
	btn.custom_minimum_size = Vector2(480, 40)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var normal := StyleBoxFlat.new()
	normal.bg_color = PALETTE.paper_wash
	normal.border_color = PALETTE.paper_ink
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(PALETTE.paper_wash, 0.8)
	hover.border_color = PALETTE.accent
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", hover)

	btn.add_theme_color_override("font_color", PALETTE.text)
	btn.add_theme_color_override("font_hover_color", PALETTE.accent)
	btn.add_theme_font_override("font", UI.interface_font())
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(action)
	return btn

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
