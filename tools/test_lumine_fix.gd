@tool
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var scene: PackedScene = load("res://assets/characters/roster/lumine/lumine.vrm")
	var inst: Node3D = scene.instantiate()
	root.add_child(inst)
	
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0.0, 1.35, 1.1)
	cam.look_at_from_position(cam.position, Vector3(0.0, 1.3, 0.0), Vector3.UP)
	cam.current = true
	
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, 45, 0)
	light.light_energy = 1.0
	root.add_child(light)
	
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("90b4d4")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c0d8e8")
	env.ambient_light_energy = 0.6
	env_node.environment = env
	root.add_child(env_node)
	
	# Apply NPR
	var npr_script = load("res://scripts/characters/character_npr.gd")
	var res: Dictionary = npr_script.apply_npr(inst, "lumine")
	print("NPR applied: ", res)
	
	for f in 10:
		await physics_frame
	await RenderingServer.frame_post_draw
	
	var img: Image = root.get_viewport().get_texture().get_image()
	var out_path := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/batch09_review/lumine_hair_fix_test.png"
	img.save_png(out_path)
	print("Saved test render: ", out_path)
	quit(0)
