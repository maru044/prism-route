extends CanvasLayer
## Genshin Impact style radial character switch wheel and team HUD.
## Supports numeric keys [1]-[4], wheel selection via [Tab], and HUD clicking.

signal character_selected(character_id: String)

const TEAM_MEMBERS: Array[Dictionary] = [
	{
		"id": "stelle",
		"slot": 1,
		"name": "星",
		"title": "开拓者 · 星",
		"desc": "毁灭 · 物理 | 棒球棍与星核之力",
		"color": Color(0.96, 0.82, 0.28),
		"accent": Color(1.0, 0.92, 0.55),
	},
	{
		"id": "ganyu",
		"slot": 2,
		"name": "甘雨",
		"title": "循旅觅途 · 甘雨",
		"desc": "冰元素 · 弓箭 | 璃月七星秘书",
		"color": Color(0.42, 0.78, 0.98),
		"accent": Color(0.70, 0.90, 1.0),
	},
	{
		"id": "lumine",
		"slot": 3,
		"name": "荧",
		"title": "旅行者 · 荧",
		"desc": "风 / 岩元素 · 单手剑 | 异界寻亲旅者",
		"color": Color(0.98, 0.88, 0.52),
		"accent": Color(1.0, 0.95, 0.70),
	},
	{
		"id": "firefly",
		"slot": 4,
		"name": "流萤",
		"title": "格拉默铁骑 · 流萤",
		"desc": "毁灭 · 火 | 萨姆装甲驾驶员",
		"color": Color(0.38, 0.92, 0.76),
		"accent": Color(0.65, 1.0, 0.88),
	}
]

var active_character_id: String = "stelle"
var hovered_index: int = 0
var wheel_visible: bool = false
var tab_press_time: float = 0.0
var tab_is_down: bool = false
var tween_wheel: Tween
var tween_banner: Tween

@onready var wheel_root: Control = $WheelRoot
@onready var wheel_draw: Control = $WheelRoot/WheelCanvas
@onready var center_title: Label = $WheelRoot/CenterInfo/TitleLabel
@onready var center_name: Label = $WheelRoot/CenterInfo/NameLabel
@onready var center_desc: Label = $WheelRoot/CenterInfo/DescLabel
@onready var center_badge: Label = $WheelRoot/CenterInfo/KeyLabel
@onready var hud_team_list: VBoxContainer = $TeamHud/TeamList
@onready var switch_banner: PanelContainer = $SwitchBanner
@onready var banner_label: Label = $SwitchBanner/BannerMargin/BannerText

func _ready() -> void:
	layer = 100
	wheel_root.visible = false
	wheel_root.modulate.a = 0.0
	switch_banner.visible = false
	switch_banner.modulate.a = 0.0
	if wheel_draw != null and not wheel_draw.draw.is_connected(_on_wheel_draw):
		wheel_draw.draw.connect(_on_wheel_draw)
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

func _process(delta: float) -> void:
	if tab_is_down and not wheel_visible:
		tab_press_time += delta
		if tab_press_time >= 0.18:
			_open_wheel()
	if wheel_visible:
		_update_wheel_hover()
		wheel_draw.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		match code:
			KEY_1:
				if event.pressed: _trigger_switch(String(TEAM_MEMBERS[0].get("id", "")))
			KEY_2:
				if event.pressed: _trigger_switch(String(TEAM_MEMBERS[1].get("id", "")))
			KEY_3:
				if event.pressed: _trigger_switch(String(TEAM_MEMBERS[2].get("id", "")))
			KEY_4:
				if event.pressed: _trigger_switch(String(TEAM_MEMBERS[3].get("id", "")))
			KEY_TAB:
				if event.pressed:
					tab_is_down = true
					tab_press_time = 0.0
				else:
					tab_is_down = false
					if wheel_visible:
						_close_wheel(true)
					elif tab_press_time < 0.18:
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

func _open_wheel() -> void:
	wheel_visible = true
	wheel_root.visible = true
	Engine.time_scale = 0.22
	for i in TEAM_MEMBERS.size():
		if String(TEAM_MEMBERS[i].get("id", "")) == active_character_id:
			hovered_index = i
			break
	_update_center_info(hovered_index)
	
	if tween_wheel != null and tween_wheel.is_valid():
		tween_wheel.kill()
	tween_wheel = create_tween()
	tween_wheel.set_parallel(true)
	tween_wheel.tween_property(wheel_root, "modulate:a", 1.0, 0.15)
	tween_wheel.tween_property(wheel_root, "scale", Vector2.ONE, 0.15).from(Vector2(0.85, 0.85))

func _close_wheel(confirm_selection: bool) -> void:
	wheel_visible = false
	Engine.time_scale = 1.0
	if confirm_selection and hovered_index >= 0 and hovered_index < TEAM_MEMBERS.size():
		var selected_id: String = String(TEAM_MEMBERS[hovered_index].get("id", ""))
		_trigger_switch(selected_id)
	
	if tween_wheel != null and tween_wheel.is_valid():
		tween_wheel.kill()
	tween_wheel = create_tween()
	tween_wheel.set_parallel(true)
	tween_wheel.tween_property(wheel_root, "modulate:a", 0.0, 0.12)
	tween_wheel.tween_property(wheel_root, "scale", Vector2(0.9, 0.9), 0.12)
	tween_wheel.chain().tween_callback(func(): wheel_root.visible = false)

func _update_wheel_hover() -> void:
	var center: Vector2 = wheel_root.get_viewport_rect().size * 0.5
	var mouse_pos: Vector2 = wheel_root.get_viewport().get_mouse_position()
	var offset: Vector2 = mouse_pos - center
	var dist: float = offset.length()
	
	if dist > 35.0:
		var deg: float = rad_to_deg(atan2(offset.y, offset.x))
		if deg < 0:
			deg += 360.0
		if deg >= 225.0 and deg < 315.0:
			hovered_index = 0
		elif deg >= 315.0 or deg < 45.0:
			hovered_index = 1
		elif deg >= 45.0 and deg < 135.0:
			hovered_index = 2
		else:
			hovered_index = 3
	_update_center_info(hovered_index)

func _update_center_info(idx: int) -> void:
	if idx < 0 or idx >= TEAM_MEMBERS.size():
		return
	var member: Dictionary = TEAM_MEMBERS[idx]
	center_name.text = String(member.get("name", ""))
	center_title.text = String(member.get("title", ""))
	center_desc.text = String(member.get("desc", ""))
	center_badge.text = "快捷键 [%d]" % int(member.get("slot", 1))
	center_name.add_theme_color_override("font_color", member.get("accent", Color.WHITE))
	center_title.add_theme_color_override("font_color", member.get("color", Color.WHITE))

func _on_wheel_draw() -> void:
	var center: Vector2 = wheel_draw.size * 0.5
	var outer_r: float = 195.0
	var inner_r: float = 78.0
	var sector_angles: Array[float] = [270.0, 0.0, 90.0, 180.0]
	
	wheel_draw.draw_circle(center, outer_r + 8.0, Color(0.04, 0.06, 0.09, 0.40))
	wheel_draw.draw_circle(center, outer_r, Color(0.08, 0.11, 0.16, 0.85))
	
	for i in 4:
		var base_deg: float = sector_angles[i]
		var is_hovered: bool = (i == hovered_index)
		var m_id: String = String(TEAM_MEMBERS[i].get("id", ""))
		var is_current: bool = (m_id == active_character_id)
		var member: Dictionary = TEAM_MEMBERS[i]
		var m_color: Color = member.get("color", Color.WHITE)
		var m_accent: Color = member.get("accent", Color.WHITE)
		var m_name: String = String(member.get("name", ""))
		var m_slot: int = int(member.get("slot", 1))
		
		var start_rad: float = deg_to_rad(base_deg - 44.0)
		var end_rad: float = deg_to_rad(base_deg + 44.0)
		var r_outer: float = outer_r + (12.0 if is_hovered else 0.0)
		var r_inner: float = inner_r
		
		var poly := PackedVector2Array()
		var steps: int = 24
		for s in range(steps + 1):
			var a: float = lerpf(start_rad, end_rad, float(s) / steps)
			poly.append(center + Vector2(cos(a), sin(a)) * r_outer)
		for s in range(steps, -1, -1):
			var a: float = lerpf(start_rad, end_rad, float(s) / steps)
			poly.append(center + Vector2(cos(a), sin(a)) * r_inner)
		
		var fill_color := Color(0.12, 0.16, 0.23, 0.50)
		if is_hovered:
			fill_color = Color(m_color.r, m_color.g, m_color.b, 0.45)
		elif is_current:
			fill_color = Color(m_color.r * 0.7, m_color.g * 0.7, m_color.b * 0.7, 0.30)
		wheel_draw.draw_colored_polygon(poly, fill_color)
		
		var border_color: Color = m_accent if is_hovered else (m_color if is_current else Color(0.35, 0.40, 0.50, 0.60))
		var border_width: float = 3.5 if is_hovered else (2.0 if is_current else 1.2)
		wheel_draw.draw_arc(center, r_outer, start_rad, end_rad, steps, border_color, border_width)
		
		var dir := Vector2(cos(deg_to_rad(base_deg)), sin(deg_to_rad(base_deg)))
		var badge_pos: Vector2 = center + dir * (outer_r * 0.68)
		var badge_str: String = "[%d] %s" % [m_slot, m_name]
		var font: Font = ThemeDB.fallback_font
		wheel_draw.draw_string(font, badge_pos + Vector2(-36, 6), badge_str, HORIZONTAL_ALIGNMENT_CENTER, 72, 16, border_color)
	
	wheel_draw.draw_circle(center, inner_r, Color(0.06, 0.08, 0.12, 0.95))
	wheel_draw.draw_arc(center, inner_r, 0, TAU, 48, Color(0.85, 0.75, 0.45), 2.5)
