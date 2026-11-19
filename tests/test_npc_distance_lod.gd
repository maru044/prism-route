extends SceneTree

const MAP_SCENE := preload("res://scenes/map_1021.tscn")

func _init() -> void:
	print("--- Running test_npc_distance_lod ---")
	call_deferred("_run")

func _expect(cond: bool, msg: String) -> bool:
	if not cond:
		push_error("TEST FAILED: " + msg)
		print("  ✗ FAIL: ", msg)
		quit(1)
		return false
	return true

func _run() -> void:
	var root_node := Node3D.new()
	root_node.name = "TestRoot"
	root.add_child(root_node)

	var map := MAP_SCENE.instantiate()
	root_node.add_child(map)

	for i in range(10):
		await process_frame

	var npcs := get_nodes_in_group("world_interactive_npcs")
	if not _expect(npcs.size() == 47, "Expected 47 interactive NPCs, got %d" % npcs.size()):
		return

	var npcs_by_char := {}
	for npc in npcs:
		if npc.get("runtime"):
			npcs_by_char[npc.runtime.character_id] = npc

	# 1. Initial State: Player is spawned near initial ruin / temple.
	# Faraway NPCs must be inactive.
	var keqing_duel = npcs_by_char.get("keqing")
	var ganyu_duel = npcs_by_char.get("ganyu")
	var yae_miko_duel = npcs_by_char.get("yae_miko")
	var kafka_duel = npcs_by_char.get("kafka")

	var active_count := 0
	for npc in npcs:
		if npc.is_npc_active:
			active_count += 1
	print("Initial active NPCs near player: %d / 47" % active_count)
	if not _expect(active_count <= 6, "Expected at most 6 active NPCs at spawn, got %d" % active_count):
		return
	if not _expect(not keqing_duel.is_npc_active and not keqing_duel.actor.visible, "Keqing should be inactive when far"):
		return
	if not _expect(not yae_miko_duel.is_npc_active and not yae_miko_duel.actor.visible, "Yae Miko should be inactive when far"):
		return
	print("  ✓ Faraway NPCs are properly deactivated on map startup")

	# 2. Teleport to Sandbar Pavilion (near Keqing and Ganyu)
	var sandbar_pos: Vector3 = keqing_duel.anchor.global_position + Vector3(1.0, 0.0, 0.0)
	map.character.global_position = sandbar_pos
	# Allow LOD check to trigger
	await process_frame
	await process_frame

	if not _expect(keqing_duel.is_npc_active and keqing_duel.actor.visible, "Keqing should activate when player approaches"):
		return
	if not _expect(ganyu_duel.is_npc_active and ganyu_duel.actor.visible, "Ganyu should activate when player approaches"):
		return
	if not _expect(not yae_miko_duel.is_npc_active and not yae_miko_duel.actor.visible, "Yae Miko should still be inactive"):
		return
	print("  ✓ Sandbar NPCs (Keqing, Ganyu) activated upon arrival")

	# 3. Check proximity interaction works for active NPC
	map.character.global_position = keqing_duel.anchor.global_position + keqing_duel.anchor.global_transform.basis * Vector3(0.0, 0.0, -1.2)
	await process_frame
	await process_frame
	if not _expect(keqing_duel.prompt.visible, "Keqing prompt should show when in interaction distance"):
		return
	print("  ✓ Proximity interaction prompt verified for active NPC: ", keqing_duel.prompt.text)

	# 4. Teleport away beyond unload radius (e.g. 150m away from Sandbar)
	map.character.global_position = sandbar_pos + Vector3(150.0, 0.0, 0.0)
	await process_frame
	await process_frame

	if not _expect(not keqing_duel.is_npc_active and not keqing_duel.actor.visible, "Keqing should deactivate when player moves beyond unload radius"):
		return
	if not _expect(not keqing_duel.prompt.visible, "Keqing prompt must be hidden when inactive"):
		return
	print("  ✓ NPCs cleanly deactivate and hide prompt when player departs beyond unload radius")

	# 5. Test set_npc_lod_enabled toggle
	map.set_npc_lod_enabled(false)
	await process_frame
	var all_active := 0
	for npc in npcs:
		if npc.is_npc_active and npc.actor.visible:
			all_active += 1
	if not _expect(all_active == 47, "Expected all 47 NPCs active when LOD disabled, got %d" % all_active):
		return
	print("  ✓ set_npc_lod_enabled(false) restored all 47 NPCs to active")

	map.set_npc_lod_enabled(true)
	await process_frame
	var lod_active := 0
	for npc in npcs:
		if npc.is_npc_active:
			lod_active += 1
	if not _expect(lod_active <= 6, "Expected at most 6 active NPCs when LOD re-enabled, got %d" % lod_active):
		return
	print("  ✓ set_npc_lod_enabled(true) re-applied distance LOD")

	print("\nALL NPC DISTANCE LOD TESTS PASSED!")
	quit(0)
