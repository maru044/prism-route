extends SceneTree
## Captures screenshots of the Turn-Based Combat Demo with dual blowjob animation and temple door respawn perspective.

const CAPTURE_DIR := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/"

func _init() -> void:
	call_deferred("_run_capture")

func _run_capture() -> void:
	root.size = Vector2i(1920, 1080)
	var demo_scene = load("res://scenes/combat/sparkle_tutorial_combat_demo.tscn")
	var demo = demo_scene.instantiate()
	root.add_child(demo)
	
	# Wait for temple scene and actors to initialize
	for i in range(45):
		await process_frame
		
	# 1. Advance dialogue from 'start' -> 'sparkle_intro_2' -> 'main_menu_choices'
	demo.dialogue_manager.advance_text()
	demo.dialogue_manager.advance_text()
	for i in range(10):
		await process_frame
		
	# Choose option 4 (index 3): Enter combat
	demo.dialogue_manager.choose_option(3)
	
	# Allow dual blowjob animations to play and settle for 40 frames
	for i in range(40):
		await process_frame
		
	await RenderingServer.frame_post_draw
	var img_blowjob := root.get_texture().get_image()
	img_blowjob.save_png(CAPTURE_DIR + "turn_combat_dual_blowjob_action.png")
	print("Saved turn_combat_dual_blowjob_action.png")
	
	# 2. Trigger Mid-Battle Negotiation (Ensure combat HUD stays visible behind dialogue)
	demo.combat_manager.request_in_battle_negotiation()
	for i in range(15):
		await process_frame
		
	await RenderingServer.frame_post_draw
	var img_mid_dialogue := root.get_texture().get_image()
	img_mid_dialogue.save_png(CAPTURE_DIR + "turn_combat_in_battle_dialogue_floating.png")
	print("Saved turn_combat_in_battle_dialogue_floating.png")
	
	# 3. Simulate defeat to capture temple door respawn perspective
	demo.dialogue_manager.choose_option(0) # resume
	demo.player_pleasure.add_pleasure(100.0) # defeat master
	demo.combat_manager._check_battle_state()
	
	for i in range(80):
		await process_frame
		
	await RenderingServer.frame_post_draw
	var img_respawn := root.get_texture().get_image()
	img_respawn.save_png(CAPTURE_DIR + "turn_combat_temple_door_respawn.png")
	print("Saved turn_combat_temple_door_respawn.png")
	
	print("ALL CAPTURES COMPLETED SUCCESSFULLY!")
	quit(0)
