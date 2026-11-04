extends "res://scripts/character_mmd_validation.gd"
## One shared-clock review scene for paired assets and isolated-role diagnostics.
const CATALOG_PATH := "res://assets/characters/mmd_validation/paired/catalog.json"
const ACTOR_SCENE := preload("res://scenes/characters/keqing_mmd_vrm.tscn")
const SHARED_ACTOR_SCENE := preload("res://scenes/characters/shared_humanoid_actor.tscn")
const PARTNER_PROXIES := preload("res://scripts/characters/mmd_partner_colliders.gd")
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
var partner_on := true
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
	details.custom_minimum_size=Vector2(330,150)
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
	timeline.drag_started.connect(func(): playing = false; _refresh_ui())
	timeline.value_changed.connect(func(value):
		if not initialized: return
		playing = false
		seek_frame(roundi(value*FPS)))
	var row := HBoxContainer.new()
	controls.add_child(row)
	row.add_child(play_button)
	play_button.pressed.connect(func():
		if not initialized: return
		if time>=duration: seek_frame(0)
		playing = not playing
		_refresh_ui())
	for view in [{"label":"正面","yaw":0.0},{"label":"侧面","yaw":PI/2},{"label":"背面","yaw":PI}]:
		var button := Button.new()
		button.text = view.label
		row.add_child(button)
		button.pressed.connect(func():
			if camera: yaw = view.yaw; _update_camera())
	var skeleton_toggle := CheckButton.new()
	skeleton_toggle.text = "骨架"
	row.add_child(skeleton_toggle)
	skeleton_toggle.toggled.connect(func(value): overlay.visible = value)
	for field in ["头发物理","服饰物理","对方碰撞"]:
		var toggle := CheckButton.new()
		toggle.text = field
		toggle.button_pressed = true
		row.add_child(toggle)
		toggle.toggled.connect(func(value):
			if field=="头发物理": hair_on=value
			elif field=="服饰物理": clothes_on=value
			else: partner_on=value
			_apply_physics())
	var hint := Label.new()
	hint.text = "同一时间轴控制全部角色 · 右键旋转 / 滚轮缩放 · 暂停动作后服饰继续收敛"
	controls.add_child(hint)

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
		var haystack:String=item.label
		for track in item.source_tracks:haystack+=" "+str(track.file)
		if not search.text.is_empty() and not haystack.to_lower().contains(search.text.to_lower()): continue
		filtered_entries.append(entry)
		library_list.add_item("%d人 · %s" % [people,item.label])
		library_list.set_item_tooltip(filtered_entries.size()-1,"%s\n%d–%d 帧 · %.2f 秒 · %d 个角色位" % [item.label,item.frame_start,item.frame_end,item.duration,people])
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
				instance.position=Vector3(offset[0],offset[1],offset[2])
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
	heading.text=entry.label+"  |  "+" / ".join(role_labels)
	details.text="配套来源：%s\n%s\n\n%d–%d 帧 / %d FPS / %.2f 秒\n当前显示：%s\n\n共用时钟，保留原始相对坐标。\n角色拆分是诊断视图，不代表原作是单人动作。\n\n接触适配待审阅，局部服饰重叠仍需处理。\n对方碰撞只作用于头发和服饰，不自动修正身体动作。" % [pack.label,"\n".join(source_labels),pack.frame_start,pack.frame_end,int(catalog.fps),duration,", ".join(visible_roles)]
	if pack.get("shared", false):
		details.text="%s\n\n%d 个角色实例，共用标准人形姿态资源。\n保留各自骨长与辅助骨结构。\n\n%.3f 秒 / %d FPS\n资源按来源角色位保存，不为目标角色复制。\n\n并排布局仅供观察；双人组保留共同坐标。\n头发与服饰使用各角色已有配置。\n接触适配与物理美术质量需另行审核。" % [pack.label,visible_roles.size(),duration,int(catalog.fps)]
	if pack.get("selected",false):
		details.text="源范围 %d–%d 帧\n%.2f 秒 · %d 个角色位\n\n整组共用时间与坐标。模型可切换，动作资源保持共享。\n\n本批是身体动作；原表情、专有形变和道具独立接入。\n循环预览不代表接缝已修整。" % [pack.frame_start,pack.frame_end,duration,pack.roles.size()]
	if current_pack=="shared_walk":
		details.text="历史 VRMA 共享走路样本（非地图 A05）\n地图基础动作请打开 character_roster_review 场景。\n\n"+details.text
	_sync_group_controls()
	_filter_entries()
	_refresh_ui()

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

func _seek_animation(value: float) -> void:
	for instance in actors.values(): instance.seek(value)
	for proxy in role_proxies.values(): proxy.update_proxies()

func _advance_animation(delta: float) -> void:
	var next_time:=time+delta
	var wrapped: bool=pack.get("loop_preview", false) and next_time>=duration
	time=fmod(next_time,duration) if wrapped else minf(next_time,duration)
	# One absolute time sample, never one independent delta accumulator per role.
	for instance in actors.values():
		if delta>.1 or wrapped: instance.seek(time)
		else: instance.sample_time(time)
	for proxy in role_proxies.values(): proxy.update_proxies()

func _process(delta: float) -> void:
	if not initialized or loading: return
	if playing:
		_advance_animation(delta)
		if time>=duration and not pack.get("loop_preview", false): playing=false
		timeline.set_value_no_signal(time)
		_refresh_ui()
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

func _refresh_ui() -> void:
	if not initialized: return
	var phases: Array[String]=[]
	for role_id in visible_roles:
		phases.append("%s %03d" % [role_id,roundi(actors[role_id].time*FPS)])
	status.text="共同时间 %.2f s  |  帧 %03d / %d  |  %s" % [time,roundi(time*FPS),roundi(duration*FPS)," / ".join(phases)]
	play_button.text="暂停动作" if playing else "播放动作"

func _unhandled_input(event: InputEvent) -> void:
	if initialized: super._unhandled_input(event)

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

