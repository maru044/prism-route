@tool
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("================ ALL FOUR CHARACTERS MATERIAL AUDIT ================")
	var paths := {
		"ganyu": "res://scenes/characters/ganyu.tscn",
		"stelle": "res://assets/characters/roster/stelle/stelle.vrm",
		"lumine": "res://assets/characters/roster/lumine/lumine.vrm",
		"firefly": "res://assets/characters/roster/firefly/firefly.vrm",
	}
	
	for char_id in paths:
		var scene: PackedScene = load(paths[char_id])
		var inst: Node3D = scene.instantiate()
		root.add_child(inst)
		print("\n>>> CHARACTER: ", char_id, " <<<")
		for mesh: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
			if mesh.mesh == null: continue
			print(" Mesh: ", mesh.name, " (surfaces: ", mesh.mesh.get_surface_count(), ")")
			for i in mesh.mesh.get_surface_count():
				var s_name: String = mesh.mesh.surface_get_name(i) if mesh.mesh is ArrayMesh else ""
				var mat := mesh.get_active_material(i)
				var mat_class := mat.get_class() if mat else "NULL"
				var s_res := mat.resource_name if mat else ""
				var sh_path := ""
				var col := Color.WHITE
				var has_tex := false
				var is_trans := false
				var is_cutout := false
				var cull_off := false
				if mat is ShaderMaterial and mat.shader != null:
					sh_path = mat.shader.resource_path.get_file()
					is_trans = sh_path.contains("trans")
					is_cutout = sh_path.contains("cutout")
					cull_off = sh_path.contains("cull_off")
					if mat.get_shader_parameter("_Color") != null:
						col = mat.get_shader_parameter("_Color")
					has_tex = (mat.get_shader_parameter("_MainTex") != null)
				elif mat is StandardMaterial3D:
					col = mat.albedo_color
					has_tex = (mat.albedo_texture != null)
					is_trans = (mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA or mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS)
					is_cutout = (mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR or mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH)
					cull_off = (mat.cull_mode == BaseMaterial3D.CULL_DISABLED)
				print("   [%2d] '%s' (mat '%s', %s) sh=%s trans=%s cut=%s cull_off=%s col=%s has_tex=%s" % [
					i, s_name, s_res, mat_class, sh_path, is_trans, is_cutout, cull_off, col, has_tex
				])
		inst.queue_free()
	print("================ AUDIT FINISHED ================")
	quit(0)
