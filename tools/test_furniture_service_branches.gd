extends SceneTree

const ENCOUNTER_CLASS := preload("res://scripts/world/initial_temple_encounter_controller.gd")
const WORLD_CHAR_SCENE := preload("res://scenes/characters/world_ganyu.tscn")
const DIALOGUE_CLASS := preload("res://scripts/narrative/sparkle_tutorial_dialogue.gd")
const DIALOGUE_MANAGER_CLASS := preload("res://scripts/narrative/dialogue_manager.gd")

func _init() -> void:
	call_deferred("_run_furniture_service_test")

func _run_furniture_service_test() -> void:
	print("=== STARTING FURNITURE SERVICE BRANCHES TEST ===")

	# 1. Verify Dialogue Graph and Sub-branches
	print("Step 1: Testing dialogue graph sub-branches")
	var graph: Dictionary = DIALOGUE_CLASS.get_dialogue_graph()
	var nodes: Dictionary = graph.get("nodes", {})
	assert(nodes.has("spare_dialogue"), "Graph must contain spare_dialogue node")
	assert(nodes.has("spare_choices"), "Graph must contain spare_choices node")
	assert(nodes.has("virgin_service_transition"), "Graph must contain virgin_service_transition node")
	assert(nodes.has("virgin_service_action"), "Graph must contain virgin_service_action node")
	assert(nodes.has("honban_service_transition"), "Graph must contain honban_service_transition node")
	assert(nodes.has("honban_service_action"), "Graph must contain honban_service_action node")

	var spare_choices: Array = nodes["spare_choices"].get("choices", [])
	assert(spare_choices.size() >= 2, "spare_choices must offer both virgin and honban options")
	assert(spare_choices[0]["target"] == "virgin_service_transition", "First choice must target virgin_service_transition")
	assert(spare_choices[1]["target"] == "honban_service_transition", "Second choice must target honban_service_transition")

	var virgin_action_node: Dictionary = nodes["virgin_service_action"]
	var virgin_choices: Array = virgin_action_node.get("choices", [])
	assert(virgin_choices[0]["action"] == "spare_virgin", "Virgin branch action must be spare_virgin")

	var honban_action_node: Dictionary = nodes["honban_service_action"]
	var honban_choices: Array = honban_action_node.get("choices", [])
	assert(honban_choices[0]["action"] == "spare_honban", "Honban branch action must be spare_honban")
	print("PASS: Dialogue sub-branches verified successfully")

	# 2. Build Test World Scene
	print("Step 2: Constructing test world with furniture and controller")
	var root_node := Node3D.new()
	root_node.name = "FurnitureTestRoot"
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

	var world := Node3D.new()
	world.name = "MockWorld"
	world.set("automation_enabled", true)
	root_node.add_child(world)

	var char_node: CharacterBody3D = WORLD_CHAR_SCENE.instantiate()
	char_node.name = "Character"
	char_node.position = Vector3(0.0, 0.0, 1.8)
	world.add_child(char_node)
	world.set_meta("character", char_node)

	var encounter: ENCOUNTER_CLASS = ENCOUNTER_CLASS.new()
	encounter.name = "InitialTempleEncounterController"
	temple.add_child(encounter)
	encounter.initialize(temple, world, npc_anchor, npc_avatar, npc_body)

	for f in 3:
		await process_frame

	assert(encounter.current_state == encounter.EncounterState.AVAILABLE, "Expected AVAILABLE")

	# 3. Test Retain Virginity Body Service on Furniture seat_01
	print("Step 3: Testing Retain Virginity Service on seat_01")
	encounter._begin_furniture_service_staging("virgin")
	assert(encounter.current_state == encounter.EncounterState.FURNITURE_SERVICE_STAGING, "Expected FURNITURE_SERVICE_STAGING")
	assert(encounter.combat_camera.current == true, "Combat camera should activate during service staging")

	var start_time := Time.get_ticks_msec()
	while encounter.current_state == encounter.EncounterState.FURNITURE_SERVICE_STAGING:
		await process_frame
		if Time.get_ticks_msec() - start_time > 6000:
			push_error("Virgin service staging timed out")
			quit(1)
			return

	assert(encounter.current_state == encounter.EncounterState.FURNITURE_SERVICE_ACTIVE, "Expected FURNITURE_SERVICE_ACTIVE")
	assert(encounter.combat_actors_root.visible == true, "Dual paired actors must be visible")
	assert(encounter.sparkle_combat_actor != null, "Sparkle actor must exist")
	assert(encounter.sparkle_combat_actor.motion_resource == encounter.MOTION_VIRGIN_SPARKLE, "Sparkle motion must be virgin armchair paizuri")
	assert(encounter.master_combat_actor != null, "Master actor must exist")
	assert(encounter.master_combat_actor.motion_resource == encounter.MOTION_VIRGIN_MASTER, "Master motion must be virgin armchair master")
	assert(encounter.companion_unlocked == true, "Sparkle companion must be unlocked")
	assert(encounter.service_hud.visible == true, "Service HUD banner must be visible")
	print("PASS: Virgin armchair service activated with correct paired animations on seat_01")

	# Test camera controls during active furniture service
	print("Step 4: Testing interactive camera controls during furniture service")
	var initial_yaw: float = encounter.combat_cam_yaw
	var initial_dist: float = encounter.combat_cam_distance

	# Simulate right-drag rotation
	var ev_drag := InputEventMouseMotion.new()
	encounter.is_dragging_combat_cam = true
	ev_drag.relative = Vector2(40.0, -20.0)
	encounter._unhandled_input(ev_drag)
	encounter.is_dragging_combat_cam = false
	assert(encounter.combat_cam_yaw != initial_yaw, "Camera yaw should change on right-drag")
	print("PASS: Service camera rotation verified")

	# Simulate wheel zoom
	var ev_wheel_in := InputEventMouseButton.new()
	ev_wheel_in.button_index = MOUSE_BUTTON_WHEEL_UP
	ev_wheel_in.pressed = true
	encounter._unhandled_input(ev_wheel_in)
	assert(encounter.combat_cam_distance < initial_dist, "Camera distance should decrease on wheel up")
	print("PASS: Service camera zoom verified")

	# Simulate middle click reset
	var ev_mid := InputEventMouseButton.new()
	ev_mid.button_index = MOUSE_BUTTON_MIDDLE
	ev_mid.pressed = true
	encounter._unhandled_input(ev_mid)
	assert(absf(encounter.combat_cam_yaw - encounter.default_combat_cam_yaw) < 0.001, "Camera yaw should reset on middle click")
	assert(absf(encounter.combat_cam_distance - encounter.default_combat_cam_distance) < 0.001, "Camera distance should reset on middle click")
	print("PASS: Service camera middle-click reset verified")

	# Conclude virgin service with KEY_E
	print("Step 5: Testing service conclusion and return to world")
	var ev_key_e := InputEventKey.new()
	ev_key_e.keycode = KEY_E
	ev_key_e.pressed = true
	encounter._unhandled_input(ev_key_e)

	for f in 3:
		await process_frame

	assert(encounter.current_state == encounter.EncounterState.COMPLETED, "State should be COMPLETED after finishing service")
	assert(encounter.service_hud.visible == false, "Service HUD banner should be hidden")
	assert(encounter.combat_actors_root.visible == false, "Combat actors should be hidden")
	assert(char_node.visible == true, "World player character should be restored")
	assert(npc_avatar.visible == true, "World NPC avatar should be restored")
	print("PASS: Retain virginity service cleanly concluded and world restored")

	# 4. Test Honban Service on Furniture rest_01 (Bed Missionary)
	print("Step 6: Testing Honban Service on rest_01")
	encounter._begin_furniture_service_staging("honban")
	assert(encounter.current_state == encounter.EncounterState.FURNITURE_SERVICE_STAGING, "Expected FURNITURE_SERVICE_STAGING")

	start_time = Time.get_ticks_msec()
	while encounter.current_state == encounter.EncounterState.FURNITURE_SERVICE_STAGING:
		await process_frame
		if Time.get_ticks_msec() - start_time > 6000:
			push_error("Honban service staging timed out")
			quit(1)
			return

	assert(encounter.current_state == encounter.EncounterState.FURNITURE_SERVICE_ACTIVE, "Expected FURNITURE_SERVICE_ACTIVE")
	assert(encounter.combat_actors_root.visible == true, "Dual paired actors must be visible")
	assert(encounter.sparkle_combat_actor != null, "Sparkle actor must exist")
	assert(encounter.sparkle_combat_actor.motion_resource == encounter.MOTION_HONBAN_SPARKLE, "Sparkle motion must be honban missionary")
	assert(encounter.master_combat_actor != null, "Master actor must exist")
	assert(encounter.master_combat_actor.motion_resource == encounter.MOTION_HONBAN_MASTER, "Master motion must be honban missionary master")
	assert(encounter.service_hud.visible == true, "Service HUD banner must be visible")
	print("PASS: Honban missionary service activated with correct paired animations on rest_01")

	# Conclude honban service with KEY_SPACE
	var ev_key_space := InputEventKey.new()
	ev_key_space.keycode = KEY_SPACE
	ev_key_space.pressed = true
	encounter._unhandled_input(ev_key_space)

	for f in 3:
		await process_frame

	assert(encounter.current_state == encounter.EncounterState.COMPLETED, "State should be COMPLETED after honban service")
	assert(encounter.service_hud.visible == false, "Service HUD banner should be hidden")
	print("PASS: Honban service cleanly concluded and world restored")

	print("=== ALL FURNITURE SERVICE BRANCHES TESTS PASSED 100%! ===")
	quit(0)
