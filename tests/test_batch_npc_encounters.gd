extends SceneTree

const Runtime := preload("res://scripts/world/npc_encounter_runtime.gd")
const Combat := preload("res://scripts/combat/turn_combat_manager.gd")
const Motion := preload("res://scripts/world/motion_resolver.gd")
const NPCSites := preload("res://scripts/world/npc_preview_sites.gd")

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
	print("--- Running test_batch_npc_encounters ---")
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

	var expected_ids := [
		"keqing",
		"ganyu",
		"yelan",
		"ningguang",
		"yae_miko",
		"raiden_shogun",
		"barbara",
		"jean",
		"furina",
		"tingyun"
	]

	var npcs_by_char: Dictionary = {}
	for node in interactive_npcs:
		if "runtime" in node and is_instance_valid(node.runtime):
			var char_id: String = node.runtime.encounter_bundle.get("character", {}).get("character_id", "")
			if not char_id.is_empty():
				npcs_by_char[char_id] = node

	# 1. Verify all 10 NPCs are present in the world
	for cid: String in expected_ids:
		if not _expect(npcs_by_char.has(cid), "Expected NPC '%s' was not mounted in world" % cid):
			return
	print("  ✓ All 10 NPCs mounted successfully in open world")

	# 2. Verify physics collision, avatar profiles, and zero-radius Jolt guards
	for cid: String in expected_ids:
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

		if not _expect(is_equal_approx(duel.anchor.global_rotation.y, deg_to_rad(runtime.spawn_heading)),
				"World heading does not match spawn definition for %s" % cid):
			return

	print("  ✓ All 10 NPCs passed collision layer 64, zero-radius Jolt guard, position and heading verification")

	# 3. Verify furniture bindings
	# Yelan on cafe_seat_01 (seat)
	var yelan_duel = npcs_by_char["yelan"]
	var cafe_seat = world.sandbar_pavilion.furniture_instances.get("cafe_seat_01")
	if not _expect(cafe_seat != null, "cafe_seat_01 missing in Sandbar Pavilion"):
		return
	var yelan_motion = yelan_duel.runtime.resolve_bound_service_motion("seat_service", world.sandbar_pavilion.furniture_instances, yelan_duel.anchor.global_transform)
	if not _expect(yelan_motion.get("found", false) and yelan_motion.get("type") == "furniture" and yelan_motion.furniture == cafe_seat,
			"Yelan seat_service did not resolve to cafe_seat_01"):
		return
	print("  ✓ Yelan bound furniture resolved to cafe_seat_01")

	# Ningguang on lounger_01 (bed)
	var ningguang_duel = npcs_by_char["ningguang"]
	var lounger = world.sandbar_pavilion.furniture_instances.get("lounger_01")
	if not _expect(lounger != null, "lounger_01 missing in Sandbar Pavilion"):
		return
	var ningguang_motion = ningguang_duel.runtime.resolve_bound_service_motion("bed_service", world.sandbar_pavilion.furniture_instances, ningguang_duel.anchor.global_transform)
	if not _expect(ningguang_motion.get("found", false) and ningguang_motion.get("type") == "furniture" and ningguang_motion.furniture == lounger,
			"Ningguang bed_service did not resolve to lounger_01"):
		return
	print("  ✓ Ningguang bound furniture resolved to lounger_01")

	# Furina on ground
	var furina_duel = npcs_by_char["furina"]
	var furina_motion = furina_duel.runtime.resolve_bound_service_motion("ground_service", {}, furina_duel.anchor.global_transform)
	if not _expect(furina_motion.get("found", false) and furina_motion.get("type") == "ground",
			"Furina ground_service did not resolve to ground"):
		return
	print("  ✓ Furina ground_service resolved to ground")

	# 4. Proximity prompt and dialogue session for Yelan
	world.character.global_position = yelan_duel.anchor.global_position + Vector3(0.5, 0.0, 1.2)
	await process_frame
	await process_frame
	if not _expect(yelan_duel.prompt.visible, "Yelan proximity prompt not shown"):
		return
	if not _expect(yelan_duel.prompt.text == "【E】与夜兰交涉", "Prompt text mismatch: " + yelan_duel.prompt.text):
		return
	print("  ✓ Proximity prompt verified: ", yelan_duel.prompt.text)

	_key(KEY_E)
	await process_frame
	if not _expect(yelan_duel.runtime.dialogue_manager.session_active, "Yelan dialogue session failed to start"):
		return
	yelan_duel.runtime.dialogue_manager.cancel_session()
	await process_frame
	if not _expect(not yelan_duel.runtime.dialogue_manager.session_active, "Yelan dialogue cancellation failed"):
		return
	print("  ✓ Dialogue start and cancel verified")

	# 5. Service staging activation and finish for Yelan (Seat)
	yelan_duel.begin_furniture_service_staging("seat_service")
	if not _expect(yelan_duel.is_service_active and is_instance_valid(yelan_duel.master_paired_actor),
			"Yelan seat service staging failed to activate"):
		return
	yelan_duel.finish_furniture_service()
	if not _expect(not yelan_duel.is_service_active and yelan_duel.actor.visible,
			"Yelan seat service failed to finish"):
		return
	print("  ✓ Yelan seat_service staging and finish verified")

	# 6. Service staging activation and finish for Ningguang (Bed)
	ningguang_duel.begin_furniture_service_staging("bed_service")
	if not _expect(ningguang_duel.is_service_active and is_instance_valid(ningguang_duel.master_paired_actor),
			"Ningguang bed service staging failed to activate"):
		return
	ningguang_duel.finish_furniture_service()
	if not _expect(not ningguang_duel.is_service_active and ningguang_duel.actor.visible,
			"Ningguang bed service failed to finish"):
		return
	print("  ✓ Ningguang bed_service staging and finish verified")

	# 7. Service staging activation and finish for Furina (Ground)
	furina_duel.begin_furniture_service_staging("ground_service")
	if not _expect(furina_duel.is_service_active and is_instance_valid(furina_duel.master_paired_actor),
			"Furina ground service staging failed to activate"):
		return
	furina_duel.finish_furniture_service()
	if not _expect(not furina_duel.is_service_active and furina_duel.actor.visible,
			"Furina ground service failed to finish"):
		return
	print("  ✓ Furina ground_service staging and finish verified")

	# 8. Settlement kill ragdoll and 30m respawn on Yelan
	yelan_duel._execute_settlement_kill()
	if not _expect(yelan_duel.is_ragdoll_active and is_instance_valid(yelan_duel.corpse_actor),
			"Yelan ragdoll failed to activate on settlement kill"):
		return
	world.character.global_position = yelan_duel.anchor.global_position + Vector3(35.0, 0.0, 0.0)
	await process_frame
	await process_frame
	if not _expect(not yelan_duel.is_ragdoll_active and yelan_duel.actor.visible,
			"Yelan failed to respawn after player moved beyond 30m"):
		return
	print("  ✓ Settlement kill ragdoll and 30m respawn verified")

	# 9. Two-stage progression & Cheats in Dialogue
	var graph: Dictionary = yelan_duel.runtime.encounter_bundle.dialogue
	var nodes: Dictionary = graph.nodes
	if not _expect(nodes.has("start") and nodes.has("start_unlocked"), "Missing start or start_unlocked node"):
		return
	if not _expect(nodes.has("mid_battle_manual") and nodes.has("mid_battle_manual_unlocked"), "Missing mid battle nodes"):
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
			"Unlocked mid-battle manual missing required in-battle cheats"):
		return
	print("  ✓ Two-stage progression and mid-battle cheats verified")

	print("\nALL BATCH NPC ENCOUNTER TESTS PASSED!")
	quit(0)
