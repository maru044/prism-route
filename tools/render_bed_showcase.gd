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
	env.background_color = Color("E5EAF0")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8592A0")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_node.add_child(world_env)
	
	# Key Sun light
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -32, 0)
	sun.light_color = Color("FFFBF2")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.shadow_bias = 0.02
	world_node.add_child(sun)
	
	# Fill light
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_color = Color("D5E5F8")
	fill.light_energy = 0.5
	world_node.add_child(fill)
	
	# Studio Floor
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(25, 25)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("E0E5EC")
	floor_mat.roughness = 0.35
	var floor_inst := MeshInstance3D.new()
	floor_inst.mesh = floor_mesh
	floor_inst.material_override = floor_mat
	floor_inst.position = Vector3(0, 0, 0)
	world_node.add_child(floor_inst)
	
	# Load Bed
	var bed_scene = load("res://assets/furniture/prism/prism_geo_bed.glb")
	var bed = bed_scene.instantiate()
	world_node.add_child(bed)
	
	# Camera setup
	var cam := Camera3D.new()
	cam.fov = 38
	world_node.add_child(cam)
	
	var out_dir := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/bed_showcase/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	
	var shots := [
		# 1. Perspective showcase matching reference image angle
		{
			"pos": Vector3(-3.4, 2.1, 4.0),
			"look_at": Vector3(0.0, 0.45, 0.0),
			"name": "sculpted_bed_godot_showcase.png"
		},
		# 2. Side profile showing origami faceted geometry & floating base
		{
			"pos": Vector3(-4.5, 1.4, 0.0),
			"look_at": Vector3(0.0, 0.45, 0.0),
			"name": "sculpted_bed_godot_side.png"
		},
		# 3. Front view showing low foot rim and mattress crown
		{
			"pos": Vector3(0.0, 1.5, 4.2),
			"look_at": Vector3(0.0, 0.45, 0.0),
			"name": "sculpted_bed_godot_front.png"
		},
		# 4. Close-up on pillows and headboard cushion
		{
			"pos": Vector3(-1.8, 1.6, 0.8),
			"look_at": Vector3(0.0, 0.65, -0.6),
			"name": "sculpted_bed_godot_closeup.png"
		}
	]
	
	for shot in shots:
		cam.position = shot["pos"]
		cam.look_at(shot["look_at"], Vector3.UP)
		for f in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var p: String = out_dir + String(shot["name"])
		img.save_png(p)
		print("Saved showcase render: ", p)
		
	print("All bed showcase renders completed!")
	quit(0)
