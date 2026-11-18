extends Node

const Runtime := preload("res://scripts/world/npc_encounter_runtime.gd")
const WorldControl := preload("res://scripts/world/world_control_context.gd")
const NPCSites := preload("res://scripts/world/npc_preview_sites.gd")
const ACTOR := preload("res://scenes/characters/shared_humanoid_actor.tscn")
const MTOON := preload("res://scripts/characters/mtoon_materials.gd")
const CorpseControllerClass := preload("res://scripts/characters/corpse_ragdoll_controller.gd")
const CorpseInteractionHandlerClass := preload("res://scripts/world/corpse_interaction_handler.gd")

const NPC_SOLID_LAYER := 64
const COMBAT_MOTION_KEQING := "res://assets/characters/mmd_selected/animations/mmd_fcc0340f8227_a.tres"
const COMBAT_MOTION_MASTER := "res://assets/characters/mmd_selected/animations/mmd_fcc0340f8227_b.tres"

const MASTER_CONFIGS: Dictionary = {
	"lumine": {
		"model": "res://assets/characters/roster/lumine/lumine.vrm",
		"mtoon": "lumine"
	},
	"aether": {
		"model": "res://assets/characters/roster/aether/aether.vrm",
		"mtoon": "aether"
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
var npc_body: StaticBody3D
var panel: DialoguePanel
var hud: TurnCombatHUD
var prompt: Label
var service_hud: Label

var combat_actors_root: Node3D
var npc_paired_actor: Node3D
var master_paired_actor: Node3D
var service_camera: Camera3D

var is_combat_active: bool = false
var is_service_active: bool = false
var is_ragdoll_active: bool = false
var corpse_actor: Node3D
var corpse_handler: CorpseInteractionHandlerClass
var saved_player_collision_layer: int = 2
var saved_player_collision_mask: int = 96
var last_service_approach_pos: Vector3 = Vector3.ZERO
var last_service_approach_basis: Basis = Basis.IDENTITY

var default_cam_distance: float = 2.2
var cam_distance: float = 2.2
var cam_yaw: float = 0.0
var cam_pitch: float = 0.2
var cam_focal_point: Vector3 = Vector3.ZERO
var is_dragging_cam: bool = false
var game_progress: RefCounted = null

func _set_actor_visible(is_vis: bool) -> void:
	if is_instance_valid(actor):
		actor.visible = is_vis
		if actor.has_method("set_playback_active"):
			actor.set_playback_active(is_vis)

func _unlock_companion() -> void:
	if game_progress and game_progress.has_method("unlock_companion") and runtime != null:
		game_progress.unlock_companion(runtime.character_id)

func _unlock_keqing() -> void:
	_unlock_companion()

func initialize(host: Node3D, p_world: Node3D, p_runtime: Runtime) -> void:
	world = p_world
	runtime = p_runtime

	if world != null:
		if "game_progress" in world and world.get("game_progress") != null:
			game_progress = world.get("game_progress")
		elif "progress" in world and world.get("progress") != null:
			game_progress = world.get("progress")
	if game_progress == null:
		game_progress = load("res://scripts/progress/game_progress.gd").new()
	if runtime != null and "game_progress" in runtime:
		runtime.game_progress = game_progress
	anchor = runtime.create_anchor(host, "DuelNPC")
	actor = runtime.create_idle_actor(anchor, "IdleActor", 33)
	add_to_group(WorldControl.GROUP_INPUT_BLOCKERS)

	npc_body = StaticBody3D.new()
	npc_body.name = "NPCBody"
	npc_body.collision_layer = NPC_SOLID_LAYER
	npc_body.collision_mask = 0
	anchor.add_child(npc_body)
	var col_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.24
	capsule.height = 1.45
	col_shape.position.y = 0.725
	col_shape.shape = capsule
	npc_body.add_child(col_shape)

	combat_actors_root = Node3D.new()
	combat_actors_root.name = "CombatDualActors"
	combat_actors_root.visible = false
	host.add_child(combat_actors_root)

	add_to_group(WorldControl.GROUP_INPUT_BLOCKERS)

	service_camera = Camera3D.new()
	service_camera.name = "ServiceCamera"
	service_camera.current = false
	host.add_child(service_camera)

	corpse_actor = CorpseControllerClass.new()
	corpse_actor.name = "%sCorpse" % runtime.character_id.capitalize()
	corpse_actor.character_scene = null
	corpse_actor.auto_start_ragdoll = false
	corpse_actor.visible = false
	host.add_child(corpse_actor)

	corpse_handler = CorpseInteractionHandlerClass.new()
	corpse_handler.player_left_corpse.connect(func(_dist: float):
		_respawn_npc_after_kill()
	)

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
	prompt.anchor_left = 0.4
	prompt.anchor_right = 0.6
	prompt.anchor_top = 0.72
	prompt.anchor_bottom = 0.76
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 18)
	prompt.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))
	prompt.add_theme_color_override("font_outline_color", Color(0.06, 0.08, 0.16, 0.85))
	prompt.add_theme_constant_override("outline_size", 4)
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
	return is_service_active or is_combat_active or (runtime != null and runtime.current_state in [
		Runtime.EncounterState.INTRO_DIALOGUE,
		Runtime.EncounterState.COMBAT,
		Runtime.EncounterState.RESULT_DIALOGUE,
		Runtime.EncounterState.SETTLEMENT,
	])

func is_service_staging_active() -> bool:
	return is_service_active or is_combat_active

func get_active_custom_camera() -> Camera3D:
	if (is_service_active or is_combat_active) and is_instance_valid(service_camera):
		return service_camera
	return null

func _can_interact() -> bool:
	if is_ragdoll_active or is_service_active or is_combat_active:
		return false
	if not (is_instance_valid(world) and world.test_ready and world.character_mode and not world.free_mode \
		and not world.has_llm_panel_open() and not world.encounter_ui_active and world.is_world_input_allowed()):
		return false
	var char_node: Node = world.character
	if not is_instance_valid(char_node) or not is_instance_valid(actor) or not is_instance_valid(actor.character):
		return false
	var target_pos: Vector3 = anchor.global_position if is_instance_valid(anchor) else actor.global_position
	var player_pos: Vector3 = char_node.global_position
	var horiz_dist: float = Vector2(player_pos.x - target_pos.x, player_pos.z - target_pos.z).length()
	var vert_dist: float = absf(player_pos.y - target_pos.y)
	if horiz_dist > 2.8 or vert_dist > 1.5:
		return false

	var world_3d: World3D = world.get_world_3d() if world.has_method("get_world_3d") else null
	if world_3d and world_3d.direct_space_state:
		var ray_query := PhysicsRayQueryParameters3D.create(
			player_pos + Vector3(0.0, 1.0, 0.0),
			target_pos + Vector3(0.0, 1.0, 0.0)
		)
		var exclude: Array[RID] = []
		if "get_rid" in char_node:
			exclude.append(char_node.get_rid())
		if is_instance_valid(npc_body):
			exclude.append(npc_body.get_rid())
		ray_query.exclude = exclude
		ray_query.collision_mask = 1
		var hit := world_3d.direct_space_state.intersect_ray(ray_query)
		if not hit.is_empty():
			return false
	return true

func _process(delta: float) -> void:
	if is_ragdoll_active:
		if corpse_handler:
			corpse_handler.tick(delta)
		return
	prompt.visible = _can_interact()

func _unhandled_input(event: InputEvent) -> void:
	if is_ragdoll_active and corpse_handler:
		if corpse_handler.handle_input(event):
			get_viewport().set_input_as_handled()
			return

	if is_service_active or is_combat_active:
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
		elif is_service_active and event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_ESCAPE] or event.physical_keycode in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
				get_viewport().set_input_as_handled()
				finish_furniture_service()
				return
		return

	if not is_world_input_locked() and _can_interact():
		if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_E or event.keycode == KEY_E)):
			get_viewport().set_input_as_handled()
			runtime.start_intro_dialogue()

func _on_phase_changed(phase: int) -> void:
	var combat := runtime.combat_manager
	hud.update_round(combat.round_count)
	hud.set_chat_open(phase == TurnCombatManager.Phase.MID_BATTLE_DIALOGUE)
	hud.set_input_enabled(phase == TurnCombatManager.Phase.PLAYER_INPUT)

func _on_encounter_state_changed(_old: int, state: int) -> void:
	hud.visible = (state == Runtime.EncounterState.COMBAT)
	if state == Runtime.EncounterState.COMBAT:
		_set_combat_visuals(true)
	elif not is_service_active:
		if is_combat_active and state != Runtime.EncounterState.RESULT_DIALOGUE:
			_set_combat_visuals(false)
	var busy := is_world_input_locked()
	if not busy:
		panel.hide()
	world.set_encounter_ui_active(busy)
	world._sync_actor_controls()
	if busy and is_instance_valid(world.character) and world.character.has_method("set_control_enabled"):
		world.character.set_control_enabled(false)

func _setup_combat_actors() -> bool:
	var npc_model := str(runtime.encounter_bundle.get("avatar", {}).get("model_resource", ""))
	var master_model := _get_master_model()
	var combat_binding: Dictionary = runtime.encounter_bundle.get("motions", {}).get("bindings", {}).get("ground_service", {})
	var role_a_motion := str(combat_binding.get("role_a_motion", COMBAT_MOTION_KEQING))
	var role_b_motion := str(combat_binding.get("role_b_motion", COMBAT_MOTION_MASTER))

	if npc_model.is_empty() or not ResourceLoader.exists(npc_model):
		return false
	if master_model.is_empty() or not ResourceLoader.exists(master_model):
		return false
	if role_a_motion.is_empty() or not ResourceLoader.exists(role_a_motion):
		return false
	if role_b_motion.is_empty() or not ResourceLoader.exists(role_b_motion):
		return false

	var ground_tf: Transform3D = anchor.global_transform if is_instance_valid(anchor) else Transform3D.IDENTITY
	combat_actors_root.global_transform = ground_tf

	if is_instance_valid(npc_paired_actor):
		npc_paired_actor.queue_free()
	if is_instance_valid(master_paired_actor):
		master_paired_actor.queue_free()

	npc_paired_actor = ACTOR.instantiate()
	npc_paired_actor.name = "%sCombatActor" % runtime.character_id.capitalize()
	npc_paired_actor.model_resource = npc_model
	npc_paired_actor.motion_resource = role_a_motion
	npc_paired_actor.auto_play = true
	npc_paired_actor.environment_mask = 33
	npc_paired_actor.initialized.connect(func():
		if is_instance_valid(npc_paired_actor) and npc_paired_actor.character:
			MTOON.apply(npc_paired_actor.character, runtime.encounter_bundle["avatar"]["material_id"])
	)
	combat_actors_root.add_child(npc_paired_actor)
	npc_paired_actor.transform = Transform3D.IDENTITY

	master_paired_actor = ACTOR.instantiate()
	master_paired_actor.name = "MasterCombatActor"
	master_paired_actor.model_resource = master_model
	master_paired_actor.motion_resource = role_b_motion
	master_paired_actor.auto_play = true
	master_paired_actor.environment_mask = 33
	master_paired_actor.initialized.connect(func():
		if is_instance_valid(master_paired_actor) and master_paired_actor.character:
			MTOON.apply(master_paired_actor.character, _get_master_mtoon())
	)
	combat_actors_root.add_child(master_paired_actor)
	master_paired_actor.transform = Transform3D.IDENTITY
	return true

func _set_combat_visuals(active: bool) -> void:
	if is_combat_active == active:
		return
	is_combat_active = active
	var char_node: Node = world.character if is_instance_valid(world) else null

	if active:
		is_dragging_cam = false
		if not _setup_combat_actors():
			is_combat_active = false
			return

		_set_actor_visible(false)
		if is_instance_valid(npc_body):
			npc_body.collision_layer = 0

		if is_instance_valid(char_node):
			char_node.visible = false

		combat_actors_root.visible = true
		_setup_service_camera(anchor.global_transform if is_instance_valid(anchor) else combat_actors_root.global_transform)
		service_camera.current = true
	else:
		is_dragging_cam = false
		if is_instance_valid(service_camera):
			service_camera.current = false
		if is_instance_valid(combat_actors_root) and not is_service_active:
			combat_actors_root.visible = false
			if is_instance_valid(npc_paired_actor):
				npc_paired_actor.queue_free()
				npc_paired_actor = null
			if is_instance_valid(master_paired_actor):
				master_paired_actor.queue_free()
				master_paired_actor = null

		if not is_service_active and not is_ragdoll_active:
			_set_actor_visible(true)
			if is_instance_valid(npc_body):
				npc_body.collision_layer = NPC_SOLID_LAYER
			if is_instance_valid(char_node):
				char_node.visible = true
				if "camera" in char_node and char_node.camera:
					char_node.camera.current = true

func _handle_player_defeat() -> void:
	if is_instance_valid(world):
		var spawn: Dictionary = runtime.encounter_bundle["spawn"]
		var point := NPCSites.resolve_battle_respawn(world, spawn["region"], spawn["character_id"])
		if not point.is_empty() and is_instance_valid(world.character):
			world.character.set_spawn(point["position"], point["heading"])
	runtime._set_state(Runtime.EncounterState.AVAILABLE)

func _on_dialogue_ended(payload: Dictionary) -> void:
	if not runtime.dialogue_manager.session_active:
		panel.hide()
	var act: String = payload.get("action", "")
	if payload.get("source") == Runtime.DialogueManagerClass.DialogueSource.POST_BATTLE_RESULT:
		# The runtime has already handled the state transition. Consume this result
		# once; cancelled and failed actions also carry 'close' for cleanup.
		var winner := runtime.last_battle_winner
		runtime.last_battle_winner = ""
		if payload.get("cancelled", false) or payload.get("failed", false):
			return
		if winner == "player" and (act.begins_with("spare") or act.ends_with("_service") or act in ["kill", "close"]):
			_unlock_companion()
		elif not winner.is_empty() and winner != "player" and act == "close":
			_handle_player_defeat()
			return

	if act in ["spare_desk", "desk_service"]:
		begin_furniture_service_staging("desk_service")
	elif act in ["spare_seat", "seat_service"]:
		begin_furniture_service_staging("seat_service")
	elif act == "spare":
		var chosen_service := "desk_service"
		var bindings: Dictionary = runtime.encounter_bundle.get("motions", {}).get("bindings", {})
		for k in bindings:
			if k != "ground_service":
				chosen_service = k
				break
		begin_furniture_service_staging(chosen_service)
	elif act == "kill":
		_set_combat_visuals(false)
		_execute_settlement_kill()
	elif act == "finish_service":
		if is_service_active:
			finish_furniture_service()
		else:
			var default_serv := "desk_service"
			var bindings: Dictionary = runtime.encounter_bundle.get("motions", {}).get("bindings", {})
			for k in bindings:
				if k != "ground_service":
					default_serv = k
					break
			begin_furniture_service_staging(default_serv)
	elif act == "finish":
		_set_combat_visuals(false)
		if is_instance_valid(runtime):
			runtime.finish_dialogue()
		if is_instance_valid(world):
			world.set_encounter_ui_active(false)
			world._sync_actor_controls()

func begin_furniture_service_staging(interaction_type: String = "desk_service") -> void:
	var char_node: Node = world.character if is_instance_valid(world) else null
	if is_instance_valid(char_node):
		if "collision_layer" in char_node and char_node.collision_layer != 0:
			saved_player_collision_layer = char_node.collision_layer
		if "collision_mask" in char_node and char_node.collision_mask != 0:
			saved_player_collision_mask = char_node.collision_mask

	var furniture_dict: Dictionary = {}
	if is_instance_valid(world) and world.sandbar_pavilion:
		furniture_dict = world.sandbar_pavilion.furniture_instances
	var ground_tf: Transform3D = anchor.global_transform if is_instance_valid(anchor) else Transform3D.IDENTITY
	var resolution := runtime.resolve_bound_service_motion(interaction_type, furniture_dict, ground_tf)
	if not resolution.get("found", false):
		resolution = runtime.resolve_service_motion(interaction_type, [], ground_tf)
	if not resolution.get("found", false):
		var reason := str(resolution.get("reason", "unknown"))
		push_warning("[Duel] Service staging aborted for %s: %s" % [interaction_type, reason])
		abort_service_staging(reason)
		return

	var npc_model := str(runtime.encounter_bundle.get("avatar", {}).get("model_resource", ""))
	var master_model := _get_master_model()
	var role_a_motion := str(resolution.get("role_a_motion", ""))
	var role_b_motion := str(resolution.get("role_b_motion", ""))

	if npc_model.is_empty() or not ResourceLoader.exists(npc_model):
		push_warning("[Duel] Service staging aborted: NPC model resource missing: %s" % npc_model)
		abort_service_staging("missing_npc_model")
		return

	if master_model.is_empty() or not ResourceLoader.exists(master_model):
		push_warning("[Duel] Service staging aborted: Master model resource missing: %s" % master_model)
		abort_service_staging("missing_master_model")
		return

	if role_a_motion.is_empty() or not ResourceLoader.exists(role_a_motion):
		push_warning("[Duel] Service staging aborted: role_a motion resource missing: %s" % role_a_motion)
		abort_service_staging("missing_role_a_motion")
		return

	if role_b_motion.is_empty() or not ResourceLoader.exists(role_b_motion):
		push_warning("[Duel] Service staging aborted: role_b motion resource missing: %s" % role_b_motion)
		abort_service_staging("missing_role_b_motion")
		return

	var furn_tf: Transform3D = resolution.get("target_transform", ground_tf)
	var approach_tf: Transform3D = resolution.get("approach_transform", furn_tf)
	last_service_approach_pos = approach_tf.origin
	last_service_approach_basis = approach_tf.basis

	var role_a_target: Transform3D = resolution.get("role_a_target", furn_tf)
	var role_b_target: Transform3D = resolution.get("role_b_target", furn_tf)

	is_combat_active = false
	is_service_active = true
	panel.hide()
	hud.hide()
	prompt.hide()

	if is_instance_valid(char_node):
		if "collision_layer" in char_node:
			char_node.collision_layer = 0
		if "collision_mask" in char_node:
			char_node.collision_mask = 0

	_set_actor_visible(false)
	if is_instance_valid(npc_body):
		npc_body.collision_layer = 0

	combat_actors_root.global_transform = furn_tf

	if is_instance_valid(npc_paired_actor):
		npc_paired_actor.queue_free()
	if is_instance_valid(master_paired_actor):
		master_paired_actor.queue_free()

	npc_paired_actor = ACTOR.instantiate()
	npc_paired_actor.name = "%sPairedActor" % runtime.character_id.capitalize()
	npc_paired_actor.model_resource = npc_model
	npc_paired_actor.motion_resource = role_a_motion
	npc_paired_actor.forearm_contact_lift_m = float(resolution["binding"].get("role_a_forearm_contact_lift_m", 0.0))
	npc_paired_actor.auto_play = true
	npc_paired_actor.environment_mask = 33
	npc_paired_actor.initialized.connect(func():
		if is_instance_valid(npc_paired_actor) and npc_paired_actor.character:
			MTOON.apply(npc_paired_actor.character, runtime.encounter_bundle["avatar"]["material_id"])
	)
	combat_actors_root.add_child(npc_paired_actor)
	npc_paired_actor.transform = combat_actors_root.global_transform.affine_inverse() * role_a_target
	npc_paired_actor.global_transform = role_a_target

	master_paired_actor = ACTOR.instantiate()
	master_paired_actor.name = "MasterPairedActor"
	master_paired_actor.model_resource = master_model
	master_paired_actor.motion_resource = role_b_motion
	master_paired_actor.auto_play = true
	master_paired_actor.environment_mask = 33
	master_paired_actor.initialized.connect(func():
		if is_instance_valid(master_paired_actor) and master_paired_actor.character:
			MTOON.apply(master_paired_actor.character, _get_master_mtoon())
	)
	combat_actors_root.add_child(master_paired_actor)
	master_paired_actor.transform = combat_actors_root.global_transform.affine_inverse() * role_b_target
	master_paired_actor.global_transform = role_b_target

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

func abort_service_staging(reason: String = "") -> void:
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
	_set_actor_visible(true)
	if is_instance_valid(npc_body):
		npc_body.collision_layer = NPC_SOLID_LAYER
	var char_node: Node = world.character if is_instance_valid(world) else null
	if is_instance_valid(char_node):
		char_node.visible = true
		if "collision_layer" in char_node and saved_player_collision_layer != 0:
			char_node.collision_layer = saved_player_collision_layer
		if "collision_mask" in char_node and saved_player_collision_mask != 0:
			char_node.collision_mask = saved_player_collision_mask
		if char_node.has_method("set_control_enabled"):
			char_node.set_control_enabled(true)
		if "camera" in char_node and char_node.camera:
			char_node.camera.current = true
	last_service_approach_pos = Vector3.ZERO
	last_service_approach_basis = Basis.IDENTITY
	if is_instance_valid(runtime):
		runtime.abort_service(reason)
	if is_instance_valid(world):
		world.set_encounter_ui_active(false)
		world._sync_actor_controls()

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
	_set_actor_visible(true)
	var char_node: Node = world.character if is_instance_valid(world) else null
	if is_instance_valid(char_node):
		char_node.visible = true
		if "collision_layer" in char_node and saved_player_collision_layer != 0:
			char_node.collision_layer = saved_player_collision_layer
		if "collision_mask" in char_node and saved_player_collision_mask != 0:
			char_node.collision_mask = saved_player_collision_mask
		if last_service_approach_pos != Vector3.ZERO:
			char_node.global_position = last_service_approach_pos
		if char_node.has_method("set_control_enabled"):
			char_node.set_control_enabled(true)
		if "camera" in char_node and char_node.camera:
			char_node.camera.current = true
	if last_service_approach_pos != Vector3.ZERO and is_instance_valid(actor):
		var local_side := last_service_approach_basis.x.normalized()
		var new_pos := last_service_approach_pos + local_side * 0.7
		var new_yaw := last_service_approach_basis.get_euler().y
		if is_instance_valid(anchor):
			anchor.global_position = new_pos
			anchor.global_rotation.y = new_yaw
		actor.global_position = new_pos
		actor.global_rotation.y = new_yaw
	if is_instance_valid(npc_body):
		npc_body.collision_layer = NPC_SOLID_LAYER
	last_service_approach_pos = Vector3.ZERO
	last_service_approach_basis = Basis.IDENTITY
	if is_instance_valid(runtime):
		runtime.finish_service()
	if is_instance_valid(world):
		world.set_encounter_ui_active(false)
		world._sync_actor_controls()

func _get_active_master_id() -> String:
	if is_instance_valid(world):
		var char_node = world.character
		if char_node != null:
			if "character_id" in char_node and not String(char_node.character_id).is_empty():
				return String(char_node.character_id)
			if "active_character_id" in char_node and not String(char_node.active_character_id).is_empty():
				return String(char_node.active_character_id)
			if char_node.has_meta("character_id") and not String(char_node.get_meta("character_id")).is_empty():
				return String(char_node.get_meta("character_id"))
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

func _execute_settlement_kill() -> void:
	if is_ragdoll_active:
		return
	is_ragdoll_active = true
	panel.hide()
	hud.hide()
	prompt.hide()

	_set_actor_visible(false)
	if is_instance_valid(npc_body):
		npc_body.collision_layer = 0

	var spawn_pos: Vector3 = anchor.global_position if is_instance_valid(anchor) else Vector3.ZERO
	if corpse_actor:
		corpse_actor.global_position = spawn_pos
		corpse_actor.visible = true
		var ok: bool = corpse_actor.load_character(
			runtime.encounter_bundle["avatar"]["model_resource"],
			runtime.character_id,
			runtime.character_name
		)
		if ok and corpse_actor.character_instance:
			MTOON.apply(corpse_actor.character_instance, runtime.encounter_bundle["avatar"].get("material_id", runtime.character_id))
		corpse_actor.start_ragdoll()
		if corpse_handler:
			corpse_handler.activate(world, corpse_actor, prompt, runtime.character_name)

	if is_instance_valid(world):
		world.set_encounter_ui_active(false)
		world._sync_actor_controls()
		var char_node: Node = world.character
		if is_instance_valid(char_node) and char_node.has_method("set_control_enabled"):
			char_node.set_control_enabled(true)

	print("【大世界结算】主人选择【杀掉】%s！%s化为真实物理尸体倒在地面上，离开30米后将刷新重置！" % [runtime.character_name, runtime.character_name])

func _respawn_npc_after_kill() -> void:
	is_ragdoll_active = false
	if corpse_handler:
		corpse_handler.deactivate()
	if corpse_actor:
		corpse_actor.stop_ragdoll()
		corpse_actor.visible = false
		if corpse_actor.character_instance and is_instance_valid(corpse_actor.character_instance):
			corpse_actor.character_instance.queue_free()
			corpse_actor.character_instance = null
			corpse_actor.skeleton = null
			corpse_actor.simulator = null
			corpse_actor.physical_bones.clear()

	if is_instance_valid(anchor):
		anchor.global_position = runtime.spawn_position
		anchor.global_rotation.y = deg_to_rad(runtime.spawn_heading)

	_set_actor_visible(true)
	if is_instance_valid(anchor):
		actor.global_position = anchor.global_position
		actor.global_rotation.y = anchor.global_rotation.y

	if is_instance_valid(npc_body):
		npc_body.collision_layer = NPC_SOLID_LAYER

	if is_instance_valid(runtime):
		runtime._set_state(Runtime.EncounterState.AVAILABLE)

	print("【大世界刷新】主人离开超出30米范围，%s已重新刷新就位！" % runtime.character_name)

func _respawn_keqing_after_kill() -> void:
	_respawn_npc_after_kill()
