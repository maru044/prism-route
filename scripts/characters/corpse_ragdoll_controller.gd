class_name CorpseRagdollController
extends Node3D

signal state_changed(new_state: int)
signal pose_applied(pose_name: String)
signal character_changed(character_id: String, character_label: String)

enum State {
	RAGDOLL,
	DRAGGING,
	POSED,
	POSED_DRAGGING
}

const POSES_DIR := "res://assets/characters/poses"

@export var character_scene: PackedScene = preload("res://scenes/characters/ganyu.tscn")
@export var auto_start_ragdoll := true
@export var drag_spring_strength := 26.0
@export var max_drag_velocity := 8.5

var current_state: State = State.RAGDOLL
var character_instance: Node3D = null
var skeleton: Skeleton3D = null
var simulator: PhysicalBoneSimulator3D = null
var physical_bones: Dictionary = {} # bone_name: String -> PhysicalBone3D

var current_character_id := "ganyu"
var current_character_label := "甘雨"

var dragged_bone: PhysicalBone3D = null
var dragged_bone_name := "LeftFoot"
var drag_anchor: Node3D = null
var current_pose_name := ""
var tween_active := false
var current_pose_data: Dictionary = {}

# Secondary sway accumulator for posed dragging
var posed_drag_sway := 0.0

func _ready() -> void:
	_setup_character()
	if auto_start_ragdoll:
		start_ragdoll()

func _setup_character() -> void:
	if character_instance == null and character_scene != null:
		character_instance = character_scene.instantiate()
		add_child(character_instance)
	
	_setup_character_internals()

func _setup_character_internals() -> void:
	if character_instance:
		skeleton = character_instance.find_child("GeneralSkeleton", true, false) as Skeleton3D
		assert(skeleton != null, "GeneralSkeleton not found on character instance")
		
		# Stop any background AnimationPlayer from interfering with physics or poses
		var anim_player: AnimationPlayer = character_instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim_player:
			anim_player.stop()
			
		_build_physical_bones()

func load_character_from_profile(profile: Dictionary) -> bool:
	var model_path: String = profile.get("model", "")
	var char_id: String = profile.get("id", "")
	var char_label: String = profile.get("label", char_id)
	return load_character(model_path, char_id, char_label)

func load_character(model_source: Variant, char_id: String = "", char_label: String = "") -> bool:
	stop_drag()
	stop_ragdoll()
	
	# Determine spawn position from current corpse location
	var spawn_pos := global_position
	if character_instance and is_instance_valid(character_instance):
		spawn_pos = character_instance.global_position
	if physical_bones.has("Hips") and is_instance_valid(physical_bones["Hips"]):
		spawn_pos = physical_bones["Hips"].global_position
		
	# Raycast to ground surface so character spawns properly placed
	var ground_y := 0.0
	var space_state := get_world_3d().direct_space_state
	if space_state:
		var ray_from := spawn_pos + Vector3(0, 1.0, 0)
		var ray_to := spawn_pos - Vector3(0, 4.0, 0)
		var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
		var hit := space_state.intersect_ray(query)
		if hit:
			ground_y = hit.position.y
	spawn_pos.y = ground_y + 0.35
	
	# Clean up previous instance
	if character_instance and is_instance_valid(character_instance):
		character_instance.queue_free()
		character_instance = null
		skeleton = null
		simulator = null
		physical_bones.clear()
		
	var new_inst: Node3D = null
	if model_source is PackedScene:
		new_inst = model_source.instantiate()
		character_scene = model_source
		if char_id.is_empty():
			char_id = model_source.resource_path.get_file().get_basename()
	elif model_source is String:
		var path: String = model_source
		if not ResourceLoader.exists(path):
			printerr("Character model file not found: ", path)
			return false
		var packed: PackedScene = load(path)
		if packed == null:
			printerr("Failed to load character scene: ", path)
			return false
		new_inst = packed.instantiate()
		character_scene = packed
		if char_id.is_empty():
			char_id = path.get_file().get_basename()
	else:
		return false
		
	character_instance = new_inst
	add_child(character_instance)
	character_instance.global_position = spawn_pos
	
	if char_label.is_empty():
		char_label = char_id
	current_character_id = char_id
	current_character_label = char_label
	
	_setup_character_internals()
	start_ragdoll()
	character_changed.emit(current_character_id, current_character_label)
	return true

func _build_physical_bones() -> void:
	if not skeleton: return
	
	simulator = skeleton.get_node_or_null("PhysicalBoneSimulator3D") as PhysicalBoneSimulator3D
	if simulator == null:
		simulator = PhysicalBoneSimulator3D.new()
		simulator.name = "PhysicalBoneSimulator3D"
		skeleton.add_child(simulator)
	
	for c in simulator.get_children():
		c.queue_free()
	physical_bones.clear()
	
	# Anatomical bone specifications for realistic humanoid ragdoll
	# In Godot 4, all PhysicalBone3D nodes MUST be direct children of PhysicalBoneSimulator3D
	# Skeleton3D hierarchy establishes joints automatically between physical bones
	# Mass rebalanced so adjacent bone ratio is <= 1:1.5 for optimal joint impulse propagation
	# Format: [name, radius, height, mass, joint_type, col_offset, joint_rot_deg, limit_lower, limit_upper, swing_span, twist_span]
	var bone_specs: Array = [
		["Hips", 0.09, 0.22, 6.0, PhysicalBone3D.JOINT_TYPE_NONE, Vector3(0, 0.08, 0), Vector3.ZERO, 0.0, 0.0, 0.0, 0.0],
		["Spine", 0.08, 0.18, 5.0, PhysicalBone3D.JOINT_TYPE_CONE, Vector3(0, 0.06, 0), Vector3.ZERO, 0.0, 0.0, 20.0, 15.0],
		["Chest", 0.085, 0.22, 5.0, PhysicalBone3D.JOINT_TYPE_CONE, Vector3(0, 0.11, 0), Vector3.ZERO, 0.0, 0.0, 20.0, 15.0],
		["Head", 0.09, 0.20, 2.5, PhysicalBone3D.JOINT_TYPE_CONE, Vector3(0, 0.10, 0), Vector3.ZERO, 0.0, 0.0, 25.0, 30.0],
		
		# Legs: Hinge joints with calibrated flexion limits (0° to 135°) to prevent hyperextension or backward folding
		["LeftUpperLeg", 0.065, 0.38, 4.0, PhysicalBone3D.JOINT_TYPE_CONE, Vector3(0, 0.20, 0), Vector3.ZERO, 0.0, 0.0, 45.0, 30.0],
		["LeftLowerLeg", 0.055, 0.38, 3.0, PhysicalBone3D.JOINT_TYPE_HINGE, Vector3(0, 0.20, 0), Vector3(0, 90.0, 0), 0.0, 135.0, 0.0, 0.0],
		["LeftFoot", 0.045, 0.14, 2.2, PhysicalBone3D.JOINT_TYPE_CONE, Vector3(0, 0.06, 0.02), Vector3.ZERO, 0.0, 0.0, 25.0, 25.0],
		
		["RightUpperLeg", 0.065, 0.38, 4.0, PhysicalBone3D.JOINT_TYPE_CONE, Vector3(0, 0.20, 0), Vector3.ZERO, 0.0, 0.0, 45.0, 30.0],
		["RightLowerLeg", 0.055, 0.38, 3.0, PhysicalBone3D.JOINT_TYPE_HINGE, Vector3(0, 0.20, 0), Vector3(0, 90.0, 0), 0.0, 135.0, 0.0, 0.0],
		["RightFoot", 0.045, 0.14, 2.2, PhysicalBone3D.JOINT_TYPE_CONE, Vector3(0, 0.06, 0.02), Vector3.ZERO, 0.0, 0.0, 25.0, 25.0],
		
		# Arms: Cone for shoulders, Hinge for elbows (0° to 135° forward flexion), Cone for wrists
		["LeftUpperArm", 0.045, 0.22, 2.5, PhysicalBone3D.JOINT_TYPE_CONE, Vector3(0, 0.10, 0), Vector3.ZERO, 0.0, 0.0, 50.0, 30.0],
		["LeftLowerArm", 0.040, 0.18, 1.8, PhysicalBone3D.JOINT_TYPE_HINGE, Vector3(0, 0.09, 0), Vector3(0, 90.0, 0), 0.0, 135.0, 0.0, 0.0],
		["LeftHand", 0.035, 0.10, 1.2, PhysicalBone3D.JOINT_TYPE_CONE, Vector3(0, 0.05, 0), Vector3.ZERO, 0.0, 0.0, 25.0, 25.0],
		
		["RightUpperArm", 0.045, 0.22, 2.5, PhysicalBone3D.JOINT_TYPE_CONE, Vector3(0, 0.10, 0), Vector3.ZERO, 0.0, 0.0, 50.0, 30.0],
		["RightLowerArm", 0.040, 0.18, 1.8, PhysicalBone3D.JOINT_TYPE_HINGE, Vector3(0, 0.09, 0), Vector3(0, -90.0, 0), 0.0, 135.0, 0.0, 0.0],
		["RightHand", 0.035, 0.10, 1.2, PhysicalBone3D.JOINT_TYPE_CONE, Vector3(0, 0.05, 0), Vector3.ZERO, 0.0, 0.0, 25.0, 25.0],
	]
	
	for spec in bone_specs:
		var bname: String = spec[0]
		var radius: float = spec[1]
		var height: float = spec[2]
		var mass: float = spec[3]
		var joint_t: int = spec[4]
		var col_offset: Vector3 = spec[5]
		var joint_rot_deg: Vector3 = spec[6]
		var limit_lower: float = spec[7]
		var limit_upper: float = spec[8]
		var swing_span: float = spec[9]
		var twist_span: float = spec[10]
		
		var b_idx: int = skeleton.find_bone(bname)
		if b_idx < 0:
			continue
			
		var b_gr: Transform3D = skeleton.get_bone_global_rest(b_idx)
		
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + bname
		pb.bone_name = bname
		pb.joint_type = joint_t
		pb.mass = mass
		pb.friction = 0.15 # Low friction allows smooth floor sliding without sticking
		pb.linear_damp = 0.12 # Low damping preserves momentum propagation
		pb.angular_damp = 0.30 # Minimal rotational damping prevents flailing
		pb.can_sleep = false # Keep active so it doesn't freeze asleep
		pb.collision_layer = 4 # Physical ragdoll corpse layer
		pb.collision_mask = 1 # Collides with Floor & Furniture (Layer 1)
		pb.transform = b_gr
		pb.set_meta("corpse_bone_name", bname)
		
		if joint_t == PhysicalBone3D.JOINT_TYPE_HINGE:
			var rot_rad := Vector3(deg_to_rad(joint_rot_deg.x), deg_to_rad(joint_rot_deg.y), deg_to_rad(joint_rot_deg.z))
			pb.joint_rotation = rot_rad
			pb.joint_offset = Transform3D(Basis.from_euler(rot_rad), Vector3.ZERO)
			pb.set("joint_constraints/angular_limit_enabled", true)
			pb.set("joint_constraints/angular_limit_lower", limit_lower)
			pb.set("joint_constraints/angular_limit_upper", limit_upper)
		elif joint_t == PhysicalBone3D.JOINT_TYPE_CONE:
			pb.set("joint_constraints/swing_span", swing_span)
			pb.set("joint_constraints/twist_span", twist_span)
		
		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = radius
		cap.height = height
		col.shape = cap
		col.position = col_offset # Centered along the anatomical bone segment
		pb.add_child(col)
		
		# All 16 PhysicalBone3D are direct children of PhysicalBoneSimulator3D
		simulator.add_child(pb)
		physical_bones[bname] = pb

func start_ragdoll() -> void:
	if not simulator: return
	dragged_bone = null
	drag_anchor = null
	tween_active = false
	current_state = State.RAGDOLL
	simulator.physical_bones_start_simulation()
	state_changed.emit(current_state)

func stop_ragdoll() -> void:
	if not simulator: return
	simulator.physical_bones_stop_simulation()

func start_drag(bone_name: String, anchor: Node3D) -> bool:
	drag_anchor = anchor
	
	if current_state == State.POSED or current_state == State.POSED_DRAGGING:
		# Posed dragging: Drag the posed body smoothly along the floor/bed without breaking pose!
		dragged_bone_name = bone_name
		current_state = State.POSED_DRAGGING
		state_changed.emit(current_state)
		return true
		
	# Limp ragdoll dragging
	if not physical_bones.has(bone_name):
		if physical_bones.has("LeftFoot"): bone_name = "LeftFoot"
		elif physical_bones.has("Hips"): bone_name = "Hips"
		else: return false
		
	dragged_bone = physical_bones[bone_name]
	dragged_bone_name = bone_name
	current_state = State.DRAGGING
	
	if not simulator.is_simulating_physics():
		simulator.physical_bones_start_simulation()
		
	state_changed.emit(current_state)
	return true

func stop_drag() -> void:
	dragged_bone = null
	drag_anchor = null
	if current_state == State.DRAGGING:
		current_state = State.RAGDOLL
		state_changed.emit(current_state)
	elif current_state == State.POSED_DRAGGING:
		current_state = State.POSED
		state_changed.emit(current_state)

func _physics_process(delta: float) -> void:
	if current_state == State.DRAGGING and dragged_bone and drag_anchor:
		_process_ragdoll_drag(delta)
	elif current_state == State.POSED_DRAGGING and drag_anchor:
		_process_posed_drag(delta)

func _process_ragdoll_drag(delta: float) -> void:
	if not dragged_bone or not drag_anchor: return
	var target_pos := drag_anchor.global_position
	var current_pos := dragged_bone.global_position
	var to_target := target_pos - current_pos
	
	# High-responsiveness spring drive on grabbed bone
	var dist := to_target.length()
	var pull_dir := to_target.normalized()
	var pull_vel := pull_dir * (dist * drag_spring_strength)
	if pull_vel.length() > max_drag_velocity:
		pull_vel = pull_vel.normalized() * max_drag_velocity
		
	# Fast responsiveness ensures sufficient momentum transfers through the joint chain to pull the whole body
	dragged_bone.linear_velocity = dragged_bone.linear_velocity.lerp(pull_vel, clampf(delta * 26.0, 0.0, 1.0))

func _process_posed_drag(delta: float) -> void:
	if not character_instance or not drag_anchor: return
	
	# Smoothly slide the posed character along the floor/bed towards player's drag anchor
	var target_h_pos := Vector3(drag_anchor.global_position.x, character_instance.global_position.y, drag_anchor.global_position.z)
	var to_target := target_h_pos - character_instance.global_position
	var dist := to_target.length()
	
	if dist > 0.04:
		var move_speed := clampf(dist * 3.5, 0.0, 3.8)
		var move_dir := to_target.normalized()
		character_instance.global_position += move_dir * move_speed * delta
		
		# Gentle secondary sway to give organic liveliness
		posed_drag_sway += delta * 6.0
		var sway_offset := sin(posed_drag_sway) * 0.02
		character_instance.rotation.z = lerpf(character_instance.rotation.z, sway_offset, delta * 4.0)

func apply_pose_by_name(pose_name: String, duration: float = 0.35) -> bool:
	var path := POSES_DIR + "/" + pose_name + ".json"
	if not FileAccess.file_exists(path):
		path = POSES_DIR + "/" + pose_name
	if not FileAccess.file_exists(path):
		printerr("Pose file not found: ", path)
		return false
	return apply_pose_file(path, duration)

func apply_pose_file(path: String, duration: float = 0.35) -> bool:
	var raw := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		printerr("Invalid pose JSON: ", path)
		return false
		
	stop_drag()
	
	# Synchronize world position with current corpse location on the supporting surface (floor/bed/desk)
	if simulator and simulator.is_simulating_physics() and physical_bones.has("Hips"):
		var hip_pos: Vector3 = physical_bones["Hips"].global_position
		var ground_y := 0.0
		var space_state := get_world_3d().direct_space_state
		if space_state:
			var ray_from := hip_pos + Vector3(0, 0.5, 0)
			var ray_to := hip_pos - Vector3(0, 4.0, 0)
			var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1) # Layer 1: Floor & Furniture
			var hit := space_state.intersect_ray(query)
			if hit:
				ground_y = hit.position.y
		character_instance.global_position = Vector3(hip_pos.x, ground_y, hip_pos.z)
		
		# Align yaw with torso orientation
		if physical_bones.has("Chest"):
			var chest_pos: Vector3 = physical_bones["Chest"].global_position
			var fwd: Vector3 = (hip_pos - chest_pos)
			fwd.y = 0.0
			if fwd.length_squared() > 0.01:
				character_instance.look_at(character_instance.global_position + fwd.normalized(), Vector3.UP)
				
	stop_ragdoll()
	current_state = State.POSED
	current_pose_name = data.get("name", path.get_file().get_basename())
	current_pose_data = data
	state_changed.emit(current_state)
	
	_interpolate_to_pose(data, duration)
	return true

func _interpolate_to_pose(pose_data: Dictionary, duration: float) -> void:
	if not skeleton: return
	
	var bones_target: Dictionary = pose_data.get("bones", {})
	var start_rotations: Dictionary = {}
	var start_positions: Dictionary = {}
	var target_rotations: Dictionary = {}
	var target_positions: Dictionary = {}
	
	for bname in bones_target:
		var idx := skeleton.find_bone(bname)
		if idx >= 0:
			start_rotations[idx] = skeleton.get_bone_pose_rotation(idx)
			start_positions[idx] = skeleton.get_bone_pose_position(idx)
			var bentry: Dictionary = bones_target[bname]
			if bentry.has("rot"):
				var q: Array = bentry["rot"]
				target_rotations[idx] = Quaternion(q[0], q[1], q[2], q[3])
			if bentry.has("pos"):
				var p: Array = bentry["pos"]
				target_positions[idx] = Vector3(p[0], p[1], p[2])
				
	tween_active = true
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	
	tw.tween_method(func(t: float):
		if not tween_active: return
		for idx in target_rotations:
			var r_start: Quaternion = start_rotations[idx]
			var r_end: Quaternion = target_rotations[idx]
			skeleton.set_bone_pose_rotation(idx, r_start.slerp(r_end, t))
		for idx in target_positions:
			var p_start: Vector3 = start_positions[idx]
			var p_end: Vector3 = target_positions[idx]
			skeleton.set_bone_pose_position(idx, p_start.lerp(p_end, t))
		skeleton.force_update_all_bone_transforms()
	, 0.0, 1.0, duration)
	
	tw.finished.connect(func():
		tween_active = false
		pose_applied.emit(current_pose_name)
	)

func get_closest_bone_to_ray(ray_origin: Vector3, ray_dir: Vector3, max_dist: float = 3.5) -> Dictionary:
	var closest_bone := ""
	var closest_pb: PhysicalBone3D = null
	var min_perp_dist := 999.0
	
	# If in ragdoll/dragging mode, test against physical bone colliders
	if current_state == State.RAGDOLL or current_state == State.DRAGGING:
		for bname in physical_bones:
			var pb: PhysicalBone3D = physical_bones[bname]
			var bone_pos := pb.global_position
			var to_bone := bone_pos - ray_origin
			var proj := to_bone.dot(ray_dir)
			if proj < 0.0 or proj > max_dist:
				continue
			var perp_dist := (to_bone - ray_dir * proj).length()
			if perp_dist < min_perp_dist and perp_dist < 0.65:
				min_perp_dist = perp_dist
				closest_bone = bname
				closest_pb = pb
	else:
		# In posed mode, test against skeleton bone world positions
		if skeleton:
			for bname in ["LeftFoot", "RightFoot", "Hips", "Head", "LeftHand", "RightHand"]:
				var idx := skeleton.find_bone(bname)
				if idx >= 0:
					var b_pos := skeleton.global_transform * skeleton.get_bone_global_pose(idx).origin
					var to_bone := b_pos - ray_origin
					var proj := to_bone.dot(ray_dir)
					if proj < 0.0 or proj > max_dist:
						continue
					var perp_dist := (to_bone - ray_dir * proj).length()
					if perp_dist < min_perp_dist and perp_dist < 0.70:
						min_perp_dist = perp_dist
						closest_bone = bname
						
	return {
		"bone_name": closest_bone,
		"physical_bone": closest_pb,
		"distance": min_perp_dist
	}
