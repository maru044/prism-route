extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var world_node := Node3D.new()
	root.add_child(world_node)
	
	# Environment with clean architectural lighting
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("E2E7ED")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8592A0")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_node.add_child(world_env)
	
	# Key Sun light (from high front-left)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -32, 0)
	sun.light_color = Color("FFFBF2")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.shadow_bias = 0.02
	world_node.add_child(sun)
	
	# Soft sky fill from opposite side
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_color = Color("D5E5F8")
	fill.light_energy = 0.5
	world_node.add_child(fill)
	
	# Studio Floor
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(20, 20)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("E0E5EC")
	floor_mat.roughness = 0.35
	var floor_inst := MeshInstance3D.new()
	floor_inst.mesh = floor_mesh
	floor_inst.material_override = floor_mat
	floor_inst.position = Vector3(0, 0, 0)
	world_node.add_child(floor_inst)
	
	# Load Chair
	var chair_scene = load("res://assets/furniture/prism/prism_geo_chair.glb")
	var chair = chair_scene.instantiate()
	world_node.add_child(chair)
	
	# Camera setup
	var cam := Camera3D.new()
	cam.fov = 34
	cam.current = true
	world_node.add_child(cam)
	
	var out_dir := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/"
	
	# Shot 1: Beauty 3/4 Perspective matching Master's reference image
	cam.position = Vector3(-1.9, 1.15, 2.3)
	cam.look_at(Vector3(0, 0.44, 0))
	
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	
	var img1 := root.get_texture().get_image()
	img1.save_png(out_dir + "sculpted_chair_godot_showcase.png")
	print("SAVED: ", out_dir + "sculpted_chair_godot_showcase.png")
	
	# Shot 2: Closer 3/4
	cam.position = Vector3(-1.5, 0.95, 1.8)
	cam.look_at(Vector3(0, 0.43, 0))
	
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	
	var img2 := root.get_texture().get_image()
	img2.save_png(out_dir + "sculpted_chair_godot_closeup.png")
	print("SAVED: ", out_dir + "sculpted_chair_godot_closeup.png")
	
	# Shot 3: Side Profile view showing the faceted origami lines
	cam.position = Vector3(-2.3, 0.65, 0.0)
	cam.look_at(Vector3(0, 0.44, 0))
	
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	
	var img3 := root.get_texture().get_image()
	img3.save_png(out_dir + "sculpted_chair_godot_side.png")
	print("SAVED: ", out_dir + "sculpted_chair_godot_side.png")
	
	quit(0)
