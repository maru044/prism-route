extends SceneTree
## Full end-to-end verification of Sparkle Temple Encounter in the actual Overworld (scenes/main.tscn).
## Verifies:
## 1. First encounter & [E] interaction in Overworld
## 2. Enter combat with dual blowjob animation
## 3. In-battle negotiation with explicit DialogueContext (non-exiting)
## 4. Defeat & respawn at doorway without forced dialogue (player regains free movement)
## 5. Player walks across temple to Sparkle and presses [E] to initiate second-attempt dialogue
## 6. Victory settlement (Spare / Kill) reaching COMPLETED encounter state

func _init() -> void:
	call_deferred("_verify_input_layout" if "--verify-temple-input-layout" in OS.get_cmdline_user_args() else "_run_overworld_flow")

func _get_capture_dir() -> String:
	var custom_dir := OS.get_environment("PRISM_CAPTURE_DIR")
	if not custom_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(custom_dir)
		return custom_dir.trim_suffix("/") + "/"
	var default_dir := ProjectSettings.globalize_path("res://.current_map_build/captures/")
	DirAccess.make_dir_recursive_absolute(default_dir)
	return default_dir

func _save_screenshot(img: Image, file_name: String) -> void:
	if img == null or img.is_empty():
		return
	var target_dir := _get_capture_dir()
	var path := target_dir + file_name
	img.save_png(path)
	print("Saved screenshot to: ", path)

	# Also sync to conversation brain directory if present
	var brain_dir := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/"
	if DirAccess.dir_exists_absolute(brain_dir):
		img.save_png(brain_dir + file_name)

func _wait_for_screenshot_draw() -> void:
	if DisplayServer.get_name() == "headless":
		for i in range(2):
			await process_frame
	else:
		await _wait_for_screenshot_draw()

func _run_overworld_flow() -> void:
	root.size = Vector2i(1920, 1080)
	var main_scene = load("res://scenes/main.tscn")
	var world = main_scene.instantiate()
	root.add_child(world)

	print("Waiting for world to initialize")
	while not world.test_ready or not world.initial_ruin or not world.initial_ruin.npc_ready:
		await process_frame

	for i in range(30):
		await process_frame

	var ruin = world.initial_ruin
	var player = world.character
	var encounter = ruin.encounter
	print("World ready! Player pos: ", player.global_position, " Sparkle pos: ", ruin.npc_anchor.global_position)
	assert(encounter != null, "InitialTempleEncounterController must be attached")

	# Step 1: Approach Sparkle in temple
	var near_pos: Vector3 = ruin.npc_anchor.global_position + Vector3(0.5, 0.0, 1.2)
	player.global_position = near_pos
	for i in range(10):
		await process_frame

	print("Player moved close. interact_prompt visible: ", ruin.interact_prompt.visible)
	assert(ruin.interact_prompt.visible, "Interact prompt should be visible near Sparkle")

	# Step 2: Trigger [E] interaction to start in-world dialogue
	encounter.start_encounter_dialogue()
	for i in range(10):
		await process_frame
	print("Dialogue started. DialoguePanel visible: ", ruin.dialogue_panel.visible)
	assert(ruin.dialogue_panel.visible, "DialoguePanel should be visible in world")
	assert(player.animation_state == "idle", "Player animation state must be idle during dialogue")
	print("Player animation during dialogue verified: ", player.animation_state)

	# Advance dialogue and choose combat
	encounter.dialogue_manager.advance_text()
	encounter.dialogue_manager.advance_text()
	for i in range(5):
		await process_frame
	encounter.dialogue_manager.choose_option(3) # Enter combat

	# Wait for seamless combat staging transition to complete
	while encounter.current_state != encounter.EncounterState.COMBAT:
		await process_frame

	print("Combat active. Combat actors visible: ", encounter.combat_actors_root.visible)
	assert(encounter.combat_actors_root.visible, "Dual combat actors should be visible")
	assert(encounter.combat_hud.visible, "Combat HUD should be visible")
	assert(encounter.current_state == encounter.EncounterState.COMBAT, "State must be COMBAT")

	# Capture Overworld dual blowjob battle
	await _wait_for_screenshot_draw()
	_save_screenshot(root.get_texture().get_image(), "overworld_temple_dual_blowjob_combat.png")

	# Step 3: Mid-battle negotiation in Overworld
	encounter.combat_manager.request_in_battle_negotiation()
	for i in range(15):
		await process_frame
	print("Mid-battle dialogue requested. HUD visible: ", ruin.combat_hud.visible, " Panel visible: ", ruin.dialogue_panel.visible)
	assert(ruin.combat_hud.visible, "HUD must remain visible during mid-battle dialogue")
	assert(ruin.dialogue_panel.visible, "DialoguePanel must be floating over HUD")

	# Capture Overworld mid-battle negotiation
	await _wait_for_screenshot_draw()
	_save_screenshot(root.get_texture().get_image(), "overworld_temple_mid_battle_negotiation.png")

	# Advance text -> choices -> choose "【返回对决】" (choice 3)
	encounter.dialogue_manager.advance_text()
	for i in range(5):
		await process_frame
	encounter.dialogue_manager.choose_option(3) # 返回对决
	for i in range(10):
		await process_frame
	assert(not ruin.dialogue_panel.visible, "DialoguePanel should hide after returning to combat")
	assert(ruin.combat_hud.visible, "Combat HUD should remain active")
	print("Mid-battle negotiation smoothly returned to combat!")

	# Step 4: Simulate Master defeat in Round 1 (Teaching Kill)
	print("Simulating Master defeat in Overworld")
	encounter.player_pleasure.add_pleasure(100.0)
	encounter.combat_manager._check_battle_state()

	# Wait for defeat resolution
	for i in range(80):
		await process_frame

	print("After defeat, player pos: ", player.global_position)
	print("Expected doorway respawn: ", encounter.RESPAWN_POINT)
	var respawn_dist = player.global_position.distance_to(encounter.RESPAWN_POINT)
	print("Distance to doorway: ", respawn_dist)
	assert(respawn_dist < 1.0, "Player must be at doorway entrance")
	assert(not ruin.dialogue_panel.visible, "Dialogue must NOT be forcibly opened at the door!")
	assert(not ruin.is_in_dialogue_or_combat, "Player must have full freedom of movement!")

	# Capture doorway respawn perspective where player has full control
	await _wait_for_screenshot_draw()
	_save_screenshot(root.get_texture().get_image(), "overworld_temple_respawn_free_movement.png")

	# Step 5: Player walks across temple over to Sparkle
	print("Player physically walking across the temple towards Sparkle")
	player.global_position = near_pos
	for i in range(15):
		await process_frame

	print("Player arrived in front of Sparkle. interact_prompt visible: ", ruin.interact_prompt.visible)
	assert(ruin.interact_prompt.visible, "Interact prompt should appear when walking up to Sparkle again")

	# Step 6: Player presses [E] to talk
	encounter.start_encounter_dialogue()
	for i in range(10):
		await process_frame

	print("Second encounter dialogue started! DialoguePanel visible: ", ruin.dialogue_panel.visible)
	assert(ruin.dialogue_panel.visible, "DialoguePanel should open on manual interaction")
	assert(encounter.defeat_count == 1, "Defeat count should be 1")

	# Capture second-attempt dialogue in front of Sparkle
	await _wait_for_screenshot_draw()
	_save_screenshot(root.get_texture().get_image(), "overworld_temple_second_encounter_dialogue.png")

	# Step 7: Advance second-encounter choices and select instant surrender to test settlement
	encounter.dialogue_manager.advance_text()
	for i in range(5):
		await process_frame
	encounter.dialogue_manager.choose_option(3) # 【特权命令】直接认输
	encounter.dialogue_manager.advance_text()
	for i in range(5):
		await process_frame
	encounter.dialogue_manager.choose_option(0) # 开战

	while encounter.current_state != encounter.EncounterState.RESULT_DIALOGUE:
		await process_frame

	# Combat ends immediately with Sparkle defeated -> Victory dialogue
	assert(encounter.current_state == encounter.EncounterState.RESULT_DIALOGUE, "State should be RESULT_DIALOGUE")
	encounter.dialogue_manager.advance_text()
	encounter.dialogue_manager.advance_text()
	for i in range(5):
		await process_frame

	# Test Kill Branch settlement and physical corpse
	print("Testing Kill Branch settlement and physical corpse:")
	encounter.dialogue_manager.choose_option(0) # 【杀掉】

	while encounter.current_state != encounter.EncounterState.COMPLETED:
		await process_frame

	for i in range(15):
		await process_frame

	assert(encounter.is_ragdoll_active == true, "Ragdoll must be active after kill")
	assert(encounter.corpse_actor.visible == true, "Corpse actor must be visible after kill")
	assert(encounter.corpse_actor.physical_bones.size() == 16, "Corpse must have 16 physical bones")
	assert(encounter.npc_avatar.visible == false, "Living NPC avatar must be hidden")
	assert(ruin.npc_body.collision_layer == 0, "Standing NPC collision must be disabled")
	assert(encounter.companion_unlocked == true, "Companion must also be unlocked after kill")
	print("Kill settlement verified: Corpse spawned at ", encounter.get_corpse_position())

	# Capture corpse ragdoll screenshot
	await _wait_for_screenshot_draw()
	_save_screenshot(root.get_texture().get_image(), "overworld_temple_sparkle_corpse_ragdoll.png")

	# Test respawn when leaving 30m
	print("Simulating player walking 35m away from corpse:")
	player.global_position = encounter.get_corpse_position() + Vector3(35.0, 0.0, 0.0)
	for i in range(10):
		await process_frame

	assert(encounter.is_ragdoll_active == false, "Ragdoll must be inactive after leaving 30m")
	assert(encounter.corpse_actor.visible == false, "Corpse must be hidden after respawn")
	assert(encounter.npc_avatar.visible == true, "Living avatar must be restored")
	assert(ruin.npc_body.collision_layer == 64, "Standing collision must be restored")
	assert(encounter.current_state == encounter.EncounterState.AVAILABLE, "State must be reset to AVAILABLE")
	print("Leaving 30m successfully respawned Sparkle!")

	# Test Dynamic NPC tracking when NPC moves
	print("Testing dynamic NPC interaction position tracking:")
	var original_npc_pos: Vector3 = encounter.get_npc_interaction_position()
	ruin.npc_anchor.position += Vector3(2.0, 0.0, 1.0)
	for i in range(5):
		await process_frame
	var moved_npc_pos: Vector3 = encounter.get_npc_interaction_position()
	assert(moved_npc_pos != original_npc_pos, "NPC interaction position must follow NPC movement")
	print("NPC moved to: ", moved_npc_pos)

	# Move player to moved NPC position
	player.global_position = moved_npc_pos + Vector3(0.5, 0.0, 1.2)
	for i in range(10):
		await process_frame
	assert(ruin.interact_prompt.visible, "Interact prompt must follow moved NPC")
	print("Interact prompt dynamically follows moved NPC!")

	# Trigger dialogue with moved NPC, enter combat, and test Spare branch
	encounter.start_encounter_dialogue()
	for i in range(5):
		await process_frame
	encounter.dialogue_manager.advance_text()
	for i in range(5):
		await process_frame
	encounter.dialogue_manager.choose_option(0) # 再次对决 (enter_combat)
	while encounter.current_state != encounter.EncounterState.COMBAT:
		await process_frame

	# Simulate instant win for spare verification
	encounter.npc_pleasure.add_pleasure(100.0)
	encounter.combat_manager._check_battle_state()

	while encounter.current_state != encounter.EncounterState.RESULT_DIALOGUE:
		await process_frame

	encounter.dialogue_manager.advance_text()
	encounter.dialogue_manager.advance_text()
	for i in range(5):
		await process_frame
	encounter.dialogue_manager.choose_option(1) # 【放过】
	encounter.dialogue_manager.advance_text()
	for i in range(5):
		await process_frame
	encounter.dialogue_manager.choose_option(0)
	encounter.dialogue_manager.advance_text()
	for i in range(5):
		await process_frame
	encounter.dialogue_manager.choose_option(0)

	while encounter.current_state != encounter.EncounterState.FURNITURE_SERVICE_ACTIVE:
		await process_frame

	assert(encounter.current_state == encounter.EncounterState.FURNITURE_SERVICE_ACTIVE, "Must reach FURNITURE_SERVICE_ACTIVE")
	assert(encounter.combat_actors_root.visible == true, "Dual actors must be visible on furniture")
	assert(encounter.service_hud.visible == true, "Service HUD must be visible")
	print("Furniture service active on seat_01! Capturing screenshot")

	await _wait_for_screenshot_draw()
	_save_screenshot(root.get_texture().get_image(), "overworld_temple_furniture_service.png")

	encounter._finish_furniture_service()
	for i in range(10):
		await process_frame

	assert(encounter.current_state == encounter.EncounterState.COMPLETED, "State must reach COMPLETED")
	assert(encounter.companion_unlocked == true, "Companion must be unlocked")
	print("Victory and Spare settlement reached COMPLETED state successfully!")

	print("=== ALL OVERWORLD TEMPLE WORKFLOW CHECKS PASSED 100%! ===")
	quit(0)

# Neutral UI + real world geometry regression; does not start narrative/combat.
var input_layout_failures: Array[String] = []
func _input_layout_expect(ok: bool, message: String) -> void:
	if not ok:
		input_layout_failures.append(message)
		push_error(message)

func _audit_key(code: Key, pressed := true, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)

func _verify_input_layout() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	world.automation_enabled = true
	root.add_child(world)
	var deadline := Time.get_ticks_msec() + 90000
	while not world.test_ready or not world.initial_ruin.npc_ready:
		await process_frame
		if Time.get_ticks_msec() > deadline:
			push_error("Temple input/layout initialization timed out")
			quit(2)
			return
	var ruin = world.initial_ruin
	var encounter = ruin.encounter
	# Only pause these diagnostic instances; no production lifecycle changes.
	encounter.sparkle_combat_actor.auto_play = false
	encounter.master_combat_actor.auto_play = false
	var panel = encounter.dialogue_panel
	var actor = world.character
	actor.set_control_enabled(false)
	encounter.current_state = encounter.EncounterState.INTRO_DIALOGUE
	panel.visible = true
	panel.display_choices([{"text": "Audit choice 1"}, {"text": "Audit choice 2"}])
	var chosen: Array = []
	var close_on_choice := [false]
	panel.option_selected.connect(func(index: int):
		chosen.append(index)
		if close_on_choice[0]: panel.visible = false)
	var before_id: String = actor.active_character_id
	var before_spawn: int = world.spawn_index
	var before_position: Vector3 = actor.global_position
	_audit_key(KEY_2)
	for frame in 3: await process_frame
	_input_layout_expect(chosen == [1], "Digit 2 did not select dialogue option 2 exactly once")
	_input_layout_expect(actor.active_character_id == before_id, "Dialogue key changed character")
	_input_layout_expect(world.spawn_index == before_spawn and actor.global_position.distance_to(before_position) < 0.001, "Dialogue key teleported player")
	_input_layout_expect(not actor.is_physics_processing(), "Dialogue key re-enabled player controls")
	_audit_key(KEY_2, true, true)
	_audit_key(KEY_2, false)
	_audit_key(KEY_9)
	_audit_key(KEY_9, false)
	_audit_key(KEY_TAB)
	_audit_key(KEY_TAB, false)
	_audit_key(KEY_F)
	_audit_key(KEY_F, false)
	actor.switch_wheel._trigger_switch("ganyu" if before_id != "ganyu" else "lumine")
	for frame in 3: await process_frame
	_input_layout_expect(chosen == [1], "Repeat or invalid digit selected another option")
	_input_layout_expect(actor.active_character_id == before_id and world.spawn_index == before_spawn and not world.free_mode, "World/HUD shortcut leaked through dialogue")
	# Selection closes the panel synchronously: the same key must still be consumed.
	close_on_choice[0] = true
	_audit_key(KEY_1)
	_audit_key(KEY_1, false)
	for frame in 3: await process_frame
	_input_layout_expect(chosen == [1, 0] and not panel.visible, "Closing dialogue selection did not complete")
	_input_layout_expect(actor.active_character_id == before_id and world.spawn_index == before_spawn, "Closing selection leaked into world shortcuts")
	panel.visible = true
	panel.display_text("Audit", "Neutral input verification")
	var next_count := [0]
	panel.next_pressed.connect(func(): next_count[0] += 1)
	_audit_key(KEY_ENTER)
	_audit_key(KEY_ENTER, false)
	for frame in 2: await process_frame
	_input_layout_expect(next_count[0] == 1, "Enter did not advance text exactly once")
	panel.visible = false
	encounter.current_state = encounter.EncounterState.AVAILABLE
	_audit_key(KEY_TAB)
	_audit_key(KEY_TAB, false)
	for frame in 4: await process_frame
	_input_layout_expect(actor.active_character_id != before_id, "Character shortcut did not resume after dialogue closed")
	_input_layout_expect(world.spawn_index == before_spawn, "Tab outside dialogue changed map spawn")
	actor.set_control_enabled(false)
	print("TEMPLE_INPUT_CHECK ", JSON.stringify({"choices": chosen, "text_advances": next_count[0], "spawn_unchanged": world.spawn_index == before_spawn, "passed": input_layout_failures.is_empty()}))
	var seat = ruin.furniture_instances.seat_01
	var rows: Array = []
	for id: String in ruin.furniture_instances:
		var furniture = ruin.furniture_instances[id]
		var front: Node3D = furniture.get_node("Anchor_Front")
		var result := _temple_clearance(world, front.global_position)
		_input_layout_expect(result.blockers.is_empty(), "Furniture entrance blocked: " + id + " " + str(result.blockers))
		_input_layout_expect(result.supported, "Furniture entrance has no level floor: " + id)
		rows.append({"id": id, "front": str(front.global_position), "blockers": result.blockers, "supported": result.supported})
	# A standing approach corridor between the seat's Front and front edge.
	for step in 6:
		var point: Vector3 = seat.global_transform * Vector3(0, 0, 0.85 + 0.04 * step)
		var result := _temple_clearance(world, point)
		_input_layout_expect(result.blockers.is_empty() and result.supported, "Seat approach corridor is obstructed")
	print("TEMPLE_LAYOUT_CHECK ", JSON.stringify({"entrances": rows, "failures": input_layout_failures, "passed": input_layout_failures.is_empty()}))
	world.queue_free()
	await process_frame
	quit(0 if input_layout_failures.is_empty() else 1)

func _temple_clearance(world, point: Vector3) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var shape: CapsuleShape3D = world.character.collision_shape.shape.duplicate()
	shape.radius = maxf(shape.radius, 0.26) + 0.05
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * (shape.height * 0.5 + 0.025))
	query.collision_mask = 32 | 64
	query.exclude = [world.character.get_rid()]
	var blockers: Array = []
	for overlap in space.intersect_shape(query, 16):
		var id: String = overlap.collider.get_meta("source_id", str(overlap.collider.name))
		if not blockers.has(id): blockers.append(id)
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.1, point - Vector3.UP * 0.2, 32)
	var hit := space.intersect_ray(ray)
	var supported: bool = not hit.is_empty() and hit.normal.y > 0.72 and absf(hit.position.y - point.y) < 0.005
	return {"blockers": blockers, "supported": supported}
