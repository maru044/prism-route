extends "res://scripts/character_mmd_validation.gd"
## One shared-clock review scene for paired assets and isolated-role diagnostics.
const CATALOG_PATH := "res://assets/characters/mmd_validation/paired/catalog.json"
const ACTOR_SCENE := preload("res://scenes/characters/keqing_mmd_vrm.tscn")
const SHARED_ACTOR_SCENE := preload("res://scenes/characters/shared_humanoid_actor.tscn")
const PARTNER_PROXIES := preload("res://scripts/characters/mmd_partner_colliders.gd")
const HUMANOID_RIG := preload("res://scripts/characters/humanoid_rig.gd")
var actor: Node3D
var initialized := false
var loading := false
var catalog: Dictionary
var pack: Dictionary
var actors := {}
var role_proxies := {}
var visible_roles: Array = []
var current_entry := ""
var current_pack := ""
var library_list := ItemList.new()
var search := LineEdit.new()
var category := OptionButton.new()
var details := Label.new()
var filtered_entries: Array = []
var heading := Label.new()
var hair_on := true
var clothes_on := true
var partner_on := false # 暂时的选择：双人亲密交互碰撞不可预测，容易引起服饰/发丝高频震颤，默认关闭
var stage_collisions_on := false
var group := Node3D.new()
var scope_select := OptionButton.new()
var view_mode := OptionButton.new()
var loop_toggle := CheckButton.new()
var model_controls := VBoxContainer.new()
var count_label := Label.new()
var avatar_profiles: Array = []
var model_overrides := {}
var preview_floor: MeshInstance3D
var ground_body: StaticBody3D
var ground_snap_enabled := false
var furniture_root := Node3D.new()
var furniture_instance: Node3D = null
var furniture_select := OptionButton.new()
var furniture_offset := Vector3.ZERO
var furniture_rot_y := 0.0
var furniture_visible := false
var furniture_catalog: Array = []
var furn_offset_labels := {}
var auto_furn_match := true
var furn_slider_nodes := {}
var first_person_mode := false
var fp_button: Button = null
var fp_yaw_offset := 0.0
var fp_pitch_offset := 0.0
var fp_fov := 72.0
const POSES_DIR := "res://assets/characters/poses"
var is_previewing_pose := false
var active_pose_data: Dictionary = {}
var pose_panel: PanelContainer = null
var pose_list := ItemList.new()
var pose_name_input := LineEdit.new()
var pose_search := LineEdit.new()
var pose_status_label := Label.new()
var pose_role_select := OptionButton.new()
var pose_ground_toggle := CheckButton.new()
var pose_details_label := Label.new()
var pose_count_label := Label.new()
var pose_files: Array[String] = []
var rename_box: HBoxContainer = null
var rename_input: LineEdit = null
var delete_confirm_box: HBoxContainer = null
var delete_confirm_label: Label = null

static func available_profiles() -> Array:
	var result: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/mmd_validation/shared/manifest.json")).profiles
	var ids: Dictionary={}
	for row: Dictionary in result:ids[row.id]=true
	const ROSTER="res://assets/characters/roster/catalog.json"
	if FileAccess.file_exists(ROSTER):
		var roster: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROSTER))
		for row: Dictionary in roster.profiles:
			if not ids.has(row.id):result.append(row);ids[row.id]=true
	return result

func _ready() -> void:
	playing = false
	body_bones = ["下半身","Spine","Chest","Neck","Head","LeftShoulder","LeftUpperArm","LeftLowerArm","LeftHand","RightShoulder","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","LeftToes","RightUpperLeg","RightLowerLeg","RightFoot","RightToes"]
	catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	avatar_profiles=available_profiles()
	const FURN_CAT := "res://assets/furniture/scifi/furniture_catalog.json"
	if FileAccess.file_exists(FURN_CAT):
		var raw_f := FileAccess.get_file_as_string(FURN_CAT)
		var parsed_f: Dictionary = JSON.parse_string(raw_f)
		if parsed_f and parsed_f.has("furniture"):
			furniture_catalog = parsed_f["furniture"]
	add_child(furniture_root)
	_build_library_ui()
	group.name = "PairedActors"
	add_child(group)
	_filter_entries()
	var selected_id: String = catalog.default_entry
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--entry="): selected_id = argument.trim_prefix("--entry=")
	await select_entry(selected_id)
	if "--capture-mmd" in OS.get_cmdline_user_args():
		playing = false
		_capture_sequence.call_deferred()

func _build_library_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var sidebar := PanelContainer.new()
	sidebar.position = Vector2(16,16)
	sidebar.size = Vector2(380,1048)
	layer.add_child(sidebar)
	var margin:=MarginContainer.new()
	for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,12)
	sidebar.add_child(margin)
	var scroll:=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x=340
	scroll.add_child(panel)
	var title := Label.new()
	title.text = "共享动作预览"
	title.add_theme_font_size_override("font_size",25)
	panel.add_child(title)
	var roster_nav_btn := Button.new()
	roster_nav_btn.text = "← 🚶 返回单人中性动作检查 (character_roster_review)"
	roster_nav_btn.custom_minimum_size.y = 30
	roster_nav_btn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/character_roster_review.tscn")
	)
	panel.add_child(roster_nav_btn)
	panel.add_child(count_label)
	scope_select.add_item("已选动作")
	scope_select.add_item("验证样本")
	if not catalog.packs.any(func(p):return p.get("selected",false)):scope_select.select(1)
	panel.add_child(scope_select)
	scope_select.item_selected.connect(func(_index):_filter_entries())
	search.placeholder_text = "搜索动作组"
	panel.add_child(search)
	search.text_changed.connect(func(_value): _filter_entries())
	category.add_item("全部人数")
	category.add_item("单人")
	category.add_item("双人")
	category.add_item("三人")
	category.add_item("多人对照")
	panel.add_child(category)
	category.item_selected.connect(func(_index): _filter_entries())
	library_list.custom_minimum_size = Vector2(340,270)
	panel.add_child(library_list)
	library_list.item_selected.connect(func(index): select_entry(filtered_entries[index].id))
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var mode_label:=Label.new()
	mode_label.text="播放模式"
	panel.add_child(mode_label)
	panel.add_child(view_mode)
	view_mode.item_selected.connect(_on_view_mode)
	var model_label:=Label.new()
	model_label.text="角色选择（共 47 位全图鉴角色自由替换）"
	model_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(model_label)
	panel.add_child(model_controls)
	loop_toggle.text="循环预览（不修改动作）"
	panel.add_child(loop_toggle)
	loop_toggle.toggled.connect(func(value):pack["loop_preview"]=value)
	var light_label := Label.new()
	light_label.text = "光照曝光 (Exposure: 1.00)"
	light_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(light_label)
	var exposure_slider := HSlider.new()
	exposure_slider.min_value = 0.5
	exposure_slider.max_value = 1.6
	exposure_slider.step = 0.05
	exposure_slider.value = 1.0
	panel.add_child(exposure_slider)
	exposure_slider.value_changed.connect(func(v: float):
		if environment:
			environment.tonemap_exposure = v
			light_label.text = "光照曝光 (Exposure: %.2f)" % v
	)
	var ground_snap_toggle := CheckButton.new()
	ground_snap_toggle.text = "贴地校准 (Ground Snap 补偿)"
	ground_snap_toggle.button_pressed = false
	panel.add_child(ground_snap_toggle)
	ground_snap_toggle.toggled.connect(func(enabled: bool):
		_update_ground_snap(enabled)
	)
	var furn_box := VBoxContainer.new()
	panel.add_child(furn_box)
	var furn_label := Label.new()
	furn_label.text = "🪑 科技家具与交互对齐预览"
	furn_label.add_theme_font_size_override("font_size", 14)
	furn_box.add_child(furn_label)
	furniture_select.add_item("隐藏家具 (None)")
	furniture_select.add_item("★ 自动动作匹配 (Auto Match)")
	for item in furniture_catalog:
		furniture_select.add_item(item["name_zh"])
	furniture_select.select(1)
	furniture_visible = true
	auto_furn_match = true
	furn_box.add_child(furniture_select)
	furniture_select.item_selected.connect(_on_furniture_selected)
	var furn_sliders_container := VBoxContainer.new()
	furn_box.add_child(furn_sliders_container)
	for axis_info in [
		{"name": "X", "label": "X 左右", "min": -2.0, "max": 2.0, "step": 0.01, "default": 0.0},
		{"name": "Y", "label": "Y 高程", "min": -0.5, "max": 0.8, "step": 0.01, "default": 0.0},
		{"name": "Z", "label": "Z 进深", "min": -2.0, "max": 2.0, "step": 0.01, "default": 0.0},
		{"name": "Rot", "label": "水平朝向", "min": -180.0, "max": 180.0, "step": 5.0, "default": 0.0}
	]:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s: %.2f" % [axis_info.name, axis_info.default]
		l.custom_minimum_size.x = 75
		furn_offset_labels[axis_info.name] = l
		var s := HSlider.new()
		s.min_value = axis_info.min
		s.max_value = axis_info.max
		s.step = axis_info.step
		s.value = axis_info.default
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		furn_slider_nodes[axis_info.name] = s
		var ax: String = axis_info.name
		s.value_changed.connect(func(v: float):
			_on_furn_slider_changed(ax, v)
		)
		row.add_child(l)
		row.add_child(s)
		furn_sliders_container.add_child(row)
	var reset_furn_btn := Button.new()
	reset_furn_btn.text = "↺ 重置家具位姿偏移"
	reset_furn_btn.pressed.connect(func():
		_reset_furniture_sliders()
	)
	furn_box.add_child(reset_furn_btn)
	details.custom_minimum_size=Vector2(330,240)
	panel.add_child(details)
	heading.position = Vector2(420,24)
	heading.size=Vector2(1470,75)
	heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size",23)
	layer.add_child(heading)
	var controls := VBoxContainer.new()
	controls.position = Vector2(420,966)
	controls.custom_minimum_size = Vector2(1400,100)
	layer.add_child(controls)
	controls.add_child(status)
	timeline.step = 1.0/FPS
	timeline.max_value = 16.0
	controls.add_child(timeline)
	timeline.drag_started.connect(func(): playing = false; is_previewing_pose = false; _refresh_ui())
	timeline.value_changed.connect(func(value):
		if not initialized: return
		playing = false
		is_previewing_pose = false
		seek_frame(roundi(value*FPS)))
	var row := HBoxContainer.new()
	controls.add_child(row)
	row.add_child(play_button)
	play_button.pressed.connect(func():
		if not initialized: return
		if is_previewing_pose:
			is_previewing_pose = false
		if time>=duration: seek_frame(0)
		playing = not playing
		_refresh_ui())
	for view_name in ["正面", "侧面", "背面"]:
		var button := Button.new()
		button.text = view_name
		row.add_child(button)
		button.pressed.connect(func():
			if first_person_mode:
				_set_first_person(false)
			if camera:
				var reversed: bool = _is_pack_reversed()
				match view_name:
					"正面": yaw = PI if reversed else 0.0
					"侧面": yaw = PI / 2
					"背面": yaw = 0.0 if reversed else PI
				_update_camera())
	fp_button = Button.new()
	fp_button.text = "第一人称 (竿役)"
	fp_button.tooltip_text = "切换为角色B (竿役) 第一人称沉浸视角 [快捷键: V]，右键拖拽微调视线，滚轮调节视野(FOV)，中键重置视线"
	row.add_child(fp_button)
	fp_button.pressed.connect(func():
		_set_first_person(not first_person_mode))
	var skeleton_toggle := CheckButton.new()
	skeleton_toggle.text = "骨架"
	row.add_child(skeleton_toggle)
	skeleton_toggle.toggled.connect(func(value): overlay.visible = value)
	for field in ["头发物理","服饰物理","对方碰撞","地面／家具碰撞"]:
		var toggle := CheckButton.new()
		toggle.text = field
		toggle.button_pressed = field in ["头发物理", "服饰物理"]
		if field == "对方碰撞":
			toggle.tooltip_text = "【暂时的选择】默认关闭以防服饰高频震颤。需要观察对方身体碰撞对衣发的影响时可手动开启。"
		elif field == "地面／家具碰撞":
			toggle.tooltip_text = "默认关闭。检查衣发与预览地面或可见家具的接触时开启。"
		row.add_child(toggle)
		toggle.toggled.connect(func(value):
			match field:
				"头发物理": hair_on = value
				"服饰物理": clothes_on = value
				"对方碰撞": partner_on = value
				"地面／家具碰撞":
					stage_collisions_on = value
					_sync_stage_collisions()
			_apply_physics())
	var pose_mgr_btn := Button.new()
	pose_mgr_btn.text = "📷 姿态捕获与管理"
	pose_mgr_btn.tooltip_text = "打开战利品姿态捕获与文件管理器面板 [快捷键: P]"
	row.add_child(pose_mgr_btn)
	pose_mgr_btn.pressed.connect(_toggle_pose_manager)
	var hint := Label.new()
	hint.text = "同一时间轴控制全部角色 · 右键旋转/微调视线 · 滚轮缩放/视场 · [V] 第一人称 · [P] 姿态管理器 · 空格播放/暂停"
	controls.add_child(hint)
	_build_pose_manager_ui(layer)

func _source_badge(item: Dictionary) -> String:
	match item.get("source_library", ""):
		"koikatsu": return "【恋活】"
		"mmd": return "【MMD】"
	return ""

func _filter_entries() -> void:
	filtered_entries.clear()
	library_list.clear()
	for item in catalog.packs:
		if bool(item.get("selected",false))!=(scope_select.selected==0):continue
		var people:int=item.roles.size()
		if category.selected>0 and mini(people,4)!=category.selected:continue
		var entry:Dictionary={}
		for candidate in catalog.entries:
			if candidate.pack==item.id and candidate.roles.size()==people:
				entry=candidate
				break
		if entry.is_empty():continue
		var badge := _source_badge(item)
		var haystack:String=badge + " " + item.label + " " + item.get("title_zh", "") + " " + item.get("category_zh", "") + " " + item.get("description_zh", "")
		if item.has("placement"):
			haystack += " " + str(item.placement.get("type_zh", "")) + " " + str(item.placement.get("prop_needed", ""))
		for track in item.source_tracks:haystack+=" "+str(track.file)
		if not search.text.is_empty() and not haystack.to_lower().contains(search.text.to_lower()): continue
		filtered_entries.append(entry)
		var display_title: String = badge + String(item.get("display_label", "%d人 · %s" % [people,item.label]))
		library_list.add_item(display_title)
		var tooltip_desc: String = item.get("description_zh", "")
		if not tooltip_desc.is_empty():
			library_list.set_item_tooltip(filtered_entries.size()-1, "%s\n\n%s\n\n%d–%d 帧 · %.2f 秒 · %d 个角色位" % [display_title, tooltip_desc, item.frame_start, item.frame_end, item.duration, people])
		else:
			library_list.set_item_tooltip(filtered_entries.size()-1, "%s\n%d–%d 帧 · %.2f 秒 · %d 个角色位" % [display_title, item.frame_start, item.frame_end, item.duration, people])
		if item.id==current_pack:library_list.select(filtered_entries.size()-1)
	count_label.text="%d 个动作组 · 每组只列一次" % filtered_entries.size()
	library_list.custom_minimum_size.y=clampf(filtered_entries.size()*30.0+12.0,150,344)

func _on_view_mode(index:int) -> void:
	if not initialized or loading:return
	visible_roles=[]
	if index==0:
		for role in pack.roles:visible_roles.append(role.id)
	else:visible_roles.append(pack.roles[index-1].id)
	for role_id in actors:actors[role_id].visible=role_id in visible_roles
	_apply_physics()
	_reframe()
	_update_camera()
	_refresh_ui()

func _effective_profile(role:Dictionary) -> String:
	return String(model_overrides.get(role.id,role.profile)) if role.get("shared",false) else String(role.profile)

func _model_label(role:Dictionary) -> String:
	for profile in avatar_profiles:
		if profile.id==_effective_profile(role):return profile.label
	return role.label

func _sync_group_controls() -> void:
	view_mode.clear()
	view_mode.add_item("整组播放")
	for role in pack.roles:view_mode.add_item("只看角色 "+role.id)
	view_mode.select(0)
	if visible_roles.size()==1 and pack.roles.size()>1:
		for i in pack.roles.size():
			if pack.roles[i].id==visible_roles[0]:view_mode.select(i+1)
	for node in model_controls.get_children():node.queue_free()
	for role in pack.roles:
		var row:=HBoxContainer.new()
		var label:=Label.new();label.text="角色 "+role.id;label.custom_minimum_size.x=65;row.add_child(label)
		var options:=OptionButton.new();options.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		for profile in avatar_profiles:
			options.add_item(profile.label)
			options.set_item_metadata(options.item_count-1,profile.id)
			if profile.id==_effective_profile(role):options.select(options.item_count-1)
		options.disabled=not role.get("shared",false)
		options.item_selected.connect(_on_model_choice.bind(String(role.id),options))
		row.add_child(options);model_controls.add_child(row)
	if pack.roles.size() >= 2:
		var swap_btn := Button.new()
		swap_btn.text = "⇄ 互换角色 A 与 B (换位)"
		swap_btn.pressed.connect(swap_roles_a_b)
		model_controls.add_child(swap_btn)
	loop_toggle.set_pressed_no_signal(pack.get("loop_preview",false))

func swap_roles_a_b() -> void:
	if loading or pack.roles.size() < 2: return
	var prof_a: String = _effective_profile(pack.roles[0])
	var prof_b: String = _effective_profile(pack.roles[1])
	model_overrides["A"] = prof_b
	model_overrides["B"] = prof_a
	current_pack = ""
	await select_entry(current_entry)
	_sync_group_controls()
	_refresh_ui()

func _on_model_choice(index:int,role_id:String,options:OptionButton) -> void:
	await set_role_model(role_id,String(options.get_item_metadata(index)))

func set_role_model(role_id:String,profile_id:String) -> void:
	if loading:return
	assert(avatar_profiles.any(func(p):return p.id==profile_id))
	var old_time:=time;var old_playing:=playing;var old_roles:=visible_roles.duplicate();var entry:=current_entry
	model_overrides[role_id]=profile_id
	current_pack=""
	await select_entry(entry)
	visible_roles=old_roles
	for id in actors:actors[id].visible=id in visible_roles
	_apply_physics();seek_frame(roundi(old_time*FPS));playing=old_playing
	_sync_group_controls();_refresh_ui()

func select_entry(id: String) -> void:
	if loading: return
	var entry: Dictionary = {}
	for item in catalog.entries:
		if item.id==id: entry=item
	assert(not entry.is_empty(),"Unknown review entry: "+id)
	loading=true
	playing=false
	library_list.mouse_filter=Control.MOUSE_FILTER_IGNORE
	if current_pack!=entry.pack:
		for node in group.get_children(): node.queue_free()
		actors.clear()
		role_proxies.clear()
		await get_tree().process_frame
		for item in catalog.packs:
			if item.id==entry.pack: pack=item
		assert(not pack.is_empty())
		for i in pack.roles.size():
			var role: Dictionary=pack.roles[i]
			assert(ResourceLoader.exists(role.model) and ResourceLoader.exists(role.motion),"Missing paired asset")
			var instance = (SHARED_ACTOR_SCENE if role.get("shared", false) else ACTOR_SCENE).instantiate()
			instance.name="Role"+role.id
			instance.auto_play=false
			instance.model_resource=role.model
			if role.get("shared",false):
				for profile in avatar_profiles:
					if profile.id==_effective_profile(role):instance.model_resource=profile.model
			instance.motion_resource=role.motion
			instance.profile_resource=role.report
			instance.environment_mask=1
			if role.get("shared", false):
				instance.translation_policy=role.get("translation_policy", "height_scaled")
				var offset: Array=role.get("presentation_offset", [0,0,0])
				var ground_snap_y: float = float(pack.placement.get("ground_offset", 0.0)) if (ground_snap_enabled and pack.has("placement")) else 0.0
				instance.position=Vector3(offset[0], offset[1] + ground_snap_y, offset[2])
			group.add_child(instance)
			actors[role.id]=instance
			if role.get("shared", false) and pack.roles.size()>2 and not pack.get("selected",false):
				var caption:=Label3D.new()
				caption.text=_model_label(role)
				caption.font_size=64
				caption.pixel_size=.003
				caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED
				caption.position=Vector3(0,1.95,0)
				instance.add_child(caption)
		for instance in actors.values():
			if not instance.ready_for_review: await instance.initialized
		for i in pack.roles.size():
			var role: Dictionary=pack.roles[i]
			var proxy = PARTNER_PROXIES.new()
			group.add_child(proxy)
			proxy.configure(actors[role.id].skeleton,1 << (i+1))
			role_proxies[role.id]=proxy
		current_pack=entry.pack
		if first_person_mode:
			_set_first_person(false)
		yaw = PI if _is_pack_reversed() else 0.0
		if auto_furn_match and furniture_visible:
			_auto_match_furniture()
	duration=float(pack.duration)
	timeline.max_value=duration
	visible_roles=entry.roles
	for role_id in actors:
		actors[role_id].visible=role_id in visible_roles
	actor=actors[visible_roles[0]]
	character=actor.character
	skeleton=actor.skeleton
	player=actor.player
	clip_name="mmd/loop03"
	current_entry=id
	scope_select.select(0 if pack.get("selected",false) else 1)
	_apply_physics()
	_reframe()
	if camera==null:
		var initial_bounds:=_review_bounds()
		_build_stage(initial_bounds)
		_add_ground_collision(initial_bounds)
		overlay.mesh=overlay_lines
		overlay.visible=false
		overlay_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		overlay_material.vertex_color_use_as_albedo=true
		overlay_material.no_depth_test=true
		add_child(overlay)
	else: _update_camera()
	initialized=true
	loading=false
	library_list.mouse_filter=Control.MOUSE_FILTER_STOP
	seek_frame(0)
	playing=true
	var role_labels:Array[String]=[]
	var source_labels:Array[String]=[]
	for i in pack.roles.size():
		role_labels.append(pack.roles[i].id+" · "+_model_label(pack.roles[i]))
		var file:String=str(pack.source_tracks[i].file).replace("\\","/").get_file()
		source_labels.append("%s：%s" % [pack.roles[i].label,file])
	var title_display: String = pack.get("display_label", entry.label)
	heading.text = _source_badge(pack) + title_display + "  |  " + " / ".join(role_labels)
	if pack.has("title_zh"):
		var pinfo: Dictionary = pack.get("placement", {})
		var rdesc_lines: Array[String] = []
		if pack.has("roles_desc"):
			for rid in pack.roles_desc:
				rdesc_lines.append("  · 角色 %s: %s" % [rid, pack.roles_desc[rid]])
		details.text = "【姿势】%s (%s)\n【分类】%s  |  【推荐依托】%s\n【基准标高】%.2fm  |  【贴地偏移】%.2fm\n\n【动作详解与特征】\n%s\n\n【角色分工】\n%s\n\n【规格】%d~%d 帧 | %d FPS | %.2f 秒 | %s\n\n※ 提示：对方碰撞已默认关闭（防止双人紧贴时服饰不可预测地持续震颤，属于当前阶段的暂时选择，可在底部控制栏随时手动开启）。" % [
			pack.title_zh, pack.label,
			pack.get("category_zh", ""),
			pinfo.get("prop_needed", "地面"),
			pinfo.get("base_height", 0.0),
			pinfo.get("ground_offset", 0.0),
			pack.get("description_zh", ""),
			"\n".join(rdesc_lines),
			pack.frame_start, pack.frame_end, int(catalog.fps), duration, ", ".join(visible_roles)
		]
	elif pack.get("shared", false):
		details.text="%s\n\n%d 个角色实例，共用标准人形姿态资源。\n保留各自骨长与辅助骨结构。\n\n%.3f 秒 / %d FPS\n资源按来源角色位保存，不为目标角色复制。\n\n并排布局仅供观察；双人组保留共同坐标。\n头发与服饰使用各角色已有配置。\n接触适配与物理美术质量需另行审核。" % [pack.label,visible_roles.size(),duration,int(catalog.fps)]
	elif pack.get("selected",false):
		details.text="源范围 %d–%d 帧\n%.2f 秒 · %d 个角色位\n\n整组共用时间与坐标。模型可切换，动作资源保持共享。\n\n本批是身体动作；原表情、专有形变和道具独立接入。\n循环预览不代表接缝已修整。" % [pack.frame_start,pack.frame_end,duration,pack.roles.size()]
	if current_pack=="shared_walk":
		details.text="历史 VRMA 共享走路样本（非地图 A05）\n地图基础动作请打开 character_roster_review 场景。\n\n"+details.text
	_sync_group_controls()
	_filter_entries()
	_refresh_ui()

func _update_ground_snap(enabled: bool) -> void:
	ground_snap_enabled = enabled
	var offset_y: float = float(pack.placement.get("ground_offset", 0.0)) if (enabled and pack.has("placement")) else 0.0
	for role_id in actors:
		var inst: Node3D = actors[role_id]
		var orig_offset: Array = [0, 0, 0]
		for r in pack.roles:
			if r.id == role_id:
				orig_offset = r.get("presentation_offset", [0, 0, 0])
		inst.position = Vector3(orig_offset[0], orig_offset[1] + offset_y, orig_offset[2])

func _apply_physics() -> void:
	for role_id in actors:
		var instance=actors[role_id]
		var active: bool=role_id in visible_roles
		var other_mask:=0
		for i in pack.roles.size():
			if pack.roles[i].id!=role_id and pack.roles[i].id in visible_roles: other_mask |= 1 << (i+1)
		instance.environment_mask=1|(other_mask if partner_on and visible_roles.size()>1 else 0)
		for spring in instance.all_springs: spring.environment_collision_mask=instance.environment_mask
		instance.set_physics_enabled(active and hair_on,active and clothes_on)
		instance.seek(time)
		if role_id in role_proxies:
			role_proxies[role_id].enabled=active and partner_on
			role_proxies[role_id].update_proxies()

func _review_bounds() -> AABB:
	var bounds:=AABB()
	var first:=true
	var previous_time:=time
	for fraction in [0.0,.25,.5,.75,1.0]:
		_seek_animation(duration*fraction)
		for role_id in visible_roles:
			var skel: Skeleton3D=actors[role_id].skeleton
			for name in body_bones:
				var index:=skel.find_bone(name)
				if index<0: continue
				var p:=skel.global_transform*skel.get_bone_global_pose(index).origin
				if first:
					bounds=AABB(p,Vector3.ZERO)
					first=false
				else: bounds=bounds.expand(p)
	_seek_animation(previous_time)
	return bounds

func _reframe() -> void:
	var bounds:=_review_bounds()
	camera_target=bounds.get_center()+Vector3(0,.05,0)
	distance=maxf(2.8,bounds.size.length()*1.9)
	_position_stage(bounds)

func _build_stage(bounds:AABB) -> void:
	super._build_stage(bounds)
	for child in get_children():
		if child is MeshInstance3D and child.mesh is PlaneMesh:preview_floor=child
	_position_stage(bounds)

func _position_stage(bounds:AABB) -> void:
	var floor_position:=Vector3(camera_target.x,minf(0,bounds.position.y-.02),camera_target.z)
	if preview_floor:preview_floor.position=floor_position
	if ground_body:ground_body.position=floor_position-Vector3(0,.05,0)

func _add_ground_collision(bounds: AABB) -> void:
	var body:=StaticBody3D.new()
	ground_body=body
	body.position=Vector3(camera_target.x,minf(0,bounds.position.y-.02)-.05,camera_target.z)
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(8,.1,8)
	shape.shape=box
	body.add_child(shape)
	add_child(body)
	_sync_stage_collisions()

func _sync_stage_collisions() -> void:
	if is_instance_valid(ground_body):
		ground_body.collision_layer = 1 if stage_collisions_on else 0
	if is_instance_valid(furniture_instance):
		var collision_active := stage_collisions_on and furniture_instance.visible
		furniture_instance.process_mode = Node.PROCESS_MODE_INHERIT if collision_active else Node.PROCESS_MODE_DISABLED

func _set_furniture_preview_visible(shown: bool) -> void:
	if not is_instance_valid(furniture_instance): return
	furniture_instance.visible = shown
	_sync_stage_collisions()

func _seek_animation(value: float) -> void:
	for instance in actors.values(): instance.seek(value)
	for proxy in role_proxies.values(): proxy.update_proxies()

func _advance_animation(delta: float) -> void:
	var next_time:=time+delta
	var wrapped: bool=pack.get("loop_preview", false) and next_time>=duration
	time=fmod(next_time,duration) if wrapped else minf(next_time,duration)
	# One absolute time sample, never one independent delta accumulator per role.
	# A prepared seam can keep the spring history across an ordinary wrap.
	var reset_physics: bool = delta > 0.1 or (wrapped and not pack.get("seamless_loop", false))
	for instance in actors.values():
		if reset_physics: instance.seek(time)
		else: instance.sample_time(time)
	for proxy in role_proxies.values(): proxy.update_proxies()

func _process(delta: float) -> void:
	if not initialized or loading: return
	if playing:
		_advance_animation(delta)
		if time>=duration and not pack.get("loop_preview", false): playing=false
		timeline.set_value_no_signal(time)
		_refresh_ui()
	if first_person_mode:
		_update_first_person_camera()
	if overlay.visible:
		overlay_lines.clear_surfaces()
		overlay_lines.surface_begin(Mesh.PRIMITIVE_LINES,overlay_material)
		for role_id in visible_roles:
			var skel: Skeleton3D=actors[role_id].skeleton
			for name in body_bones:
				var index:=skel.find_bone(name)
				if index<0: continue
				var parent:=skel.get_bone_parent(index)
				if parent<0: continue
				var color:=Color("51d5e8") if role_id=="A" else Color("f2ba76")
				overlay_lines.surface_set_color(color)
				overlay_lines.surface_add_vertex(skel.global_transform*skel.get_bone_global_pose(parent).origin)
				overlay_lines.surface_set_color(color)
				overlay_lines.surface_add_vertex(skel.global_transform*skel.get_bone_global_pose(index).origin)
		overlay_lines.surface_end()

func seek_frame(frame: int) -> void:
	super.seek_frame(frame)
	if first_person_mode:
		_update_first_person_camera()

func _refresh_ui() -> void:
	if not initialized: return
	var phases: Array[String]=[]
	for role_id in visible_roles:
		phases.append("%s %03d" % [role_id,roundi(actors[role_id].time*FPS)])
	var view_str := "  |  [第一人称·右键微调视线]" if first_person_mode else ""
	status.text="共同时间 %.2f s  |  帧 %03d / %d  |  %s%s" % [time,roundi(time*FPS),roundi(duration*FPS)," / ".join(phases), view_str]
	play_button.text="暂停动作" if playing else "播放动作"

func _unhandled_input(event: InputEvent) -> void:
	if not initialized: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_V:
			_set_first_person(not first_person_mode)
			return
		elif event.keycode == KEY_P:
			_toggle_pose_manager()
			return
	if first_person_mode:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				dragging = event.pressed
			elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
				fp_yaw_offset = 0.0
				fp_pitch_offset = 0.0
				_update_first_person_camera()
			elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				fp_fov = clampf(fp_fov + (-3.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 3.0), 40.0, 95.0)
				_update_first_person_camera()
		elif event is InputEventMouseMotion and dragging:
			fp_yaw_offset = clampf(fp_yaw_offset - event.relative.x * 0.005, -deg_to_rad(85.0), deg_to_rad(85.0))
			fp_pitch_offset = clampf(fp_pitch_offset - event.relative.y * 0.005, -deg_to_rad(75.0), deg_to_rad(75.0))
			_update_first_person_camera()
		elif event.is_action_pressed("ui_accept"):
			playing = not playing
			_refresh_ui()
	else:
		super._unhandled_input(event)

func _set_first_person(enabled: bool) -> void:
	first_person_mode = enabled
	if fp_button:
		fp_button.text = "[第一人称 (竿役)]" if first_person_mode else "第一人称 (竿役)"
	if first_person_mode:
		fp_yaw_offset = 0.0
		fp_pitch_offset = 0.0
		_update_first_person_camera()
	else:
		if camera:
			camera.fov = 38.0
			camera.near = 0.02
			_update_camera()

func _update_first_person_camera() -> void:
	if not first_person_mode or not camera:
		return
	var target_role := "B"
	if not actors.has(target_role) or not actors[target_role].visible:
		target_role = "A"
	if not actors.has(target_role):
		return
	
	var actor_instance = actors[target_role]
	var skel: Skeleton3D = actor_instance.skeleton
	if not skel:
		return
	
	var head_idx := skel.find_bone("Head")
	if head_idx < 0:
		return
	
	var head_xf: Transform3D = skel.global_transform * skel.get_bone_global_pose(head_idx)
	var le_idx := skel.find_bone("LeftEye")
	var re_idx := skel.find_bone("RightEye")
	
	var eye_pos: Vector3
	var base_forward: Vector3
	var base_up: Vector3
	
	if le_idx >= 0 and re_idx >= 0:
		var le_wp: Vector3 = (skel.global_transform * skel.get_bone_global_pose(le_idx)).origin
		var re_wp: Vector3 = (skel.global_transform * skel.get_bone_global_pose(re_idx)).origin
		eye_pos = (le_wp + re_wp) * 0.5
		base_forward = (eye_pos - head_xf.origin).normalized()
		if base_forward.length_squared() < 0.1:
			base_forward = -head_xf.basis.z.normalized()
		base_up = head_xf.basis.y.normalized()
	else:
		base_forward = -head_xf.basis.z.normalized()
		base_up = head_xf.basis.y.normalized()
		eye_pos = head_xf.origin + base_forward * 0.08 + base_up * 0.03
	
	var cam_pos: Vector3 = eye_pos + base_forward * 0.05
	var base_right := base_forward.cross(base_up).normalized()
	if base_right.length_squared() < 0.1:
		base_right = Vector3.RIGHT
	base_up = base_right.cross(base_forward).normalized()
	
	var look_dir := base_forward.rotated(base_up, fp_yaw_offset)
	var current_right := look_dir.cross(base_up).normalized()
	look_dir = look_dir.rotated(current_right, fp_pitch_offset).normalized()
	var current_up := current_right.cross(look_dir).normalized()
	
	camera.global_position = cam_pos
	camera.look_at(cam_pos + look_dir, current_up)
	camera.fov = fp_fov
	camera.near = 0.03

func _capture_sequence() -> void:
	var directory:="res://.godot/mmd_pair_validation"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): directory=argument.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	playing=false
	var capture_frames: Array=[0,6,12,18] if current_pack=="shared_walk" else [0,60,240,480]
	for frame in capture_frames:
		seek_frame(frame)
		await get_tree().create_timer(.8).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory+"/paired_%03d.png" % frame)
	yaw=PI/2
	_update_camera()
	seek_frame(6 if current_pack=="shared_walk" else 60)
	await get_tree().create_timer(.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory+("/paired_side_006.png" if current_pack=="shared_walk" else "/paired_side_060.png"))
	get_tree().quit()

func _on_furniture_selected(index: int) -> void:
	if index == 0:
		furniture_visible = false
		auto_furn_match = false
		_set_furniture_preview_visible(false)
	elif index == 1:
		furniture_visible = true
		auto_furn_match = true
		_auto_match_furniture()
	else:
		furniture_visible = true
		auto_furn_match = false
		var furn_data: Dictionary = furniture_catalog[index - 2]
		_load_furniture(furn_data)

func _is_pack_reversed() -> bool:
	if not pack or pack.is_empty(): return false
	return pack.id in [
		"mmd_71dec5bd8390", "shared_mmd_role_a", "shared_pair",
		"mmd_fcc0340f8227", "mmd_87e004f6db53", "mmd_c63e75bc7057",
		"mmd_fca4bab1635f", "mmd_86e40adc8f14"
	]

func _auto_match_furniture() -> void:
	if not furniture_visible or not auto_furn_match or not pack or pack.is_empty():
		return
	var target_id := ""
	var default_offset := Vector3.ZERO
	var default_rot := 0.0

	# 装配极简科技系列定制家具：折面单人椅（prism_geo_chair）与几何双人床（prism_geo_bed）
	match pack.id:
		"mmd_781d8c87fd79": # Welcome - BJV2 (受纳方端坐受纳，角色对齐单人椅 Anchor_Seat，家具零偏移静止)
			target_id = "prism_geo_chair"
			default_offset = Vector3.ZERO
			default_rot = 0.0
		"mmd_beee0d2eb57b": # Loop 20 Chikan 03 (坐姿膝上怀抱把玩)
			target_id = "prism_geo_chair"
			default_offset = Vector3.ZERO
			default_rot = 0.0
		"mmd_160b1e7a411c": # 浪漫情侣背面坐位 (Lap Sitting，角色对齐单人椅 Anchor_Seat，家具零偏移静止)
			target_id = "prism_geo_chair"
			default_offset = Vector3.ZERO
			default_rot = 0.0
		"mmd_0a3f6ba5f5de": # 床沿仰卧互动 (床沿定位点 Anchor_BedEdge_Front)
			target_id = "prism_geo_bed"
			default_offset = Vector3(0.0, 0.0, -1.33)
			default_rot = 0.0
		"mmd_71dec5bd8390": # Loop 03 双女床沿闲坐温存 (床沿定位点 Anchor_BedEdge_Front)
			target_id = "prism_geo_bed"
			default_offset = Vector3(0.0, 0.0, -1.82)
			default_rot = 0.0
		"mmd_aec34d147925": # Loop 05 双女床沿深层爱抚 (床沿定位点 Anchor_BedEdge_Front)
			target_id = "prism_geo_bed"
			default_offset = Vector3(0.0, 0.0, -1.28)
			default_rot = 0.0
		"mmd_43916ffe3d35": # 双人夜色卧姿骑乘 (床面中心定位点 Anchor_Bed_Center)
			target_id = "prism_geo_bed"
			default_offset = Vector3(0.0, 0.0, -0.30)
			default_rot = 0.0
		"mmd_6e891982bb51": # Loop 02 单人自慰循环 (床头靠倚定位点 Anchor_Bed_Headboard)
			target_id = "prism_geo_bed"
			default_offset = Vector3(0.0, 0.0, 0.45)
			default_rot = 0.0
		"mmd_fca4bab1635f": # TSFB V2 经典俯身扶桌后背位 (自动匹配科技长案桌 Anchor_Desk_Surface)
			target_id = "prism_geo_desk"
			default_offset = Vector3.ZERO
			default_rot = 0.0
		_:
			# 其余地面通用/空中动作不默认配家具，保持场景开阔空置（如 mmd_16a2ecfb7781 平躺口交、mmd_1256ad646811 汤匙位等）
			target_id = ""

	if target_id != "":
		for item in furniture_catalog:
			if item.id == target_id:
				_load_furniture(item, default_offset, default_rot)
				break
	else:
		_set_furniture_preview_visible(false)

func _load_furniture(data: Dictionary, default_pos: Vector3 = Vector3.ZERO, default_rot_deg: float = 0.0) -> void:
	_set_furniture_preview_visible(false)
	for c in furniture_root.get_children():
		c.queue_free()
	furniture_instance = null
	var path_to_load: String = data.get("scene_file", data.file) if ResourceLoader.exists(data.get("scene_file", "")) else data.file
	if not ResourceLoader.exists(path_to_load):
		return
	var res = load(path_to_load)
	if res:
		furniture_instance = res.instantiate()
		furniture_root.add_child(furniture_instance)
		_set_furniture_preview_visible(furniture_visible)
		_set_furniture_sliders(default_pos, default_rot_deg)

func _set_furniture_sliders(pos: Vector3, rot_deg: float) -> void:
	furniture_offset = pos
	furniture_rot_y = deg_to_rad(rot_deg)
	if furn_slider_nodes.has("X"): furn_slider_nodes["X"].set_value_no_signal(pos.x)
	if furn_slider_nodes.has("Y"): furn_slider_nodes["Y"].set_value_no_signal(pos.y)
	if furn_slider_nodes.has("Z"): furn_slider_nodes["Z"].set_value_no_signal(pos.z)
	if furn_slider_nodes.has("Rot"): furn_slider_nodes["Rot"].set_value_no_signal(rot_deg)
	if furn_offset_labels.has("X"): furn_offset_labels["X"].text = "X: %.2f" % pos.x
	if furn_offset_labels.has("Y"): furn_offset_labels["Y"].text = "Y: %.2f" % pos.y
	if furn_offset_labels.has("Z"): furn_offset_labels["Z"].text = "Z: %.2f" % pos.z
	if furn_offset_labels.has("Rot"): furn_offset_labels["Rot"].text = "Rot: %.0f°" % rot_deg
	_update_furniture_transform()

func _reset_furniture_sliders() -> void:
	_set_furniture_sliders(Vector3.ZERO, 0.0)

func _on_furn_slider_changed(axis: String, val: float) -> void:
	match axis:
		"X": furniture_offset.x = val
		"Y": furniture_offset.y = val
		"Z": furniture_offset.z = val
		"Rot": furniture_rot_y = deg_to_rad(val)
	if furn_offset_labels.has(axis):
		furn_offset_labels[axis].text = ("%s: %.2f" % [axis, val]) if axis != "Rot" else ("Rot: %.0f°" % val)
	_update_furniture_transform()

func _update_furniture_transform() -> void:
	if furniture_instance:
		furniture_instance.position = furniture_offset
		furniture_instance.rotation = Vector3(0, furniture_rot_y, 0)


# ==============================================================================
# 战利品姿态捕获与文件管理器系统 (Pose Snapshot & File Resource Manager)
# ==============================================================================

func _build_pose_manager_ui(layer: CanvasLayer) -> void:
	pose_panel = PanelContainer.new()
	pose_panel.position = Vector2(1480, 24)
	pose_panel.size = Vector2(420, 920)
	pose_panel.visible = false
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14, 0.94)
	style.border_color = Color(0.28, 0.48, 0.72, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	pose_panel.add_theme_stylebox_override("panel", style)
	layer.add_child(pose_panel)
	
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pose_panel.add_child(vbox)
	
	# Header
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title_lbl := Label.new()
	title_lbl.text = "📷 战利品姿态管理器"
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_lbl)
	
	var close_btn := Button.new()
	close_btn.text = " ✕ "
	close_btn.tooltip_text = "关闭面板 [快捷键: P]"
	close_btn.pressed.connect(func(): pose_panel.visible = false)
	header.add_child(close_btn)
	
	vbox.add_child(HSeparator.new())
	
	# Section 1: Capture
	var cap_title := Label.new()
	cap_title.text = "【姿态快照】捕获当前骨骼状态为姿态资源"
	cap_title.add_theme_font_size_override("font_size", 13)
	vbox.add_child(cap_title)
	
	var cap_row1 := HBoxContainer.new()
	vbox.add_child(cap_row1)
	var r_lbl := Label.new()
	r_lbl.text = "目标通道:"
	cap_row1.add_child(r_lbl)
	pose_role_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap_row1.add_child(pose_role_select)
	pose_ground_toggle.text = "贴地对齐"
	pose_ground_toggle.button_pressed = true
	pose_ground_toggle.tooltip_text = "开启时自动检测角色与地面最低骨骼触点，将姿态垂直重心贴地对齐（适合平放或床面）。"
	cap_row1.add_child(pose_ground_toggle)
	
	var cap_row2 := HBoxContainer.new()
	vbox.add_child(cap_row2)
	pose_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pose_name_input.placeholder_text = "姿态文件名 (如 pose_bed_spread)"
	cap_row2.add_child(pose_name_input)
	
	var auto_name_btn := Button.new()
	auto_name_btn.text = "⚡ 自动命名"
	auto_name_btn.tooltip_text = "根据当前动作编号、角色通道和帧编号自动生成语义化文件名"
	auto_name_btn.pressed.connect(_suggest_pose_name)
	cap_row2.add_child(auto_name_btn)
	
	var cap_btn := Button.new()
	cap_btn.text = "📸 捕获当前帧并导出姿态文件 (.json)"
	cap_btn.custom_minimum_size.y = 32
	cap_btn.pressed.connect(_capture_current_pose)
	vbox.add_child(cap_btn)
	
	vbox.add_child(HSeparator.new())
	
	# Section 2: Library
	var lib_header := HBoxContainer.new()
	vbox.add_child(lib_header)
	pose_count_label.text = "📁 已存姿态库 (0 个)"
	pose_count_label.add_theme_font_size_override("font_size", 13)
	pose_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lib_header.add_child(pose_count_label)
	
	var refresh_btn := Button.new()
	refresh_btn.text = "🔄 刷新"
	refresh_btn.pressed.connect(_refresh_pose_list)
	lib_header.add_child(refresh_btn)
	
	var folder_btn := Button.new()
	folder_btn.text = "📂 打开目录"
	folder_btn.tooltip_text = "在系统资源管理器中打开姿态文件存储目录"
	folder_btn.pressed.connect(_open_poses_folder)
	lib_header.add_child(folder_btn)
	
	pose_search.placeholder_text = "🔍 过滤搜索姿态名称..."
	pose_search.text_changed.connect(func(_t: String): _refresh_pose_list())
	vbox.add_child(pose_search)
	
	pose_list.custom_minimum_size = Vector2(390, 240)
	pose_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pose_list.item_selected.connect(_on_pose_item_selected)
	pose_list.item_activated.connect(func(_idx: int): _preview_selected_pose())
	vbox.add_child(pose_list)
	
	pose_details_label.text = "点击上方文件可查看元数据，双击直接预览。"
	pose_details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pose_details_label.custom_minimum_size.y = 50
	pose_details_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(pose_details_label)
	
	vbox.add_child(HSeparator.new())
	
	# Section 3: Operations
	var op_row1 := HBoxContainer.new()
	vbox.add_child(op_row1)
	var prev_btn := Button.new()
	prev_btn.text = "▶ 应用/预览姿态"
	prev_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev_btn.custom_minimum_size.y = 30
	prev_btn.tooltip_text = "冻结当前动作播放，将选中姿态的骨骼位姿应用至场景模型"
	prev_btn.pressed.connect(_preview_selected_pose)
	op_row1.add_child(prev_btn)
	
	var resume_btn := Button.new()
	resume_btn.text = "↺ 恢复动作播放"
	resume_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume_btn.custom_minimum_size.y = 30
	resume_btn.pressed.connect(_resume_from_pose_preview)
	op_row1.add_child(resume_btn)
	
	var op_row2 := HBoxContainer.new()
	vbox.add_child(op_row2)
	var rename_btn := Button.new()
	rename_btn.text = "✏️ 重命名"
	rename_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rename_btn.pressed.connect(_start_rename)
	op_row2.add_child(rename_btn)
	
	var delete_btn := Button.new()
	delete_btn.text = "🗑️ 删除文件"
	delete_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_btn.pressed.connect(_start_delete)
	op_row2.add_child(delete_btn)
	
	# Inline rename box
	rename_box = HBoxContainer.new()
	rename_box.visible = false
	vbox.add_child(rename_box)
	rename_input = LineEdit.new()
	rename_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rename_box.add_child(rename_input)
	var conf_ren_btn := Button.new()
	conf_ren_btn.text = "✓ 确认"
	conf_ren_btn.pressed.connect(_confirm_rename)
	rename_box.add_child(conf_ren_btn)
	var cancel_ren_btn := Button.new()
	cancel_ren_btn.text = "✕ 取消"
	cancel_ren_btn.pressed.connect(func(): rename_box.visible = false)
	rename_box.add_child(cancel_ren_btn)
	
	# Inline delete confirmation box
	delete_confirm_box = HBoxContainer.new()
	delete_confirm_box.visible = false
	vbox.add_child(delete_confirm_box)
	delete_confirm_label = Label.new()
	delete_confirm_label.text = "确定删除？"
	delete_confirm_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_confirm_label.add_theme_font_size_override("font_size", 12)
	delete_confirm_box.add_child(delete_confirm_label)
	var conf_del_btn := Button.new()
	conf_del_btn.text = "✓ 确认删除"
	conf_del_btn.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	conf_del_btn.pressed.connect(_confirm_delete)
	delete_confirm_box.add_child(conf_del_btn)
	var cancel_del_btn := Button.new()
	cancel_del_btn.text = "✕ 取消"
	cancel_del_btn.pressed.connect(func(): delete_confirm_box.visible = false)
	delete_confirm_box.add_child(cancel_del_btn)
	
	# Status message label
	pose_status_label.text = "就绪。按 [P] 随时切换此管理器。"
	pose_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pose_status_label.add_theme_font_size_override("font_size", 12)
	pose_status_label.custom_minimum_size.y = 36
	vbox.add_child(pose_status_label)

func _toggle_pose_manager() -> void:
	if not pose_panel: return
	pose_panel.visible = not pose_panel.visible
	if pose_panel.visible:
		_update_pose_roles_dropdown()
		_suggest_pose_name()
		_refresh_pose_list()

func _update_pose_roles_dropdown() -> void:
	pose_role_select.clear()
	if not pack or not pack.has("roles"): return
	for i in pack.roles.size():
		var r: Dictionary = pack.roles[i]
		var rid: String = r.id
		var role_tag := " (受体/被动)" if (i == 0 or rid == "B") else ""
		pose_role_select.add_item("角色 %s (%s)%s" % [rid, _model_label(r), role_tag])
		pose_role_select.set_item_metadata(i, rid)
	if visible_roles.size() == 1:
		for i in pose_role_select.item_count:
			if String(pose_role_select.get_item_metadata(i)) == visible_roles[0]:
				pose_role_select.select(i)
				break
	elif pose_role_select.item_count > 1:
		var found_b := false
		for i in pose_role_select.item_count:
			if String(pose_role_select.get_item_metadata(i)) == "B":
				pose_role_select.select(i)
				found_b = true
				break
		if not found_b:
			pose_role_select.select(0)

func _suggest_pose_name() -> void:
	var role_id := "B"
	if pose_role_select.item_count > 0 and pose_role_select.selected >= 0:
		role_id = String(pose_role_select.get_item_metadata(pose_role_select.selected))
	elif not visible_roles.is_empty():
		role_id = visible_roles[0]
	var clean_pack: String = current_pack.trim_prefix("shared_").replace("-", "_")
	var frame_idx: int = roundi(time * FPS)
	pose_name_input.text = "pose_%s_%s_f%03d" % [clean_pack, role_id.to_lower(), frame_idx]

func _capture_current_pose() -> void:
	if not initialized or loading: return
	var role_id := "B"
	if pose_role_select.item_count > 0 and pose_role_select.selected >= 0:
		role_id = String(pose_role_select.get_item_metadata(pose_role_select.selected))
	elif not visible_roles.is_empty():
		role_id = visible_roles[0]
	
	if not actors.has(role_id):
		pose_status_label.text = "错误: 角色 %s 实例不存在" % role_id
		return
	
	var inst = actors[role_id]
	var skel: Skeleton3D = inst.skeleton
	if not skel:
		pose_status_label.text = "错误: 角色 %s 骨架不存在" % role_id
		return
	
	var pose_name: String = pose_name_input.text.strip_edges()
	if pose_name.is_empty():
		_suggest_pose_name()
		pose_name = pose_name_input.text.strip_edges()
	if pose_name.ends_with(".json"):
		pose_name = pose_name.trim_suffix(".json")
	
	var char_pos: Vector3 = inst.character.position
	var char_rot: Vector3 = inst.character.rotation
	
	if pose_ground_toggle.button_pressed:
		var lowest_y := 999.0
		for i in skel.get_bone_count():
			var p := (skel.global_transform * skel.get_bone_global_pose(i)).origin
			if p.y < lowest_y:
				lowest_y = p.y
		if lowest_y < 900.0:
			char_pos.y -= lowest_y
	
	var bones_data: Dictionary = {}
	for i in skel.get_bone_count():
		var bname: String = skel.get_bone_name(i)
		if bname.begins_with("hair") or bname.begins_with("skirt") or bname.begins_with("Spring") or bname.contains("Collider"):
			continue
		var rot: Quaternion = skel.get_bone_pose_rotation(i)
		var pos: Vector3 = skel.get_bone_pose_position(i)
		var b_entry: Dictionary = {
			"rot": [snappedf(rot.x, 0.0001), snappedf(rot.y, 0.0001), snappedf(rot.z, 0.0001), snappedf(rot.w, 0.0001)]
		}
		if pos.length_squared() > 0.00001:
			b_entry["pos"] = [snappedf(pos.x, 0.001), snappedf(pos.y, 0.001), snappedf(pos.z, 0.001)]
		bones_data[bname] = b_entry
	
	var pose_data: Dictionary = {
		"schema": "prism_pose_v2",
		"source_model": inst.model_resource,
		"name": pose_name,
		"created_at": Time.get_datetime_string_from_system(),
		"source_pack": current_pack,
		"source_pack_title": pack.get("title_zh", pack.label),
		"source_role": role_id,
		"source_time": snappedf(time, 0.001),
		"source_frame": roundi(time * FPS),
		"grounded": pose_ground_toggle.button_pressed,
		"character_pos": [snappedf(char_pos.x, 0.001), snappedf(char_pos.y, 0.001), snappedf(char_pos.z, 0.001)],
		"character_rot": [snappedf(char_rot.x, 0.001), snappedf(char_rot.y, 0.001), snappedf(char_rot.z, 0.001)],
		"bone_count": bones_data.size(),
		"bones": bones_data
	}
	var rig := HUMANOID_RIG.new()
	if not rig.setup(skel):
		pose_status_label.text = "无法识别身体根与骨盆，未保存姿态"
		return
	var skel_in_model: Transform3D = inst.character.global_transform.affine_inverse() * skel.global_transform
	pose_data["humanoid_pose"] = rig.capture_pose(skel_in_model.basis.inverse() * char_pos)
	
	if not DirAccess.dir_exists_absolute(POSES_DIR):
		DirAccess.make_dir_recursive_absolute(POSES_DIR)
	
	var file_path := POSES_DIR + "/" + pose_name + ".json"
	var fa := FileAccess.open(file_path, FileAccess.WRITE)
	if fa:
		fa.store_string(JSON.stringify(pose_data, "	"))
		fa.close()
		pose_status_label.text = "✓ 成功保存姿态: %s.json (%d 根骨骼)" % [pose_name, bones_data.size()]
		_refresh_pose_list()
		for idx in pose_files.size():
			if pose_files[idx] == pose_name + ".json":
				pose_list.select(idx)
				_on_pose_item_selected(idx)
				break
	else:
		pose_status_label.text = "✕ 保存失败: 无法写入 " + file_path

func _refresh_pose_list() -> void:
	pose_files.clear()
	pose_list.clear()
	if rename_box: rename_box.visible = false
	if delete_confirm_box: delete_confirm_box.visible = false
	if not DirAccess.dir_exists_absolute(POSES_DIR):
		DirAccess.make_dir_recursive_absolute(POSES_DIR)
	var raw_files := DirAccess.get_files_at(POSES_DIR)
	var search_filter := pose_search.text.strip_edges().to_lower()
	for f in raw_files:
		if f.ends_with(".json"):
			if search_filter.is_empty() or f.to_lower().contains(search_filter):
				pose_files.append(f)
	pose_files.sort()
	for f in pose_files:
		var display_name := f.trim_suffix(".json")
		pose_list.add_item("🎭 " + display_name)
	pose_count_label.text = "📁 已存姿态库 (%d 个)" % pose_files.size()

func _on_pose_item_selected(index: int) -> void:
	if index < 0 or index >= pose_files.size(): return
	var fname := pose_files[index]
	var path := POSES_DIR + "/" + fname
	if not FileAccess.file_exists(path):
		pose_details_label.text = "文件不存在"
		return
	var raw := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(raw)
	if typeof(data) == TYPE_DICTIONARY:
		var pack_title: String = data.get("source_pack_title", data.get("source_pack", "未知"))
		var role_str: String = data.get("source_role", "未知")
		var b_count: int = data.get("bone_count", data.get("bones", {}).size())
		var ground_str: String = "已贴地" if data.get("grounded", false) else "原始高度"
		var time_str: String = "%.2fs (帧 %d)" % [float(data.get("source_time", 0.0)), int(data.get("source_frame", 0))]
		pose_details_label.text = "【%s】
来源动作: %s | 通道: 角色 %s | %s | %s | %d 根骨骼" % [
			data.get("name", fname), pack_title, role_str, time_str, ground_str, b_count
		]
	else:
		pose_details_label.text = fname

func _preview_selected_pose() -> void:
	if not initialized or loading: return
	var selected_items := pose_list.get_selected_items()
	if selected_items.is_empty():
		pose_status_label.text = "请先选择一个姿态文件"
		return
	var fname := pose_files[selected_items[0]]
	var path := POSES_DIR + "/" + fname
	if not FileAccess.file_exists(path):
		pose_status_label.text = "文件不存在: " + fname
		return
	var raw := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		pose_status_label.text = "错误: 姿态文件损坏或无法解析"
		return
	
	var role_id: String = data.get("source_role", "B")
	if pose_role_select.item_count > 0 and pose_role_select.selected >= 0:
		role_id = String(pose_role_select.get_item_metadata(pose_role_select.selected))
	elif not visible_roles.is_empty() and not visible_roles.has(role_id):
		role_id = visible_roles[0]
	elif not actors.has(role_id):
		role_id = actors.keys()[0] if not actors.is_empty() else ""
	
	if not actors.has(role_id):
		pose_status_label.text = "错误: 未找到角色实例 " + role_id
		return
	
	var inst = actors[role_id]
	var skel: Skeleton3D = inst.skeleton
	if not skel: return
	var payload := HUMANOID_RIG.pose_payload(data)
	if payload.is_empty():
		pose_status_label.text = "旧姿态缺少来源模型，请从原角色重新保存"
		return
	var rig := HUMANOID_RIG.new()
	if not rig.setup(skel): return
	
	playing = false
	is_previewing_pose = true
	active_pose_data = data
	_refresh_ui()
	
	skel.reset_bone_poses()
	
	if data.has("character_rot"):
		var r: Array = data["character_rot"]
		inst.character.rotation = Vector3(r[0], r[1], r[2])
	
	var solution := rig.solve_pose(payload)
	rig.apply_solution(solution)
	var skel_in_model: Transform3D = inst.character.global_transform.affine_inverse() * skel.global_transform
	inst.character.position = skel_in_model.basis * solution.root_displacement
	pose_status_label.text = "▶ 已应用姿态: %s 到角色 %s (动画已冻结)" % [data.get("name", fname), role_id]

func _resume_from_pose_preview() -> void:
	if not initialized: return
	is_previewing_pose = false
	active_pose_data.clear()
	seek_frame(roundi(time * FPS))
	pose_status_label.text = "↺ 已恢复原始 MMD 动作序列"

func _start_rename() -> void:
	var selected_items := pose_list.get_selected_items()
	if selected_items.is_empty():
		pose_status_label.text = "请先选择要重命名的姿态"
		return
	var fname := pose_files[selected_items[0]]
	rename_input.text = fname.trim_suffix(".json")
	rename_box.visible = true
	delete_confirm_box.visible = false
	rename_input.grab_focus()

func _confirm_rename() -> void:
	var selected_items := pose_list.get_selected_items()
	if selected_items.is_empty():
		rename_box.visible = false
		return
	var old_file := pose_files[selected_items[0]]
	var new_base := rename_input.text.strip_edges().trim_suffix(".json")
	if new_base.is_empty():
		pose_status_label.text = "重命名错误: 文件名不能为空"
		return
	var new_file := new_base + ".json"
	if new_file == old_file:
		rename_box.visible = false
		return
	var old_path := POSES_DIR + "/" + old_file
	var new_path := POSES_DIR + "/" + new_file
	if FileAccess.file_exists(new_path):
		pose_status_label.text = "重命名失败: 目标文件已存在 " + new_file
		return
	var err := DirAccess.rename_absolute(old_path, new_path)
	if err == OK:
		var raw := FileAccess.get_file_as_string(new_path)
		var data: Variant = JSON.parse_string(raw)
		if typeof(data) == TYPE_DICTIONARY:
			data["name"] = new_base
			var fa := FileAccess.open(new_path, FileAccess.WRITE)
			if fa:
				fa.store_string(JSON.stringify(data, "\t"))
				fa.close()
		pose_status_label.text = "✓ 重命名成功: " + new_file
		rename_box.visible = false
		_refresh_pose_list()
		for i in pose_files.size():
			if pose_files[i] == new_file:
				pose_list.select(i)
				_on_pose_item_selected(i)
				break
	else:
		pose_status_label.text = "✕ 重命名失败: 错误码 %d" % err

func _start_delete() -> void:
	var selected_items := pose_list.get_selected_items()
	if selected_items.is_empty():
		pose_status_label.text = "请先选择要删除的姿态"
		return
	var fname := pose_files[selected_items[0]]
	delete_confirm_label.text = "确认删除 '%s' 吗？" % fname
	delete_confirm_box.visible = true
	rename_box.visible = false

func _confirm_delete() -> void:
	var selected_items := pose_list.get_selected_items()
	if selected_items.is_empty():
		delete_confirm_box.visible = false
		return
	var fname := pose_files[selected_items[0]]
	var path := POSES_DIR + "/" + fname
	var err := DirAccess.remove_absolute(path)
	if err == OK:
		pose_status_label.text = "✓ 已删除姿态文件: " + fname
		delete_confirm_box.visible = false
		_refresh_pose_list()
		pose_details_label.text = "文件已删除"
	else:
		pose_status_label.text = "✕ 删除失败: 错误码 %d" % err

func _open_poses_folder() -> void:
	var global_path := ProjectSettings.globalize_path(POSES_DIR)
	OS.shell_open(global_path)
	pose_status_label.text = "已打开系统文件夹: " + global_path
