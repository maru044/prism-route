class_name InitialTempleEncounterController
extends Node
## Encounter controller for Initial Temple Sparkle battle and narrative flow.
## Decouples world geometry representation from the narrative/combat lifecycle.

signal encounter_state_changed(old_state: int, new_state: int)
signal settlement_completed(outcome: String)

enum EncounterState {
	AVAILABLE,
	INTRO_DIALOGUE,
	COMBAT,
	RESULT_DIALOGUE,
	SETTLEMENT,
	RESPAWN,
	COMPLETED
}

const NPC := preload("res://scenes/characters/shared_humanoid_actor.tscn")
const MTOON := preload("res://scripts/characters/mtoon_materials.gd")
const DialogueManagerClass := preload("res://scripts/narrative/dialogue_manager.gd")
const TurnCombatManagerClass := preload("res://scripts/combat/turn_combat_manager.gd")
const DialoguePanelClass := preload("res://scenes/narrative/dialogue_panel.gd")
const TurnCombatHUDClass := preload("res://scenes/combat/turn_combat_hud.gd")
const PleasureComponentClass := preload("res://scripts/combat/pleasure_component.gd")
const SparkleTutorialDialogueClass := preload("res://scripts/narrative/sparkle_tutorial_dialogue.gd")
const CorpseControllerClass := preload("res://scripts/characters/corpse_ragdoll_controller.gd")

const RESPAWN_POINT := Vector3(-1012.685, 61.1, 1262.287)
const RESPAWN_HEADING := 0.38

const MOTION_SPARKLE_BLOWJOB := "res://assets/characters/mmd_selected/animations/mmd_781d8c87fd79_a.tres"
const MOTION_MASTER_RECEIVING := "res://assets/characters/mmd_selected/animations/mmd_781d8c87fd79_b.tres"

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
var player_pleasure: PleasureComponent
var npc_pleasure: PleasureComponent

var combat_actors_root: Node3D
var sparkle_combat_actor: Node3D
var master_combat_actor: Node3D
var combat_camera: Camera3D
var corpse_actor: Node3D

var interact_prompt: Label
var defeat_count: int = 0
var companion_unlocked: bool = false
var is_ragdoll_active: bool = false

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
	combat_hud.visible = false
	canvas.add_child(combat_hud)
	
	dialogue_panel = DialoguePanelClass.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.visible = false
	canvas.add_child(dialogue_panel)
	
	# Signal connections
	dialogue_manager.text_updated.connect(dialogue_panel.display_text)
	dialogue_manager.choices_presented.connect(dialogue_panel.display_choices)
	dialogue_panel.option_selected.connect(dialogue_manager.choose_option)
	dialogue_panel.next_pressed.connect(dialogue_manager.advance_text)
	dialogue_manager.dialogue_ended.connect(_on_dialogue_ended)
	
	combat_manager.log_message_emitted.connect(combat_hud.append_log)
	combat_manager.phase_changed.connect(_on_combat_phase_changed)
	combat_manager.combat_ended.connect(_on_combat_ended)
	combat_manager.mid_battle_dialogue_requested.connect(_on_mid_battle_dialogue_requested)
	
	combat_hud.action_chosen.connect(combat_manager.execute_player_action)
	combat_hud.meta_dialogue_requested.connect(combat_manager.request_in_battle_negotiation)
	
	player_pleasure.pleasure_changed.connect(combat_hud.update_player_pleasure)
	npc_pleasure.pleasure_changed.connect(combat_hud.update_npc_pleasure)

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

func tick(_delta: float) -> void:
	if not world or not is_instance_valid(world.character):
		if interact_prompt and interact_prompt.visible:
			interact_prompt.visible = false
		return
		
	var player_pos: Vector3 = world.character.global_position
	
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
		
	if dist <= 2.8:
		interact_prompt.visible = true
		if Input.is_key_pressed(KEY_E) or Input.is_action_just_pressed("ui_accept"):
			start_encounter_dialogue()
	else:
		interact_prompt.visible = false

func start_encounter_dialogue() -> void:
	if is_ragdoll_active:
		return
		
	_set_encounter_state(EncounterState.INTRO_DIALOGUE)
	interact_prompt.visible = false
	
	if world and is_instance_valid(world.character):
		world.character.set_control_enabled(false)
		
	dialogue_panel.visible = true
	var graph: Dictionary = SparkleTutorialDialogueClass.get_dialogue_graph()
	var start_node := "start"
	if companion_unlocked:
		start_node = "post_spare_greeting" if "post_spare_greeting" in graph.get("nodes", {}) else "start"
	elif defeat_count > 0:
		start_node = "respawn_dialogue"
		
	dialogue_manager.start_dialogue(
		graph,
		start_node,
		DialogueManagerClass.DialogueSource.WORLD_INTERACTION,
		DialogueManagerClass.ResumePolicy.RETURN_TO_WORLD
	)

func _set_combat_visuals(active: bool) -> void:
	if npc_anchor:
		npc_anchor.visible = not active
	if npc_avatar:
		npc_avatar.visible = not active
	combat_actors_root.visible = active
	
	if active:
		if world and is_instance_valid(world.character):
			world.character.visible = false
			
		var npc_pos: Vector3 = get_npc_interaction_position()
		var basis: Basis = get_npc_basis()
		combat_actors_root.global_position = npc_pos
		combat_actors_root.global_basis = basis
		
		var forward: Vector3 = get_npc_forward()
		var right: Vector3 = basis.x.normalized()
		var cam_pos: Vector3 = npc_pos + forward * 1.5 + right * 0.9 + Vector3.UP * 0.85
		combat_camera.global_position = cam_pos
		combat_camera.look_at(npc_pos + Vector3.UP * 0.65, Vector3.UP)
		combat_camera.current = true
	else:
		combat_camera.current = false
		if world and is_instance_valid(world.character):
			world.character.visible = true
			if world.character.camera:
				world.character.camera.current = true

func _on_dialogue_ended(payload: Dictionary) -> void:
	var action: String = payload.get("action", "close")
	var source: int = payload.get("source", DialogueManagerClass.DialogueSource.WORLD_INTERACTION)
	var policy: int = payload.get("resume_policy", DialogueManagerClass.ResumePolicy.RETURN_TO_WORLD)
	
	# Mid-battle dialogue floating resolution
	if current_state == EncounterState.COMBAT:
		dialogue_panel.visible = false
		combat_hud.visible = true
		
		var cheat_mode: String = dialogue_manager.blackboard.get("meta_cheat_mode", "none")
		if cheat_mode == "distracted":
			combat_manager.npc_pleasure.damage_taken_multiplier = 2.5
			combat_manager.log_message_emitted.emit("【战中识趣】花火故意走神了！受到的快感倍率提升至 2.5 倍！")
		elif cheat_mode == "lock_master_pleasure":
			combat_manager.player_pleasure.pleasure_locked = true
			combat_manager.player_pleasure.pleasure_cap = 90.0
			combat_manager.log_message_emitted.emit("【战中识趣】花火施加了保护！主人的快感上限被锁定在90%！")
			
		if dialogue_manager.blackboard.get("edging_endure", false):
			dialogue_manager.blackboard["edging_endure"] = false
			combat_manager.temporary_defense_modifier = 0.5
			combat_manager.log_message_emitted.emit("【咬牙忍耐】主人集中精神咬牙忍耐，本轮快感减免 50%！")
			
		var instant: bool = (cheat_mode == "instant_surrender")
		var is_next_turn: bool = (policy == DialogueManagerClass.ResumePolicy.NEXT_TURN)
		combat_manager.resume_combat_after_dialogue(instant, is_next_turn)
		return
		
	if action == DialogueManagerClass.ACTION_ENTER_COMBAT:
		_set_encounter_state(EncounterState.COMBAT)
		dialogue_panel.visible = false
		combat_hud.visible = true
		_set_combat_visuals(true)
		
		var is_tutorial := (defeat_count == 0)
		var meta_rules := {
			"meta_cheat_mode": dialogue_manager.blackboard.get("meta_cheat_mode", "none")
		}
		combat_manager.start_combat(is_tutorial, meta_rules)
	elif action == DialogueManagerClass.ACTION_KILL:
		_execute_settlement_kill()
	elif action == DialogueManagerClass.ACTION_SPARE:
		_execute_settlement_spare()
	elif action == DialogueManagerClass.ACTION_CLOSE:
		dialogue_panel.visible = false
		_restore_world_controls()
		_set_encounter_state(EncounterState.AVAILABLE)

func _on_combat_phase_changed(phase: int) -> void:
	combat_hud.update_round(combat_manager.round_count)
	combat_hud.set_input_enabled(phase == TurnCombatManagerClass.Phase.PLAYER_INPUT)

func _on_combat_ended(winner: String, _loser: String, _reason: String) -> void:
	await temple_node.get_tree().create_timer(1.0).timeout
	combat_hud.visible = false
	_set_combat_visuals(false)
	
	var graph: Dictionary = SparkleTutorialDialogueClass.get_dialogue_graph()
	if winner == "Sparkle":
		_set_encounter_state(EncounterState.RESPAWN)
		defeat_count += 1
		dialogue_manager.blackboard["defeat_count"] = defeat_count
		
		if world and is_instance_valid(world.character):
			world.character.set_spawn(RESPAWN_POINT, RESPAWN_HEADING)
			world.character.set_control_enabled(true)
			if world.character.camera:
				world.character.camera.current = true
				
		dialogue_panel.visible = false
		_set_encounter_state(EncounterState.AVAILABLE)
		print("【大世界】主人败北射精虚脱，已在神殿门前重新站起！请自由走入神殿再次与花火交涉。")
	else:
		_set_encounter_state(EncounterState.RESULT_DIALOGUE)
		dialogue_panel.visible = true
		dialogue_manager.start_dialogue(
			graph,
			"victory_node",
			DialogueManagerClass.DialogueSource.POST_BATTLE_RESULT,
			DialogueManagerClass.ResumePolicy.END_COMBAT
		)

func _on_mid_battle_dialogue_requested(reason: String) -> void:
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
	companion_unlocked = true
	
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

func _execute_settlement_spare() -> void:
	_set_encounter_state(EncounterState.SETTLEMENT)
	dialogue_panel.visible = false
	_set_combat_visuals(false)
	_restore_world_controls()
	
	companion_unlocked = true
	if npc_avatar:
		npc_avatar.visible = true
	if npc_body:
		npc_body.collision_layer = 64
	if corpse_actor:
		corpse_actor.stop_ragdoll()
		corpse_actor.visible = false
		
	print("【大世界结算】主人选择【放过】花火！乞命侍奉达成，花火永久解锁为可用伙伴！")
	settlement_completed.emit("spare")
	_set_encounter_state(EncounterState.COMPLETED)

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
	if world and is_instance_valid(world.character):
		world.character.set_control_enabled(true)
		if world.character.camera:
			world.character.camera.current = true

func _set_encounter_state(new_state: EncounterState) -> void:
	var old_state := current_state
	current_state = new_state
	encounter_state_changed.emit(old_state, new_state)
