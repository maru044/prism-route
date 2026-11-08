extends Node3D

const CORPSE_SCRIPT = preload("res://scripts/characters/corpse_ragdoll_controller.gd")

@onready var player: CharacterBody3D = $WorldGanyu
@onready var corpse: Node3D = $CorpseCharacter

var drag_anchor: Node3D = null
var is_dragging := false
var current_drag_bone := "LeftFoot"

# UI Nodes
var ui_layer: CanvasLayer = null
var prompt_label: Label = null
var status_label: Label = null
var char_panel: PanelContainer = null
var is_char_panel_open := false
var char_buttons: Array[Button] = []
var char_search_input: LineEdit = null

# Roster
var roster_profiles: Array = []
var current_roster_idx := 0

# Store original player speed for heavy drag feel
var orig_player_run_speed := 4.2

func _ready() -> void:
	_setup_roster()
	_setup_drag_anchor()
	_setup_ui()
	if player and "running_speed" in player:
		orig_player_run_speed = player.running_speed

func _setup_roster() -> void:
	roster_profiles = load("res://scripts/character_mmd_vrm_validation.gd").available_profiles()
	if corpse:
		for i in roster_profiles.size():
			if roster_profiles[i].id == corpse.current_character_id:
				current_roster_idx = i
				break

func _setup_drag_anchor() -> void:
	drag_anchor = Node3D.new()
	drag_anchor.name = "DragAnchor"
	# Held naturally in front of player character's waist/hands at ~0.65m height
	drag_anchor.position = Vector3(0.0, 0.65, 0.85)
	var visual: Node3D = player.get_node_or_null("Visual")
	if visual:
		visual.add_child(drag_anchor)
	else:
		player.add_child(drag_anchor)

func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	
	# Top-left Instructions
	var info_panel := PanelContainer.new()
	info_panel.position = Vector2(24, 24)
	info_panel.size = Vector2(380, 185)
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color(0.08, 0.10, 0.14, 0.88)
	info_style.border_color = Color(0.25, 0.45, 0.65, 0.75)
	info_style.set_border_width_all(2)
	info_style.set_corner_radius_all(8)
	info_style.set_content_margin_all(14)
	info_panel.add_theme_stylebox_override("panel", info_style)
	ui_layer.add_child(info_panel)
	
	var info_vbox := VBoxContainer.new()
	info_panel.add_child(info_vbox)
	
	var title_lbl := Label.new()
	title_lbl.text = "⚔️ 战利品玩弄与拖拽沙盒 (Sandbox)"
	title_lbl.add_theme_font_size_override("font_size", 16)
	info_vbox.add_child(title_lbl)
	info_vbox.add_child(HSeparator.new())
	
	var help_lbl := Label.new()
	help_lbl.text = "• WASD / Shift: 人物移动 / 跑步\n• 鼠标右键拖动: 旋转视角 (支持大仰角特写)\n• 滚轮: 视距拉近/特写 (0.45m～10.0m)\n• [E] 键 (按一次开始/再按结束): 抓取拖拽/放下尸体\n• [C] 键: 呼出换尸角色菜单 (共47位全角色)\n• [Q] 键: 快速切换至下一位尸体角色"
	help_lbl.add_theme_font_size_override("font_size", 13)
	info_vbox.add_child(help_lbl)
	
	# Center Screen Prompts
	prompt_label = Label.new()
	prompt_label.position = Vector2(500, 810)
	prompt_label.size = Vector2(920, 70)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 17)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
	ui_layer.add_child(prompt_label)
	
	# Status message toast
	status_label = Label.new()
	status_label.position = Vector2(500, 880)
	status_label.size = Vector2(920, 40)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	ui_layer.add_child(status_label)
	
	_setup_character_panel()

func _setup_character_panel() -> void:
	char_panel = PanelContainer.new()
	char_panel.position = Vector2(480, 160)
	char_panel.size = Vector2(960, 600)
	char_panel.visible = false
	
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = Color(0.06, 0.08, 0.12, 0.96)
	cstyle.border_color = Color(0.3, 0.75, 0.6, 0.9)
	cstyle.set_border_width_all(3)
	cstyle.set_corner_radius_all(12)
	cstyle.set_content_margin_all(16)
	char_panel.add_theme_stylebox_override("panel", cstyle)
	ui_layer.add_child(char_panel)
	
	var cvbox := VBoxContainer.new()
	char_panel.add_child(cvbox)
	
	var ch_title := Label.new()
	ch_title.text = "👤 切换尸体角色 (Roster Selector · 共 %d 位角色)" % roster_profiles.size()
	ch_title.add_theme_font_size_override("font_size", 18)
	ch_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cvbox.add_child(ch_title)
	cvbox.add_child(HSeparator.new())
	
	# Search line edit
	char_search_input = LineEdit.new()
	char_search_input.placeholder_text = "🔍 搜索角色名称或拼音/ID (例如: 雷电将军, 刻晴, furina)..."
	char_search_input.text_changed.connect(_filter_character_buttons)
	cvbox.add_child(char_search_input)
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(920, 460)
	cvbox.add_child(scroll)
	
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	
	char_buttons.clear()
	for i in roster_profiles.size():
		var profile: Dictionary = roster_profiles[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(215, 42)
		btn.text = "%s (%s)" % [profile.get("label", profile.id), profile.id]
		btn.set_meta("profile_id", profile.id)
		btn.set_meta("profile_label", profile.get("label", profile.id))
		var idx: int = i
		btn.pressed.connect(func():
			_select_character(idx)
		)
		grid.add_child(btn)
		char_buttons.append(btn)
		
	var close_hint := Label.new()
	close_hint.text = "按 [C] 或 [ESC] 关闭角色菜单 · 游戏中按 [Q] 可快速顺切下一位角色"
	close_hint.add_theme_font_size_override("font_size", 12)
	close_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cvbox.add_child(close_hint)

func _filter_character_buttons(query: String) -> void:
	var q := query.strip_edges().to_lower()
	for btn in char_buttons:
		if q.is_empty():
			btn.visible = true
		else:
			var pid: String = btn.get_meta("profile_id", "").to_lower()
			var plabel: String = btn.get_meta("profile_label", "").to_lower()
			btn.visible = q in pid or q in plabel

func _toggle_char_panel() -> void:
	is_char_panel_open = not is_char_panel_open
	char_panel.visible = is_char_panel_open
	if is_char_panel_open and char_search_input:
		char_search_input.text = ""
		_filter_character_buttons("")
		char_search_input.grab_focus()

func _select_character(idx: int) -> void:
	if idx < 0 or idx >= roster_profiles.size(): return
	current_roster_idx = idx
	var profile: Dictionary = roster_profiles[idx]
	var ok: bool = corpse.load_character_from_profile(profile)
	if ok:
		status_label.text = "✓ 已将尸体角色切换为【%s (%s)】！已就绪物理布娃娃瘫态。" % [profile.get("label", profile.id), profile.id]
	else:
		status_label.text = "✕ 角色切换失败: " + profile.id
	is_char_panel_open = false
	char_panel.visible = false

func _cycle_next_character() -> void:
	if roster_profiles.is_empty(): return
	current_roster_idx = (current_roster_idx + 1) % roster_profiles.size()
	_select_character(current_roster_idx)

func _process(_delta: float) -> void:
	var dist_to_corpse := player.global_position.distance_to(corpse.global_position)
	if corpse.character_instance:
		dist_to_corpse = minf(dist_to_corpse, player.global_position.distance_to(corpse.character_instance.global_position))
	if corpse.physical_bones.has("Hips"):
		dist_to_corpse = minf(dist_to_corpse, player.global_position.distance_to(corpse.physical_bones["Hips"].global_position))
		
	var in_range: bool = dist_to_corpse < 3.2
	
	# Raycast check for closest bone to crosshair / camera
	var camera: Camera3D = player.get_node_or_null("CameraPivot/SpringArm3D/Camera3D")
	var detected_bone := "LeftFoot"
	if camera and corpse.has_method("get_closest_bone_to_ray"):
		var ray_origin := camera.global_position
		var ray_dir := -camera.global_transform.basis.z
		var bone_hit: Dictionary = corpse.get_closest_bone_to_ray(ray_origin, ray_dir, 4.5)
		if not bone_hit.bone_name.is_empty():
			detected_bone = bone_hit.bone_name
	
	var char_name: String = corpse.current_character_label
	if is_dragging:
		prompt_label.text = "✊ 正在物理拖拽: %s · %s\n[按 E] 放下肢体  |  [WASD] 移动拖行  |  [Shift] 慢步拖拽" % [char_name, _bone_name_zh(current_drag_bone)]
	elif in_range:
		var bone_zh := _bone_name_zh(detected_bone)
		prompt_label.text = "【纯自然物理布娃娃 · %s】\n[按 E] 拖拽%s  |  [按 C] 换尸(%d/%d)  |  [按 Q] 快速切尸" % [
			char_name, bone_zh, current_roster_idx + 1, roster_profiles.size()
		]
		current_drag_bone = detected_bone
	else:
		prompt_label.text = ""

func _bone_name_zh(bname: String) -> String:
	match bname:
		"LeftFoot": return "左脚踝 (倒提)"
		"RightFoot": return "右脚踝 (倒提)"
		"LeftLowerLeg": return "左小腿"
		"RightLowerLeg": return "右小腿"
		"LeftUpperLeg": return "左大腿"
		"RightUpperLeg": return "右大腿"
		"LeftHand": return "左手腕"
		"RightHand": return "右手腕"
		"Hips": return "腰臀 (提拉)"
		"Head": return "头部"
		_: return "肢体 (" + bname + ")"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			# Toggle E: Single press to start dragging, press again to stop dragging!
			if is_dragging:
				_stop_drag()
			else:
				_start_drag_if_possible()
		elif event.keycode == KEY_C:
			_toggle_char_panel()
		elif event.keycode == KEY_Q:
			_cycle_next_character()
		elif event.keycode == KEY_ESCAPE:
			if is_char_panel_open:
				_toggle_char_panel()

func _start_drag_if_possible() -> void:
	var dist := player.global_position.distance_to(corpse.global_position)
	if corpse.character_instance:
		dist = minf(dist, player.global_position.distance_to(corpse.character_instance.global_position))
	if corpse.physical_bones.has("Hips"):
		dist = minf(dist, player.global_position.distance_to(corpse.physical_bones["Hips"].global_position))
		
	if dist < 3.2:
		is_dragging = true
		corpse.start_drag(current_drag_bone, drag_anchor)
		if player and "running_speed" in player:
			player.running_speed = 2.6 # Heavy drag resistance feel
		status_label.text = "✓ 已抓住 %s 开始拖行，按 [E] 可随时放下。" % _bone_name_zh(current_drag_bone)

func _stop_drag() -> void:
	is_dragging = false
	corpse.stop_drag()
	if player and "running_speed" in player:
		player.running_speed = orig_player_run_speed
	status_label.text = "已松开肢体，尸体自然软瘫在地面上。"
