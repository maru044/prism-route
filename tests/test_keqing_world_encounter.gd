extends SceneTree
## Boots the same main scene as the title menu. Only travel and animation delays
## are shortened; dialogue input, actions, turns and outcome run normally.

const Runtime := preload("res://scripts/world/npc_encounter_runtime.gd")
const Combat := preload("res://scripts/combat/turn_combat_manager.gd")
const Motion := preload("res://scripts/world/motion_resolver.gd")

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)

func _run() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	world.automation_enabled = true
	root.add_child(world)
	current_scene = world
	var deadline := Time.get_ticks_msec() + 120000
	while not world.test_ready:
		if not _expect(Time.get_ticks_msec() < deadline, "World initialization timed out"):
			return
		await process_frame

	if not _expect(is_instance_valid(world.sandbar_duel) and is_instance_valid(world.initial_ruin.encounter), "World NPC adapters never mounted"):
		return
	var duel = world.sandbar_duel
	var runtime: Runtime = world.sandbar_duel_runtime
	var temple = world.initial_ruin
	var temple_runtime: Runtime = temple.encounter_runtime
	if not _expect(is_instance_valid(duel.actor.character) and is_instance_valid(duel.actor.skeleton)
			and duel.actor.model_resource == runtime.encounter_bundle.avatar.model_resource
			and duel.anchor.global_position.is_equal_approx(runtime.spawn_position)
			and is_equal_approx(duel.anchor.global_rotation.y, deg_to_rad(runtime.spawn_heading)),
			"Registered Keqing avatar/spawn was not used in the world"):
		return
	if not _expect(temple.npc_ready and temple.npc_anchor.global_position.is_equal_approx(temple_runtime.spawn_position)
			and temple.encounter.dialogue_manager == temple_runtime.dialogue_manager
			and temple.encounter.combat_manager == temple_runtime.combat_manager
			and temple_runtime.combat_manager.combat_strategy.profile_id == "sparkle_tutorial_combat",
			"Temple adapter did not adopt the shared runtime"):
		return
	print("WORLD_ACTORS_OK keqing=", duel.anchor.global_position, " sparkle=", temple.npc_anchor.global_position)

	var desk = world.sandbar_pavilion.furniture_instances.get("desk_01")
	var result := runtime.resolve_bound_service_motion("desk_service", world.sandbar_pavilion.furniture_instances, duel.anchor.global_transform)
	if not _expect(result.get("type") == "furniture" and result.furniture == desk
			and result.approach_anchor == desk.get_node("Anchor_Front")
			and result.contact_anchor == desk.get_node("Anchor_Desk_Surface"), "Keqing motion did not use the real desk"):
		return
	var seat = temple.furniture_instances.get("seat_01")
	var seat_motion := Motion.resolve_motion(temple_runtime.encounter_bundle.motions, "virgin", [seat])
	var bed = temple.furniture_instances.get("rest_01")
	var bed_motion := Motion.resolve_motion(temple_runtime.encounter_bundle.motions, "honban", [bed])
	if not _expect(seat_motion.get("type") == "furniture" and seat_motion.furniture == seat
			and seat_motion.role_b_target == seat.get_node("Anchor_Seat").global_transform
			and bed_motion.get("type") == "furniture" and bed_motion.furniture == bed
			and bed_motion.role_a_target == bed.get_node("Anchor_Bed_Center").global_transform,
			"Temple staging targets did not come from real furniture"):
		return
	print("WORLD_MOTION_ANCHORS_OK desk seat bed")

	world.character.global_position = duel.anchor.global_position + Vector3(0.5, 0.0, 1.2)
	await process_frame
	await process_frame
	if not _expect(duel.prompt.visible, "Keqing interaction prompt was not shown within range"):
		return
	_key(KEY_E)
	await process_frame
	var dialogue := runtime.dialogue_manager
	if not _expect(duel.panel.visible and dialogue.session_active
			and dialogue.current_session.character_id == "keqing"
			and dialogue.current_session.spawn_id == "sandbar_keqing"
			and dialogue.current_session.encounter_id == "sandbar_keqing", "Missing Keqing world dialogue session or IDs"):
		return
	_key(KEY_ENTER)
	_key(KEY_2)
	await process_frame
	var combat := runtime.combat_manager
	combat.animation_delays = false
	if not _expect(duel.hud.visible and not duel.panel.visible and combat.current_phase == Combat.Phase.PLAYER_INPUT
			and combat.combat_strategy.profile_id == "keqing_combat"
			and combat.combat_strategy.skill_ids.has("yunlai_sword"), "World dialogue did not enter Keqing's configured duel"):
		return

	var used_npc_turn := [false]
	combat.phase_changed.connect(func(phase: int):
		if phase == Combat.Phase.NPC_ACTION:
			used_npc_turn[0] = true
	)
	for i in range(16):
		if combat.is_resolved:
			break
		duel.hud._open_battle()
		duel.hud._show_group("toy")
		duel.hud._choose_action(duel.hud.ACTIONS.toy_vibe)
		await process_frame
	if not _expect(combat.is_resolved and used_npc_turn[0] and duel.panel.visible
			and runtime.current_state == Runtime.EncounterState.RESULT_DIALOGUE
			and dialogue.session_active, "Normal HUD actions did not produce a result dialogue"):
		return
	var winner := runtime.last_battle_winner
	# Result dialogue already uses a choice entry on victory, and text on defeat.
	if winner == "player":
		_key(KEY_2)
	else:
		_key(KEY_ENTER)
	await process_frame
	if not _expect(not duel.panel.visible and not duel.hud.visible and not dialogue.session_active
			and runtime.current_state == Runtime.EncounterState.COMPLETED and not world.encounter_ui_active
			and world.is_world_input_allowed() and world.character.is_physics_processing(),
			"Result action did not end the encounter and return world control"):
		return
	print("KEQING_WORLD_ENCOUNTER_PASS winner=", winner, " rounds=", combat.round_count)

	# Break a real temple furniture approach marker after acquiring the normal dialogue lock.
	var encounter = temple.encounter
	world.character.global_position = temple.npc_anchor.global_position + Vector3(0.5, 0.0, 1.2)
	await process_frame
	await process_frame
	if not _expect(temple.interact_prompt.visible, "Temple interaction prompt was not shown within range"):
		return
	encounter.start_encounter_dialogue()
	await process_frame
	if not _expect(encounter.dialogue_panel.visible and temple_runtime.dialogue_manager.current_session.character_id == "sparkle",
			"Temple did not start its registered dialogue session"):
		return
	var player_layer: int = world.character.collision_layer
	var player_mask: int = world.character.collision_mask
	var npc_layer: int = temple.npc_body.collision_layer
	var npc_mask: int = temple.npc_body.collision_mask
	var approach: Node3D = seat.get_node("Anchor_Front")
	approach.name = "Missing_For_Test"
	encounter._begin_furniture_service_staging("virgin")
	approach.name = "Anchor_Front"
	if not _expect(not encounter.dialogue_panel.visible and not world.encounter_ui_active and world.is_world_input_allowed()
			and world.character.is_physics_processing() and world.character.collision_layer == player_layer
			and world.character.collision_mask == player_mask and temple.npc_body.collision_layer == npc_layer
			and temple.npc_body.collision_mask == npc_mask and not temple_runtime.dialogue_manager.session_active,
			"Missing real anchor did not safely restore controls and collisions"):
		return
	print("TEMPLE_MISSING_ANCHOR_ABORT_PASS")
	world.queue_free()
	await process_frame
	await process_frame
	quit(0)
