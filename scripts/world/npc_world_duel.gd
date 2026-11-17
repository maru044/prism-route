extends Node

const Runtime := preload("res://scripts/world/npc_encounter_runtime.gd")
const WorldControl := preload("res://scripts/world/world_control_context.gd")
const ACTOR := preload("res://scenes/characters/shared_humanoid_actor.tscn")
const MTOON := preload("res://scripts/characters/mtoon_materials.gd")

const MASTER_CONFIGS: Dictionary = {
	"lumine": {
		"model": "res://assets/characters/roster/lumine/lumine.vrm",
		"mtoon": "lumine"
	},
	"ganyu": {
		"model": "res://assets/characters/ganyu/ganyu.vrm",
		"mtoon": "ganyu"
	}
}

var runtime: Runtime
var world: Node3D
var anchor: Marker3D
var actor: Node3D
var panel: DialoguePanel
var hud: TurnCombatHUD
var prompt: Label
var service_hud: Label

var combat_actors_root: Node3D
var npc_paired_actor: Node3D
var master_paired_actor: Node3D
var service_camera: Camera3D

var is_service_active: bool = false
var saved_player_collision_layer: int = 2
var saved_player_collision_mask: int = 1
var last_service_approach_pos: Vector3 = Vector3.ZERO
var last_service_approach_basis: Basis = Basis.IDENTITY

var default_cam_distance: float = 2.2
var cam_distance: float = 2.2
var cam_yaw: float = 0.0
var cam_pitch: float = 0.2
var cam_focal_point: Vector3 = Vector3.ZERO
var is_dragging_cam: bool = false

func initialize(host: Node3D, p_world: Node3D, p_runtime: Runtime) -> void:
	world = p_world
	runtime = p_runtime
	anchor = runtime.create_anchor(host, "DuelNPC")
	actor = runtime.create_idle_actor(anchor, "IdleActor", 33)
	add_to_group(WorldControl.GROUP_INPUT_BLOCKERS)

	combat_actors_root = Node3D.new()
	combat_actors_root.name = "CombatDualActors"
	combat_actors_root.visible = false
	host.add_child(combat_actors_root)

	service_camera = Camera3D.new()
	service_camera.name = "ServiceCamera"
	service_camera.current = false
	host.add_child(service_camera)

	var canvas := CanvasLayer.new()
	canvas.layer = 12
	add_child(canvas)
	var palette: Resource = load(runtime.encounter_bundle["presentation"]["ui_palette"])
	hud = TurnCombatHUD.new()
	hud.palette = palette
	hud.opponent_name = runtime.character_name
	hud.hide()
	canvas.add_child(hud)
	panel = DialoguePanel.new()
	panel.palette = palette
	panel.opponent_name = runtime.character_name
	panel.hide()
	canvas.add_child(panel)

	prompt = Label.new()
	prompt.text = "【E】与%s交涉" % runtime.character_name
	prompt.set_anchor_and_offset(SIDE_LEFT, 0.0, 0.0)
	prompt.set_anchor_and_offset(SIDE_RIGHT, 1.0, 0.0)
	prompt.set_anchor_and_offset(SIDE_TOP, 0.72, 0.0)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 18)
	prompt.hide()
	canvas.add_child(prompt)

	service_hud = Label.new()
	service_hud.name = "ServiceHUD"
	service_hud.set_anchor_and_offset(SIDE_LEFT, 0.1, 0.0)
	service_hud.set_anchor_and_offset(SIDE_RIGHT, 0.9, 0.0)
	service_hud.set_anchor_and_offset(SIDE_TOP, 0.84, 0.0)
	service_hud.set_anchor_and_offset(SIDE_BOTTOM, 0.93, 0.0)
	service_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	service_hud.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	service_hud.add_theme_font_size_override("font_size", 16)
	service_hud.add_theme_color_override("font_color", Color(1.0, 0.96, 0.72))
	service_hud.visible = false
	canvas.add_child(service_hud)

	var dialogue := runtime.dialogue_manager
	dialogue.text_updated.connect(panel.display_text)
	dialogue.choices_presented.connect(panel.display_choices)
	dialogue.dialogue_started.connect(func(_graph_id: String): panel.show())
	dialogue.dialogue_ended.connect(_on_dialogue_ended)
	panel.next_pressed.connect(dialogue.advance_text)
	panel.option_selected.connect(dialogue.choose_option)

	var combat := runtime.combat_manager
	combat.combat_started.connect(hud.reset_battle)
	combat.log_message_emitted.connect(hud.append_log)
	combat.koujou_triggered.connect(hud.display_koujou)
	combat.phase_changed.connect(_on_phase_changed)
	hud.action_chosen.connect(combat.execute_player_action)
	hud.meta_dialogue_requested.connect(combat.request_in_battle_negotiation)
	runtime.player_pleasure.pleasure_changed.connect(hud.update_player_pleasure)
	runtime.npc_pleasure.pleasure_changed.connect(hud.update_npc_pleasure)
	hud.set_opponent_pleasure(runtime.npc_pleasure)
	runtime.encounter_state_changed.connect(_on_encounter_state_changed)

func is_world_input_locked() -> bool:
	return is_service_active or (runtime != null and runtime.current_state in [
		Runtime.EncounterState.INTRO_DIALOGUE,
		Runtime.EncounterState.COMBAT,
		Runtime.EncounterState.RESULT_DIALOGUE,
		Runtime.EncounterState.SETTLEMENT,
	])

func _can_interact() -> bool:
	return is_instance_valid(world) and world.test_ready and world.character_mode and not world.free_mode \
		and not world.has_llm_panel_open() and not world.encounter_ui_active and world.is_world_input_allowed() \
		and is_instance_valid(actor.character) and world.character.global_position.distance_to(anchor.global_position) < 2.6

func _process(_delta: float) -> void:
	prompt.visible = _can_interact()

func _unhandled_input(event: InputEvent) -> void:
	if is_service_active:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				is_dragging_cam = event.pressed
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
				cam_distance = default_cam_distance
				_update_service_camera()
				get_viewport().set_input_as_handled()
				return
			elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				var delta: float = 0.25 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -0.25
				cam_distance = clampf(cam_distance + delta, 0.8, 5.0)
				_update_service_camera()
				get_viewport().set_input_as_handled()
				return
		elif event is InputEventMouseMotion and is_dragging_cam:
			cam_yaw -= event.relative.x * 0.004
			cam_pitch = clampf(cam_pitch - event.relative.y * 0.003, -1.2, 1.2)
			_update_service_camera()
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_ESCAPE] or event.physical_keycode in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
				get_viewport().set_input_as_handled()
				finish_furniture_service()
				return
		return

	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_E or event.keycode == KEY_E) and _can_interact():
		get_viewport().set_input_as_handled()
		runtime.start_intro_dialogue()

func _on_phase_changed(phase: int) -> void:
	var combat := runtime.combat_manager
	hud.update_round(combat.round_count)
	hud.set_chat_open(phase == TurnCombatManager.Phase.MID_BATTLE_DIALOGUE)
	hud.set_input_enabled(phase == TurnCombatManager.Phase.PLAYER_INPUT)

func _on_encounter_state_changed(_old: int, state: int) -> void:
	var busy := is_world_input_locked()
	hud.visible = state == Runtime.EncounterState.COMBAT
	if not busy:
		panel.hide()
	world.set_encounter_ui_active(busy)
	world._sync_actor_controls()
	if busy and is_instance_valid(world.character) and world.character.has_method("set_control_enabled"):
		world.character.set_control_enabled(false)

func _on_dialogue_ended(payload: Dictionary) -> void:
	if not runtime.dialogue_manager.session_active:
		panel.hide()
	var act: String = payload.get("action", "")
	if act in ["spare_desk", "desk_service", "spare"]:
		begin_furniture_service_staging("desk_service")
	elif act == "finish_service":
		if is_service_active:
			finish_furniture_service()
		else:
			begin_furniture_service_staging("desk_service")

func begin_furniture_service_staging(interaction_type: String = "desk_service") -> void:
	var furniture_dict: Dictionary = {}
	if is_instance_valid(world) and world.sandbar_pavilion:
		furniture_dict = world.sandbar_pavilion.furniture_instances
	var resolution := runtime.resolve_bound_service_motion(interaction_type, furniture_dict, anchor.global_transform)
	if not resolution.get("found", false):
		resolution = runtime.resolve_service_motion(interaction_type, [], anchor.global_transform)
	if not resolution.get("found", false):
		push_warning("[Duel] Service staging aborted for %s: %s" % [interaction_type, resolution.get("reason", "unknown")])
		finish_furniture_service()
		return

	is_service_active = true
	panel.hide()
	hud.hide()
	prompt.hide()

	var char_node: Node = world.character if is_instance_valid(world) else null
	if is_instance_valid(char_node):
		if "collision_layer" in char_node:
			saved_player_collision_layer = char_node.collision_layer
			char_node.collision_layer = 0
		if "collision_mask" in char_node:
			saved_player_collision_mask = char_node.collision_mask
			char_node.collision_mask = 0
		if char_node.has_method("set_control_enabled"):
			char_node.set_control_enabled(false)
		char_node.visible = false

	if is_instance_valid(actor):
		actor.visible = false

	var furn_tf: Transform3D = resolution["target_transform"]
	var approach_tf: Transform3D = resolution.get("approach_transform", furn_tf)
	last_service_approach_pos = approach_tf.origin
	last_service_approach_basis = approach_tf.basis

	combat_actors_root.global_transform = furn_tf

	if is_instance_valid(npc_paired_actor):
		npc_paired_actor.queue_free()
	if is_instance_valid(master_paired_actor):
		master_paired_actor.queue_free()

	npc_paired_actor = ACTOR.instantiate()
	npc_paired_actor.name = "KeqingPairedActor"
	npc_paired_actor.model_resource = runtime.encounter_bundle["avatar"]["model_resource"]
	npc_paired_actor.motion_resource = resolution["role_a_motion"]
	npc_paired_actor.auto_play = true
	npc_paired_actor.environment_mask = 33
	npc_paired_actor.initialized.connect(func():
		if is_instance_valid(npc_paired_actor) and npc_paired_actor.character:
			MTOON.apply(npc_paired_actor.character, runtime.encounter_bundle["avatar"]["material_id"])
	)
	combat_actors_root.add_child(npc_paired_actor)

	master_paired_actor = ACTOR.instantiate()
	master_paired_actor.name = "MasterPairedActor"
	master_paired_actor.model_resource = _get_master_model()
	master_paired_actor.motion_resource = resolution["role_b_motion"]
	master_paired_actor.auto_play = true
	master_paired_actor.environment_mask = 33
	master_paired_actor.initialized.connect(func():
		if is_instance_valid(master_paired_actor) and master_paired_actor.character:
			MTOON.apply(master_paired_actor.character, _get_master_mtoon())
	)
	combat_actors_root.add_child(master_paired_actor)

	combat_actors_root.visible = true

	_setup_service_camera(furn_tf)

	if is_instance_valid(service_hud):
		service_hud.text = "【长案侍奉 · 办公长案俯身侍奉】\n右键环绕视角 | 滚轮缩放视距 | 中键复位视角 | 按【E】完成侍奉"
		service_hud.visible = true

	world.set_encounter_ui_active(true)
	world._sync_actor_controls()

func _setup_service_camera(furn_tf: Transform3D) -> void:
	cam_focal_point = furn_tf.origin + Vector3(0.0, 0.45, 0.0)
	var cam_forward: Vector3 = furn_tf.basis.z.normalized()
	var cam_side: Vector3 = furn_tf.basis.x.normalized()
	var target_cam_pos: Vector3 = cam_focal_point + (cam_forward * 0.85 + cam_side * 0.85 + Vector3.UP * 0.55).normalized() * 2.2
	var cam_offset: Vector3 = target_cam_pos - cam_focal_point
	default_cam_distance = cam_offset.length()
	cam_distance = default_cam_distance
	cam_yaw = atan2(cam_offset.x, cam_offset.z)
	cam_pitch = asin(clampf(cam_offset.y / default_cam_distance, -0.99, 0.99))
	_update_service_camera()
	service_camera.current = true

func _update_service_camera() -> void:
	if not is_instance_valid(service_camera):
		return
	var offset := Vector3(
		sin(cam_yaw) * cos(cam_pitch),
		sin(cam_pitch),
		cos(cam_yaw) * cos(cam_pitch)
	) * cam_distance
	service_camera.global_position = cam_focal_point + offset
	service_camera.look_at(cam_focal_point, Vector3.UP)

func finish_furniture_service() -> void:
	if not is_service_active:
		return
	is_service_active = false
	is_dragging_cam = false
	if is_instance_valid(service_hud):
		service_hud.visible = false
	if is_instance_valid(service_camera):
		service_camera.current = false
	if is_instance_valid(combat_actors_root):
		combat_actors_root.visible = false
	if is_instance_valid(npc_paired_actor):
		npc_paired_actor.queue_free()
		npc_paired_actor = null
	if is_instance_valid(master_paired_actor):
		master_paired_actor.queue_free()
		master_paired_actor = null
	if is_instance_valid(actor):
		actor.visible = true
	var char_node: Node = world.character if is_instance_valid(world) else null
	if is_instance_valid(char_node):
		char_node.visible = true
		if "collision_layer" in char_node:
			char_node.collision_layer = saved_player_collision_layer
		if "collision_mask" in char_node:
			char_node.collision_mask = saved_player_collision_mask
		if last_service_approach_pos != Vector3.ZERO:
			char_node.global_position = last_service_approach_pos
		if char_node.has_method("set_control_enabled"):
			char_node.set_control_enabled(true)
	if last_service_approach_pos != Vector3.ZERO and is_instance_valid(actor):
		var local_side := last_service_approach_basis.x.normalized()
		actor.global_position = last_service_approach_pos + local_side * 0.7
		actor.global_rotation.y = last_service_approach_basis.get_euler().y
	if is_instance_valid(runtime):
		runtime.finish_service()
	if is_instance_valid(world):
		world.set_encounter_ui_active(false)
		world._sync_actor_controls()

func _get_active_master_id() -> String:
	if is_instance_valid(world):
		var char_node = world.character
		if char_node != null:
			if "active_character_id" in char_node and not String(char_node.active_character_id).is_empty():
				return String(char_node.active_character_id)
			if char_node.has_meta("active_character_id") and not String(char_node.get_meta("active_character_id")).is_empty():
				return String(char_node.get_meta("active_character_id"))
		var switch_wheel = world.find_child("CharacterSwitchWheel", true, false)
		if switch_wheel and "active_character_id" in switch_wheel and not String(switch_wheel.active_character_id).is_empty():
			return String(switch_wheel.active_character_id)
	return "lumine"

func _get_master_model() -> String:
	var master_id := _get_active_master_id()
	var cfg: Dictionary = MASTER_CONFIGS.get(master_id, MASTER_CONFIGS["lumine"])
	return cfg.get("model", MASTER_CONFIGS["lumine"]["model"])

func _get_master_mtoon() -> String:
	var master_id := _get_active_master_id()
	var cfg: Dictionary = MASTER_CONFIGS.get(master_id, MASTER_CONFIGS["lumine"])
	return cfg.get("mtoon", "lumine")
