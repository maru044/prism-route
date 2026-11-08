@tool
extends SceneTree

const OUTLINE_SHADER = preload("res://shaders/characters/npr_outline.gdshader")
const TOON_OPAQUE = preload("res://shaders/characters/toon_opaque.gdshader")
const TOON_OPAQUE_CULL_OFF = preload("res://shaders/characters/toon_opaque_cull_off.gdshader")
const TOON_BLEND_CULL_OFF = preload("res://shaders/characters/toon_blend_cull_off.gdshader")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var world := Node3D.new()
	root.add_child(world)
	
	var env := WorldEnvironment.new()
	var env_res := Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color(0.72, 0.78, 0.85)
	env.environment = env_res
	world.add_child(env)
	
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 45, 0)
	light.light_color = Color(1.0, 0.98, 0.95)
	world.add_child(light)
	
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.45, 1.1)
	cam.look_at_from_position(cam.position, Vector3(0, 1.40, 0), Vector3.UP)
	cam.current = true
	world.add_child(cam)
	
	var p_stelle: PackedScene = load("res://assets/characters/roster/stelle/stelle.vrm")
	var inst: Node3D = p_stelle.instantiate()
	world.add_child(inst)
	
	var skel: Skeleton3D = inst.find_child("GeneralSkeleton", true, false)
	var skel_path = inst.get_path_to(skel)
	var anim: Animation = load("res://assets/characters/motion_review/A01.tres").duplicate(true)
	for t in anim.get_track_count():
		var p = str(anim.track_get_path(t))
		var col = p.find(":")
		if col != -1:
			var bone_part = p.substr(col)
			anim.track_set_path(t, NodePath(str(skel_path) + bone_part))
	
	var player = AnimationPlayer.new()
	inst.add_child(player)
	var lib = AnimationLibrary.new()
	lib.add_animation("idle", anim)
	player.add_animation_library("", lib)
	player.play("idle")
	
	var mesh: MeshInstance3D = inst.find_child("女主1_0_mesh", true, false)
	var head_idx = skel.find_bone("Head")
	var head_rest_inv = skel.get_bone_global_rest(head_idx).basis.inverse() if head_idx >= 0 else Basis.IDENTITY
	
	# Apply C0 Shaders to Stelle
	var selected_outline: Array[Dictionary] = []
	for i in mesh.mesh.get_surface_count():
		var s_name = mesh.mesh.surface_get_name(i)
		var orig_mat = mesh.get_active_material(i)
		var tex = orig_mat.get_shader_parameter("_MainTex")
		var is_trans = (s_name == "眼睛1")
		var is_cutout = (s_name in ["新建", "表情"])
		var cull_off = not (s_name in ["外套", "外套衣饰铁", "外套内侧"])
		
		var mat := ShaderMaterial.new()
		mat.shader = TOON_BLEND_CULL_OFF if is_trans else (TOON_OPAQUE_CULL_OFF if cull_off else TOON_OPAQUE)
		mat.set_shader_parameter("base_texture", tex)
		mat.set_shader_parameter("base_color", Color.WHITE)
		mat.set_shader_parameter("alpha_cutoff", 0.5 if is_cutout else 0.0)
		mat.set_shader_parameter("tone_bands", 2)
		mat.set_shader_parameter("edge_softness", 0.05)
		
		# Regions: 0=face, 1=skin, 2=hair, 3=body, 4=eye, 5=accessory
		var region_code = 3
		if s_name in ["脸", "眉毛", "口腔"]: region_code = 0
		elif s_name in ["皮肤", "新胖次"]: region_code = 1
		elif s_name == "头发": region_code = 2
		elif s_name in ["眼睛", "眼白", "眼睛1"]: region_code = 4
		elif s_name in ["衣饰铁", "外套衣饰铁", "怀表"]: region_code = 5
		
		mat.set_shader_parameter("region", region_code)
		mat.set_shader_parameter("face_softness", 0.75)
		mat.set_shader_parameter("hair_highlight", 0.28)
		mat.set_shader_parameter("eye_highlight", 0.15)
		mat.set_shader_parameter("skin_shadow_multiplier", Vector3(0.92, 0.78, 0.80))
		mat.set_shader_parameter("shadow_multiplier", Vector3(0.68, 0.65, 0.78))
		if s_name == "外套内侧":
			mat.set_shader_parameter("shadow_multiplier", Vector3(0.85, 0.72, 0.48))
		mesh.set_surface_override_material(i, mat)
		
		# Outline eligible
		if region_code in [0, 2, 3, 5] and not is_trans and not is_cutout:
			var out_mat := ShaderMaterial.new()
			out_mat.shader = OUTLINE_SHADER
			out_mat.set_shader_parameter("base_texture", tex)
			out_mat.set_shader_parameter("base_color", Color.WHITE)
			var out_color = Color("383248")
			if region_code == 0: out_color = Color("784c55")
			elif region_code == 2: out_color = Color("403850")
			out_mat.set_shader_parameter("outline_color", out_color)
			out_mat.set_shader_parameter("outline_pixels", 0.95 if region_code != 0 else 0.55)
			selected_outline.append({"index": i, "material": out_mat})
	
	# Build Smoothed Normal Outline Shell (Ganyu C1 Technique!)
	var derived := ArrayMesh.new()
	var groups := {}
	for entry in selected_outline:
		var arrays := mesh.mesh.surface_get_arrays(entry.index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in vertices.size():
			var p := Vector3i(roundi(vertices[i].x * 100000.0), roundi(vertices[i].y * 100000.0), roundi(vertices[i].z * 100000.0))
			if not groups.has(p): groups[p] = []
			if not groups[p].has(normals[i]): groups[p].append(normals[i])
			
	for entry in selected_outline:
		var arrays := mesh.mesh.surface_get_arrays(entry.index).duplicate(true)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL].duplicate()
		for i in vertices.size():
			var p := Vector3i(roundi(vertices[i].x * 100000.0), roundi(vertices[i].y * 100000.0), roundi(vertices[i].z * 100000.0))
			var average := Vector3.ZERO
			for candidate: Vector3 in groups[p]:
				if candidate.dot(normals[i]) > 0.0: average += candidate
			if average.length_squared() > 0.0001: normals[i] = average.normalized()
		arrays[Mesh.ARRAY_NORMAL] = normals
		derived.add_surface_from_arrays(mesh.mesh.surface_get_primitive_type(entry.index), arrays)
		
	var outline_shell := MeshInstance3D.new()
	outline_shell.mesh = derived
	outline_shell.skin = mesh.skin
	outline_shell.skeleton = mesh.skeleton
	outline_shell.transform = mesh.transform
	for i in selected_outline.size():
		outline_shell.set_surface_override_material(i, selected_outline[i].material)
	mesh.get_parent().add_child(outline_shell)
	
	# Update head forward on face materials
	for i in 15: await physics_frame
	await process_frame
	await process_frame
	
	var head_basis = skel.global_basis * skel.get_bone_global_pose(head_idx).basis * head_rest_inv
	var forward = (head_basis * Vector3.BACK).normalized()
	for i in mesh.mesh.get_surface_count():
		var mat = mesh.get_surface_override_material(i) as ShaderMaterial
		if mat and mat.get_shader_parameter("region") == 0:
			mat.set_shader_parameter("head_forward", forward)
	
	await process_frame
	await process_frame
	
	var img: Image = root.get_viewport().get_texture().get_image()
	var p := "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/batch09_review/stelle_c0_npr_test.png"
	img.save_png(p)
	print("Saved C0 NPR Test for Stelle: ", p)
	quit(0)
