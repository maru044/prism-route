@tool
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== INSPECTING LUMINE SURFACES & MATERIALS ===")
	var scene: PackedScene = load("res://assets/characters/roster/lumine/lumine.vrm")
	var inst: Node3D = scene.instantiate()
	root.add_child(inst)
	
	for mesh: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		print("MeshInstance3D: ", mesh.name, " surfaces: ", mesh.mesh.get_surface_count())
		for i in mesh.mesh.get_surface_count():
			var s_name: String = mesh.mesh.surface_get_name(i) if mesh.mesh is ArrayMesh else ""
			var mat: Material = mesh.get_active_material(i)
			var mat_type: String = mat.get_class() if mat else "NULL"
			var res_name: String = mat.resource_name if mat else ""
			print(" Surface [", i, "] name='", s_name, "' mat_type=", mat_type, " res_name='", res_name, "'")
			if mat is ShaderMaterial:
				print("    shader: ", mat.shader.resource_path)
				var main_tex = mat.get_shader_parameter("_MainTex")
				var color = mat.get_shader_parameter("_Color")
				var shade_col = mat.get_shader_parameter("_ShadeColor")
				print("    _MainTex: ", main_tex, " _Color: ", color, " _ShadeColor: ", shade_col)
			elif mat is StandardMaterial3D:
				print("    albedo_color: ", mat.albedo_color, " albedo_texture: ", mat.albedo_texture)

	quit(0)
