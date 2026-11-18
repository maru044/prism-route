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
const ACTOR := preload("res://scenes/characters/shared_humanoid_actor.tscn")
const MTOON := preload("res://scripts/characters/mtoon_materials.gd")
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
var character_id: String = ""
var character_name: String = ""
var last_battle_winner: String = ""
var settlement_outcome: String = ""
var game_progress: RefCounted = null

func setup_encounter(p_encounter_id: String, adapter_manages_flow := false) -> bool:
	if current_state != EncounterState.UNINITIALIZED:
		return false
	encounter_id = p_encounter_id
	encounter_bundle = NPCRegistryClass.assemble_encounter(encounter_id)
	if not encounter_bundle.get("valid", false):
		push_error("[NPCEncounterRuntime] Failed to assemble encounter: " + str(encounter_bundle.get("error", "unknown")))
		return false

	var char_def: Dictionary = encounter_bundle["character"]
	var spawn_def: Dictionary = encounter_bundle["spawn"]
	character_id = encounter_bundle.get("identity", {}).get("character_id", char_def.get("character_id", ""))
	character_name = char_def.get("display_name", "NPC")

	var pos_arr: Array = spawn_def.get("position", [0, 0, 0])
	spawn_position = Vector3(pos_arr[0], pos_arr[1], pos_arr[2])
	spawn_heading = spawn_def.get("heading", 0.0)

	# 1. Dialogue Manager
	dialogue_manager = DialogueManagerClass.new()
	dialogue_manager.name = "DialogueManager"
	add_child(dialogue_manager)
	dialogue_manager.text_updated.connect(_on_text_updated)
	if not adapter_manages_flow:
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

	player_pleasure.character_name = "主人"
	npc_pleasure.character_name = character_name
	npc_pleasure.max_pleasure = float(encounter_bundle["combat"]["npc_max_pleasure"])
	var combat_strategy := NPCRegistryClass.create_strategy(encounter_bundle["combat"])

	# 4. Turn Combat Manager
	combat_manager = TurnCombatManagerClass.new()
	combat_manager.name = "CombatManager"
	add_child(combat_manager)
	combat_manager.setup(player_pleasure, npc_pleasure)
	combat_manager.configure_npc(character_name, reactions_dict, combat_strategy)
	if not adapter_manages_flow:
		combat_manager.combat_ended.connect(_on_combat_ended)
		combat_manager.mid_battle_dialogue_requested.connect(_on_negotiation)

	_set_state(EncounterState.AVAILABLE)
	return true

func create_flow_adapter() -> Node:
	var adapter_script: Script = load(encounter_bundle["flow_path"])
	return adapter_script.new() if adapter_script != null else null

func create_anchor(host: Node3D, anchor_name: String) -> Marker3D:
	var anchor := Marker3D.new()
	anchor.name = anchor_name
	host.add_child(anchor)
	anchor.global_position = spawn_position
	anchor.global_rotation.y = deg_to_rad(spawn_heading)
	anchor.set_meta("spawn_id", encounter_bundle["identity"]["spawn_id"])
	return anchor

func create_idle_actor(anchor: Marker3D, actor_name: String, environment: int) -> Node3D:
	var avatar: Dictionary = encounter_bundle["avatar"]
	var actor := ACTOR.instantiate()
	actor.name = actor_name
	actor.model_resource = avatar["model_resource"]
	actor.motion_resource = avatar["idle_motion"]
	actor.environment_mask = environment
	actor.auto_play = true
	actor.initialized.connect(func(): MTOON.apply(actor.character, avatar["material_id"]))
	anchor.add_child(actor)
	return actor

func start_dialogue(graph: Dictionary, node: String, source: int, policy: int, context: Dictionary = {}) -> void:
	dialogue_manager.start_dialogue(graph, node, source, policy, context, {}, {}, encounter_bundle["identity"])

func start_intro_dialogue() -> void:
	if current_state != EncounterState.AVAILABLE and current_state != EncounterState.COMPLETED:
		return
	_set_state(EncounterState.INTRO_DIALOGUE)
	var diag_graph: Dictionary = encounter_bundle.get("dialogue", {})
	var start_entry: String = diag_graph["entry_points"]["world_start"]
	
	var is_unlocked := false
	if game_progress != null and game_progress.has_method("is_companion_unlocked") and not character_id.is_empty():
		is_unlocked = game_progress.is_companion_unlocked(character_id)
		
	if settlement_outcome == "kill" and diag_graph["entry_points"].has("post_kill"):
		start_entry = diag_graph["entry_points"]["post_kill"]
	elif settlement_outcome.begins_with("spare") and diag_graph["entry_points"].has("post_spare"):
		start_entry = diag_graph["entry_points"]["post_spare"]
	elif is_unlocked and diag_graph["entry_points"].has("unlocked_start"):
		start_entry = diag_graph["entry_points"]["unlocked_start"]
	start_dialogue(
		diag_graph,
		start_entry,
		DialogueManagerClass.DialogueSource.WORLD_INTERACTION,
		DialogueManagerClass.ResumePolicy.RETURN_TO_WORLD,
		{}
	)

func start_combat() -> void:
	_set_state(EncounterState.COMBAT)
	var is_unlocked := false
	if game_progress != null and game_progress.has_method("is_companion_unlocked") and not character_id.is_empty():
		is_unlocked = game_progress.is_companion_unlocked(character_id)
		
	var cheat_data: Dictionary = dialogue_manager.consume_battle_cheats() if dialogue_manager else {}
	var meta_rules := {
		"meta_cheat_mode": cheat_data.get("meta_cheat_mode", "none"),
		"is_unlocked": is_unlocked
	}
	combat_manager.start_combat(false, meta_rules)
	
	if is_unlocked:
		npc_pleasure.damage_taken_multiplier = 1.8
		player_pleasure.damage_taken_multiplier = 0.7
		combat_manager.log_message_emitted.emit("【识趣玩伴】%s深知自己的玩伴身份，身体对主人的抚弄格外敏感！" % character_name)
	else:
		npc_pleasure.damage_taken_multiplier = 1.0
		player_pleasure.damage_taken_multiplier = 1.0
		
	combat_started.emit()

func start_result_dialogue(winner: String) -> void:
	_set_state(EncounterState.RESULT_DIALOGUE)
	last_battle_winner = winner
	var diag_graph: Dictionary = encounter_bundle.get("dialogue", {})
	var entry_key: String = "victory_settlement" if winner == "player" else "defeat_settlement"
	var start_entry: String = diag_graph["entry_points"][entry_key]

	start_dialogue(
		diag_graph,
		start_entry,
		DialogueManagerClass.DialogueSource.POST_BATTLE_RESULT,
		DialogueManagerClass.ResumePolicy.END_COMBAT,
		{"winner": winner}
	)

func _on_negotiation(reason: String) -> void:
	var graph: Dictionary = encounter_bundle["dialogue"]
	var manual := reason == "player_manual_call"
	
	var is_unlocked := false
	if game_progress != null and game_progress.has_method("is_companion_unlocked") and not character_id.is_empty():
		is_unlocked = game_progress.is_companion_unlocked(character_id)
		
	var entry_key := "combat_manual" if manual else "combat_edging"
	if is_unlocked and manual and graph["entry_points"].has("combat_manual_unlocked"):
		entry_key = "combat_manual_unlocked"
		
	var entry: String = graph["entry_points"].get(entry_key, "")
	if entry.is_empty():
		combat_manager.resume_combat_after_dialogue(false, not manual)
		return
	var source := DialogueManagerClass.DialogueSource.MID_BATTLE_MANUAL if manual else DialogueManagerClass.DialogueSource.MID_BATTLE_EDGING
	var policy := DialogueManagerClass.ResumePolicy.SAME_TURN if manual else DialogueManagerClass.ResumePolicy.NEXT_TURN
	start_dialogue(graph, entry, source, policy)

func resolve_bound_service_motion(interaction_type: String, furniture_by_id: Dictionary, ground_tf: Transform3D) -> Dictionary:
	var furniture: Array = []
	for row: Dictionary in encounter_bundle["spawn"].get("bound_furniture", []):
		var instance: Node3D = furniture_by_id.get(row["id"])
		if is_instance_valid(instance) and instance.find_child(row["anchor"], true, false) != null:
			furniture.append(instance)
	return resolve_service_motion(interaction_type, furniture, ground_tf)

func resolve_service_motion(interaction_type: String, furniture_list: Array = [],
		ground_tf: Variant = null) -> Dictionary:
	var motion_profile: Dictionary = encounter_bundle.get("motions", {})
	if ground_tf == null:
		ground_tf = Transform3D(Basis(Vector3.UP, deg_to_rad(spawn_heading)), spawn_position)
	return MotionResolverClass.resolve_motion(motion_profile, interaction_type, furniture_list, ground_tf)

func _set_state(new_state: EncounterState) -> void:
	var old_state := current_state
	current_state = new_state
	encounter_state_changed.emit(old_state, new_state)

func _on_text_updated(sp: String, tx: String, em: String) -> void:
	dialogue_updated.emit(sp, tx, em)

func _on_dialogue_ended(payload: Dictionary) -> void:
	var act: String = payload.get("action", "")
	if current_state == EncounterState.COMBAT:
		var cheat_data: Dictionary = dialogue_manager.consume_battle_cheats() if dialogue_manager else {}
		var cheat_mode: String = cheat_data.get("meta_cheat_mode", "none")
		if cheat_mode == "distracted":
			combat_manager.npc_pleasure.damage_taken_multiplier = 2.5
			combat_manager.log_message_emitted.emit("【战中识趣】%s故意走神了！受到的快感倍率提升至 2.5 倍！" % character_name)
		elif cheat_mode == "lock_master_pleasure":
			combat_manager.player_pleasure.pleasure_locked = true
			combat_manager.player_pleasure.pleasure_cap = 90.0
			combat_manager.log_message_emitted.emit("【战中识趣】%s施加了保护！主人的快感上限被锁定在90%%！" % character_name)
		elif cheat_mode == "reduce_damage":
			combat_manager.player_pleasure.damage_taken_multiplier = 0.4
			combat_manager.log_message_emitted.emit("【战中识趣】防线强化！主人受到的快感大幅降低！")
			
		if cheat_data.get("edging_endure", false):
			combat_manager.temporary_defense_modifier = 0.5
			combat_manager.log_message_emitted.emit("【咬牙忍耐】主人集中精神咬牙忍耐，本轮快感减免 50%！")
			
		var instant: bool = (cheat_mode == "instant_surrender" or act == "surrender")
		var next_turn: bool = payload.get("resume_policy") == DialogueManagerClass.ResumePolicy.NEXT_TURN
		combat_manager.resume_combat_after_dialogue(instant, next_turn)
	elif act == "enter_combat":
		start_combat()
	elif act in ["spare_desk", "desk_service"]:
		settlement_outcome = act
		_set_state(EncounterState.SETTLEMENT)
		settlement_finished.emit(act)
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

func finish_service() -> void:
	if current_state == EncounterState.SETTLEMENT:
		_set_state(EncounterState.COMPLETED)

func abort_service(reason: String = "") -> void:
	settlement_outcome = "aborted" if reason.is_empty() else "aborted_" + reason
	if current_state in [EncounterState.SETTLEMENT, EncounterState.RESULT_DIALOGUE]:
		_set_state(EncounterState.COMPLETED)

func _on_combat_ended(winner: String, _loser: String = "", _reason: String = "") -> void:
	combat_ended.emit(winner)
	start_result_dialogue(winner)
