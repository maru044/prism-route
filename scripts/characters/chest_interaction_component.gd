class_name ChestInteractionComponent
extends Node3D

## Standalone physics-based tactile chest fondling component.
## Works on all humanoid skeletons with dynamic multi-tier bone resolution.
## Zero text, zero HUD clutter: purely tactile interaction for player discovery.

const PICK_LAYER := 1 << 19 # Layer 20
const HIT_RADIUS := 0.044
const MAX_DRAG := 0.026
const PRESS_DEPTH := 0.006
const MAX_INTERACTION_DISTANCE := 4.5
const HVoiceManagerClass := preload("res://scripts/audio/h_voice_manager.gd")

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

var skeleton: Skeleton3D
var pose: GrabPose
var targets: Array[Area3D] = []
var _attachments: Array[BoneAttachment3D] = []

var hovered := -1
var held := -1
var _pointer := Vector2.ZERO
var _queued_press: Variant
var _drag_plane: Plane
var _grab_origin: Vector3
var _active_camera: Camera3D
var _cursor_set_by_us := false
var _hold_duration: float = 0.0
var _continuous_fondle_triggered: bool = false

func setup(p_skeleton: Skeleton3D) -> void:
	cleanup()
	skeleton = p_skeleton
	if skeleton == null:
		return
	_build_targets()

func cleanup() -> void:
	_release()
	hovered = -1
	held = -1
	targets.clear()
	for att in _attachments:
		if is_instance_valid(att):
			att.queue_free()
	_attachments.clear()
	if is_instance_valid(pose):
		pose.queue_free()
		pose = null
	skeleton = null
	_active_camera = null

func _build_targets() -> void:
	if skeleton == null:
		return
	var resolved := _resolve_chest_bones(skeleton)
	if resolved.pairs.is_empty():
		return

	var bones := PackedInt32Array()
	var tips := PackedInt32Array()
	for pair in resolved.pairs:
		bones.append(pair.base)
		tips.append(pair.tip)

	pose = GrabPose.new()
	pose.name = "ChestGrabPose"
	pose.bones = bones
	pose.offsets.resize(bones.size())
	skeleton.add_child(pose)

	for i in bones.size():
		_add_target(bones[i], tips[i])

class BoneResolveResult:
	var scheme: String = ""
	var pairs: Array[Dictionary] = []

static func _resolve_chest_bones(skel: Skeleton3D) -> BoneResolveResult:
	var result := BoneResolveResult.new()
	var candidates: Array[Dictionary] = [
		{
			"scheme": "标准骨骼链",
			"base_l": &"胸上2.L", "tip_l": &"胸先.L",
			"base_r": &"胸上2.R", "tip_r": &"胸先.R"
		},
		{
			"scheme": "数字编号骨骼链",
			"base_l": &"胸１.L", "tip_l": &"胸２.L",
			"base_r": &"胸１.R", "tip_r": &"胸２.R"
		},
		{
			"scheme": "单段胸上2骨骼",
			"base_l": &"胸上2.L", "tip_l": &"",
			"base_r": &"胸上2.R", "tip_r": &""
		},
		{
			"scheme": "单段胸点骨骼",
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

	return result

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

func _unhandled_input(event: InputEvent) -> void:
	if targets.is_empty() or pose == null:
		return
	if WorldControlContext.is_world_input_blocked(get_tree()):
		if held >= 0:
			_release()
		return

	if event is InputEventMouseMotion:
		_pointer = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer = event.position
		if event.pressed:
			_queued_press = event.position
		else:
			_release()

func _physics_process(delta: float) -> void:
	if targets.is_empty() or pose == null or skeleton == null or not is_inside_tree():
		return
	if WorldControlContext.is_world_input_blocked(get_tree()):
		if held >= 0:
			_release()
		return

	var vp := get_viewport()
	if vp == null:
		return
	var cam := vp.get_camera_3d()
	if cam == null:
		return
	_active_camera = cam

	if _queued_press != null:
		_begin_grab(_queued_press)
		_queued_press = null

	if held < 0:
		_hold_duration = 0.0
		_continuous_fondle_triggered = false
		var hit := _ray_hit(_pointer)
		var collider: Variant = hit.get("collider")
		var hit_idx := targets.find(collider) if collider != null else -1
		if hit_idx != hovered:
			hovered = hit_idx
			_update_cursor()
	else:
		_hold_duration += delta
		if _hold_duration > 1.2 and not _continuous_fondle_triggered:
			_continuous_fondle_triggered = true
			var vm: Node = HVoiceManagerClass.instance
			if is_instance_valid(vm):
				vm.play_chest_fondle(true)
		_update_cursor()

	var blend := 1.0 - exp(-17.0 * delta)
	for i in pose.offsets.size():
		var goal := _drag_offset(i) if i == held else Vector3.ZERO
		pose.offsets[i] = pose.offsets[i].lerp(goal, blend)
		if goal.is_zero_approx() and pose.offsets[i].length_squared() < 0.00000001:
			pose.offsets[i] = Vector3.ZERO

func _ray_hit(point: Vector2) -> Dictionary:
	var vp := get_viewport()
	if vp == null or not vp.get_visible_rect().has_point(point):
		return {}
	if _active_camera == null:
		return {}

	var start := _active_camera.project_ray_origin(point)
	var end := start + _active_camera.project_ray_normal(point) * MAX_INTERACTION_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(start, end, PICK_LAYER)
	query.collide_with_bodies = false
	query.collide_with_areas = true
	var world_3d: World3D = skeleton.get_world_3d() if skeleton != null and skeleton.is_inside_tree() else get_world_3d()
	if world_3d == null:
		return {}
	return world_3d.direct_space_state.intersect_ray(query)

func _begin_grab(point: Vector2) -> void:
	var hit := _ray_hit(point)
	var collider: Variant = hit.get("collider")
	var hit_idx := targets.find(collider) if collider != null else -1
	if hit_idx < 0:
		return
	held = hit_idx
	hovered = held
	_grab_origin = hit.position
	_drag_plane = Plane(_active_camera.global_basis.z, _grab_origin)
	_hold_duration = 0.0
	_continuous_fondle_triggered = false
	var vm: Node = HVoiceManagerClass.instance
	if is_instance_valid(vm):
		vm.play_chest_fondle(false)

func _drag_offset(side: int) -> Vector3:
	if _active_camera == null:
		return Vector3.ZERO
	var point: Variant = _drag_plane.intersects_ray(_active_camera.project_ray_origin(_pointer), _active_camera.project_ray_normal(_pointer))
	if point == null:
		return Vector3.ZERO
	var shift: Vector3 = point - _grab_origin
	shift = shift.limit_length(MAX_DRAG) - _active_camera.global_basis.z * PRESS_DEPTH
	var parent := skeleton.get_bone_parent(pose.bones[side])
	var parent_basis := skeleton.global_basis
	if parent >= 0:
		parent_basis = skeleton.global_basis * skeleton.get_bone_global_pose(parent).basis
	return parent_basis.inverse() * shift

func _update_cursor() -> void:
	if held >= 0:
		_cursor_set_by_us = true
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	elif hovered >= 0:
		_cursor_set_by_us = true
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	elif _cursor_set_by_us:
		_cursor_set_by_us = false
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _release() -> void:
	held = -1
	_queued_press = null
	_hold_duration = 0.0
	_continuous_fondle_triggered = false
	if _cursor_set_by_us and hovered < 0:
		_cursor_set_by_us = false
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release()

func _exit_tree() -> void:
	cleanup()
