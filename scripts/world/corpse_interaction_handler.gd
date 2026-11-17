class_name CorpseInteractionHandler
extends RefCounted

## Handles player interaction with corpse ragdolls in the overworld.
## Supports raycast limb selection, [E] grabbing/dragging, drag resistance physics,
## and distance tracking for leaving (>30m) respawn triggers.

signal player_left_corpse(distance: float)
signal drag_started(bone_name: String)
signal drag_stopped()

const DRAG_RESISTANCE_SPEED: float = 2.6
const INTERACTION_DISTANCE: float = 3.2
const RESPAWN_DISTANCE: float = 30.0
const RAY_MAX_DISTANCE: float = 4.5

var is_active := false
var is_dragging := false
var current_drag_bone := "LeftFoot"

var world: Node = null
var corpse: Node3D = null # CorpseRagdollController
var prompt_label: Label = null
var character_name: String = ""

var drag_anchor: Node3D = null
var orig_player_run_speed: float = 4.2
var has_stored_speed := false

static func bone_name_zh(bname: String) -> String:
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

func activate(p_world: Node, p_corpse: Node3D, p_prompt_label: Label, p_character_name: String) -> void:
	world = p_world
	corpse = p_corpse
	prompt_label = p_prompt_label
	character_name = p_character_name
	is_active = true
	is_dragging = false
	current_drag_bone = "LeftFoot"
	
	_setup_drag_anchor()
	
	var player := _get_player()
	if player and "running_speed" in player:
		orig_player_run_speed = player.running_speed
		has_stored_speed = true

func deactivate() -> void:
	if is_dragging:
		stop_drag()
	if is_instance_valid(drag_anchor):
		drag_anchor.queue_free()
		drag_anchor = null
	if prompt_label and is_instance_valid(prompt_label):
		prompt_label.text = ""
		prompt_label.visible = false
	is_active = false
	corpse = null
	world = null

func _setup_drag_anchor() -> void:
	if is_instance_valid(drag_anchor):
		drag_anchor.queue_free()
		drag_anchor = null
		
	var player := _get_player()
	if player == null or not is_instance_valid(player):
		return
		
	drag_anchor = Node3D.new()
	drag_anchor.name = "CorpseDragAnchor"
	# Held naturally in front of player character's waist/hands at ~0.65m height
	drag_anchor.position = Vector3(0.0, 0.65, 0.85)
	
	var visual: Node3D = player.get_node_or_null("Visual")
	if visual:
		visual.add_child(drag_anchor)
	else:
		player.add_child(drag_anchor)

func _get_player() -> Node3D:
	if world == null or not is_instance_valid(world):
		return null
	if world.has_method("active_actor"):
		var actor = world.active_actor()
		if actor != null and is_instance_valid(actor) and actor is Node3D:
			return actor as Node3D
	if "character" in world:
		var c = world.get("character")
		if c != null and is_instance_valid(c) and c is Node3D:
			return c as Node3D
	return null

func get_corpse_position() -> Vector3:
	if corpse and is_instance_valid(corpse):
		if "physical_bones" in corpse and corpse.physical_bones.has("Hips") and is_instance_valid(corpse.physical_bones["Hips"]):
			return corpse.physical_bones["Hips"].global_position
		if "character_instance" in corpse and corpse.character_instance and is_instance_valid(corpse.character_instance):
			return corpse.character_instance.global_position
		return corpse.global_position
	return Vector3.ZERO

func tick(_delta: float) -> void:
	if not is_active or not is_instance_valid(corpse):
		return
		
	var player: Node3D = _get_player()
	if player == null or not is_instance_valid(player):
		return
		
	# Ensure drag anchor is valid and attached
	if not is_instance_valid(drag_anchor):
		_setup_drag_anchor()
		
	var corpse_pos: Vector3 = get_corpse_position()
	var dist_to_corpse: float = player.global_position.distance_to(corpse_pos)
	
	# Check for 30-meter leaving respawn condition
	if dist_to_corpse > RESPAWN_DISTANCE:
		if is_dragging:
			stop_drag()
		player_left_corpse.emit(dist_to_corpse)
		return
		
	var in_range: bool = dist_to_corpse < INTERACTION_DISTANCE
	
	# Raycast check for closest bone to crosshair / camera
	var camera: Camera3D = null
	if "camera" in player and is_instance_valid(player.camera):
		camera = player.camera
	elif world and is_instance_valid(world) and world.get_viewport():
		camera = world.get_viewport().get_camera_3d()
		
	var detected_bone := "LeftFoot"
	if camera and corpse.has_method("get_closest_bone_to_ray"):
		var ray_origin: Vector3 = camera.global_position
		var ray_dir: Vector3 = -camera.global_transform.basis.z
		var bone_hit: Dictionary = corpse.get_closest_bone_to_ray(ray_origin, ray_dir, RAY_MAX_DISTANCE)
		if not bone_hit.get("bone_name", "").is_empty():
			detected_bone = bone_hit.bone_name
	elif not corpse.physical_bones.is_empty():
		var min_d: float = 999.0
		for bname in corpse.physical_bones:
			var pb: PhysicalBone3D = corpse.physical_bones[bname]
			var d: float = player.global_position.distance_to(pb.global_position)
			if d < min_d:
				min_d = d
				detected_bone = bname
				
	# Update UI prompts
	if prompt_label and is_instance_valid(prompt_label):
		if is_dragging:
			prompt_label.text = "✊ 正在物理拖拽: %s · %s\n[按 E] 放下肢体  |  [WASD] 移动拖行  |  [Shift] 慢步拖拽" % [
				character_name, bone_name_zh(current_drag_bone)
			]
			prompt_label.visible = true
		elif in_range:
			current_drag_bone = detected_bone
			prompt_label.text = "【物理布娃娃 · %s】\n[按 E] 拖拽%s" % [
				character_name, bone_name_zh(current_drag_bone)
			]
			prompt_label.visible = true
		else:
			prompt_label.text = ""
			prompt_label.visible = false

func handle_input(event: InputEvent) -> bool:
	if not is_active or not is_instance_valid(corpse):
		return false
		
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.physical_keycode == KEY_E:
			if is_dragging:
				stop_drag()
				return true
			else:
				var player: Node3D = _get_player()
				if player and is_instance_valid(player):
					var dist: float = player.global_position.distance_to(get_corpse_position())
					if dist < INTERACTION_DISTANCE:
						start_drag(current_drag_bone)
						return true
	return false

func start_drag(bone_name: String) -> bool:
	if not is_active or not is_instance_valid(corpse):
		return false
	if not is_instance_valid(drag_anchor):
		_setup_drag_anchor()
	if not is_instance_valid(drag_anchor):
		return false
		
	is_dragging = true
	current_drag_bone = bone_name
	corpse.start_drag(current_drag_bone, drag_anchor)
	
	var player := _get_player()
	if player and "running_speed" in player:
		if not has_stored_speed:
			orig_player_run_speed = player.running_speed
			has_stored_speed = true
		player.running_speed = DRAG_RESISTANCE_SPEED
		
	drag_started.emit(current_drag_bone)
	if prompt_label and is_instance_valid(prompt_label):
		prompt_label.text = "✊ 正在物理拖拽: %s · %s\n[按 E] 放下肢体  |  [WASD] 移动拖行  |  [Shift] 慢步拖拽" % [
			character_name, bone_name_zh(current_drag_bone)
		]
		prompt_label.visible = true
	return true

func stop_drag() -> void:
	if not is_dragging:
		return
	is_dragging = false
	if is_instance_valid(corpse):
		corpse.stop_drag()
		
	var player: Node3D = _get_player()
	if player and "running_speed" in player and has_stored_speed:
		player.running_speed = orig_player_run_speed
		
	if prompt_label and is_instance_valid(prompt_label):
		prompt_label.text = "【物理布娃娃 · %s】\n[按 E] 拖拽%s" % [
			character_name, bone_name_zh(current_drag_bone)
		]
		prompt_label.visible = true
		
	drag_stopped.emit()
