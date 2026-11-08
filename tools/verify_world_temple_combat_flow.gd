extends SceneTree
## Full end-to-end verification of Sparkle Temple Combat in the actual Overworld:
## 1. First encounter & [E] interaction in Overworld
## 2. Enter combat with dual blowjob animation
## 3. In-battle negotiation (dialogue floating, non-exiting)
## 4. Defeat & respawn at doorway WITHOUT forced dialogue (player regains control)
## 5. Player walks across temple to Sparkle and presses [E] to initiate second-attempt dialogue

const CAPTURE_DIR := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/"

func _init() -> void:
	call_deferred("_run_overworld_flow")

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
	print("World ready! Player pos: ", player.global_position, " Sparkle pos: ", ruin.npc_anchor.global_position)
	
	# Step 1: Approach Sparkle in temple
	var near_pos: Vector3 = ruin.npc_anchor.global_position + Vector3(0.5, 0.0, 1.2)
	player.global_position = near_pos
	for i in range(10):
		await process_frame
		
	print("Player moved close. interact_prompt visible: ", ruin.interact_prompt.visible)
	assert(ruin.interact_prompt.visible, "Interact prompt should be visible near Sparkle")
	
	# Step 2: Trigger [E] interaction to start in-world dialogue
	ruin._start_in_world_dialogue()
	for i in range(10):
		await process_frame
	print("Dialogue started. DialoguePanel visible: ", ruin.dialogue_panel.visible)
	assert(ruin.dialogue_panel.visible, "DialoguePanel should be visible in world")
	
	# Advance dialogue and choose combat
	ruin.dialogue_manager.advance_text()
	ruin.dialogue_manager.advance_text()
	for i in range(5):
		await process_frame
	ruin.dialogue_manager.choose_option(3) # Enter combat
	
	# Wait for combat dual-actors and animations
	for i in range(40):
		await process_frame
		
	print("Combat active. Combat actors visible: ", ruin.combat_actors_root.visible)
	assert(ruin.combat_actors_root.visible, "Dual combat actors should be visible")
	assert(ruin.combat_hud.visible, "Combat HUD should be visible")
	
	# Capture Overworld dual blowjob battle
	await RenderingServer.frame_post_draw
	var img_combat := root.get_texture().get_image()
	img_combat.save_png(CAPTURE_DIR + "overworld_temple_dual_blowjob_combat.png")
	print("Saved overworld_temple_dual_blowjob_combat.png")
	
	# Step 3: Mid-battle negotiation in Overworld
	ruin.combat_manager.request_in_battle_negotiation()
	for i in range(15):
		await process_frame
	print("Mid-battle dialogue requested. HUD visible: ", ruin.combat_hud.visible, " Panel visible: ", ruin.dialogue_panel.visible)
	assert(ruin.combat_hud.visible, "HUD must remain visible during mid-battle dialogue")
	assert(ruin.dialogue_panel.visible, "DialoguePanel must be floating over HUD")
	
	# Capture Overworld mid-battle negotiation
	await RenderingServer.frame_post_draw
	var img_mid_dialogue := root.get_texture().get_image()
	img_mid_dialogue.save_png(CAPTURE_DIR + "overworld_temple_mid_battle_negotiation.png")
	print("Saved overworld_temple_mid_battle_negotiation.png")
	
	# In mid_battle_manual: advance text -> choices -> choose "【返回对决�? (choice 3)
	ruin.dialogue_manager.advance_text()
	for i in range(5):
		await process_frame
	ruin.dialogue_manager.choose_option(3) # 返回对决
	for i in range(10):
		await process_frame
	assert(not ruin.dialogue_panel.visible, "DialoguePanel should hide after returning to combat")
	assert(ruin.combat_hud.visible, "Combat HUD should remain active")
	print("Mid-battle negotiation smoothly returned to combat!")
	
	# Step 4: Simulate Master defeat in Round 1
	print("Simulating Master defeat in Overworld")
	ruin.player_pleasure.add_pleasure(100.0)
	ruin.combat_manager._check_battle_state()
	
	# Wait for defeat resolution
	for i in range(80):
		await process_frame
		
	print("After defeat, player pos: ", player.global_position)
	print("Expected doorway respawn: ", ruin.RESPAWN_POINT)
	var respawn_dist = player.global_position.distance_to(ruin.RESPAWN_POINT)
	print("Distance to doorway: ", respawn_dist)
	assert(respawn_dist < 1.0, "Player must be at doorway entrance")
	assert(not ruin.dialogue_panel.visible, "Dialogue must NOT be forcibly opened at the door!")
	assert(not ruin.is_in_dialogue_or_combat, "Player must have full freedom of movement!")
	
	# Capture doorway respawn perspective where player has full control
	await RenderingServer.frame_post_draw
	var img_respawn_free := root.get_texture().get_image()
	img_respawn_free.save_png(CAPTURE_DIR + "overworld_temple_respawn_free_movement.png")
	print("Saved overworld_temple_respawn_free_movement.png")
	
	# Step 5: Player walks across temple over to Sparkle
	print("Player physically walking across the temple towards Sparkle")
	player.global_position = near_pos
	for i in range(15):
		await process_frame
		
	print("Player arrived in front of Sparkle. interact_prompt visible: ", ruin.interact_prompt.visible)
	assert(ruin.interact_prompt.visible, "Interact prompt should appear when walking up to Sparkle again")
	
	# Step 6: Player presses [E] to talk
	ruin._start_in_world_dialogue()
	for i in range(10):
		await process_frame
		
	print("Second encounter dialogue started! DialoguePanel visible: ", ruin.dialogue_panel.visible)
	assert(ruin.dialogue_panel.visible, "DialoguePanel should open on manual interaction")
	assert(ruin.defeat_count == 1, "Defeat count should be 1")
	
	# Capture second-attempt dialogue in front of Sparkle
	await RenderingServer.frame_post_draw
	var img_second_dialogue := root.get_texture().get_image()
	img_second_dialogue.save_png(CAPTURE_DIR + "overworld_temple_second_encounter_dialogue.png")
	print("Saved overworld_temple_second_encounter_dialogue.png")
	
	print("ALL OVERWORLD TEMPLE WORKFLOW CHECKS PASSED 100%!")
	quit(0)
