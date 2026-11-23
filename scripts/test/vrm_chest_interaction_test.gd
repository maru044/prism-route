extends Node3D

const UI := preload("res://scenes/combat/encounter_ui_style.gd")
const PAPER := preload("res://scenes/combat/temple_paper_palette.tres")
const ACTOR_SCENE := preload("res://scenes/characters/shared_humanoid_actor.tscn")
const CATALOG_PATH := "res://assets/characters/roster/catalog.json"
const DEFAULT_MOTION := "res://assets/characters/roster/motions/koikatsu_idle.tres"

const PICK_LAYER := 1 << 19
const HIT_RADIUS := 0.044
const MAX_DRAG := 0.026
const PRESS_DEPTH := 0.006

class GrabPose extends SkeletonModifier3D:
	var bones := PackedInt32Array()
	var offsets := PackedVector3Array()

	func _process_modification_with_delta(_delta: float) -> void:
		var skeleton := get_skeleton()
		if skeleton == null:
			return
		for i in bones.size():
			var bone := bones[i]
			skeleton.set_bone_pose_position(bone, skeleton.get_bone_pose_position(bone) + offsets[i])

@onready var camera: Camera3D = $Camera3D
@onready var overlay: CanvasLayer = $Overlay
@onready var panel: Control = $Overlay/Panel
@onready var hint: Label = $Overlay/Panel/Hint
@onready var status: Label = $Overlay/Panel/Status

var actor: Node3D
var skeleton: Skeleton3D
var pose: GrabPose
var targets: Array[Area3D] = []
var hit_guides: Array[MeshInstance3D] = []
var _attachments: Array[BoneAttachment3D] = []
var hovered := -1
var held := -1
var _pointer := Vector2.ZERO
var _queued_press: Variant
var _drag_plane: Plane
var _grab_origin: Vector3
var _show_guides := false

var _models: Array[Dictionary] = []
var _current_index := 0
var _is_loading := false
var _current_scheme := ""

# UI Elements
var _top_panel: PanelContainer
var _model_select: OptionButton
var _prev_btn: Button
var _next_btn: Button

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_pointer = get_viewport().get_mouse_position()
	UI.paper_backing(panel, PAPER)
	hint.add_theme_font_override("font", UI.interface_font())
	status.add_theme_font_override("font", UI.interface_font())
	hint.text = "左键按住拖动 · 松手回位 · [Q/E] 切换角色 · [H] 命中区 · 滚轮缩放"

	# Clean up any static child actor from .tscn template
	if has_node("Keqing"):
		$Keqing.free()

	_build_model_list()
	_build_top_ui()
	await select_model(0)

func _build_model_list() -> void:
	_models.clear()
	# Priority local validation models
	var priority_models: Array[Dictionary] = [
		{
			"id": "keqing_physics",
			"label": "刻晴 (物理验证)",
			"game": "原神",
			"model": "res://assets/characters/mmd_validation/keqing_physics.vrm"
		},
		{
			"id": "ganyu_physics",
			"label": "甘雨 (物理验证)",
			"game": "原神",
			"model": "res://assets/characters/mmd_validation/paired/ganyu_physics.vrm"
		},
		{
			"id": "huahuo_fixed",
			"label": "花火 (修正版)",
			"game": "崩坏：星穹铁道",
			"model": "res://assets/characters/import_tests_local/huahuo/huahuo_fixed.vrm"
		}
	]
	for pm in priority_models:
		if ResourceLoader.exists(pm.model) or FileAccess.file_exists(pm.model):
			_models.append(pm)

	# Read from roster catalog
	if FileAccess.file_exists(CATALOG_PATH):
		var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
		if file != null:
			var data: Dictionary = JSON.parse_string(file.get_as_text())
			var profiles: Array = data.get("profiles", [])
			for p in profiles:
				var m_path: String = p.get("model", "")
				if ResourceLoader.exists(m_path) or FileAccess.file_exists(m_path):
					_models.append({
						"id": p.get("id", ""),
						"label": p.get("label", ""),
						"game": p.get("game", "原神/星铁"),
						"model": m_path
					})

func _build_top_ui() -> void:
	_top_panel = PanelContainer.new()
	_top_panel.anchor_left = 0.5
	_top_panel.anchor_right = 0.5
	_top_panel.offset_left = -340.0
	_top_panel.offset_top = 18.0
	_top_panel.offset_right = 340.0
	_top_panel.offset_bottom = 66.0
	overlay.add_child(_top_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_top_panel.add_child(row)

	_prev_btn = Button.new()
	_prev_btn.text = "< [Q]"
	_prev_btn.custom_minimum_size = Vector2(60, 36)
	_prev_btn.pressed.connect(func(): _switch_character_relative(-1))
	row.add_child(_prev_btn)

	_model_select = OptionButton.new()
	_model_select.custom_minimum_size = Vector2(360, 36)
	_model_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in _models.size():
		var m: Dictionary = _models[i]
		var label_str: String = "[%d/%d][%s] %s" % [i + 1, _models.size(), m.get("game", ""), m.get("label", m.get("id", ""))]
		_model_select.add_item(label_str, i)
	_model_select.item_selected.connect(_on_model_selected)
	row.add_child(_model_select)

	_next_btn = Button.new()
	_next_btn.text = "[E] >"
	_next_btn.custom_minimum_size = Vector2(60, 36)
	_next_btn.pressed.connect(func(): _switch_character_relative(1))
	row.add_child(_next_btn)

func _on_model_selected(index: int) -> void:
	select_model(index)

func _switch_character_relative(step: int) -> void:
	if _models.is_empty():
		return
	var target_index := (_current_index + step) % _models.size()
	if target_index < 0:
		target_index += _models.size()
	select_model(target_index)

class BoneResolveResult:
	var scheme: String = ""
	var pairs: Array[Dictionary] = []

func _resolve_chest_bones(skel: Skeleton3D) -> BoneResolveResult:
	var result := BoneResolveResult.new()
	var candidates: Array[Dictionary] = [
		{
			"scheme": "标准骨骼链 (胸上2 -> 胸先)",
			"base_l": &"胸上2.L", "tip_l": &"胸先.L",
			"base_r": &"胸上2.R", "tip_r": &"胸先.R"
		},
		{
			"scheme": "数字编号骨骼链 (胸１ -> 胸２)",
			"base_l": &"胸１.L", "tip_l": &"胸２.L",
			"base_r": &"胸１.R", "tip_r": &"胸２.R"
		},
		{
			"scheme": "单段胸上2骨骼 (胸上2)",
			"base_l": &"胸上2.L", "tip_l": &"",
			"base_r": &"胸上2.R", "tip_r": &""
		},
		{
			"scheme": "单段胸点骨骼 (胸.L/R)",
			"base_l": &"胸.L", "tip_l": &"",
			"base_r": &"胸.R", "tip_r": &""
		}
	]

	for cand in candidates:
		var b_l := skel.find_bone(cand.base_l)
		var b_r := skel.find_bone(cand.base_r)
		if b_l >= 0 and b_r >= 0:
			var t_l := skel.find_bone(cand.tip_l) if not String(cand.tip_l).is_empty() else -1
			var t_r := skel.find_bone(cand.tip_r) if not String(cand.tip_r).is_empty() else -1
			if String(cand.tip_l).is_empty() or (t_l >= 0 and t_r >= 0):
				result.scheme = cand.scheme
				result.pairs.append({"base": b_l, "tip": t_l, "base_name": cand.base_l, "tip_name": cand.tip_l})
				result.pairs.append({"base": b_r, "tip": t_r, "base_name": cand.base_r, "tip_name": cand.tip_r})
				return result

	result.scheme = "微乳/无独立胸部物理骨骼"
	return result

func _cleanup_current_model() -> void:
	_release()
	hovered = -1
	held = -1
	targets.clear()
	hit_guides.clear()
	for att in _attachments:
		if is_instance_valid(att):
			att.queue_free()
	_attachments.clear()
	if is_instance_valid(pose):
		pose.queue_free()
		pose = null
	if is_instance_valid(actor):
		actor.queue_free()
		actor = null
	skeleton = null

func select_model(index: int) -> void:
	if _is_loading or index < 0 or index >= _models.size():
		return
	_is_loading = true
	_current_index = index
	if _model_select != null and _model_select.selected != index:
		_model_select.select(index)

	_cleanup_current_model()
	var m: Dictionary = _models[index]
	var m_label: String = m.get("label", m.get("id", ""))
	status.text = "正在载入【%s】模型~" % m_label

	actor = ACTOR_SCENE.instantiate()
	actor.name = "Actor"
	actor.model_resource = m.get("model", "")
	actor.motion_resource = DEFAULT_MOTION
	actor.auto_play = true
	actor.environment_collision_enabled = false
	add_child(actor)

	while not actor.ready_for_review:
		await get_tree().process_frame

	skeleton = actor.skeleton
	assert(skeleton != null)

	var resolved := _resolve_chest_bones(skeleton)
	_current_scheme = resolved.scheme

	if resolved.pairs.is_empty():
		_adjust_camera_to_chest(PackedInt32Array())
		_update_feedback()
		_is_loading = false
		return

	var bones := PackedInt32Array()
	var tips := PackedInt32Array()
	for pair in resolved.pairs:
		bones.append(pair.base)
		tips.append(pair.tip)

	pose = GrabPose.new()
	pose.bones = bones
	pose.offsets.resize(bones.size())
	skeleton.add_child(pose)

	for i in bones.size():
		_add_target(bones[i], tips[i])

	_adjust_camera_to_chest(bones)
	_update_feedback()
	_is_loading = false

func _adjust_camera_to_chest(bones: PackedInt32Array) -> void:
	if bones.is_empty():
		camera.position.y = 1.17
		return
	var sum_y := 0.0
	for b in bones:
		var world_tf := skeleton.global_transform * skeleton.get_bone_global_rest(b)
		sum_y += world_tf.origin.y
	var avg_y := sum_y / float(bones.size())
	camera.position.y = clampf(avg_y, 0.8, 1.6)

func _add_target(bone: int, tip: int) -> void:
	var attachment := BoneAttachment3D.new()
	attachment.bone_idx = bone
	skeleton.add_child(attachment)
	_attachments.append(attachment)

	var target := Area3D.new()
	target.collision_layer = PICK_LAYER
	target.collision_mask = 0
	target.monitoring = false

	if tip >= 0:
		var bone_rest := skeleton.get_bone_global_rest(bone)
		var tip_rest := skeleton.get_bone_global_rest(tip)
		target.position = (bone_rest.affine_inverse() * tip_rest.origin) * 0.5
	else:
		target.position = Vector3(0.0, 0.015, 0.025)

	attachment.add_child(target)

	var sphere := SphereShape3D.new()
	sphere.radius = HIT_RADIUS
	var collider := CollisionShape3D.new()
	collider.shape = sphere
	target.add_child(collider)
	targets.append(target)

	var mesh := SphereMesh.new()
	mesh.radius = HIT_RADIUS
	mesh.height = HIT_RADIUS * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#57afe65c")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	var guide := MeshInstance3D.new()
	guide.mesh = mesh
	guide.material_override = material
	guide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	guide.visible = _show_guides
	target.add_child(guide)
	hit_guides.append(guide)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_pointer = event.position
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_pointer = event.position
			if event.pressed:
				_queued_press = event.position
			else:
				_release()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = clampf(camera.size - 0.05, 0.35, 2.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = clampf(camera.size + 0.05, 0.35, 2.0)
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_H:
			_show_guides = not _show_guides
			for guide in hit_guides:
				if is_instance_valid(guide):
					guide.visible = _show_guides
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_Q or event.physical_keycode == KEY_BRACKETLEFT or event.physical_keycode == KEY_LEFT:
			_switch_character_relative(-1)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_E or event.physical_keycode == KEY_BRACKETRIGHT or event.physical_keycode == KEY_RIGHT:
			_switch_character_relative(1)
			get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if _is_loading:
		return
	if targets.is_empty() or pose == null:
		return
	if _queued_press != null:
		_begin_grab(_queued_press)
		_queued_press = null
	if held < 0:
		hovered = targets.find(_ray_hit(_pointer).get("collider"))
	_update_feedback()

	var blend := 1.0 - exp(-17.0 * delta)
	for i in pose.offsets.size():
		var goal := _drag_offset(i) if i == held else Vector3.ZERO
		pose.offsets[i] = pose.offsets[i].lerp(goal, blend)
		if goal.is_zero_approx() and pose.offsets[i].length_squared() < 0.00000001:
			pose.offsets[i] = Vector3.ZERO

func _ray_hit(point: Vector2) -> Dictionary:
	if not get_viewport().get_visible_rect().has_point(point):
		return {}
	var start := camera.project_ray_origin(point)
	var end := start + camera.project_ray_normal(point) * camera.far
	var query := PhysicsRayQueryParameters3D.create(start, end, PICK_LAYER)
	query.collide_with_bodies = false
	query.collide_with_areas = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func _begin_grab(point: Vector2) -> void:
	var hit := _ray_hit(point)
	held = targets.find(hit.get("collider"))
	if held < 0:
		return
	hovered = held
	_grab_origin = hit.position
	_drag_plane = Plane(camera.global_basis.z, _grab_origin)

func _drag_offset(side: int) -> Vector3:
	var point: Variant = _drag_plane.intersects_ray(camera.project_ray_origin(_pointer), camera.project_ray_normal(_pointer))
	if point == null:
		return Vector3.ZERO
	var shift: Vector3 = point - _grab_origin
	shift = shift.limit_length(MAX_DRAG) - camera.global_basis.z * PRESS_DEPTH
	var parent := skeleton.get_bone_parent(pose.bones[side])
	var parent_basis := skeleton.global_basis
	if parent >= 0:
		parent_basis = skeleton.global_basis * skeleton.get_bone_global_pose(parent).basis
	return parent_basis.inverse() * shift

func _update_feedback() -> void:
	var cur_name: String = ""
	if _current_index >= 0 and _current_index < _models.size():
		cur_name = _models[_current_index].get("label", "")

	if held >= 0:
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)
		status.text = "【%s】正在揉弄胸部~ (%s)" % [cur_name, _current_scheme]
	elif hovered >= 0:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		status.text = "【%s】可抓取，按住左键拖动 (%s)" % [cur_name, _current_scheme]
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		if targets.is_empty():
			status.text = "【%s】%s" % [cur_name, _current_scheme]
		else:
			status.text = "【%s】移到模型胸部即可玩弄 (%s)" % [cur_name, _current_scheme]

func _release() -> void:
	held = -1
	_queued_press = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release()

func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
