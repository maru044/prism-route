extends Node3D
## Full integration demo for the Sparkle Tutorial Combat:
## - Temple scene & Temple Door Respawn Point
## - Dual-character Blowjob animations (Huahuo kneeling + Master receiving)
## - Pure pleasure duel (no endurance / MP system)
## - In-battle non-exiting dialogue & meta negotiation
## - Teaching kill & Settlement (Ragdoll / Honban unlock)

const SHARED_ACTOR := preload("res://scenes/characters/shared_humanoid_actor.tscn")
const DialogueManager := preload("res://scripts/narrative/dialogue_manager.gd")
const TurnCombatManager := preload("res://scripts/combat/turn_combat_manager.gd")
const DialoguePanel := preload("res://scenes/narrative/dialogue_panel.gd")
const TurnCombatHUD := preload("res://scenes/combat/turn_combat_hud.gd")
const PleasureComponent := preload("res://scripts/combat/pleasure_component.gd")
const SparkleTutorialDialogue := preload("res://scripts/narrative/sparkle_tutorial_dialogue.gd")
const MTOON := preload("res://scripts/characters/mtoon_materials.gd")

# Temple Door Respawn Point (Front of the temple steps)
const TEMPLE_DOOR_RESPAWN := Vector3(-1006.5, 61.05, 1262.5)
const TEMPLE_NPC_POSITION := Vector3(-1015.28, 61.05, 1255.79)

const MOTION_SPARKLE_IDLE := "res://assets/characters/roster/motions/shared_world_A01.tres"
const MOTION_SPARKLE_BLOWJOB := "res://assets/characters/mmd_selected/animations/mmd_781d8c87fd79_a.tres"
const MOTION_MASTER_RECEIVING := "res://assets/characters/mmd_selected/animations/mmd_781d8c87fd79_b.tres"

var dialogue_manager
var combat_manager

var dialogue_panel
var combat_hud

var player_pleasure
var npc_pleasure

var ruin_scene_node: Node3D
var camera: Camera3D
var defeat_count: int = 0

# Dual actors during combat
var combat_actors_root: Node3D
var sparkle_combat_actor: Node3D
var master_combat_actor: Node3D

func _ready() -> void:
	_setup_environment()
	_setup_ruin_scene()
	_setup_combat_and_dialogue_systems()
	_setup_combat_actors()
	_start_tutorial_flow()

func _setup_environment() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.6, 0.75, 0.9)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.85, 0.88, 0.95)
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	add_child(env)
	
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 140, 0)
	sun.light_color = Color(1.0, 0.96, 0.92)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	
	camera = Camera3D.new()
	camera.position = Vector3(-1014.2, 62.0, 1258.2)
	camera.look_at_from_position(camera.position, TEMPLE_NPC_POSITION + Vector3(0, 0.8, 0), Vector3.UP)
	camera.current = true
	add_child(camera)

func _setup_ruin_scene() -> void:
	var ruin_res = load("res://scenes/world/initial_ruin.tscn")
	ruin_scene_node = ruin_res.instantiate()
	add_child(ruin_scene_node)

func _setup_combat_actors() -> void:
	combat_actors_root = Node3D.new()
	combat_actors_root.name = "CombatDualActors"
	combat_actors_root.position = TEMPLE_NPC_POSITION
	combat_actors_root.visible = false
	add_child(combat_actors_root)
	
	# Sparkle kneeling blowjob actor
	sparkle_combat_actor = SHARED_ACTOR.instantiate()
	sparkle_combat_actor.name = "SparkleBlowjob"
	sparkle_combat_actor.model_resource = "res://assets/characters/import_tests_local/huahuo/huahuo_fixed.vrm"
	sparkle_combat_actor.motion_resource = MOTION_SPARKLE_BLOWJOB
	sparkle_combat_actor.auto_play = true
	sparkle_combat_actor.environment_mask = 33
	sparkle_combat_actor.initialized.connect(func():
		MTOON.apply(sparkle_combat_actor.character, "huahuo")
	)
	combat_actors_root.add_child(sparkle_combat_actor)
	
	# Master receiving actor (Lumine model)
	master_combat_actor = SHARED_ACTOR.instantiate()
	master_combat_actor.name = "MasterReceiving"
	master_combat_actor.model_resource = "res://assets/characters/roster/lumine/lumine.vrm"
	master_combat_actor.motion_resource = MOTION_MASTER_RECEIVING
	master_combat_actor.auto_play = true
	master_combat_actor.environment_mask = 33
	master_combat_actor.initialized.connect(func():
		MTOON.apply(master_combat_actor.character, "lumine")
	)
	combat_actors_root.add_child(master_combat_actor)

func _setup_combat_and_dialogue_systems() -> void:
	# 1. Pleasure Components (no endurance)
	player_pleasure = PleasureComponent.new()
	player_pleasure.name = "PlayerPleasure"
	player_pleasure.character_name = "主人"
	add_child(player_pleasure)
	
	npc_pleasure = PleasureComponent.new()
	npc_pleasure.name = "NPCPleasure"
	npc_pleasure.character_name = "花火"
	add_child(npc_pleasure)
	
	# 2. Combat Manager
	combat_manager = TurnCombatManager.new()
	combat_manager.name = "TurnCombatManager"
	add_child(combat_manager)
	combat_manager.setup(player_pleasure, npc_pleasure)
	
	# 3. Dialogue Manager
	dialogue_manager = DialogueManager.new()
	dialogue_manager.name = "DialogueManager"
	add_child(dialogue_manager)
	
	# 4. Canvas UI Layer
	var canvas := CanvasLayer.new()
	add_child(canvas)
	
	combat_hud = TurnCombatHUD.new()
	combat_hud.name = "TurnCombatHUD"
	combat_hud.visible = false
	canvas.add_child(combat_hud)
	
	dialogue_panel = DialoguePanel.new()
	dialogue_panel.name = "DialoguePanel"
	canvas.add_child(dialogue_panel)
	
	# Connect Dialogue Signals
	dialogue_manager.text_updated.connect(dialogue_panel.display_text)
	dialogue_manager.choices_presented.connect(dialogue_panel.display_choices)
	dialogue_panel.option_selected.connect(dialogue_manager.choose_option)
	dialogue_panel.next_pressed.connect(dialogue_manager.advance_text)
	dialogue_manager.dialogue_ended.connect(_on_dialogue_ended)
	
	# Connect Combat Signals
	combat_manager.log_message_emitted.connect(combat_hud.append_log)
	combat_manager.phase_changed.connect(_on_combat_phase_changed)
	combat_manager.combat_ended.connect(_on_combat_ended)
	combat_manager.mid_battle_dialogue_requested.connect(_on_mid_battle_dialogue_requested)
	
	combat_hud.action_chosen.connect(combat_manager.execute_player_action)
	combat_hud.meta_dialogue_requested.connect(combat_manager.request_in_battle_negotiation)
	
	# Connect Pleasure gauge updates to HUD
	player_pleasure.pleasure_changed.connect(combat_hud.update_player_pleasure)
	npc_pleasure.pleasure_changed.connect(combat_hud.update_npc_pleasure)

func _start_tutorial_flow() -> void:
	var graph: Dictionary = SparkleTutorialDialogue.get_dialogue_graph()
	dialogue_manager.start_dialogue(graph, "start")

func _set_combat_visuals(active: bool) -> void:
	if ruin_scene_node and ruin_scene_node.has_node("NPC_Idle"):
		ruin_scene_node.get_node("NPC_Idle").visible = not active
	combat_actors_root.visible = active
	
	if active:
		# Combat camera: Intimate close angle
		camera.position = TEMPLE_NPC_POSITION + Vector3(0.9, 0.85, 1.4)
		camera.look_at_from_position(camera.position, TEMPLE_NPC_POSITION + Vector3(0.0, 0.65, 0.0), Vector3.UP)
	else:
		# Return to temple overview
		camera.position = Vector3(-1014.2, 62.0, 1258.2)
		camera.look_at_from_position(camera.position, TEMPLE_NPC_POSITION + Vector3(0, 0.8, 0), Vector3.UP)

func _on_dialogue_ended(payload: Dictionary) -> void:
	var action: String = payload.get("action", "close")
	
	# Check if this dialogue occurred mid-combat
	if combat_manager.current_phase == TurnCombatManager.Phase.MID_BATTLE_DIALOGUE:
		dialogue_panel.visible = false
		combat_hud.visible = true
		var cheat_mode: String = dialogue_manager.blackboard.get("meta_cheat_mode", "none")
		var instant: bool = (cheat_mode == "instant_surrender")
		combat_manager.resume_combat_after_dialogue(instant)
		return
		
	if action == "enter_combat":
		dialogue_panel.visible = false
		combat_hud.visible = true
		_set_combat_visuals(true)
		
		var is_tutorial := (defeat_count == 0)
		var meta_rules := {
			"meta_cheat_mode": dialogue_manager.blackboard.get("meta_cheat_mode", "none")
		}
		combat_manager.start_combat(is_tutorial, meta_rules)
	elif action == "kill":
		dialogue_panel.visible = false
		_set_combat_visuals(false)
		print("【结算分支】主人选择【杀掉】花火！激活物理布娃娃玩尸系统，超出警戒范围后静默刷新！")
	elif action == "spare":
		dialogue_panel.visible = false
		_set_combat_visuals(false)
		print("【结算分支】主人选择【放过】花火！乞命侍奉本番达成，花火逻辑永久解锁为可用伙伴！")
	elif action == "close":
		dialogue_panel.visible = false

func _on_combat_phase_changed(phase: int) -> void:
	combat_hud.update_round(combat_manager.round_count)
	combat_hud.set_input_enabled(phase == TurnCombatManager.Phase.PLAYER_INPUT)

func _on_combat_ended(winner: String, loser: String, reason: String) -> void:
	await get_tree().create_timer(1.0).timeout
	combat_hud.visible = false
	_set_combat_visuals(false)
	
	var graph: Dictionary = SparkleTutorialDialogue.get_dialogue_graph()
	if winner == "Sparkle":
		# Master defeated in Round 1 teaching kill -> Respawn at temple door
		defeat_count += 1
		dialogue_manager.blackboard["defeat_count"] = defeat_count
		
		# Move camera and player perspective to temple door respawn point
		camera.position = TEMPLE_DOOR_RESPAWN + Vector3(0, 1.4, 0)
		camera.look_at_from_position(camera.position, TEMPLE_NPC_POSITION + Vector3(0, 0.8, 0), Vector3.UP)
		
		dialogue_panel.visible = true
		dialogue_manager.start_dialogue(graph, "respawn_dialogue")
	else:
		# Sparkle defeated
		dialogue_panel.visible = true
		dialogue_manager.start_dialogue(graph, "victory_node")

func _on_mid_battle_dialogue_requested(reason: String) -> void:
	# Keep Combat HUD visible in background, overlay dialogue panel as a floating prompt
	dialogue_panel.visible = true
	var graph: Dictionary = SparkleTutorialDialogue.get_dialogue_graph()
	dialogue_manager.start_dialogue(graph, "mid_battle_edging")
