extends SceneTree

const ACTOR_SCENE := preload("res://scenes/characters/shared_humanoid_actor.tscn")
const WORLD_CHARACTER_SCENE := preload("res://scenes/characters/world_ganyu.tscn")
const DEFAULT_MOTION := "res://assets/characters/roster/motions/koikatsu_idle.tres"
const CHEST_FONDLE_COMPONENT := preload("res://scripts/characters/chest_interaction_component.gd")

func _init() -> void:
	print("Starting test_game_chest_interaction_system.gd~")

	# Test 1: SharedHumanoidActor auto-attachment
	print("\n--- Test 1: SharedHumanoidActor Component Attachment ---")
	var actor = ACTOR_SCENE.instantiate()
	actor.model_resource = "res://assets/characters/roster/raiden_shogun/raiden_shogun.vrm"
	actor.motion_resource = DEFAULT_MOTION
	actor.auto_play = true
	actor.environment_collision_enabled = false
	root.add_child(actor)

	while not actor.ready_for_review:
		await process_frame

	var comp = actor.get_node_or_null("ChestInteractionComponent")
	assert(comp != null, "ChestInteractionComponent should be automatically attached to SharedHumanoidActor")
	assert(comp.targets.size() == 2, "Raiden Shogun should have 2 targets")
	assert(comp.pose != null, "Raiden Shogun should have GrabPose attached")
	print("  [Pass] SharedHumanoidActor auto-attached component successfully with 2 targets!")

	# Test 2: Distance limit check (< 4.5m vs > 4.5m)
	print("\n--- Test 2: Distance Limit Check ---")
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.25, 2.0) # 2.0m away (under 4.5m)
	root.add_child(cam)
	cam.make_current()

	var near_hit: Dictionary = comp._ray_hit(Vector2(0, 0))
	# Position camera exactly in front of the chest
	var chest_world_pos: Vector3 = comp.targets[0].global_position
	cam.look_at(chest_world_pos)
	cam.position = chest_world_pos + Vector3(0, 0, 1.5) # 1.5m away
	await physics_frame
	await physics_frame

	var screen_pos: Vector2 = cam.unproject_position(chest_world_pos)
	near_hit = comp._ray_hit(screen_pos)
	assert(not near_hit.is_empty(), "Raycast within 1.5m should hit target")
	assert(near_hit.get("collider") == comp.targets[0] or near_hit.get("collider") == comp.targets[1], "Hit collider should be a chest target")
	print("  [Pass] Near interaction (< 4.5m) hit chest target successfully!")

	# Move camera to 10.0m away (beyond MAX_INTERACTION_DISTANCE = 4.5m)
	cam.position = chest_world_pos + Vector3(0, 0, 10.0)
	await physics_frame
	await physics_frame
	screen_pos = cam.unproject_position(chest_world_pos)
	var far_hit: Dictionary = comp._ray_hit(screen_pos)
	assert(far_hit.is_empty(), "Raycast at 10.0m should NOT hit target due to max distance cutoff")
	print("  [Pass] Far interaction (> 4.5m) successfully ignored!")

	cam.queue_free()
	actor.queue_free()
	await process_frame

	# Test 3: WorldCharacterController Component Attachment & Character Switch
	print("\n--- Test 3: WorldCharacterController Auto-Attachment & Switch ---")
	var world_char = WORLD_CHARACTER_SCENE.instantiate()
	world_char.active_character_id = "lumine"
	root.add_child(world_char)
	await process_frame

	var wc_comp = world_char.get_node_or_null("ChestInteractionComponent")
	assert(wc_comp != null, "WorldCharacterController should have ChestInteractionComponent")
	assert(wc_comp.targets.size() == 2, "Lumine should have 2 targets")
	print("  [Pass] WorldCharacterController Lumine has component with 2 targets!")

	# Test switching character to Stelle
	print("  Switching WorldCharacter to Stelle~")
	world_char.switch_character("stelle")
	await process_frame
	assert(wc_comp.targets.size() == 2, "Stelle should have 2 targets after switch")
	assert(wc_comp.pose != null, "Stelle should have GrabPose after switch")
	print("  [Pass] Switched to Stelle cleanly, component re-bound with 2 targets!")

	# Test switching character to Firefly
	print("  Switching WorldCharacter to Firefly~")
	world_char.switch_character("firefly")
	await process_frame
	assert(wc_comp.targets.size() == 2, "Firefly should have 2 targets after switch")
	assert(wc_comp.pose != null, "Firefly should have GrabPose after switch")
	print("  [Pass] Switched to Firefly cleanly, component re-bound with 2 targets!")

	world_char.queue_free()
	await process_frame

	print("\n==================================================")
	print("ALL GAME CHEST INTERACTION SYSTEM TESTS PASSED!")
	print("==================================================")
	quit(0)
