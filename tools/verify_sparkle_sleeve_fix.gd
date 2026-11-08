extends SceneTree
## Verifies that Sparkle NPCBody collision layer decoupling is correctly applied and captures screenshots.

const CAPTURE_DIR := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/"

func _init() -> void:
	call_deferred("_run_verification")

func _run_verification() -> void:
	root.size = Vector2i(1920, 1080)
	var root_node := Node3D.new()
	root.add_child(root_node)
	
	# Environment and Lighting
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.6, 0.75, 0.9)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.85, 0.88, 0.95)
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	root_node.add_child(env)
	
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 140, 0)
	sun.light_color = Color(1.0, 0.96, 0.92)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	root_node.add_child(sun)
	
	# Load initial ruin
	var ruin_scene = load("res://scenes/world/initial_ruin.tscn")
	var ruin: Node3D = ruin_scene.instantiate()
	root_node.add_child(ruin)
	
	# Camera looking directly at Sparkle NPC
	var cam := Camera3D.new()
	cam.position = Vector3(-1014.2, 62.0, 1258.5)
	cam.look_at_from_position(cam.position, Vector3(-1015.28, 61.9, 1255.79), Vector3.UP)
	cam.current = true
	root_node.add_child(cam)
	
	while not ruin.npc_ready:
		await process_frame
		
	# Warm up simulation for 45 frames
	for i in range(45):
		await process_frame
		
	print("--- VERIFYING SPARKLE COLLISION LAYERS ---")
	print("NPCBody collision_layer: ", ruin.npc_body.collision_layer, " (Expected: 64)")
	print("Avatar environment_mask: ", ruin.avatar.environment_mask, " (Expected: 33)")
	
	assert(ruin.npc_body.collision_layer == 64, "NPCBody layer must be 64")
	assert(ruin.avatar.environment_mask == 33, "Avatar environment mask must be 33")
	assert((ruin.avatar.environment_mask & ruin.npc_body.collision_layer) == 0, "Avatar must not hit NPCBody")
	
	# Check Spring bones
	var all_springs_checked := 0
	for spring in ruin.avatar.all_springs:
		all_springs_checked += 1
		assert(spring.environment_collision_mask == 33, "Spring environment mask must be 33")
	print("Verified all %d SpringBone chains have mask 33 (excluding layer 64)!" % all_springs_checked)
	
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(CAPTURE_DIR + "sparkle_sleeve_fix_closeup.png")
	print("Saved closeup to sparkle_sleeve_fix_closeup.png")
	
	# Move camera back for temple view
	cam.position = Vector3(-1012.0, 62.8, 1262.0)
	cam.look_at_from_position(cam.position, Vector3(-1014.5, 61.8, 1255.0), Vector3.UP)
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var full_img := root.get_texture().get_image()
	full_img.save_png(CAPTURE_DIR + "sparkle_sleeve_fix_temple.png")
	print("Saved temple view to sparkle_sleeve_fix_temple.png")
	
	print("ALL SPARKLE SLEEVE CHECKS PASSED!")
	quit(0)
