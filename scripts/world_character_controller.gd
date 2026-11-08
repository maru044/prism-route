extends CharacterBody3D
const SURFACE_MOTION := preload("res://scripts/surface_motion.gd")
const MTOON_MATERIALS := preload("res://scripts/characters/mtoon_materials.gd")
const WETNESS := preload("res://scripts/characters/character_wetness.gd")
const WHEEL_SCENE := preload("res://scenes/ui/character_switch_wheel.tscn")

## Camera-relative world controller with Genshin Impact style dynamic character switching.
## Supports Stelle, Ganyu, Lumine, and Firefly with auto-retargeting and MToon NPR tuning.

signal character_switched(new_id: String, old_id: String)

const MOTIONS := {"idle": "A01", "walk": "A05", "run": "A06", "jump_start": "A18", "jump_air": "A19", "jump_land": "A20", "greet": "A25"}
const MOTION_LABELS := {"idle": "待机", "walk": "步行", "run": "奔跑", "jump_start": "起跳", "jump_air": "空中", "jump_land": "落地", "greet": "招呼"}

const SOURCE_REST_HIPS := Vector3(0.0, 0.661507, 0.0)

const ROSTER_PROFILES: Dictionary = {
	"stelle": {
		"name": "星",
		"model_path": "res://assets/characters/roster/stelle/stelle.vrm",
		"capsule_height": 1.62,
		"capsule_radius": 0.26,
		"camera_pivot_height": 1.08,
		"walking_speed": 1.65,
		"running_speed": 4.3,
	},
	"ganyu": {
		"name": "甘雨",
		"model_path": "res://scenes/characters/ganyu.tscn",
		"capsule_height": 1.45,
		"capsule_radius": 0.24,
		"camera_pivot_height": 0.95,
		"walking_speed": 1.6,
		"running_speed": 4.2,
	},
	"lumine": {
		"name": "荧",
		"model_path": "res://assets/characters/roster/lumine/lumine.vrm",
		"capsule_height": 1.48,
		"capsule_radius": 0.24,
		"camera_pivot_height": 0.96,
		"walking_speed": 1.6,
		"running_speed": 4.2,
	},
	"firefly": {
		"name": "流萤",
		"model_path": "res://assets/characters/roster/firefly/firefly.vrm",
		"capsule_height": 1.55,
		"capsule_radius": 0.24,
		"camera_pivot_height": 0.98,
		"walking_speed": 1.6,
		"running_speed": 4.2,
	}
}

@export var active_character_id: String = "ganyu"
@export var walking_speed := 1.65
@export var running_speed := 4.3
@export var jump_speed := 7.0
@export var gravity_strength := 22.0
@export var surface_step_height := 0.0
@export var use_mtoon := true
@export var camera_min_distance := 0.45
@export var camera_max_distance := 10.0
@export var camera_min_pitch := -1.35
@export var camera_max_pitch := 1.25
@export var camera_pivot_height := 1.08

@onready var visual: Node3D = $Visual
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D

var character: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var animation_state := ""
var respawn_transform := Transform3D.IDENTITY
var automation_enabled := false
var test_move := Vector2.ZERO
var test_running := false
var test_jump := false
var dragging_camera := false
var jump_requested := false
var jump_time := 1.0
var landing_time := 0.0
var greeting := false
var mtoon_report: Dictionary = {}
var wetness: Node
var switch_wheel: CanvasLayer
var head_index := -1
var head_rest_inv := Basis.IDENTITY

func _ready() -> void:
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(48)
	spring_arm.add_excluded_object(get_rid())
	
	_apply_character_setup(active_character_id, false)
	
	camera_pivot.position = Vector3(0, camera_pivot_height, 0)
	respawn_transform = global_transform
	
	switch_wheel = WHEEL_SCENE.instantiate()
	add_child(switch_wheel)
	switch_wheel.character_selected.connect(func(target_id: String):
		switch_character(target_id))
	switch_wheel.set_active_character(active_character_id)

func _apply_character_setup(char_id: String, is_runtime_switch: bool) -> void:
	var profile: Dictionary = ROSTER_PROFILES.get(char_id, ROSTER_PROFILES["stelle"])
	var model_path: String = String(profile.get("model_path", ""))
	
	# Clear previous models or reuse if initial Ganyu
	var reuse_existing := false
	if not is_runtime_switch and char_id == "ganyu" and visual.has_node("GanyuModel"):
		character = visual.get_node("GanyuModel")
		reuse_existing = true
	else:
		for child in visual.get_children():
			visual.remove_child(child)
			child.queue_free()
		var packed := load(model_path) as PackedScene
		assert(packed != null, "Failed to load character model: " + model_path)
		character = packed.instantiate()
		character.name = char_id.capitalize() + "Model"
		visual.add_child(character)
	
	skeleton = character.find_child("GeneralSkeleton", true, false)
	assert(skeleton != null, "GeneralSkeleton not found in character: " + char_id)
	skeleton.motion_scale = 1.0
	
	var original: AnimationPlayer = character.find_child("AnimationPlayer", true, false)
	if original:
		original.stop()
	skeleton.reset_bone_poses()
	
	head_index = skeleton.find_bone("Head")
	if head_index >= 0:
		head_rest_inv = skeleton.get_bone_global_rest(head_index).basis.inverse()
	
	# Update collision capsule
	var h: float = float(profile.get("capsule_height", 1.62))
	var r: float = float(profile.get("capsule_radius", 0.26))
	if collision_shape != null:
		var capsule := collision_shape.shape as CapsuleShape3D
		if capsule != null:
			capsule.height = h
			capsule.radius = r
		collision_shape.position = Vector3(0, h * 0.5, 0)
	
	camera_pivot_height = float(profile.get("camera_pivot_height", 1.08))
	camera_pivot.position = Vector3(0, camera_pivot_height, 0)
	walking_speed = float(profile.get("walking_speed", 1.65))
	running_speed = float(profile.get("running_speed", 4.3))
	
	# MToon shader conversion & tuning for all roster characters
	if use_mtoon:
		mtoon_report = MTOON_MATERIALS.apply(character, char_id)
		if not mtoon_report.skipped.is_empty():
			push_warning("MToon kept unmapped source materials: " + str(mtoon_report.skipped))
		if wetness == null:
			wetness = WETNESS.new()
			wetness.name = "CharacterWetness"
			add_child(wetness)
		wetness.bind(self, character)
	
	# AnimationPlayer setup with automatic retargeting
	player = AnimationPlayer.new()
	player.name = "WorldMotionPlayer"
	player.callback_mode_process = 0
	character.add_child(player)
	
	var skel_path: NodePath = character.get_path_to(skeleton)
	var library := AnimationLibrary.new()
	for state: String in MOTIONS:
		var raw_anim: Animation = load("res://assets/characters/motion_review/%s.tres" % MOTIONS[state])
		var anim: Animation = raw_anim.duplicate(true)
		anim.loop_mode = Animation.LOOP_LINEAR if state in ["idle", "walk", "run", "jump_air"] else Animation.LOOP_NONE
		
		_retarget_and_center_clip(anim, skeleton, skel_path)
		library.add_animation(state, anim)
	
	player.add_animation_library("", library)
	player.animation_finished.connect(func(state: StringName):
		if state == "greet": greeting = false)
	
	active_character_id = char_id
	if not is_runtime_switch:
		_set_animation("idle")
	_reset_springs.call_deferred()

func switch_character(target_id: String) -> bool:
	if target_id == active_character_id:
		return false
	if not ROSTER_PROFILES.has(target_id):
		push_warning("Character ID not recognized in roster: " + target_id)
		return false
	
	var old_id := active_character_id
	var prev_pos := global_position
	var prev_heading := visual.rotation.y
	var prev_vel := velocity
	var prev_pitch := camera_pivot.rotation.x
	var prev_yaw := camera_pivot.rotation.y
	var prev_spring_len := spring_arm.spring_length
	var prev_anim := animation_state
	
	_apply_character_setup(target_id, true)
	
	global_position = prev_pos
	visual.rotation.y = prev_heading
	velocity = prev_vel
	camera_pivot.rotation.x = prev_pitch
	camera_pivot.rotation.y = prev_yaw
	spring_arm.spring_length = prev_spring_len
	
	animation_state = ""
	_set_animation(prev_anim if not prev_anim.is_empty() else "idle")
	
	if switch_wheel != null:
		switch_wheel.set_active_character(target_id)
	
	character_switched.emit(target_id, old_id)
	return true

func _retarget_and_center_clip(animation: Animation, target_skeleton: Skeleton3D, skel_path: NodePath) -> void:
	var center_idx: int = target_skeleton.find_bone("センター")
	var hips_idx: int = target_skeleton.find_bone("Hips")
	
	# If target skeleton has センター (VRM standard such as Lumine), the source animation's
	# root motion (authored on Ganyu's 0.66m Center-named-as-Hips) maps to センター.
	# Otherwise (like Ganyu herself), it maps directly to Hips.
	var use_center_for_root: bool = (center_idx >= 0)
	var root_bone_name: String = "センター" if use_center_for_root else "Hips"
	var root_bone_idx: int = center_idx if use_center_for_root else hips_idx
	var target_rest_origin: Vector3 = target_skeleton.get_bone_rest(root_bone_idx).origin if root_bone_idx >= 0 else SOURCE_REST_HIPS
	
	for track in animation.get_track_count():
		var original_path: String = str(animation.track_get_path(track))
		var colon_idx: int = original_path.find(":")
		if colon_idx != -1:
			var bone_part: String = original_path.substr(colon_idx)
			if bone_part == ":Hips" and use_center_for_root:
				bone_part = ":センター"
			animation.track_set_path(track, NodePath(str(skel_path) + bone_part))
		
		if animation.track_get_type(track) == Animation.TYPE_POSITION_3D and original_path.ends_with(":Hips"):
			var count: int = animation.track_get_key_count(track)
			if count == 0:
				continue
			
			for key in count:
				var old_val: Vector3 = animation.track_get_key_value(track, key)
				var delta: Vector3 = old_val - SOURCE_REST_HIPS
				var new_val: Vector3 = target_rest_origin + delta
				animation.track_set_key_value(track, key, new_val)
			
			var avg_xz := Vector2.ZERO
			for key in count:
				var val: Vector3 = animation.track_get_key_value(track, key)
				avg_xz += Vector2(val.x, val.z) / float(count)
			
			var offset_x: float = avg_xz.x - target_rest_origin.x
			var offset_z: float = avg_xz.y - target_rest_origin.z
			for key in count:
				var val: Vector3 = animation.track_get_key_value(track, key)
				val.x -= offset_x
				val.z -= offset_z
				animation.track_set_key_value(track, key, val)

func _process(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	var movement := test_move if automation_enabled else Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var running := test_running if automation_enabled else Input.is_physical_key_pressed(KEY_SHIFT)
	if automation_enabled and test_jump:
		jump_requested = true
		test_jump = false
	var was_grounded := is_on_floor()
	var jumped := false
	if jump_requested and was_grounded:
		velocity.y = jump_speed
		jump_time = 0
		landing_time = 0
		greeting = false
		jumped = true
	elif was_grounded:
		velocity.y = -0.5
	else:
		velocity.y -= gravity_strength * delta
	jump_requested = false
	jump_time += delta
	landing_time = maxf(0.0, landing_time - delta)
	var direction := camera_pivot.global_basis * Vector3(movement.x, 0, movement.y)
	direction.y = 0
	direction = direction.normalized() * minf(movement.length(), 1.0)
	var desired := direction * (running_speed if running else walking_speed)
	var acceleration := 12.0 if was_grounded else 6.0
	velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
	if direction.length_squared() > 0.001:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), minf(delta * 12, 1))
		greeting = false
	SURFACE_MOTION.move(self, delta, surface_step_height)
	if not was_grounded and is_on_floor():
		landing_time = 0.22
	var speed := Vector2(velocity.x, velocity.z).length()
	if jumped or not is_on_floor():
		_set_animation("jump_start" if jump_time < 0.14 else "jump_air")
	elif landing_time > 0:
		_set_animation("jump_land")
	elif speed > 0.12:
		_set_animation("run" if running else "walk")
	elif greeting:
		_set_animation("greet")
	else:
		_set_animation("idle")
	if animation_state in ["walk", "run"]:
		player.speed_scale = clampf(speed / (running_speed if animation_state == "run" else walking_speed), 0.6, 1.35)
	else:
		player.speed_scale = 1
	if global_position.y < -25:
		reset_to_respawn()

func _set_animation(state: String) -> void:
	if animation_state == state:
		return
	animation_state = state
	if player != null and player.has_animation(state):
		player.play(state, 0.14)

func set_control_enabled(enabled: bool) -> void:
	set_physics_process(enabled)
	set_process_unhandled_input(enabled)
	dragging_camera = false
	if not enabled:
		velocity = Vector3.ZERO
		jump_requested = false

func set_spawn(point: Vector3, heading: float) -> void:
	global_position = point
	rotation = Vector3.ZERO
	visual.rotation = Vector3(0, heading + PI, 0)
	camera_pivot.position = Vector3(0, camera_pivot_height, 0)
	camera_pivot.rotation = Vector3(-0.16, heading, 0)
	velocity = Vector3.ZERO
	respawn_transform = Transform3D(Basis(Vector3.UP, heading), point)
	jump_time = 1
	landing_time = 0
	greeting = false
	_set_animation("idle")
	_reset_springs.call_deferred()

func reset_to_respawn() -> void:
	if wetness != null:
		wetness.reset()
	set_spawn(respawn_transform.origin, respawn_transform.basis.get_euler().y)

func _reset_springs() -> void:
	if character == null or skeleton == null:
		return
	var controller = character.find_child("VRMSpringBoneController", true, false)
	var simulation = skeleton.get_node_or_null("VRMSpringBoneSimulation")
	if controller and simulation:
		simulation.setup(controller.spring_bones, controller.collider_groups)
		simulation.active = true

func get_speed_kph() -> float:
	return Vector2(velocity.x, velocity.z).length() * 3.6

func get_motion_label() -> String:
	return MOTION_LABELS.get(animation_state, "待机")

func _unhandled_input(event: InputEvent) -> void:
	if switch_wheel != null and switch_wheel.get("wheel_visible") == true:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode if event.physical_keycode != 0 else event.keycode:
			KEY_SPACE: jump_requested = true
			KEY_R: reset_to_respawn()
			KEY_G: greeting = is_on_floor()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging_camera = event.pressed
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			camera_pivot.rotation.x = -0.16
			spring_arm.spring_length = 4.0
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			spring_arm.spring_length = clampf(spring_arm.spring_length + (0.25 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -0.25), camera_min_distance, camera_max_distance)
	if event is InputEventMouseMotion and dragging_camera:
		camera_pivot.rotation.y -= event.relative.x * 0.004
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - event.relative.y * 0.003, camera_min_pitch, camera_max_pitch)
