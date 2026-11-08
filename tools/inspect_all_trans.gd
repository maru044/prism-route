@tool
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== CHECKING ALL ROSTER SURFACES ORIGINAL SHADERS ===")
	for char_id in ["stelle", "lumine", "firefly"]:
		var path = "res://assets/characters/roster/%s/%s.vrm" % [char_id, char_id]
		var scene: PackedScene = load(path)
		var inst: Node3D = scene.instantiate()
		root.add_child(inst)
		print("\n--- Character: ", char_id, " ---")
		for mesh: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
			for i in mesh.mesh.get_surface_count():
				var s_name: String = mesh.mesh.surface_get_name(i) if mesh.mesh is ArrayMesh else ""
				var mat: Material = mesh.get_active_material(i)
				var orig_shader = mat.shader.resource_path if (mat is ShaderMaterial and mat.shader) else "Standard"
				var is_trans = orig_shader.contains("trans")
				var is_cutout = orig_shader.contains("cutout")
				if is_trans or is_cutout or s_name.contains("+"):
					print("  Surface [", i, "] '", s_name, "' orig_shader=", orig_shader.get_file())
		inst.queue_free()
	quit(0)
