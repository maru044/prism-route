class_name NPCEncounterRuntime
extends Node
## Universal runtime lifecycle controller for 3-tier NPC encounters.
## Assembles Character + Spawn + Encounter via NPCRegistry, orchestrating Dialogue, Combat, Motions, and Settlement.

signal encounter_state_changed(old_state: int, new_state: int)
signal dialogue_updated(speaker: String, text: String, emotion: String)
signal combat_started()
signal combat_ended(winner: String)
signal settlement_finished(outcome: String)

enum EncounterState {
	UNINITIALIZED,
	AVAILABLE,
	INTRO_DIALOGUE,
	COMBAT,
	RESULT_DIALOGUE,
	SETTLEMENT,
	COMPLETED
}

const NPCRegistryClass := preload("res://scripts/npc/npc_registry.gd")
const DialogueManagerClass := preload("res://scripts/narrative/dialogue_manager.gd")
const TurnCombatManagerClass := preload("res://scripts/combat/turn_combat_manager.gd")
const CombatStrategyClass := preload("res://scripts/combat/combat_strategy.gd")
const ReactionResolverClass := preload("res://scripts/combat/reaction_resolver.gd")
const PleasureComponentClass := preload("res://scripts/combat/pleasure_component.gd")
const MotionResolverClass := preload("res://scripts/world/motion_resolver.gd")

@export var encounter_id: String = ""

var current_state: EncounterState = EncounterState.UNINITIALIZED
var encounter_bundle: Dictionary = {}

var dialogue_manager: DialogueManagerClass
var combat_manager: TurnCombatManagerClass
var player_pleasure: PleasureComponentClass
var npc_pleasure: PleasureComponentClass
var reaction_resolver: ReactionResolverClass

var spawn_position: Vector3 = Vector3.ZERO
var spawn_heading: float = 0.0
var character_name: String = ""
var last_battle_winner: String = ""
var settlement_outcome: String = ""

func setup_encounter(p_encounter_id: String) -> bool:
	encounter_id = p_encounter_id
	encounter_bundle = NPCRegistryClass.assemble_encounter(encounter_id)
	if not encounter_bundle.get("valid", false):
		push_error("[NPCEncounterRuntime] Failed to assemble encounter: " + str(encounter_bundle.get("error", "unknown")))
		return false

	var char_def: Dictionary = encounter_bundle["character"]
	var spawn_def: Dictionary = encounter_bundle["spawn"]
	character_name = char_def.get("display_name", "NPC")

	var pos_arr: Array = spawn_def.get("position", [0, 0, 0])
	spawn_position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
	spawn_heading = spawn_def.get("heading", 0.0)

	# 1. Dialogue Manager
	dialogue_manager = DialogueManagerClass.new()
	dialogue_manager.name = "DialogueManager"
	add_child(dialogue_manager)
	dialogue_manager.text_updated.connect(_on_text_updated)
	dialogue_manager.dialogue_ended.connect(_on_dialogue_ended)

	# 2. Pleasure components
	player_pleasure = PleasureComponentClass.new()
	player_pleasure.name = "PlayerPleasure"
	add_child(player_pleasure)

	npc_pleasure = PleasureComponentClass.new()
	npc_pleasure.name = "NPCPleasure"
	add_child(npc_pleasure)

	# 3. Combat Strategy and Reaction Resolver
	var reactions_dict: Dictionary = encounter_bundle.get("reactions", {})
	reaction_resolver = ReactionResolverClass.new(reactions_dict)
	reaction_resolver.speaker_name = character_name

	var combat_strategy := CombatStrategyClass.new()

	# 4. Turn Combat Manager
	combat_manager = TurnCombatManagerClass.new()
	combat_manager.name = "CombatManager"
	add_child(combat_manager)
	combat_manager.setup(player_pleasure, npc_pleasure)
	combat_manager.configure_npc(character_name, reactions_dict, combat_strategy)
	combat_manager.combat_ended.connect(_on_combat_ended)

	_set_state(EncounterState.AVAILABLE)
	return true

func start_intro_dialogue() -> void:
	if current_state != EncounterState.AVAILABLE and current_state != EncounterState.COMPLETED:
		return
	_set_state(EncounterState.INTRO_DIALOGUE)
	var diag_graph: Dictionary = encounter_bundle.get("dialogue", {})
	var start_entry: String = "start"
	if diag_graph.has("entry_points") and diag_graph["entry_points"].has("world_start"):
		start_entry = diag_graph["entry_points"]["world_start"]
	dialogue_manager.start_dialogue(
		diag_graph,
		start_entry,
		DialogueManagerClass.DialogueSource.WORLD_INTERACTION,
		DialogueManagerClass.ResumePolicy.RETURN_TO_WORLD,
		{"character_id": character_name, "encounter_id": encounter_id}
	)

func start_combat() -> void:
	_set_state(EncounterState.COMBAT)
	combat_manager.start_combat()
	combat_started.emit()

func execute_player_action(action_id: String) -> void:
	var act: Dictionary = {
		"id": action_id,
		"action_name": "轻抚爱抚",
		"base_pleasure": 15.0,
		"target_zone": "mouth",
		"self_pleasure_defense": 0.2
	}
	if action_id == "edge":
		act = {
			"id": "edge",
			"action_name": "极意快感",
			"base_pleasure": 55.0,
			"target_zone": "clitoris",
			"self_pleasure_defense": 0.4
		}
	combat_manager.execute_player_action(act)

func start_result_dialogue(winner: String) -> void:
	_set_state(EncounterState.RESULT_DIALOGUE)
	last_battle_winner = winner
	var diag_graph: Dictionary = encounter_bundle.get("dialogue", {})
	var entry_key: String = "victory_settlement" if winner == "player" else "defeat_settlement"
	var start_entry: String = "victory_node"
	if diag_graph.has("entry_points") and diag_graph["entry_points"].has(entry_key):
		start_entry = diag_graph["entry_points"][entry_key]
	elif diag_graph.has("nodes") and diag_graph["nodes"].has(start_entry):
		pass
	elif diag_graph.has("entry_points") and diag_graph["entry_points"].has("world_start"):
		start_entry = diag_graph["entry_points"]["world_start"]

	dialogue_manager.start_dialogue(
		diag_graph,
		start_entry,
		DialogueManagerClass.DialogueSource.POST_BATTLE_RESULT,
		DialogueManagerClass.ResumePolicy.END_COMBAT,
		{"winner": winner, "encounter_id": encounter_id}
	)

func resolve_service_motion(interaction_type: String, furniture_list: Array = []) -> Dictionary:
	var motion_profile: Dictionary = encounter_bundle.get("motions", {})
	var ground_tf := Transform3D(Basis(), spawn_position)
	return MotionResolverClass.resolve_motion(motion_profile, interaction_type, furniture_list, ground_tf)

func _set_state(new_state: EncounterState) -> void:
	var old_state := current_state
	current_state = new_state
	encounter_state_changed.emit(old_state, new_state)

func _on_text_updated(sp: String, tx: String, em: String) -> void:
	dialogue_updated.emit(sp, tx, em)

func _on_dialogue_ended(payload: Dictionary) -> void:
	var act: String = payload.get("action", "")
	if act == "enter_combat":
		start_combat()
	elif act in ["spare", "spare_virgin", "spare_honban", "kill", "finish_service"]:
		settlement_outcome = act
		_set_state(EncounterState.SETTLEMENT)
		settlement_finished.emit(act)
		_set_state(EncounterState.COMPLETED)
	elif act == "close":
		if current_state == EncounterState.INTRO_DIALOGUE:
			_set_state(EncounterState.AVAILABLE)
		elif current_state == EncounterState.RESULT_DIALOGUE:
			_set_state(EncounterState.COMPLETED)

func _on_combat_ended(winner: String, _loser: String = "", _reason: String = "") -> void:
	combat_ended.emit(winner)
	start_result_dialogue(winner)
