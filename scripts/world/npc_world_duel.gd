extends Node

const Runtime := preload("res://scripts/world/npc_encounter_runtime.gd")
const WorldControl := preload("res://scripts/world/world_control_context.gd")

var runtime: Runtime
var world: Node3D
var anchor: Marker3D
var actor: Node3D
var panel: DialoguePanel
var hud: TurnCombatHUD
var prompt: Label

func initialize(host: Node3D, p_world: Node3D, p_runtime: Runtime) -> void:
	world = p_world
	runtime = p_runtime
	anchor = runtime.create_anchor(host, "DuelNPC")
	actor = runtime.create_idle_actor(anchor, "IdleActor", 33)
	add_to_group(WorldControl.GROUP_INPUT_BLOCKERS)

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
	prompt.text = "銆怑銆戜笌%s浜ゆ秹" % runtime.character_name
	prompt.set_anchor_and_offset(SIDE_LEFT, 0.0, 0.0)
	prompt.set_anchor_and_offset(SIDE_RIGHT, 1.0, 0.0)
	prompt.set_anchor_and_offset(SIDE_TOP, 0.72, 0.0)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 18)
	prompt.hide()
	canvas.add_child(prompt)

	var dialogue := runtime.dialogue_manager
	dialogue.text_updated.connect(panel.display_text)
	dialogue.choices_presented.connect(panel.display_choices)
	dialogue.dialogue_started.connect(func(_graph_id: String): panel.show())
	dialogue.dialogue_ended.connect(func(_payload: Dictionary):
		if not dialogue.session_active:
			panel.hide()
	)
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
	return runtime != null and runtime.current_state in [
		Runtime.EncounterState.INTRO_DIALOGUE,
		Runtime.EncounterState.COMBAT,
		Runtime.EncounterState.RESULT_DIALOGUE,
		Runtime.EncounterState.SETTLEMENT,
	]

func _can_interact() -> bool:
	return is_instance_valid(world) and world.test_ready and world.character_mode and not world.free_mode \
		and not world.has_llm_panel_open() and not world.encounter_ui_active and world.is_world_input_allowed() \
		and is_instance_valid(actor.character) and world.character.global_position.distance_to(anchor.global_position) < 2.6

func _process(_delta: float) -> void:
	prompt.visible = _can_interact()

func _unhandled_input(event: InputEvent) -> void:
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
	if busy:
		world.character.set_control_enabled(false)
