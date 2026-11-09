extends SceneTree

const ENCOUNTER_CLASS := preload("res://scripts/world/initial_temple_encounter_controller.gd")
const WORLD_CHAR_SCENE := preload("res://scenes/characters/world_ganyu.tscn")

func _init() -> void:
	call_deferred("_run_staging_test")

func _run_staging_test() -> void:
	print("=== STARTING SEAMLESS COMBAT STAGING TEST ===")
	var root_node := Node3D.new()
	root_node.name = "StagingTestRoot"
	get_root().add_child(root_node)

	var temple := Node3D.new()
	temple.name = "TempleNode"
	root_node.add_child(temple)

	var npc_anchor := Marker3D.new()
	npc_anchor.name = "NPCAnchor"
	npc_anchor.position = Vector3(0.0, 0.0, 0.0)
	temple.add_child(npc_anchor)

	var npc_avatar := Node3D.new()
	npc_avatar.name = "NPCAvatar"
	npc_anchor.add_child(npc_avatar)

	var npc_body := StaticBody3D.new()
	npc_body.name = "NPCBody"
	npc_anchor.add_child(npc_body)

	# Mock world with real world_ganyu character
	var world := Node3D.new()
	world.name = "MockWorld"
	world.set("automation_enabled", true)
	root_node.add_child(world)

	var char_node: CharacterBody3D = WORLD_CHAR_SCENE.instantiate()
	char_node.name = "Character"
	char_node.position = Vector3(0.0, 0.0, 1.8) # standing 1.8m away in front of NPC
	world.add_child(char_node)
	world.set_meta("character", char_node)

	var encounter: ENCOUNTER_CLASS = ENCOUNTER_CLASS.new()
	encounter.name = "InitialTempleEncounterController"
	temple.add_child(encounter)
	encounter.initialize(temple, world, npc_anchor, npc_avatar, npc_body)

	# Wait frames for initialization
	for f in 3:
		await process_frame

	print("Initial encounter state: ", encounter.current_state)
	assert(encounter.current_state == encounter.EncounterState.AVAILABLE, "Expected AVAILABLE")

	# Step 1: Start Dialogue
	encounter.start_encounter_dialogue()
	for f in 3:
		await process_frame
	assert(encounter.current_state == encounter.EncounterState.INTRO_DIALOGUE, "Expected INTRO_DIALOGUE")
	print("Dialogue opened successfully")

	# Step 2: Trigger combat staging
	print("Triggering seamless combat staging")
	encounter._begin_seamless_combat_staging()
	assert(encounter.current_state == encounter.EncounterState.STAGING_TRANSITION, "Expected STAGING_TRANSITION")
	assert(encounter.combat_camera.current == true, "Combat camera should take over during staging")
	print("Combat camera smoothly activated with seamless initial transform")

	# Wait for staging tween to finish
	var start_time := Time.get_ticks_msec()
	while encounter.current_state == encounter.EncounterState.STAGING_TRANSITION:
		await process_frame
		if Time.get_ticks_msec() - start_time > 6000:
			push_error("Staging timed out")
			quit(1)
			return

	print("Staging transition completed!")
	assert(encounter.current_state == encounter.EncounterState.COMBAT, "Expected state COMBAT")
	assert(encounter.combat_actors_root.visible == true, "Dual combat actors must be visible")
	assert(encounter.combat_hud.visible == true, "Combat HUD must be visible")
	assert(char_node.visible == false, "World player should be cleanly replaced by combat actor")
	assert(npc_avatar.visible == false, "World NPC should be cleanly replaced by combat actor")

	var final_player_pos: Vector3 = char_node.global_position
	print("Player final staging pos: ", final_player_pos)
	var horizontal_dist: float = Vector2(final_player_pos.x, final_player_pos.z).distance_to(Vector2(0.0, 0.45))
	print("Horizontal distance to designated staging anchor: ", horizontal_dist)
	assert(horizontal_dist < 0.01, "Player horizontal pos should be exactly at staging anchor")

	# Step 3: Test Combat Camera Orbit & Zoom Controls
	print("Testing combat camera interactive movement & zoom")
	var initial_cam_pos: Vector3 = encounter.combat_camera.global_position
	var initial_dist: float = encounter.combat_cam_distance
	var initial_yaw: float = encounter.combat_cam_yaw

	# 1. Simulate right-click drag to rotate camera
	var ev_right_down := InputEventMouseButton.new()
	ev_right_down.button_index = MOUSE_BUTTON_RIGHT
	ev_right_down.pressed = true
	encounter._unhandled_input(ev_right_down)

	var ev_motion := InputEventMouseMotion.new()
	ev_motion.relative = Vector2(50.0, 20.0)
	encounter._unhandled_input(ev_motion)

	var ev_right_up := InputEventMouseButton.new()
	ev_right_up.button_index = MOUSE_BUTTON_RIGHT
	ev_right_up.pressed = false
	encounter._unhandled_input(ev_right_up)

	assert(encounter.combat_cam_yaw != initial_yaw, "Camera yaw must change after right drag")
	assert(encounter.combat_camera.global_position != initial_cam_pos, "Camera position must update after rotation")
	print("PASS: Right-drag camera rotation verified")

	# 2. Simulate mouse wheel zoom in
	var ev_wheel_up := InputEventMouseButton.new()
	ev_wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	ev_wheel_up.pressed = true
	encounter._unhandled_input(ev_wheel_up)
	assert(encounter.combat_cam_distance < initial_dist, "Camera distance must decrease on wheel up")
	print("PASS: Mouse wheel zoom in verified")

	# 3. Simulate mouse wheel zoom out
	var ev_wheel_down := InputEventMouseButton.new()
	ev_wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	ev_wheel_down.pressed = true
	encounter._unhandled_input(ev_wheel_down)
	encounter._unhandled_input(ev_wheel_down)
	assert(encounter.combat_cam_distance > initial_dist - 0.1, "Camera distance must increase on wheel down")
	print("PASS: Mouse wheel zoom out verified")

	# 4. Simulate middle click reset
	var ev_mid := InputEventMouseButton.new()
	ev_mid.button_index = MOUSE_BUTTON_MIDDLE
	ev_mid.pressed = true
	encounter._unhandled_input(ev_mid)
	assert(absf(encounter.combat_cam_distance - initial_dist) < 0.001, "Middle click must reset distance")
	assert(absf(encounter.combat_cam_yaw - initial_yaw) < 0.001, "Middle click must reset yaw")
	print("PASS: Middle click camera reset verified")

	print("=== SEAMLESS COMBAT STAGING AND CAMERA TEST PASSED 100%! ===")
	quit(0)
