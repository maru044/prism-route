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
	cam.position = Vector3(0, 1.4, 1.0)
	cam.look_at_from_position(cam.position, Vector3(0, 1.35, 0), Vector3.UP)
	cam.current = true
	root.add_child(cam)
	
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 45, 0)
	root.add_child(light)
	
	var mesh: MeshInstance3D = inst.find_child("荧_mesh", true, false)
	
	# Test 1: Original imported materials (how it looks natively)
	for f in 5: await physics_frame
	await RenderingServer.frame_post_draw
	var img = root.get_viewport().get_texture().get_image()
	img.save_png("C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/batch09_review/lumine_hair_native.png")
	print("Saved lumine_hair_native.png")
	
	# Test 2: With proper orig_shader inspection (is_trans for Surface 19)
	var npr_script = load("res://scripts/characters/character_npr.gd")
	# Let's inspect what happens to Surface 19
	var s19_mat = mesh.get_active_material(19)
	print("Surface 19 orig_mat: ", s19_mat.resource_name, " shader: ", s19_mat.shader.resource_path)
	print("Surface 19 _Color: ", s19_mat.get_shader_parameter("_Color"))
	
	quit(0)
