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

const WALK_MOTION := "res://assets/characters/roster/motions/koikatsu_walk.tres"
const RUN_MOTION := "res://assets/characters/roster/motions/koikatsu_run.tres"
const IDLE_MOTION := "res://assets/characters/roster/motions/koikatsu_idle.tres"

var character_id: String = ""
var plot_id: String = ""
var room_id: String = ""
var room_data: Dictionary = {}
var home: Node3D = null

var state: State = State.IDLE
var previous_state: State = State.IDLE
var actor_instance: Node3D = null
var static_body: StaticBody3D = null
var collision_shape: CollisionShape3D = null

var _wander_timer: float = 15.0
var _target_position: Vector3 = Vector3.ZERO
var _player_nearby: bool = false
var _room_cells: Array[Vector2i] = []
var _story: int = 0
var _display_name: String = ""
var _idle_path: String = IDLE_MOTION
var _current_motion_name: String = "idle"

var _player_trail: Array[Vector3] = []
var _stuck_duration: float = 0.0
var _stuck_check_timer: float = 0.5
var _last_stuck_check_pos: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("home_residents")
	_last_stuck_check_pos = global_position
	_parse_room_cells()
	_setup_model()
	_setup_collision()
	_reset_wander_timer()

func update_room_data(new_room_data: Dictionary) -> void:
	room_data = new_room_data
	_parse_room_cells()

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
	_idle_path = IDLE_MOTION

	if FileAccess.file_exists(avatar_file):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(avatar_file))
		if raw is Dictionary:
			model_path = str(raw.get("model_resource", model_path))
			_idle_path = str(raw.get("idle_motion", _idle_path))

	actor_instance = ACTOR_SCENE.instantiate()
	actor_instance.name = "HumanoidActor"
	actor_instance.model_resource = model_path
	actor_instance.motion_resource = _idle_path
	actor_instance.auto_play = true
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
		previous_state = State.FOLLOWING
		_player_trail.clear()
		_stuck_duration = 0.0
		_stuck_check_timer = 0.5
		_last_stuck_check_pos = global_position
	else:
		state = State.IDLE
		previous_state = State.IDLE
		_player_trail.clear()
		_stuck_duration = 0.0
		_reset_wander_timer()
		_update_locomotion_motion(0.0)

func is_following() -> bool:
	return state == State.FOLLOWING or previous_state == State.FOLLOWING

func enter_interaction() -> void:
	previous_state = state
	state = State.INTERACTING
	_update_locomotion_motion(0.0)

func exit_interaction() -> void:
	state = previous_state
	_update_locomotion_motion(0.0)

func _update_locomotion_motion(speed: float) -> void:
	if not is_instance_valid(actor_instance):
		return
	var desired := "idle"
	if speed > 3.0:
		desired = "run"
	elif speed > 0.15:
		desired = "walk"

	if desired == _current_motion_name:
		return
	_current_motion_name = desired
	var path := _idle_path
	if desired == "walk" and ResourceLoader.exists(WALK_MOTION):
		path = WALK_MOTION
	elif desired == "run" and ResourceLoader.exists(RUN_MOTION):
		path = RUN_MOTION
	if actor_instance.has_method("set_motion"):
		actor_instance.set_motion(path)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(home) or not is_instance_valid(home.world):
		return

	if not ("character" in home.world):
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
			_look_towards(player.global_position, delta * 5.0)

func _process_idle(delta: float) -> void:
	_update_locomotion_motion(0.0)
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_next_wander_destination()

func _pick_next_wander_destination() -> void:
	if _room_cells.is_empty() or not home.plots.has(plot_id):
		_reset_wander_timer()
		return

	var plot: Dictionary = home.plots[plot_id]
	var random_cell: Vector2i = _room_cells.pick_random()

	var local_x := random_cell.x * 2.0 + 1.0
	var local_z := random_cell.y * 2.0 + 1.0
	var local_y := 0.2 + _story * 3.6
	var target_local := Vector3(local_x, local_y, local_z)
	var target_global: Vector3 = plot.root.to_global(target_local)

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
		_update_locomotion_motion(0.0)
		return

	_look_towards(_target_position, delta * 6.0)
	var move_step := delta_pos.normalized() * (WALK_SPEED * delta)
	if move_step.length() > dist:
		move_step = delta_pos

	_apply_step_with_environment(move_step, WALK_SPEED, delta)

func _process_following(delta: float, player: Node3D, dist: float) -> void:
	var w3d := get_world_3d()
	var space: PhysicsDirectSpaceState3D = w3d.direct_space_state if w3d != null else null

	# 1. Update player breadcrumb trail
	var player_pos: Vector3 = player.global_position
	if _player_trail.is_empty() or _player_trail.back().distance_to(player_pos) >= 0.8:
		_player_trail.append(player_pos)
		if _player_trail.size() > 32:
			_player_trail.pop_front()

	# 2. Prune breadcrumbs the actor has already reached
	while not _player_trail.is_empty() and global_position.distance_to(_player_trail[0]) < 1.0:
		_player_trail.pop_front()

	# 3. Anti-stuck monitoring
	_stuck_check_timer -= delta
	if _stuck_check_timer <= 0.0:
		_stuck_check_timer = 0.5
		var moved_dist: float = global_position.distance_to(_last_stuck_check_pos)
		_last_stuck_check_pos = global_position
		if dist > 2.2 and moved_dist < 0.08:
			_stuck_duration += 0.5
		else:
			_stuck_duration = maxf(0.0, _stuck_duration - 0.5)

	# Trigger teleport catch-up if wedged in a corner for over 2.5s or far away
	if _stuck_duration >= 2.5 or dist > 14.0:
		_teleport_catch_up(player)
		_stuck_duration = 0.0
		_player_trail.clear()
		return

	# 4. Determine navigation target: Direct LOS vs Breadcrumb Waypoint
	var target_dest := player_pos
	var direct_los: bool = _has_line_of_sight(global_position, player_pos, space)

	if direct_los:
		target_dest = player_pos
		if dist <= 2.2:
			_player_trail.clear()
	elif not _player_trail.is_empty():
		var best_idx := -1
		for i in range(_player_trail.size() - 1, -1, -1):
			var pt: Vector3 = _player_trail[i]
			if _has_line_of_sight(global_position, pt, space):
				best_idx = i
				break

		if best_idx >= 0:
			target_dest = _player_trail[best_idx]
			if best_idx > 0:
				_player_trail = _player_trail.slice(best_idx)
		else:
			target_dest = _player_trail[0]

	# 5. Check distance to final player position
	if dist <= 2.0 and direct_los:
		_look_towards(player_pos, delta * 6.0)
		_update_locomotion_motion(0.0)
		return

	# 6. Calculate steering direction with multi-whisker corner avoidance
	var steer_dir: Vector3 = _calculate_steer_direction(target_dest, space)
	if steer_dir.length_squared() < 0.001:
		_look_towards(player_pos, delta * 6.0)
		_update_locomotion_motion(0.0)
		return

	_look_towards(global_position + steer_dir * 3.0, delta * 6.0)

	var speed: float = RUN_SPEED if dist > 4.5 else WALK_SPEED
	var move_step: Vector3 = steer_dir * (speed * delta)
	var remain_dist: float = dist - 1.8
	if remain_dist > 0.0 and move_step.length() > remain_dist and direct_los:
		move_step = steer_dir * remain_dist

	_apply_step_with_environment(move_step, speed, delta)

func _has_line_of_sight(from_pos: Vector3, to_pos: Vector3, space: PhysicsDirectSpaceState3D) -> bool:
	if space == null:
		return true
	var ray := PhysicsRayQueryParameters3D.create(
		from_pos + Vector3.UP * 0.8,
		to_pos + Vector3.UP * 0.8,
		1 | 32
	)
	var my_rid := static_body.get_rid() if is_instance_valid(static_body) else RID()
	if my_rid.is_valid():
		ray.exclude = [my_rid]
	var hit := space.intersect_ray(ray)
	return hit.is_empty()

func _calculate_steer_direction(target_pos: Vector3, space: PhysicsDirectSpaceState3D) -> Vector3:
	var desired := target_pos - global_position
	desired.y = 0.0
	if desired.length_squared() < 0.0001:
		return Vector3.ZERO
	var desired_dir := desired.normalized()
	if space == null:
		return desired_dir

	var origin := global_position + Vector3.UP * 0.5
	var my_rid := static_body.get_rid() if is_instance_valid(static_body) else RID()

	var probe_angles: Array[float] = [30.0, -30.0, 60.0, -60.0]
	var avoidance := Vector3.ZERO

	for ang in probe_angles:
		var ray_dir := desired_dir.rotated(Vector3.UP, deg_to_rad(ang))
		var ray_len: float = 0.6 if absf(ang) < 40.0 else 0.45
		var ray := PhysicsRayQueryParameters3D.create(origin, origin + ray_dir * ray_len, 1 | 32 | 64)
		if my_rid.is_valid():
			ray.exclude = [my_rid]
		var hit := space.intersect_ray(ray)
		if not hit.is_empty():
			var hit_norm: Vector3 = hit.normal
			hit_norm.y = 0.0
			if hit_norm.length_squared() > 0.001:
				var push_weight: float = 1.0 - (hit.position.distance_to(origin) / ray_len)
				avoidance += hit_norm.normalized() * push_weight
			else:
				var side_sign: float = -1.0 if ang > 0.0 else 1.0
				avoidance += desired_dir.rotated(Vector3.UP, side_sign * deg_to_rad(90.0)) * 0.5

	var final_steer := (desired_dir + avoidance * 0.9)
	final_steer.y = 0.0
	if final_steer.length_squared() < 0.001:
		return desired_dir
	return final_steer.normalized()

func _apply_step_with_environment(move_step: Vector3, intended_speed: float, _delta: float) -> void:
	var w3d := get_world_3d()
	var space := w3d.direct_space_state if w3d != null else null
	var my_rid := static_body.get_rid() if is_instance_valid(static_body) else RID()
	var effective_step := move_step

	if space != null and effective_step.length_squared() > 0.0001:
		var origin := global_position + Vector3.UP * 0.5
		var obs_ray := PhysicsRayQueryParameters3D.create(
			origin,
			origin + effective_step.normalized() * 0.45,
			1 | 32 | 64
		)
		if my_rid.is_valid():
			obs_ray.exclude = [my_rid]
		var obs_hit := space.intersect_ray(obs_ray)
		if not obs_hit.is_empty():
			var wall_norm: Vector3 = obs_hit.normal
			wall_norm.y = 0.0
			var can_slide := false
			if wall_norm.length_squared() > 0.001:
				wall_norm = wall_norm.normalized()
				var slide_dir := effective_step.slide(wall_norm)
				slide_dir.y = 0.0
				if slide_dir.length_squared() > 0.001:
					var test_slide := slide_dir.normalized() * effective_step.length()
					var slide_ray := PhysicsRayQueryParameters3D.create(
						origin,
						origin + test_slide.normalized() * 0.4,
						1 | 32 | 64
					)
					if my_rid.is_valid():
						slide_ray.exclude = [my_rid]
					var slide_hit := space.intersect_ray(slide_ray)
					if slide_hit.is_empty():
						effective_step = test_slide
						can_slide = true

			if not can_slide:
				_update_locomotion_motion(0.0)
				if state == State.WANDERING:
					state = State.IDLE
					_reset_wander_timer()
				return

	var next_pos := global_position + effective_step
	if space != null:
		var floor_ray := PhysicsRayQueryParameters3D.create(
			next_pos + Vector3.UP * 0.8,
			next_pos - Vector3.UP * 1.5,
			32 | 1
		)
		if my_rid.is_valid():
			floor_ray.exclude = [my_rid]
		var f_hit := space.intersect_ray(floor_ray)
		if not f_hit.is_empty():
			next_pos.y = f_hit.position.y + 0.02

	global_position = next_pos
	_update_locomotion_motion(intended_speed)

func _teleport_catch_up(player: Node3D) -> void:
	var safe_pos: Vector3 = player.global_position - player.global_basis.z * 1.8
	var w3d := get_world_3d()
	if w3d != null and w3d.direct_space_state != null:
		var floor_ray := PhysicsRayQueryParameters3D.create(
			safe_pos + Vector3.UP * 1.0,
			safe_pos - Vector3.UP * 2.5,
			32 | 1
		)
		var my_rid := static_body.get_rid() if is_instance_valid(static_body) else RID()
		if my_rid.is_valid():
			floor_ray.exclude = [my_rid]
		var hit := w3d.direct_space_state.intersect_ray(floor_ray)
		if not hit.is_empty():
			safe_pos = hit.position + Vector3.UP * 0.02
	global_position = safe_pos
	_update_locomotion_motion(0.0)

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
