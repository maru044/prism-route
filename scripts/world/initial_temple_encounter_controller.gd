class_name InitialTempleEncounterController
extends Node
## Encounter controller for Initial Temple Sparkle battle and narrative flow.
## Decouples world geometry representation from the narrative/combat lifecycle.

signal encounter_state_changed(old_state: int, new_state: int)
signal settlement_completed(outcome: String)

enum EncounterState {
	AVAILABLE,
	INTRO_DIALOGUE,
	STAGING_TRANSITION,
	COMBAT,
	RESULT_DIALOGUE,
	SETTLEMENT,
	FURNITURE_SERVICE_STAGING,
	FURNITURE_SERVICE_ACTIVE,
	RESPAWN,
	COMPLETED
}

const NPC := preload("res://scenes/characters/shared_humanoid_actor.tscn")
const MTOON := preload("res://scripts/characters/mtoon_materials.gd")
const WorldControlContextClass := preload("res://scripts/world/world_control_context.gd")
const DialogueManagerClass := preload("res://scripts/narrative/dialogue_manager.gd")

const VALID_TRANSITIONS: Dictionary = {
	EncounterState.AVAILABLE: [
		EncounterState.INTRO_DIALOGUE,
		EncounterState.STAGING_TRANSITION,
		EncounterState.FURNITURE_SERVICE_STAGING
	],
	EncounterState.INTRO_DIALOGUE: [
		EncounterState.AVAILABLE,
		EncounterState.STAGING_TRANSITION,
		EncounterState.FURNITURE_SERVICE_STAGING
	],
	EncounterState.STAGING_TRANSITION: [
		EncounterState.COMBAT,
		EncounterState.AVAILABLE
	],
	EncounterState.COMBAT: [
		EncounterState.RESULT_DIALOGUE,
		EncounterState.RESPAWN,
		EncounterState.AVAILABLE
	],
	EncounterState.RESULT_DIALOGUE: [
		EncounterState.SETTLEMENT,
		EncounterState.FURNITURE_SERVICE_STAGING,
		EncounterState.AVAILABLE
	],
	EncounterState.SETTLEMENT: [
		EncounterState.COMPLETED,
		EncounterState.AVAILABLE
	],
	EncounterState.FURNITURE_SERVICE_STAGING: [
		EncounterState.FURNITURE_SERVICE_ACTIVE,
		EncounterState.AVAILABLE
	],
	EncounterState.FURNITURE_SERVICE_ACTIVE: [
		EncounterState.COMPLETED,
		EncounterState.AVAILABLE
	],
	EncounterState.RESPAWN: [
		EncounterState.AVAILABLE
	],
	EncounterState.COMPLETED: [
		EncounterState.INTRO_DIALOGUE,
		EncounterState.STAGING_TRANSITION,
		EncounterState.FURNITURE_SERVICE_STAGING,
		EncounterState.AVAILABLE
	]
}
const TurnCombatManagerClass := preload("res://scripts/combat/turn_combat_manager.gd")
const DialoguePanelClass := preload("res://scenes/narrative/dialogue_panel.gd")
const TurnCombatHUDClass := preload("res://scenes/combat/turn_combat_hud.gd")
const EncounterPalette := preload("res://scenes/combat/encounter_ui_palette.gd")

const PleasureComponentClass := preload("res://scripts/combat/pleasure_component.gd")
const SparkleTutorialDialogueClass := preload("res://scripts/narrative/sparkle_tutorial_dialogue.gd")
const CorpseControllerClass := preload("res://scripts/characters/corpse_ragdoll_controller.gd")

const RESPAWN_POINT := Vector3(-1012.685, 61.1, 1262.287)
const RESPAWN_HEADING := 0.38

const MOTION_SPARKLE_BLOWJOB := "res://assets/characters/mmd_selected/animations/mmd_781d8c87fd79_a.tres"
const MOTION_MASTER_RECEIVING := "res://assets/characters/mmd_selected/animations/mmd_781d8c87fd79_b.tres"

const MOTION_VIRGIN_SPARKLE := "res://assets/characters/mmd_selected/animations/mmd_0a3f6ba5f5de_a.tres"
const MOTION_VIRGIN_MASTER := "res://assets/characters/mmd_selected/animations/mmd_0a3f6ba5f5de_b.tres"

const MOTION_HONBAN_SPARKLE := "res://assets/characters/mmd_selected/animations/mmd_87e004f6db53_a.tres"
const MOTION_HONBAN_MASTER := "res://assets/characters/mmd_selected/animations/mmd_87e004f6db53_b.tres"

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

@export var ui_palette: EncounterPalette = preload("res://scenes/combat/sparkle_ui_palette.tres")

var current_state: EncounterState = EncounterState.AVAILABLE
var temple_node: Node3D
var world: Node3D
var npc_anchor: Marker3D
var npc_avatar: Node3D
var npc_body: StaticBody3D

var dialogue_manager: DialogueManager
var combat_manager: TurnCombatManager
var dialogue_panel: DialoguePanel
var combat_hud: TurnCombatHUD
var service_hud: Label
var player_pleasure: PleasureComponent
var npc_pleasure: PleasureComponent

var combat_actors_root: Node3D
var sparkle_combat_actor: Node3D
var master_combat_actor: Node3D
var combat_camera: Camera3D
var corpse_actor: Node3D

var default_combat_cam_yaw: float = 0.0
var default_combat_cam_pitch: float = 0.0
var default_combat_cam_distance: float = 1.75
var default_combat_focal_point: Vector3 = Vector3.ZERO

var combat_cam_yaw: float = 0.0
var combat_cam_pitch: float = 0.0
var combat_cam_distance: float = 1.75
var combat_focal_point: Vector3 = Vector3.ZERO
var combat_cam_focal_offset: Vector3 = Vector3.ZERO

var is_dragging_combat_cam: bool = false
var is_panning_combat_cam: bool = false

var interact_prompt: Label
var last_service_approach_pos: Vector3 = RESPAWN_POINT
var defeat_count: int = 0
var companion_unlocked: bool = false
var is_ragdoll_active: bool = false

var settlement_outcome: String = "none"
var last_battle_result: String = "none"
var tutorial_completed: bool = false
var current_op_token: int = 0
var saved_world_context: Dictionary = {}

var saved_player_collision_layer: int = 2
var saved_player_collision_mask: int = 1
var saved_npc_collision_layer: int = 64
var saved_npc_collision_mask: int = 0

var last_service_approach_basis: Basis = Basis.IDENTITY
var saved_npc_service_transform: Transform3D = Transform3D.IDENTITY
var saved_player_service_transform: Transform3D = Transform3D.IDENTITY
var allow_test_fixture_fallback: bool = true
var game_progress: RefCounted = null

func initialize(
	p_temple: Node3D,
	p_world: Node3D,
	p_anchor: Marker3D,
	p_avatar: Node3D,
	p_body: StaticBody3D
) -> void:
	temple_node = p_temple
	world = p_world
	npc_anchor = p_anchor
	npc_avatar = p_avatar
	npc_body = p_body
	
	if temple_node != null:
		temple_node.add_to_group(WorldControlContextClass.GROUP_INPUT_BLOCKERS)
	add_to_group(WorldControlContextClass.GROUP_INPUT_BLOCKERS)
	
	if world != null:
		if "game_progress" in world and world.get("game_progress") != null:
			game_progress = world.get("game_progress")
		elif "progress" in world and world.get("progress") != null:
			game_progress = world.get("progress")
	if game_progress == null:
		game_progress = load("res://scripts/progress/game_progress.gd").new()
		
	if temple_node != null:
		var f_instances = temple_node.get("furniture_instances")
		if f_instances == null and temple_node.has_meta("furniture_instances"):
			f_instances = temple_node.get_meta("furniture_instances")
		if f_instances is Dictionary and not f_instances.is_empty():
			allow_test_fixture_fallback = false
	
	_build_subsystems()

func _build_subsystems() -> void:
	# 1. Dual-character combat actors
	combat_actors_root = Node3D.new()
	combat_actors_root.name = "CombatDualActors"
	combat_actors_root.transform = npc_anchor.transform
	combat_actors_root.visible = false
	temple_node.add_child(combat_actors_root)
	
	sparkle_combat_actor = NPC.instantiate()
	sparkle_combat_actor.name = "SparkleBlowjob"
	sparkle_combat_actor.model_resource = "res://assets/characters/import_tests_local/huahuo/huahuo_fixed.vrm"
	sparkle_combat_actor.motion_resource = MOTION_SPARKLE_BLOWJOB
	sparkle_combat_actor.auto_play = true
	sparkle_combat_actor.environment_mask = 33
	sparkle_combat_actor.initialized.connect(func():
		MTOON.apply(sparkle_combat_actor.character, "huahuo")
	)
	combat_actors_root.add_child(sparkle_combat_actor)
	
	master_combat_actor = NPC.instantiate()
	master_combat_actor.name = "MasterReceiving"
	master_combat_actor.model_resource = "res://assets/characters/roster/lumine/lumine.vrm"
	master_combat_actor.motion_resource = MOTION_MASTER_RECEIVING
	master_combat_actor.auto_play = true
	master_combat_actor.environment_mask = 33
	master_combat_actor.initialized.connect(func():
		MTOON.apply(master_combat_actor.character, "lumine")
	)
	combat_actors_root.add_child(master_combat_actor)
	
	if sparkle_combat_actor.has_method("set_playback_active"):
		sparkle_combat_actor.set_playback_active(false)
	if master_combat_actor.has_method("set_playback_active"):
		master_combat_actor.set_playback_active(false)
	
	# Dedicated Combat Camera
	combat_camera = Camera3D.new()
	combat_camera.name = "CombatCamera"
	combat_camera.current = false
	temple_node.add_child(combat_camera)
	
	# Corpse Controller for Kill Settlement
	corpse_actor = CorpseControllerClass.new()
	corpse_actor.name = "SparkleCorpse"
	corpse_actor.character_scene = null
	corpse_actor.auto_start_ragdoll = false
	corpse_actor.visible = false
	temple_node.add_child(corpse_actor)
	
	# 2. Pleasure components
	player_pleasure = PleasureComponentClass.new()
	player_pleasure.name = "PlayerPleasure"
	player_pleasure.character_name = "主人"
	temple_node.add_child(player_pleasure)
	
	npc_pleasure = PleasureComponentClass.new()
	npc_pleasure.name = "NPCPleasure"
	npc_pleasure.character_name = "花火"
	temple_node.add_child(npc_pleasure)
	
	# 3. Combat manager
	combat_manager = TurnCombatManagerClass.new()
	combat_manager.name = "TurnCombatManager"
	temple_node.add_child(combat_manager)
	combat_manager.setup(player_pleasure, npc_pleasure)
	
	# 4. Dialogue manager
	dialogue_manager = DialogueManagerClass.new()
	dialogue_manager.name = "DialogueManager"
	temple_node.add_child(dialogue_manager)
	
	# 5. UI Canvas Layer
	var canvas := CanvasLayer.new()
	canvas.name = "TempleCombatCanvas"
	canvas.layer = 12
	temple_node.add_child(canvas)
	
	interact_prompt = Label.new()
	interact_prompt.text = "【E】与花火交涉"
	interact_prompt.anchor_left = 0.4
	interact_prompt.anchor_right = 0.6
	interact_prompt.anchor_top = 0.72
	interact_prompt.anchor_bottom = 0.76
	interact_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_prompt.add_theme_font_size_override("font_size", 18)
	interact_prompt.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	interact_prompt.visible = false
	canvas.add_child(interact_prompt)
	
	combat_hud = TurnCombatHUDClass.new()
	combat_hud.name = "TurnCombatHUD"
	combat_hud.palette = ui_palette
	combat_hud.opponent_name = "花火"
	combat_hud.visible = false
	canvas.add_child(combat_hud)
	
	dialogue_panel = DialoguePanelClass.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.palette = ui_palette
	dialogue_panel.opponent_name = "花火"
	dialogue_panel.visible = false
	canvas.add_child(dialogue_panel)
	
	service_hud = Label.new()
	service_hud.name = "ServiceHUD"
	service_hud.anchor_left = 0.1
	service_hud.anchor_right = 0.9
	service_hud.anchor_top = 0.84
	service_hud.anchor_bottom = 0.93
	service_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	service_hud.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	service_hud.add_theme_font_size_override("font_size", 16)
	service_hud.add_theme_color_override("font_color", Color(1.0, 0.96, 0.72))
	service_hud.visible = false
	canvas.add_child(service_hud)
	
	# Signal connections
	dialogue_manager.text_updated.connect(dialogue_panel.display_text)
	dialogue_manager.choices_presented.connect(dialogue_panel.display_choices)
	dialogue_panel.option_selected.connect(dialogue_manager.choose_option)
	dialogue_panel.next_pressed.connect(dialogue_manager.advance_text)
	dialogue_manager.dialogue_ended.connect(_on_dialogue_ended)
	
	combat_manager.log_message_emitted.connect(combat_hud.append_log)
	combat_manager.koujou_triggered.connect(combat_hud.display_koujou)
	combat_manager.phase_changed.connect(_on_combat_phase_changed)
	combat_manager.combat_ended.connect(_on_combat_ended)
	combat_manager.mid_battle_dialogue_requested.connect(_on_mid_battle_dialogue_requested)
	
	combat_hud.action_chosen.connect(combat_manager.execute_player_action)
	combat_hud.meta_dialogue_requested.connect(combat_manager.request_in_battle_negotiation)
	
	player_pleasure.pleasure_changed.connect(combat_hud.update_player_pleasure)
	npc_pleasure.pleasure_changed.connect(combat_hud.update_npc_pleasure)
	combat_hud.set_opponent_pleasure(npc_pleasure)

func get_npc_interaction_position() -> Vector3:
	if npc_avatar and is_instance_valid(npc_avatar):
		if "character" in npc_avatar and is_instance_valid(npc_avatar.character):
			return npc_avatar.character.global_position
		return npc_avatar.global_position
	if npc_anchor and is_instance_valid(npc_anchor):
		return npc_anchor.global_position
	return Vector3.ZERO

func get_npc_forward() -> Vector3:
	if npc_avatar and is_instance_valid(npc_avatar):
		if "character" in npc_avatar and is_instance_valid(npc_avatar.character):
			return npc_avatar.character.global_transform.basis.z.normalized()
		return npc_avatar.global_transform.basis.z.normalized()
	if npc_anchor and is_instance_valid(npc_anchor):
		return npc_anchor.global_transform.basis.z.normalized()
	return Vector3.FORWARD

func get_npc_basis() -> Basis:
	if npc_avatar and is_instance_valid(npc_avatar):
		if "character" in npc_avatar and is_instance_valid(npc_avatar.character):
			return npc_avatar.character.global_transform.basis
		return npc_avatar.global_transform.basis
	if npc_anchor and is_instance_valid(npc_anchor):
		return npc_anchor.global_transform.basis
	return Basis.IDENTITY

func get_corpse_position() -> Vector3:
	if corpse_actor and is_instance_valid(corpse_actor):
		if "physical_bones" in corpse_actor and corpse_actor.physical_bones.has("Hips") and is_instance_valid(corpse_actor.physical_bones["Hips"]):
			return corpse_actor.physical_bones["Hips"].global_position
		if "character_instance" in corpse_actor and corpse_actor.character_instance and is_instance_valid(corpse_actor.character_instance):
			return corpse_actor.character_instance.global_position
		return corpse_actor.global_position
	return get_npc_interaction_position()


func is_world_input_locked() -> bool:
	return current_state in [
		EncounterState.INTRO_DIALOGUE,
		EncounterState.STAGING_TRANSITION,
		EncounterState.COMBAT,
		EncounterState.RESULT_DIALOGUE,
		EncounterState.SETTLEMENT,
		EncounterState.FURNITURE_SERVICE_STAGING,
		EncounterState.FURNITURE_SERVICE_ACTIVE
	]

func _capture_world_context() -> void:
	if world != null:
		saved_world_context = {
			"character_mode": world.get("character_mode") if "character_mode" in world else true,
			"free_mode": world.get("free_mode") if "free_mode" in world else false,
			"overview_mode": world.get("overview_mode") if "overview_mode" in world else false
		}


func get_active_master_id() -> String:
	var char_node := _get_world_character()
	if char_node != null:
		if "active_character_id" in char_node:
			var c_id: String = String(char_node.active_character_id)
			if not c_id.is_empty():
				return c_id
		if char_node.has_meta("active_character_id"):
			var c_id: String = String(char_node.get_meta("active_character_id"))
			if not c_id.is_empty():
				return c_id
	if world != null:
		var switch_wheel = world.find_child("CharacterSwitchWheel", true, false)
		if switch_wheel and "active_character_id" in switch_wheel:
			return String(switch_wheel.active_character_id)
	return "lumine"

func _ensure_combat_actors_ready() -> void:
	if sparkle_combat_actor != null and is_instance_valid(sparkle_combat_actor):
		if not sparkle_combat_actor.ready_for_review:
			await sparkle_combat_actor.initialized
	if master_combat_actor != null and is_instance_valid(master_combat_actor):
		if not master_combat_actor.ready_for_review:
			await master_combat_actor.initialized

func _sync_master_combat_actor_model() -> void:
	var master_id := get_active_master_id()
	var config: Dictionary = MASTER_CONFIGS.get(master_id, MASTER_CONFIGS["lumine"])
	var target_model: String = config.get("model", MASTER_CONFIGS["lumine"]["model"])
	var target_mtoon: String = config.get("mtoon", "lumine")
	
	if master_combat_actor != null and is_instance_valid(master_combat_actor):
		if master_combat_actor.model_resource == target_model:
			return
		master_combat_actor.queue_free()
		
	master_combat_actor = NPC.instantiate()
	master_combat_actor.name = "MasterReceiving"
	master_combat_actor.model_resource = target_model
	master_combat_actor.motion_resource = MOTION_MASTER_RECEIVING
	master_combat_actor.auto_play = true
	master_combat_actor.environment_mask = 33
	master_combat_actor.initialized.connect(func():
		if is_instance_valid(master_combat_actor) and master_combat_actor.character:
			MTOON.apply(master_combat_actor.character, target_mtoon)
	)
	combat_actors_root.add_child(master_combat_actor)
	if master_combat_actor.has_method("set_playback_active"):
		master_combat_actor.set_playback_active(combat_actors_root.visible)

func _get_world_var(prop_name: String, default_val = null):
	if world == null or not is_instance_valid(world):
		return default_val
	var val = world.get(prop_name)
	if val != null:
		return val
	if world.has_meta(prop_name):
		return world.get_meta(prop_name)
	return default_val

func _get_world_character() -> Node:
	if world == null or not is_instance_valid(world):
		return null
	var char_mode = _get_world_var("character_mode")
	if char_mode != null and not bool(char_mode):
		return null
	var free_mode = _get_world_var("free_mode")
	if free_mode != null and bool(free_mode):
		return null
	var overview = _get_world_var("overview_mode")
	if overview != null and bool(overview):
		return null
	var planting = _get_world_var("planting")
	if planting != null and planting.get("active") != null and bool(planting.get("active")):
		return null
	if world.has_method("active_actor"):
		var actor = world.active_actor()
		if actor != null and is_instance_valid(actor):
			if "camper" in world and actor == world.get("camper"):
				return null
			return actor
	if "character" in world:
		var node = world.get("character")
		if node != null and is_instance_valid(node):
			return node
	if world.has_meta("character"):
		var node = world.get_meta("character")
		if node != null and is_instance_valid(node):
			return node
	if world.has_node("Character"):
		return world.get_node("Character")
	return null

func tick(delta: float) -> void:
	if current_state == EncounterState.COMBAT or current_state == EncounterState.FURNITURE_SERVICE_ACTIVE:
		if not (dialogue_panel and is_instance_valid(dialogue_panel) and dialogue_panel.visible):
			_process_combat_camera_keys(delta)
			
	var char_node := _get_world_character()
	if char_node == null:
		if interact_prompt and interact_prompt.visible:
			interact_prompt.visible = false
		return
		
	var player_pos: Vector3 = char_node.global_position
	
	# Handle ragdoll respawn when player leaves temple (> 30m)
	if is_ragdoll_active:
		var corpse_pos: Vector3 = get_corpse_position()
		var dist_to_corpse: float = player_pos.distance_to(corpse_pos)
		if dist_to_corpse > 30.0:
			_respawn_sparkle_after_kill()
		if interact_prompt and interact_prompt.visible:
			interact_prompt.visible = false
		return
		
	var npc_pos: Vector3 = get_npc_interaction_position()
	var dist: float = player_pos.distance_to(npc_pos)
		
	if current_state != EncounterState.AVAILABLE and current_state != EncounterState.COMPLETED:
		if interact_prompt and interact_prompt.visible:
			interact_prompt.visible = false
		return
		
	# Block interaction when player is using camper, free camera or planting editor
	if world != null:
		if "character_mode" in world and not world.character_mode:
			if interact_prompt and interact_prompt.visible:
				interact_prompt.visible = false
			return
		if "free_mode" in world and world.free_mode:
			if interact_prompt and interact_prompt.visible:
				interact_prompt.visible = false
			return
		if "planting" in world and world.planting != null and world.planting.get("active"):
			if interact_prompt and interact_prompt.visible:
				interact_prompt.visible = false
			return

	var horiz_dist: float = Vector2(player_pos.x - npc_pos.x, player_pos.z - npc_pos.z).length()
	var dy: float = absf(player_pos.y - npc_pos.y)
	if horiz_dist <= 2.8 and dy <= 1.5:
		var has_los: bool = true
		if world and is_instance_valid(world) and world.is_inside_tree():
			var world_3d: World3D = world.get_world_3d()
			if world_3d:
				var space_state := world_3d.direct_space_state
				if space_state:
					var ray_query := PhysicsRayQueryParameters3D.create(
						player_pos + Vector3(0.0, 1.0, 0.0),
						npc_pos + Vector3(0.0, 1.0, 0.0)
					)
					var exclude_rids: Array[RID] = []
					if "get_rid" in char_node:
						exclude_rids.append(char_node.get_rid())
					if npc_body and is_instance_valid(npc_body):
						exclude_rids.append(npc_body.get_rid())
					ray_query.exclude = exclude_rids
					ray_query.collision_mask = 1
					var result := space_state.intersect_ray(ray_query)
					if not result.is_empty():
						has_los = false
						
		if has_los:
			interact_prompt.visible = true
			if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept") or Input.is_physical_key_pressed(KEY_E):
				start_encounter_dialogue()
		else:
			interact_prompt.visible = false
	else:
		interact_prompt.visible = false

func start_encounter_dialogue() -> void:
	if is_ragdoll_active:
		return
		
	if not _set_encounter_state(EncounterState.INTRO_DIALOGUE):
		return
		
	interact_prompt.visible = false
	_capture_world_context()
	
	var char_node := _get_world_character()
	if char_node != null and char_node.has_method("set_control_enabled"):
		char_node.set_control_enabled(false)
		
	dialogue_panel.visible = true
	var graph: Dictionary = SparkleTutorialDialogueClass.get_dialogue_graph()
	var start_node := "start"
	
	# Priority 1: Recent battle defeat retry takes highest priority
	if last_battle_result == "player_defeat":
		start_node = "respawn_dialogue"
		last_battle_result = "none"
	# Priority 2: Historical settlement outcome
	elif settlement_outcome == "kill":
		start_node = "post_kill_greeting" if "post_kill_greeting" in graph.get("nodes", {}) else "start"
	elif settlement_outcome.begins_with("spare"):
		start_node = "post_spare_greeting" if "post_spare_greeting" in graph.get("nodes", {}) else "start"
	else:
		start_node = "start"
		
	if start_node != "respawn_dialogue":
		dialogue_manager.reset_battle_cheats()
		
	dialogue_manager.start_dialogue(
		graph,
		start_node,
		DialogueManagerClass.DialogueSource.WORLD_INTERACTION,
		DialogueManagerClass.ResumePolicy.RETURN_TO_WORLD
	)

func _begin_seamless_combat_staging() -> void:
	if current_state == EncounterState.COMBAT:
		return
	if not _set_encounter_state(EncounterState.STAGING_TRANSITION):
		return
	current_op_token += 1
	var op_token := current_op_token
	dialogue_panel.visible = false
	if interact_prompt and is_instance_valid(interact_prompt):
		interact_prompt.visible = false
	if combat_hud and is_instance_valid(combat_hud):
		combat_hud.visible = false
		combat_hud.modulate.a = 0.0

	var char_node := _get_world_character()
	var has_character: bool = (char_node != null)
	var is_fast_mode: bool = bool(world != null and world.get("automation_enabled"))

	var npc_pos: Vector3 = get_npc_interaction_position()
	var basis: Basis = get_npc_basis()
	var forward: Vector3 = get_npc_forward()
	var right: Vector3 = basis.x.normalized()

	# Compute combat camera target pose
	var target_cam_pos: Vector3 = npc_pos + forward * 1.5 + right * 0.9 + Vector3.UP * 0.85
	var target_look_at: Vector3 = npc_pos + Vector3.UP * 0.65
	combat_camera.global_position = target_cam_pos
	combat_camera.look_at(target_look_at, Vector3.UP)
	var target_cam_tf: Transform3D = combat_camera.global_transform

	# Store initial default orbit parameters for runtime camera control
	default_combat_focal_point = target_look_at
	combat_focal_point = target_look_at
	combat_cam_focal_offset = Vector3.ZERO
	var cam_offset: Vector3 = target_cam_pos - target_look_at
	default_combat_cam_distance = cam_offset.length()
	combat_cam_distance = default_combat_cam_distance
	default_combat_cam_yaw = atan2(cam_offset.x, cam_offset.z)
	combat_cam_yaw = default_combat_cam_yaw
	default_combat_cam_pitch = asin(clampf(cam_offset.y / default_combat_cam_distance, -0.99, 0.99))
	combat_cam_pitch = default_combat_cam_pitch

	# Compute initial camera pose from active character camera
	var start_cam_tf: Transform3D = target_cam_tf
	if has_character and "camera" in char_node and is_instance_valid(char_node.camera):
		start_cam_tf = char_node.camera.global_transform
		combat_camera.fov = char_node.camera.fov
	combat_camera.global_transform = start_cam_tf
	combat_camera.current = true

	# Compute player walk destination and heading
	var start_player_pos: Vector3 = char_node.global_position if has_character else npc_pos
	var target_player_pos: Vector3 = npc_pos + forward * 0.45
	target_player_pos.y = start_player_pos.y
	var target_player_yaw: float = atan2(-forward.x, -forward.z)
	var start_player_yaw: float = char_node.visual.rotation.y if (has_character and "visual" in char_node and char_node.visual) else target_player_yaw
	var diff: Vector3 = target_player_pos - start_player_pos
	diff.y = 0.0
	var walk_distance: float = diff.length()

	if has_character and char_node.has_method("set_control_enabled"):
		char_node.set_control_enabled(false)
		if char_node.has_method("_set_animation"):
			if walk_distance > 0.08:
				char_node._set_animation("walk")
			else:
				char_node._set_animation("idle")

	var staging_duration: float = 0.35 if is_fast_mode else 1.25
	var tween := temple_node.create_tween().set_parallel(true)

	# 1. Smooth camera pan and dolly
	tween.tween_method(func(t: float):
		if is_instance_valid(combat_camera):
			combat_camera.global_transform = start_cam_tf.interpolate_with(target_cam_tf, t)
	, 0.0, 1.0, staging_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	# 2. Smooth player walk to staging position
	if has_character:
		tween.tween_method(func(t: float):
			if is_instance_valid(char_node):
				char_node.global_position = start_player_pos.lerp(target_player_pos, t)
				if "visual" in char_node and is_instance_valid(char_node.visual):
					char_node.visual.rotation.y = lerp_angle(start_player_yaw, target_player_yaw, t)
		, 0.0, 1.0, staging_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# 3. Smooth NPC alignment
	if npc_avatar and is_instance_valid(npc_avatar):
		var npc_start_yaw: float = npc_avatar.global_rotation.y
		var npc_target_yaw: float = atan2(forward.x, forward.z)
		tween.tween_method(func(t: float):
			if is_instance_valid(npc_avatar):
				npc_avatar.global_rotation.y = lerp_angle(npc_start_yaw, npc_target_yaw, t)
		, 0.0, 1.0, staging_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await tween.finished

	if not is_instance_valid(temple_node) or op_token != current_op_token or current_state != EncounterState.STAGING_TRANSITION:
		return

	if has_character and is_instance_valid(char_node) and char_node.has_method("_set_animation"):
		char_node._set_animation("idle")

	# Sync active master model and ensure actors ready before display
	_sync_master_combat_actor_model()
	await _ensure_combat_actors_ready()
	if sparkle_combat_actor and sparkle_combat_actor.has_method("seek"):
		sparkle_combat_actor.seek(0.0)
	if master_combat_actor and master_combat_actor.has_method("seek"):
		master_combat_actor.seek(0.0)

	# Seamlessly switch to combat actors and HUD
	_set_combat_visuals(true)
	_set_encounter_state(EncounterState.COMBAT)

	combat_hud.reset_battle()
	combat_hud.visible = true
	var hud_tween := temple_node.create_tween()
	hud_tween.tween_property(combat_hud, "modulate:a", 1.0, 0.25)

	var is_tutorial := (defeat_count == 0)
	var cheat_data: Dictionary = dialogue_manager.consume_battle_cheats()
	var meta_rules := {
		"meta_cheat_mode": cheat_data.get("meta_cheat_mode", "none")
	}
	combat_manager.start_combat(is_tutorial, meta_rules)

func _set_combat_visuals(active: bool) -> void:
	if npc_anchor:
		npc_anchor.visible = not active
	if npc_avatar:
		npc_avatar.visible = not active
	combat_actors_root.visible = active
	
	if active:
		var char_node := _get_world_character()
		if char_node != null:
			char_node.visible = false
			
		if current_state != EncounterState.FURNITURE_SERVICE_STAGING and current_state != EncounterState.FURNITURE_SERVICE_ACTIVE:
			var npc_pos: Vector3 = get_npc_interaction_position()
			var basis: Basis = get_npc_basis()
			combat_actors_root.global_position = npc_pos
			combat_actors_root.global_basis = basis
		
		if sparkle_combat_actor and sparkle_combat_actor.has_method("set_playback_active"):
			sparkle_combat_actor.set_playback_active(true)
		if master_combat_actor and master_combat_actor.has_method("set_playback_active"):
			master_combat_actor.set_playback_active(true)
		_update_combat_camera_transform()
		combat_camera.current = true
	else:
		if sparkle_combat_actor and sparkle_combat_actor.has_method("set_playback_active"):
			sparkle_combat_actor.set_playback_active(false)
		if master_combat_actor and master_combat_actor.has_method("set_playback_active"):
			master_combat_actor.set_playback_active(false)
		is_dragging_combat_cam = false
		is_panning_combat_cam = false
		combat_camera.current = false
		var char_node := _get_world_character()
		if char_node != null:
			char_node.visible = true
			if "camera" in char_node and char_node.camera:
				char_node.camera.current = true

func _update_combat_camera_transform() -> void:
	if not is_instance_valid(combat_camera):
		return
	var cur_focal: Vector3 = combat_focal_point + combat_cam_focal_offset
	var rot: Basis = Basis(Vector3.UP, combat_cam_yaw) * Basis(Vector3.RIGHT, -combat_cam_pitch)
	var cam_pos: Vector3 = cur_focal + rot * Vector3(0.0, 0.0, combat_cam_distance)
	combat_camera.global_position = cam_pos
	combat_camera.look_at(cur_focal, Vector3.UP)

func _reset_combat_camera_to_default() -> void:
	combat_focal_point = default_combat_focal_point
	combat_cam_yaw = default_combat_cam_yaw
	combat_cam_pitch = default_combat_cam_pitch
	combat_cam_distance = default_combat_cam_distance
	combat_cam_focal_offset = Vector3.ZERO
	_update_combat_camera_transform()

func _process_combat_camera_keys(delta: float) -> void:
	var move_x: float = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var move_y: float = float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	var move_z: float = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	if move_x != 0.0 or move_y != 0.0 or move_z != 0.0:
		var cam_basis: Basis = combat_camera.global_basis
		var dir: Vector3 = (cam_basis.x * move_x + Vector3.UP * move_y + cam_basis.z * move_z).normalized()
		combat_cam_focal_offset += dir * (1.8 * delta)
		combat_cam_focal_offset.x = clampf(combat_cam_focal_offset.x, -2.5, 2.5)
		combat_cam_focal_offset.y = clampf(combat_cam_focal_offset.y, -1.5, 2.0)
		combat_cam_focal_offset.z = clampf(combat_cam_focal_offset.z, -2.5, 2.5)
		_update_combat_camera_transform()

func _unhandled_input(event: InputEvent) -> void:
	if current_state != EncounterState.COMBAT and current_state != EncounterState.FURNITURE_SERVICE_ACTIVE:
		return
	if dialogue_panel and is_instance_valid(dialogue_panel) and dialogue_panel.visible:
		is_dragging_combat_cam = false
		is_panning_combat_cam = false
		return
		
	if current_state == EncounterState.FURNITURE_SERVICE_ACTIVE:
		if dialogue_manager and dialogue_manager.session_active:
			if (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE) or event.is_action_pressed("ui_cancel"):
				_finish_furniture_service()
				return
		else:
			var is_dismiss := false
			if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
				is_dismiss = true
			elif InputMap.has_action("cancel") and event.is_action_pressed("cancel"):
				is_dismiss = true
			elif event is InputEventKey and event.pressed:
				if event.keycode in [KEY_E, KEY_SPACE, KEY_ESCAPE]:
					is_dismiss = true
			if is_dismiss:
				_finish_furniture_service()
				return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_dragging_combat_cam = event.pressed
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_reset_combat_camera_to_default()
			is_panning_combat_cam = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var delta_dist: float = 0.25 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -0.25
			combat_cam_distance = clampf(combat_cam_distance + delta_dist, 0.45, 6.0)
			_update_combat_camera_transform()
	elif event is InputEventMouseMotion:
		if is_dragging_combat_cam:
			combat_cam_yaw -= event.relative.x * 0.004
			combat_cam_pitch = clampf(combat_cam_pitch - event.relative.y * 0.003, -1.35, 1.25)
			_update_combat_camera_transform()
		elif is_panning_combat_cam:
			var cam_basis: Basis = combat_camera.global_basis
			var right_vec: Vector3 = cam_basis.x.normalized()
			var up_vec: Vector3 = cam_basis.y.normalized()
			combat_cam_focal_offset += (-right_vec * event.relative.x + up_vec * event.relative.y) * 0.002
			combat_cam_focal_offset.x = clampf(combat_cam_focal_offset.x, -2.5, 2.5)
			combat_cam_focal_offset.y = clampf(combat_cam_focal_offset.y, -1.5, 2.0)
			combat_cam_focal_offset.z = clampf(combat_cam_focal_offset.z, -2.5, 2.5)
			_update_combat_camera_transform()

func _on_dialogue_ended(payload: Dictionary) -> void:
	var action: String = payload.get("action", "close")
	var source: int = payload.get("source", DialogueManagerClass.DialogueSource.WORLD_INTERACTION)
	var policy: int = payload.get("resume_policy", DialogueManagerClass.ResumePolicy.RETURN_TO_WORLD)
	
	# Return the dialogue panel to its bottom dock for the result sequence.
	if current_state == EncounterState.COMBAT:
		dialogue_panel.visible = false
		combat_hud.set_chat_open(false)
		combat_hud.visible = true
		
		var cheat_data: Dictionary = dialogue_manager.consume_battle_cheats()
		var cheat_mode: String = cheat_data.get("meta_cheat_mode", "none")
		if cheat_mode == "distracted":
			combat_manager.npc_pleasure.damage_taken_multiplier = 2.5
			combat_manager.log_message_emitted.emit("【战中识趣】花火故意走神了！受到的快感倍率提升至 2.5 倍！")
		elif cheat_mode == "lock_master_pleasure":
			combat_manager.player_pleasure.pleasure_locked = true
			combat_manager.player_pleasure.pleasure_cap = 90.0
			combat_manager.log_message_emitted.emit("【战中识趣】花火施加了保护！主人的快感上限被锁定在90%！")
			
		if cheat_data.get("edging_endure", false):
			combat_manager.temporary_defense_modifier = 0.5
			combat_manager.log_message_emitted.emit("【咬牙忍耐】主人集中精神咬牙忍耐，本轮快感减免 50%！")
			
		var instant: bool = (cheat_mode == "instant_surrender")
		var is_next_turn: bool = (policy == DialogueManagerClass.ResumePolicy.NEXT_TURN)
		combat_manager.resume_combat_after_dialogue(instant, is_next_turn)
		return
		
	if action == DialogueManagerClass.ACTION_ENTER_COMBAT:
		_begin_seamless_combat_staging()
	elif action == DialogueManagerClass.ACTION_KILL:
		_execute_settlement_kill()
	elif action == "spare_virgin" or action == DialogueManagerClass.ACTION_SPARE_VIRGIN:
		_begin_furniture_service_staging("virgin")
	elif action == "spare_honban" or action == DialogueManagerClass.ACTION_SPARE_HONBAN:
		_begin_furniture_service_staging("honban")
	elif action == DialogueManagerClass.ACTION_SPARE:
		_begin_furniture_service_staging("virgin")
	elif action == DialogueManagerClass.ACTION_FINISH_SERVICE or action == "finish_service":
		_finish_furniture_service()
	elif action == DialogueManagerClass.ACTION_CLOSE:
		dialogue_panel.visible = false
		_restore_world_controls()
		_set_encounter_state(EncounterState.AVAILABLE)

func _on_combat_phase_changed(phase: int) -> void:
	combat_hud.update_round(combat_manager.round_count)
	var labels := {
		TurnCombatManagerClass.Phase.PLAYER_INPUT: "你的回合",
		TurnCombatManagerClass.Phase.PLAYER_ACTION: "行动结算",
		TurnCombatManagerClass.Phase.NPC_ACTION: "花火回合",
		TurnCombatManagerClass.Phase.MID_BATTLE_DIALOGUE: "战中交涉",
		TurnCombatManagerClass.Phase.VICTORY: "对决胜利",
		TurnCombatManagerClass.Phase.DEFEAT: "对决败北",
	}
	combat_hud.set_input_enabled(phase == TurnCombatManagerClass.Phase.PLAYER_INPUT, labels.get(phase, "回合准备"))

func _on_combat_ended(winner: String, _loser: String, _reason: String) -> void:
	dialogue_manager.reset_battle_cheats()
	if player_pleasure:
		player_pleasure.pleasure_locked = false
		player_pleasure.pleasure_cap = 100.0
		player_pleasure.damage_taken_multiplier = 1.0
	if npc_pleasure:
		npc_pleasure.pleasure_locked = false
		npc_pleasure.pleasure_cap = 100.0
		npc_pleasure.damage_taken_multiplier = 1.0
	if combat_manager:
		combat_manager.temporary_defense_modifier = 0.0
		combat_manager.round_action_defense = 0.0

	await temple_node.get_tree().create_timer(1.0).timeout
	combat_hud.visible = false
	_set_combat_visuals(false)
	
	var graph: Dictionary = SparkleTutorialDialogueClass.get_dialogue_graph()
	if winner == "Sparkle":
		last_battle_result = "player_defeat"
		defeat_count += 1
		dialogue_manager.blackboard["defeat_count"] = defeat_count
		if game_progress and game_progress.has_method("record_defeat"):
			game_progress.record_defeat()
		_set_encounter_state(EncounterState.RESPAWN)
		
		var char_node := _get_world_character()
		if char_node != null:
			if char_node.has_method("set_spawn"):
				char_node.set_spawn(RESPAWN_POINT, RESPAWN_HEADING)
			if char_node.has_method("set_control_enabled"):
				char_node.set_control_enabled(true)
			if "camera" in char_node and char_node.camera:
				char_node.camera.current = true
				
		dialogue_panel.visible = false
		_restore_world_controls()
		_set_encounter_state(EncounterState.AVAILABLE)
		print("【大世界】主人败北射精虚脱，已在神殿门前重新站起！请自由走入神殿再次与花火交涉。")
	else:
		last_battle_result = "player_victory"
		_set_encounter_state(EncounterState.RESULT_DIALOGUE)
		dialogue_panel.visible = true
		dialogue_manager.start_dialogue(
			graph,
			"victory_node",
			DialogueManagerClass.DialogueSource.POST_BATTLE_RESULT,
			DialogueManagerClass.ResumePolicy.END_COMBAT
		)

func _on_mid_battle_dialogue_requested(reason: String) -> void:
	combat_hud.set_chat_open(true)
	dialogue_panel.visible = true
	var graph: Dictionary = SparkleTutorialDialogueClass.get_dialogue_graph()
	var start_node := "mid_battle_manual" if reason == "player_manual_call" else "mid_battle_edging"
	var source: int = (
		DialogueManagerClass.DialogueSource.MID_BATTLE_MANUAL
		if reason == "player_manual_call"
		else DialogueManagerClass.DialogueSource.MID_BATTLE_EDGING
	)
	var policy: int = (
		DialogueManagerClass.ResumePolicy.SAME_TURN
		if reason == "player_manual_call"
		else DialogueManagerClass.ResumePolicy.NEXT_TURN
	)
	dialogue_manager.start_dialogue(graph, start_node, source, policy)

func _execute_settlement_kill() -> void:
	_set_encounter_state(EncounterState.SETTLEMENT)
	dialogue_panel.visible = false
	_set_combat_visuals(false)
	_restore_world_controls()
	
	is_ragdoll_active = true
	tutorial_completed = true
	companion_unlocked = true
	settlement_outcome = "kill"
	if game_progress:
		if game_progress.has_method("mark_tutorial_completed"):
			game_progress.mark_tutorial_completed()
		if game_progress.has_method("set_settlement_outcome"):
			game_progress.set_settlement_outcome("kill")
	
	if npc_avatar:
		npc_avatar.visible = false
	if npc_body:
		npc_body.collision_layer = 0
		
	var corpse_spawn_pos := get_npc_interaction_position()
	if corpse_actor:
		corpse_actor.global_position = corpse_spawn_pos
		corpse_actor.visible = true
		var ok: bool = corpse_actor.load_character(
			"res://assets/characters/import_tests_local/huahuo/huahuo_fixed.vrm",
			"huahuo",
			"花火"
		)
		if ok and corpse_actor.character_instance:
			MTOON.apply(corpse_actor.character_instance, "huahuo")
		corpse_actor.start_ragdoll()
		
	print("【大世界结算】主人选择【杀掉】花火！花火化为真实物理尸体倒在神殿地板上，同时永久解锁为可用伙伴，离开30米后将刷新重置！")
	settlement_completed.emit("kill")
	_set_encounter_state(EncounterState.COMPLETED)

func _find_furniture_node(furniture_id: String) -> Node3D:
	if temple_node and is_instance_valid(temple_node):
		var furn_dict = temple_node.get("furniture_instances")
		if furn_dict == null and temple_node.has_meta("furniture_instances"):
			furn_dict = temple_node.get_meta("furniture_instances")
		if furn_dict is Dictionary and furn_dict.has(furniture_id):
			var f: Node3D = furn_dict[furniture_id]
			if f and is_instance_valid(f):
				return f
		var fallback_node: Node3D = temple_node.find_child(furniture_id, true, false)
		if fallback_node and is_instance_valid(fallback_node):
			return fallback_node
	return null

func has_furniture_anchor(furniture_id: String, anchor_name: String) -> bool:
	var f_node := _find_furniture_node(furniture_id)
	if f_node and is_instance_valid(f_node):
		if f_node.has_method("has_motion_anchor"):
			return f_node.has_motion_anchor(anchor_name)
		return f_node.get_node_or_null(anchor_name) != null
	if allow_test_fixture_fallback:
		return _has_test_fixture_anchor(furniture_id, anchor_name)
	return false

func _has_test_fixture_anchor(furniture_id: String, anchor_name: String) -> bool:
	if furniture_id == "seat_01":
		return anchor_name in ["Anchor_Seat", "Anchor_Front"]
	elif furniture_id == "rest_01":
		return anchor_name in ["Anchor_Bed_Center", "Anchor_Front", "Anchor_BedEdge_Front"]
	return false

func _get_test_fixture_anchor(furniture_id: String, anchor_name: String) -> Transform3D:
	if furniture_id == "seat_01":
		var seat_pos := Vector3(-1011.062, 61.05, 1255.254)
		var fwd := Vector3(-0.928477, 0.0, 0.371391).normalized()
		var basis := Basis(Vector3.UP.cross(fwd).normalized(), Vector3.UP, fwd)
		if anchor_name == "Anchor_Seat":
			return Transform3D(basis, Vector3(-1011.155, 61.47, 1255.291))
		elif anchor_name == "Anchor_Front":
			return Transform3D(Basis(Vector3.UP.cross(-fwd).normalized(), Vector3.UP, -fwd), Vector3(-1012.037, 61.05, 1255.644))
		return Transform3D(basis, seat_pos)
	elif furniture_id == "rest_01":
		var bed_pos := Vector3(-1017.462, 61.05, 1251.583)
		var fwd := Vector3(0.371391, 0.0, 0.928477).normalized()
		var basis := Basis(Vector3.UP.cross(fwd).normalized(), Vector3.UP, fwd)
		if anchor_name == "Anchor_Bed_Center":
			return Transform3D(basis, Vector3(-1017.462, 61.51, 1251.583))
		elif anchor_name == "Anchor_Front":
			return Transform3D(Basis(Vector3.UP.cross(-fwd).normalized(), Vector3.UP, -fwd), Vector3(-1016.682, 61.05, 1253.533))
		return Transform3D(basis, bed_pos)
	return Transform3D.IDENTITY

func get_furniture_anchor(furniture_id: String, anchor_name: String) -> Transform3D:
	var f_node := _find_furniture_node(furniture_id)
	if f_node and is_instance_valid(f_node):
		if f_node.has_method("get_motion_anchor"):
			var tf: Transform3D = f_node.get_motion_anchor(anchor_name, true)
			if tf != Transform3D.IDENTITY:
				return tf
		var m_node: Node3D = f_node.get_node_or_null(anchor_name)
		if m_node and is_instance_valid(m_node):
			return m_node.global_transform
		push_error("[InitialTempleEncounterController] Furniture '%s' found but anchor '%s' missing!" % [furniture_id, anchor_name])
		return Transform3D.IDENTITY
		
	if allow_test_fixture_fallback and _has_test_fixture_anchor(furniture_id, anchor_name):
		return _get_test_fixture_anchor(furniture_id, anchor_name)
		
	push_error("[InitialTempleEncounterController] Furniture '%s' with anchor '%s' not found! Refusing silent fallback." % [furniture_id, anchor_name])
	return Transform3D.IDENTITY

func _setup_paired_actors(sparkle_motion: String, master_motion: String, base_transform: Transform3D) -> void:
	if not is_instance_valid(combat_actors_root):
		return
	combat_actors_root.global_transform = base_transform
	
	if sparkle_combat_actor and is_instance_valid(sparkle_combat_actor):
		sparkle_combat_actor.queue_free()
	if master_combat_actor and is_instance_valid(master_combat_actor):
		master_combat_actor.queue_free()
		
	sparkle_combat_actor = NPC.instantiate()
	sparkle_combat_actor.name = "SparklePairedActor"
	sparkle_combat_actor.model_resource = "res://assets/characters/import_tests_local/huahuo/huahuo_fixed.vrm"
	sparkle_combat_actor.motion_resource = sparkle_motion
	sparkle_combat_actor.auto_play = true
	sparkle_combat_actor.environment_mask = 33
	sparkle_combat_actor.initialized.connect(func():
		if is_instance_valid(sparkle_combat_actor) and sparkle_combat_actor.character:
			MTOON.apply(sparkle_combat_actor.character, "huahuo")
	)
	combat_actors_root.add_child(sparkle_combat_actor)
	
	var master_cfg: Dictionary = MASTER_CONFIGS.get(get_active_master_id(), MASTER_CONFIGS["lumine"])
	var master_model: String = master_cfg.get("model", MASTER_CONFIGS["lumine"]["model"])
	var master_mtoon: String = master_cfg.get("mtoon", "lumine")
	
	master_combat_actor = NPC.instantiate()
	master_combat_actor.name = "MasterPairedActor"
	master_combat_actor.model_resource = master_model
	master_combat_actor.motion_resource = master_motion
	master_combat_actor.auto_play = true
	master_combat_actor.environment_mask = 33
	master_combat_actor.initialized.connect(func():
		if is_instance_valid(master_combat_actor) and master_combat_actor.character:
			MTOON.apply(master_combat_actor.character, master_mtoon)
	)
	combat_actors_root.add_child(master_combat_actor)

func _calc_walk_yaw(start_yaw: float, move_yaw: float, final_yaw: float, t: float) -> float:
	if t < 0.2:
		return lerp_angle(start_yaw, move_yaw, t / 0.2)
	elif t < 0.82:
		return move_yaw
	else:
		return lerp_angle(move_yaw, final_yaw, (t - 0.82) / 0.18)

func _calc_walk_pos(start_pos: Vector3, target_pos: Vector3, t: float) -> Vector3:
	var cur_xz := Vector2(start_pos.x, start_pos.z).lerp(Vector2(target_pos.x, target_pos.z), t)
	var cur_y: float
	if absf(target_pos.y - start_pos.y) > 0.04:
		if t < 0.55:
			cur_y = start_pos.y
		else:
			var step_t: float = (t - 0.55) / 0.45
			var smooth_step: float = smoothstep(0.0, 1.0, step_t)
			cur_y = lerp(start_pos.y, target_pos.y, smooth_step)
	else:
		cur_y = lerp(start_pos.y, target_pos.y, t)
	return Vector3(cur_xz.x, cur_y, cur_xz.y)

func _begin_furniture_service_staging(service_type: String = "virgin") -> void:
	if not _set_encounter_state(EncounterState.FURNITURE_SERVICE_STAGING):
		return
	current_op_token += 1
	var op_token := current_op_token
	settlement_outcome = "spare_" + service_type
	if dialogue_panel and is_instance_valid(dialogue_panel):
		dialogue_panel.visible = false
	if combat_hud and is_instance_valid(combat_hud):
		combat_hud.visible = false
	if interact_prompt and is_instance_valid(interact_prompt):
		interact_prompt.visible = false
		
	var char_node := _get_world_character()
	var has_character: bool = (char_node != null)
	if has_character and char_node.has_method("set_control_enabled"):
		char_node.set_control_enabled(false)
		
	# Temporarily disable character collisions so characters can freely step onto the bed/furniture
	saved_player_collision_layer = 2
	saved_player_collision_mask = 1
	if has_character:
		if "collision_layer" in char_node:
			saved_player_collision_layer = char_node.collision_layer
			char_node.collision_layer = 0
		if "collision_mask" in char_node:
			saved_player_collision_mask = char_node.collision_mask
			char_node.collision_mask = 0
			
	saved_npc_collision_layer = 64
	saved_npc_collision_mask = 0
	if npc_body and is_instance_valid(npc_body):
		saved_npc_collision_layer = npc_body.collision_layer
		saved_npc_collision_mask = npc_body.collision_mask
		npc_body.collision_layer = 0
		npc_body.collision_mask = 0
		
	var furniture_id := "seat_01" if service_type == "virgin" else "rest_01"
	var anchor_name := "Anchor_Seat" if service_type == "virgin" else "Anchor_Bed_Center"
	var sparkle_motion := MOTION_VIRGIN_SPARKLE if service_type == "virgin" else MOTION_HONBAN_SPARKLE
	var master_motion := MOTION_VIRGIN_MASTER if service_type == "virgin" else MOTION_HONBAN_MASTER
	var title_text := "【乞命侍奉 · 石椅保留处女胸部侍奉】" if service_type == "virgin" else "【乞命侍奉 · 软榻本番破处深入交合】"
	
	var furn_tf := get_furniture_anchor(furniture_id, anchor_name)
	var approach_tf := get_furniture_anchor(furniture_id, "Anchor_Front")
	if furn_tf == Transform3D.IDENTITY or approach_tf == Transform3D.IDENTITY:
		push_error("[InitialTempleEncounterController] Staging aborted: missing required anchor for %s (%s / Anchor_Front)" % [furniture_id, anchor_name])
		_restore_world_controls()
		_set_encounter_state(EncounterState.AVAILABLE)
		return
		
	if npc_avatar and is_instance_valid(npc_avatar):
		saved_npc_service_transform = npc_avatar.global_transform
	else:
		saved_npc_service_transform = Transform3D.IDENTITY
	if has_character:
		saved_player_service_transform = char_node.global_transform
	else:
		saved_player_service_transform = Transform3D.IDENTITY
		
	last_service_approach_pos = approach_tf.origin
	last_service_approach_basis = approach_tf.basis
	
	# Determine destination walk points and final facing angles
	var target_player_pos: Vector3
	var target_player_yaw: float
	var target_npc_pos: Vector3
	var target_npc_yaw: float
	
	if service_type == "virgin":
		# Master sits on armchair; Sparkle walks in front facing Master
		target_player_pos = furn_tf.origin
		target_player_yaw = furn_tf.basis.get_euler().y
		target_npc_pos = furn_tf.origin - furn_tf.basis.z * 0.45
		target_npc_yaw = furn_tf.basis.get_euler().y + PI
	else:
		# Both walk directly onto bed rest_01
		target_npc_pos = furn_tf.origin
		target_npc_yaw = furn_tf.basis.get_euler().y
		target_player_pos = furn_tf.origin + furn_tf.basis.z * 0.22
		target_player_yaw = furn_tf.basis.get_euler().y
		
	var start_player_pos: Vector3 = char_node.global_position if has_character else approach_tf.origin
	var start_player_yaw: float = char_node.visual.rotation.y if (has_character and "visual" in char_node and char_node.visual) else target_player_yaw
	var player_delta: Vector3 = target_player_pos - start_player_pos
	var player_dist: float = Vector2(player_delta.x, player_delta.z).length()
	var player_move_yaw: float = atan2(player_delta.x, player_delta.z) if player_dist > 0.05 else target_player_yaw
	
	var npc_start_pos: Vector3 = npc_avatar.global_position if npc_avatar else furn_tf.origin
	var npc_start_yaw: float = npc_avatar.global_rotation.y if npc_avatar else target_npc_yaw
	var npc_delta: Vector3 = target_npc_pos - npc_start_pos
	var npc_dist: float = Vector2(npc_delta.x, npc_delta.z).length()
	var npc_move_yaw: float = atan2(npc_delta.x, npc_delta.z) if npc_dist > 0.05 else target_npc_yaw
	
	# Activate walk animations for both characters
	if npc_avatar and is_instance_valid(npc_avatar):
		if npc_avatar.has_method("set_motion"):
			npc_avatar.set_motion("res://assets/characters/roster/motions/shared_world_A05.tres")
			npc_avatar.auto_play = true
			
	if has_character:
		if char_node.has_method("_set_animation"):
			char_node._set_animation("walk")
		if "player" in char_node and is_instance_valid(char_node.player):
			char_node.player.play("walk", 0.14)
			char_node.player.speed_scale = 1.0
			
	# Camera framing target overlooking the furniture
	var target_look_at: Vector3 = furn_tf.origin + Vector3(0.0, 0.45 if service_type == "virgin" else 0.35, 0.0)
	var cam_dist: float = 1.85 if service_type == "virgin" else 2.2
	var cam_forward: Vector3 = furn_tf.basis.z.normalized()
	var cam_side: Vector3 = furn_tf.basis.x.normalized()
	var target_cam_pos: Vector3 = target_look_at + (cam_forward * 0.85 + cam_side * 0.85 + Vector3.UP * 0.55).normalized() * cam_dist
	
	combat_camera.global_position = target_cam_pos
	combat_camera.look_at(target_look_at, Vector3.UP)
	var target_cam_tf: Transform3D = combat_camera.global_transform
	
	default_combat_focal_point = target_look_at
	combat_focal_point = target_look_at
	combat_cam_focal_offset = Vector3.ZERO
	var cam_offset: Vector3 = target_cam_pos - target_look_at
	default_combat_cam_distance = cam_offset.length()
	combat_cam_distance = default_combat_cam_distance
	default_combat_cam_yaw = atan2(cam_offset.x, cam_offset.z)
	combat_cam_yaw = default_combat_cam_yaw
	default_combat_cam_pitch = asin(clampf(cam_offset.y / default_combat_cam_distance, -0.99, 0.99))
	combat_cam_pitch = default_combat_cam_pitch
	
	var start_cam_tf: Transform3D = target_cam_tf
	if has_character and "camera" in char_node and is_instance_valid(char_node.camera):
		start_cam_tf = char_node.camera.global_transform
		combat_camera.fov = char_node.camera.fov
	combat_camera.global_transform = start_cam_tf
	combat_camera.current = true
	
	var is_fast_mode: bool = bool(world != null and world.get("automation_enabled"))
	var max_walk_dist: float = maxf(player_dist, npc_dist)
	var staging_duration: float = 0.35 if is_fast_mode else clampf(max_walk_dist / 1.5, 2.0, 3.2)
	var tween := temple_node.create_tween().set_parallel(true)
	
	# Smooth camera glide
	tween.tween_method(func(t: float):
		if is_instance_valid(combat_camera):
			combat_camera.global_transform = start_cam_tf.interpolate_with(target_cam_tf, t)
	, 0.0, 1.0, staging_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# Natural player forward walk with direction-aligned rotation and bed step-up
	if has_character:
		tween.tween_method(func(t: float):
			if is_instance_valid(char_node):
				char_node.global_position = _calc_walk_pos(start_player_pos, target_player_pos, t)
				if "visual" in char_node and is_instance_valid(char_node.visual):
					char_node.visual.rotation.y = _calc_walk_yaw(start_player_yaw, player_move_yaw, target_player_yaw, t)
		, 0.0, 1.0, staging_duration).set_trans(Tween.TRANS_LINEAR)
		
	# Natural NPC forward walk with direction-aligned rotation and bed step-up
	if npc_avatar and is_instance_valid(npc_avatar):
		tween.tween_method(func(t: float):
			if is_instance_valid(npc_avatar):
				npc_avatar.global_position = _calc_walk_pos(npc_start_pos, target_npc_pos, t)
				npc_avatar.global_rotation.y = _calc_walk_yaw(npc_start_yaw, npc_move_yaw, target_npc_yaw, t)
		, 0.0, 1.0, staging_duration).set_trans(Tween.TRANS_LINEAR)
		
	await tween.finished
	
	if not is_instance_valid(temple_node) or op_token != current_op_token or current_state != EncounterState.FURNITURE_SERVICE_STAGING:
		return
		
	if has_character and is_instance_valid(char_node) and char_node.has_method("_set_animation"):
		char_node._set_animation("idle")
		
	if npc_avatar and is_instance_valid(npc_avatar) and npc_avatar.has_method("set_motion"):
		npc_avatar.set_motion("res://assets/characters/roster/motions/shared_world_A01.tres")
		
	_setup_paired_actors(sparkle_motion, master_motion, furn_tf)
	await _ensure_combat_actors_ready()
	if sparkle_combat_actor and sparkle_combat_actor.has_method("seek"):
		sparkle_combat_actor.seek(0.0)
	if master_combat_actor and master_combat_actor.has_method("seek"):
		master_combat_actor.seek(0.0)
	_set_combat_visuals(true)
	_set_encounter_state(EncounterState.FURNITURE_SERVICE_ACTIVE)
	companion_unlocked = true
	tutorial_completed = true
	
	if service_hud:
		service_hud.text = title_text + "\n右键环绕视角 | 滚轮缩放视距 | 中键复位视角 | WASD微调对焦 | 按【E】直接完成侍奉"
		service_hud.visible = true
	print("【大世界演出】成功步入家具开启乞命侍奉: " + title_text)
	
	var start_node: String = "service_virgin_start" if service_type == "virgin" else "service_honban_start"
	if dialogue_panel and is_instance_valid(dialogue_panel):
		dialogue_panel.visible = true
	if dialogue_manager and is_instance_valid(dialogue_manager):
		dialogue_manager.start_dialogue(
			SparkleTutorialDialogueClass.get_dialogue_graph(),
			start_node,
			DialogueManagerClass.DialogueSource.POST_BATTLE_RESULT,
			DialogueManagerClass.ResumePolicy.END_COMBAT
		)

func _finish_furniture_service() -> void:
	if service_hud and is_instance_valid(service_hud):
		service_hud.visible = false
	if dialogue_panel and is_instance_valid(dialogue_panel):
		dialogue_panel.visible = false
	_set_combat_visuals(false)
	
	var char_node := _get_world_character()
	if char_node != null:
		if "collision_layer" in char_node:
			char_node.collision_layer = saved_player_collision_layer
		if "collision_mask" in char_node:
			char_node.collision_mask = saved_player_collision_mask
		char_node.global_position = last_service_approach_pos
		
	var local_side: Vector3 = last_service_approach_basis.x.normalized()
	var exit_npc_pos: Vector3 = last_service_approach_pos + local_side * 0.7
	var exit_npc_yaw: float = last_service_approach_basis.get_euler().y
	
	if npc_avatar and is_instance_valid(npc_avatar):
		npc_avatar.visible = true
		npc_avatar.global_position = exit_npc_pos
		npc_avatar.global_rotation.y = exit_npc_yaw
		if npc_avatar.has_method("set_motion"):
			npc_avatar.set_motion("res://assets/characters/roster/motions/shared_world_A01.tres")
	if npc_body and is_instance_valid(npc_body):
		npc_body.collision_layer = saved_npc_collision_layer
		npc_body.collision_mask = saved_npc_collision_mask
		npc_body.global_position = exit_npc_pos
		npc_body.global_rotation.y = exit_npc_yaw
		
	_restore_world_controls()
	_set_encounter_state(EncounterState.COMPLETED)
	tutorial_completed = true
	companion_unlocked = true
	if game_progress:
		if game_progress.has_method("mark_tutorial_completed"):
			game_progress.mark_tutorial_completed()
		if game_progress.has_method("unlock_companion"):
			game_progress.unlock_companion("sparkle")
		if game_progress.has_method("set_settlement_outcome"):
			game_progress.set_settlement_outcome(settlement_outcome)
			
	settlement_completed.emit(settlement_outcome)
	print("[InitialTempleEncounterController] Finished furniture service, restored control and local positioning.")

func _execute_settlement_spare(service_type: String = "virgin") -> void:
	_begin_furniture_service_staging(service_type)

func _respawn_sparkle_after_kill() -> void:
	is_ragdoll_active = false
	if corpse_actor:
		corpse_actor.stop_ragdoll()
		corpse_actor.visible = false
		if corpse_actor.character_instance and is_instance_valid(corpse_actor.character_instance):
			corpse_actor.character_instance.queue_free()
			corpse_actor.character_instance = null
			corpse_actor.skeleton = null
			corpse_actor.simulator = null
			corpse_actor.physical_bones.clear()
			
	if npc_avatar:
		npc_avatar.visible = true
	if npc_body:
		npc_body.collision_layer = 64
		
	_set_encounter_state(EncounterState.AVAILABLE)
	print("【大世界刷新】主人离开神殿超出30米范围，花火已重新刷新就位！")

func _restore_world_controls() -> void:
	if world != null and world.has_method("_sync_actor_controls"):
		world._sync_actor_controls()
		return
	var char_node := _get_world_character()
	if char_node != null:
		if char_node.has_method("set_control_enabled"):
			char_node.set_control_enabled(true)
		if "camera" in char_node and char_node.camera:
			char_node.camera.current = true

func _set_encounter_state(new_state: EncounterState) -> bool:
	if current_state == new_state:
		return true
	var allowed: Array = VALID_TRANSITIONS.get(current_state, [])
	if not allowed.has(new_state):
		push_warning("Invalid encounter state transition: %d -> %d" % [current_state, new_state])
		return false
	var old_state := current_state
	current_state = new_state
	if world != null and world.has_method("set_encounter_ui_active"):
		world.set_encounter_ui_active(new_state in [
			EncounterState.INTRO_DIALOGUE, EncounterState.STAGING_TRANSITION,
			EncounterState.COMBAT, EncounterState.RESULT_DIALOGUE,
		])
	encounter_state_changed.emit(old_state, new_state)
	return true
