extends SceneTree

const Runtime := preload("res://scripts/world/npc_encounter_runtime.gd")

func _initialize() -> void:
	_run.call_deferred()

func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		print("FAILED: " + message)
		quit(1)
	return condition

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)

func _run() -> void:
	print("--- Running test_batch_4_npc_encounters ---")
	var world = load("res://scenes/main.tscn").instantiate()
	world.automation_enabled = true
	root.add_child(world)
	current_scene = world
	var deadline := Time.get_ticks_msec() + 120000
	while not world.test_ready:
		if not _expect(Time.get_ticks_msec() < deadline, "World initialization timed out"):
			return
		await process_frame

	var interactive_npcs: Array[Node] = root.get_tree().get_nodes_in_group("world_interactive_npcs")
	print("Total interactive NPCs mounted: ", interactive_npcs.size())

	var batch_4_ids := [
		"fu_xuan",
		"qingque",
		"miyabi",
		"bronya",
		"seele",
		"jingliu",
		"kafka",
		"firefly",
		"mona",
		"lynette",
		"fischl",
		"shenhe",
		"amber",
		"eula",
		"charlotte",
		"sucrose",
		"lumine"
	]

	var npcs_by_char: Dictionary = {}
	for node in interactive_npcs:
		if "runtime" in node and is_instance_valid(node.runtime):
			var char_id: String = node.runtime.encounter_bundle.get("character", {}).get("character_id", "")
			if not char_id.is_empty():
				npcs_by_char[char_id] = node

	# 1. Verify all 17 Batch 4 NPCs are mounted in the world
	for cid: String in batch_4_ids:
		if not _expect(npcs_by_char.has(cid), "Batch 4 NPC '%s' was not mounted in world" % cid):
			return
	print("  ✓ All 17 Batch 4 NPCs mounted successfully in open world (Total: %d)" % interactive_npcs.size())

	# 2. Verify physics collision, avatar profiles, and zero-radius Jolt guards
	for cid: String in batch_4_ids:
		var duel = npcs_by_char[cid]
		var runtime: Runtime = duel.runtime

		if not _expect(is_instance_valid(duel.actor.character) and is_instance_valid(duel.actor.skeleton),
				"Actor character or skeleton invalid for %s" % cid):
			return

		if not _expect(is_instance_valid(duel.npc_body) and duel.npc_body.collision_layer == 64,
				"Collision layer must be 64 (NPC_SOLID_LAYER) for %s" % cid):
			return

		if not _expect(duel.actor.environment_collision_enabled == false,
				"environment_collision_enabled must be false for %s" % cid):
			return

		for spring in duel.actor.all_springs:
			if not _expect(spring.enable_environment_collision == false,
					"Spring enable_environment_collision must be false for %s" % cid):
				return

		if not _expect(duel.anchor.global_position.is_equal_approx(runtime.spawn_position),
				"World position does not match spawn definition for %s" % cid):
			return

		if not _expect(is_equal_approx(cos(duel.anchor.global_rotation.y), cos(deg_to_rad(runtime.spawn_heading)))
				and is_equal_approx(sin(duel.anchor.global_rotation.y), sin(deg_to_rad(runtime.spawn_heading))),
				"World heading does not match spawn definition for %s" % cid):
			return

	print("  ✓ All 17 Batch 4 NPCs passed collision layer 64, zero-radius Jolt guard, position and heading verification")

	# 3. Verify service motion resolution
	for cid: String in batch_4_ids:
		var d = npcs_by_char[cid]
		var motion = d.runtime.resolve_bound_service_motion("ground_service", {}, d.anchor.global_transform)
		if not _expect(motion.get("found", false) and motion.get("type") == "ground",
				"%s ground_service did not resolve to ground" % cid):
			return
	print("  ✓ Ground service verified for all 17 Batch 4 NPCs")

	# 4. Proximity prompt and dialogue session for Fu Xuan
	var fu_xuan_duel = npcs_by_char["fu_xuan"]
	world.character.global_position = fu_xuan_duel.anchor.global_position + fu_xuan_duel.anchor.global_transform.basis * Vector3(0.0, 0.0, -1.2)
	await process_frame
	await process_frame
	if not _expect(fu_xuan_duel.prompt.visible, "Fu Xuan proximity prompt not shown"):
		return
	if not _expect(fu_xuan_duel.prompt.text == "【E】与符玄交涉", "Prompt text mismatch: " + fu_xuan_duel.prompt.text):
		return
	print("  ✓ Proximity prompt verified: ", fu_xuan_duel.prompt.text)

	_key(KEY_E)
	await process_frame
	if not _expect(fu_xuan_duel.runtime.dialogue_manager.session_active, "Fu Xuan dialogue session failed to start"):
		return
	fu_xuan_duel.runtime.dialogue_manager.cancel_session()
	await process_frame
	if not _expect(not fu_xuan_duel.runtime.dialogue_manager.session_active, "Fu Xuan dialogue cancellation failed"):
		return
	print("  ✓ Dialogue start and cancel verified")

	# 5. Victory dialogue and staged settlement outcome
	for character_id: String in batch_4_ids:
		var duel = npcs_by_char[character_id]
		var runtime: Runtime = duel.runtime
		var action := "spare_ground"
		var player_layer: int = world.character.collision_layer
		var player_mask: int = world.character.collision_mask
		runtime.start_result_dialogue("player")
		await process_frame
		var dialogue := runtime.dialogue_manager
		var choices: Array = dialogue.current_graph.nodes[dialogue.current_node_id].choices
		var index := choices.find_custom(func(choice: Dictionary) -> bool: return choice.get("action") == action)
		if not _expect(index >= 0 and duel.panel.visible, "%s victory option is unavailable" % character_id):
			return
		_key(KEY_1 + index)
		await process_frame
		if not _expect(runtime.current_state == Runtime.EncounterState.SETTLEMENT
				and runtime.settlement_outcome == action and duel.is_service_active
				and is_instance_valid(duel.master_paired_actor) and not world.is_world_input_allowed()
				and world.game_progress.is_companion_unlocked(character_id),
				"%s victory option did not enter and lock staging" % character_id):
			return
		_key(KEY_E)
		await process_frame
		if not _expect(runtime.current_state == Runtime.EncounterState.COMPLETED
				and not dialogue.session_active and not duel.is_service_active and duel.actor.visible
				and world.is_world_input_allowed() and world.character.is_control_enabled()
				and world.character.visible and world.character.camera.current
				and world.character.collision_layer == player_layer and world.character.collision_mask == player_mask,
				"%s stage exit did not restore exploration" % character_id):
			return
		print("  ✓ ", character_id, " victory and exit verified: ", action)

	# 6. Settlement kill ragdoll and 30m respawn on Fu Xuan
	fu_xuan_duel._execute_settlement_kill()
	if not _expect(fu_xuan_duel.is_ragdoll_active and is_instance_valid(fu_xuan_duel.corpse_actor),
			"Fu Xuan ragdoll failed to activate on settlement kill"):
		return
	world.character.global_position = fu_xuan_duel.anchor.global_position + Vector3(35.0, 0.0, 0.0)
	await process_frame
	await process_frame
	if not _expect(not fu_xuan_duel.is_ragdoll_active and fu_xuan_duel.actor.visible,
			"Fu Xuan failed to respawn after player moved beyond 30m"):
		return
	print("  ✓ Settlement kill ragdoll and 30m respawn verified on Fu Xuan")

	# 7. Two-stage progression & Cheats in Dialogue
	for cid: String in batch_4_ids:
		var duel = npcs_by_char[cid]
		var graph: Dictionary = duel.runtime.encounter_bundle.dialogue
		var nodes: Dictionary = graph.nodes
		if not _expect(nodes.has("start") and nodes.has("start_unlocked"), "%s missing start or start_unlocked node" % cid):
			return
		if not _expect(nodes.has("mid_battle_manual") and nodes.has("mid_battle_manual_unlocked"), "%s missing mid battle nodes" % cid):
			return

		var unlocked_choices: Array = nodes["mid_battle_manual_unlocked"].choices
		var has_distracted := false
		var has_lock := false
		var has_surrender := false
		for choice: Dictionary in unlocked_choices:
			var bb: Dictionary = choice.get("set_blackboard", {})
			if bb.get("meta_cheat_mode") == "distracted":
				has_distracted = true
			elif bb.get("meta_cheat_mode") == "lock_master_pleasure":
				has_lock = true
			elif bb.get("meta_cheat_mode") == "instant_surrender":
				has_surrender = true

		if not _expect(has_distracted and has_lock and has_surrender,
				"%s unlocked mid-battle manual missing required in-battle cheats" % cid):
			return
	print("  ✓ Two-stage progression and mid-battle cheats verified for all 17 Batch 4 NPCs")

	print("\nALL BATCH 4 NPC ENCOUNTER TESTS PASSED!")
	quit(0)
