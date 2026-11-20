class_name HomeResidentActor
extends Node3D
## 3D resident actor living inside a home room.
## Handles grounded placement, light in-room wandering AI, and companion follow mode.

signal interaction_requested(actor: HomeResidentActor)

enum State {
	IDLE,
	WANDERING,
	FOLLOWING,
	INTERACTING
}

const ACTOR_SCENE := preload("res://scenes/characters/shared_humanoid_actor.tscn")
const ROSTER := preload("res://scripts/characters/character_roster_database.gd")
const NPC_SOLID_LAYER := 64
const WALK_SPEED := 1.2
const RUN_SPEED := 3.6

var character_id: String = ""
var plot_id: String = ""
var room_id: String = ""
var room_data: Dictionary = {}
var home: Node3D = null

var state: State = State.IDLE
var actor_instance: Node3D = null
var static_body: StaticBody3D = null
var collision_shape: CollisionShape3D = null

var _wander_timer: float = 15.0
var _target_position: Vector3 = Vector3.ZERO
var _player_nearby: bool = false
var _room_cells: Array[Vector2i] = []
var _story: int = 0
var _display_name: String = ""

func _ready() -> void:
	add_to_group("home_residents")
	_parse_room_cells()
	_setup_model()
	_setup_collision()
	_reset_wander_timer()

func _parse_room_cells() -> void:
	_room_cells.clear()
	_story = int(room_data.get("story", 0))
	var cells: Array = room_data.get("cells", [])
	for c: Variant in cells:
		var parts: PackedStringArray = str(c).split(":")
		if parts.size() == 3:
			_room_cells.append(Vector2i(parts[1].to_int(), parts[2].to_int()))

func _setup_model() -> void:
	var entry := ROSTER.get_entry(character_id)
	_display_name = str(entry.get("name", character_id))

	# Read avatar config
	var avatar_file := "res://assets/npc/avatars/" + character_id + ".json"
	var model_path := "res://assets/characters/roster/" + character_id + "/" + character_id + ".vrm"
	var idle_path := "res://assets/characters/roster/motions/koikatsu_idle.tres"
	var mat_id := character_id

	if FileAccess.file_exists(avatar_file):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(avatar_file))
		if raw is Dictionary:
			model_path = str(raw.get("model_resource", model_path))
			idle_path = str(raw.get("idle_motion", idle_path))
			mat_id = str(raw.get("material_id", mat_id))

	actor_instance = ACTOR_SCENE.instantiate()
	actor_instance.name = "HumanoidActor"
	actor_instance.model_resource = model_path
	actor_instance.motion_resource = idle_path
	actor_instance.environment_collision_enabled = false
	add_child(actor_instance)

func _setup_collision() -> void:
	static_body = StaticBody3D.new()
	static_body.name = "ResidentCollision"
	static_body.collision_layer = NPC_SOLID_LAYER
	static_body.collision_mask = 0
	add_child(static_body)

	collision_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	collision_shape.shape = capsule
	collision_shape.position = Vector3(0, 0.8, 0)
	static_body.add_child(collision_shape)

func _reset_wander_timer() -> void:
	_wander_timer = randf_range(12.0, 24.0)

func set_following(following: bool) -> void:
	if following:
		state = State.FOLLOWING
	else:
		state = State.IDLE
		_reset_wander_timer()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(home) or not is_instance_valid(home.world):
		return

	var player = home.world.character
	if not is_instance_valid(player):
		return

	var dist_to_player: float = global_position.distance_to(player.global_position)
	_player_nearby = (dist_to_player <= 2.2)

	match state:
		State.IDLE:
			_process_idle(delta)
		State.WANDERING:
			_process_wandering(delta)
		State.FOLLOWING:
			_process_following(delta, player, dist_to_player)
		State.INTERACTING:
			# Face player smoothly while in interaction
			_look_towards(player.global_position, delta * 5.0)

func _process_idle(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_next_wander_destination()

func _pick_next_wander_destination() -> void:
	if _room_cells.is_empty() or not home.plots.has(plot_id):
		_reset_wander_timer()
		return

	var plot: Dictionary = home.plots[plot_id]
	var random_cell: Vector2i = _room_cells.pick_random()

	# Convert cell to local coordinates on plot (each cell is 2.0m x 2.0m)
	var local_x := random_cell.x * 2.0 + 1.0
	var local_z := random_cell.y * 2.0 + 1.0
	var local_y := 0.2 + _story * 3.6
	var target_local := Vector3(local_x, local_y, local_z)
	var target_global: Vector3 = plot.root.to_global(target_local)

	# Raycast to find exact ground floor
	var w3d := get_world_3d()
	if w3d == null or w3d.direct_space_state == null:
		_reset_wander_timer()
		return
	var space := w3d.direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(target_global + Vector3.UP * 0.8, target_global - Vector3.UP * 1.5, 32)
	ray.exclude = [static_body.get_rid()]
	var hit := space.intersect_ray(ray)
	if not hit.is_empty():
		_target_position = hit.position + Vector3.UP * 0.02
		state = State.WANDERING
	else:
		_reset_wander_timer()

func _process_wandering(delta: float) -> void:
	var delta_pos := _target_position - global_position
	delta_pos.y = 0.0
	var dist := delta_pos.length()

	if dist < 0.25:
		state = State.IDLE
		_reset_wander_timer()
		return

	_look_towards(_target_position, delta * 6.0)
	var move_step := delta_pos.normalized() * (WALK_SPEED * delta)
	if move_step.length() > dist:
		move_step = delta_pos
	global_position += move_step

func _process_following(delta: float, player: Node3D, dist: float) -> void:
	_look_towards(player.global_position, delta * 6.0)
	if dist > 2.0:
		var speed := RUN_SPEED if dist > 4.5 else WALK_SPEED
		var dir := (player.global_position - global_position)
		dir.y = 0.0
		var move_step := dir.normalized() * (speed * delta)
		if move_step.length() > (dist - 1.8):
			move_step = dir.normalized() * (dist - 1.8)
		global_position += move_step

func _look_towards(target: Vector3, weight: float) -> void:
	var dir := target - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		var target_yaw := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(weight, 0.0, 1.0))

func get_display_name() -> String:
	return _display_name

func is_player_nearby() -> bool:
	return _player_nearby
