extends CanvasLayer
## Genshin Impact style character switch HUD.
## Supports numeric keys [1]-[2], direct toggle via [Tab], and HUD clicking.

signal character_selected(character_id: String)

const TEAM_MEMBERS: Array[Dictionary] = [
	{
		"id": "lumine",
		"slot": 1,
		"name": "荧",
		"title": "旅行者 · 荧",
		"desc": "风 / 岩元素 · 单手剑 | 异界寻亲旅者",
		"color": Color(0.98, 0.88, 0.52),
		"accent": Color(1.0, 0.95, 0.70),
	},
	{
		"id": "ganyu",
		"slot": 2,
		"name": "甘雨",
		"title": "循旅觅途 · 甘雨",
		"desc": "冰元素 · 弓箭 | 璃月七星秘书",
		"color": Color(0.42, 0.78, 0.98),
		"accent": Color(0.70, 0.90, 1.0),
	}
]

var active_character_id: String = "lumine"
var tween_banner: Tween
var wheel_visible: bool = false

@onready var wheel_root: Control = $WheelRoot
@onready var hud_team_list: VBoxContainer = $TeamHud/TeamList
@onready var switch_banner: PanelContainer = $SwitchBanner
@onready var banner_label: Label = $SwitchBanner/BannerMargin/BannerText

func _ready() -> void:
	layer = 100
	if wheel_root != null:
		wheel_root.visible = false
		wheel_root.process_mode = Node.PROCESS_MODE_DISABLED
	switch_banner.visible = false
	switch_banner.modulate.a = 0.0
	_build_team_hud()
	_update_hud_selection()

func set_active_character(id: String) -> void:
	if active_character_id == id:
		return
	active_character_id = id
	_update_hud_selection()
	_show_banner_message(id)

func get_team_info(id: String) -> Dictionary:
	for member: Dictionary in TEAM_MEMBERS:
		if String(member.get("id", "")) == id:
			return member
	return TEAM_MEMBERS[0]

func _build_team_hud() -> void:
	for child in hud_team_list.get_children():
		child.queue_free()
	
	for i in TEAM_MEMBERS.size():
		var member: Dictionary = TEAM_MEMBERS[i]
		var btn := Button.new()
		var m_id: String = String(member.get("id", ""))
		var m_slot: int = int(member.get("slot", 1))
		var m_name: String = String(member.get("name", ""))
		var m_color: Color = member.get("color", Color.WHITE)
		var m_accent: Color = member.get("accent", Color.WHITE)
		
		btn.name = "Slot_" + m_id
		btn.custom_minimum_size = Vector2(170, 42)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		
		var style_normal := StyleBoxFlat.new()
		style_normal.bg_color = Color(0.08, 0.10, 0.14, 0.72)
		style_normal.corner_radius_top_left = 6
		style_normal.corner_radius_top_right = 6
		style_normal.corner_radius_bottom_left = 6
		style_normal.corner_radius_bottom_right = 6
		style_normal.border_width_left = 4
		style_normal.border_color = m_color
		btn.add_theme_stylebox_override("normal", style_normal)
		
		var style_hover := style_normal.duplicate() as StyleBoxFlat
		style_hover.bg_color = Color(0.14, 0.18, 0.24, 0.88)
		style_hover.border_color = m_accent
		btn.add_theme_stylebox_override("hover", style_hover)
		
		btn.text = " [%d]  %s" % [m_slot, m_name]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 15)
		btn.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
		
		var char_id: String = m_id
		btn.pressed.connect(func():
			_trigger_switch(char_id))
		hud_team_list.add_child(btn)

func _update_hud_selection() -> void:
	for i in TEAM_MEMBERS.size():
		var member: Dictionary = TEAM_MEMBERS[i]
		var m_id: String = String(member.get("id", ""))
		var m_slot: int = int(member.get("slot", 1))
		var m_name: String = String(member.get("name", ""))
		var m_color: Color = member.get("color", Color.WHITE)
		var m_accent: Color = member.get("accent", Color.WHITE)
		
		var btn: Button = hud_team_list.get_node_or_null("Slot_" + m_id)
		if btn == null:
			continue
		var is_active: bool = (m_id == active_character_id)
		var style: StyleBoxFlat = btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		if is_active:
			style.bg_color = Color(0.18, 0.22, 0.30, 0.95)
			style.border_width_left = 6
			style.border_color = m_accent
			style.border_width_top = 1
			style.border_width_bottom = 1
			style.border_width_right = 1
			btn.text = " ◆ [%d] %s" % [m_slot, m_name]
			btn.add_theme_color_override("font_color", m_accent)
		else:
			style.bg_color = Color(0.08, 0.10, 0.14, 0.70)
			style.border_width_left = 3
			style.border_color = m_color
			style.border_width_top = 0
			style.border_width_bottom = 0
			style.border_width_right = 0
			btn.text = "   [%d] %s" % [m_slot, m_name]
			btn.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
		btn.add_theme_stylebox_override("normal", style)

func _show_banner_message(id: String) -> void:
	var info: Dictionary = get_team_info(id)
	banner_label.text = "✦ 主控角色已就绪：%s ✦" % String(info.get("title", ""))
	banner_label.add_theme_color_override("font_color", info.get("accent", Color.WHITE))
	switch_banner.visible = true
	if tween_banner != null and tween_banner.is_valid():
		tween_banner.kill()
	tween_banner = create_tween()
	tween_banner.tween_property(switch_banner, "modulate:a", 1.0, 0.18)
	tween_banner.tween_interval(1.8)
	tween_banner.tween_property(switch_banner, "modulate:a", 0.0, 0.35)
	tween_banner.tween_callback(func(): switch_banner.visible = false)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		match code:
			KEY_1:
				if event.pressed: _trigger_switch(String(TEAM_MEMBERS[0].get("id", "")))
			KEY_2:
				if event.pressed: _trigger_switch(String(TEAM_MEMBERS[1].get("id", "")))
			KEY_TAB:
				if event.pressed:
					_cycle_next_character()

func _trigger_switch(target_id: String) -> void:
	if target_id == active_character_id:
		return
	active_character_id = target_id
	_update_hud_selection()
	_show_banner_message(target_id)
	character_selected.emit(target_id)

func _cycle_next_character() -> void:
	var cur_idx: int = 0
	for i in TEAM_MEMBERS.size():
		if String(TEAM_MEMBERS[i].get("id", "")) == active_character_id:
			cur_idx = i
			break
	var next_idx: int = (cur_idx + 1) % TEAM_MEMBERS.size()
	_trigger_switch(String(TEAM_MEMBERS[next_idx].get("id", "")))
