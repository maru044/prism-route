@tool
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Testing CharacterNPR on Roster ---")
	var npr_script = load("res://scripts/characters/character_npr.gd")
	
	for char_id in ["stelle", "lumine", "firefly"]:
		var path = "res://assets/characters/roster/%s/%s.vrm" % [char_id, char_id]
		var scene: PackedScene = load(path)
		var inst: Node3D = scene.instantiate()
		root.add_child(inst)
		
		var res: Dictionary = npr_script.apply_npr(inst, char_id)
		print("\nCharacter: ", char_id)
		print("  converted materials: ", res.converted)
		print("  face materials: ", res.face_materials.size())
		print("  outline shell valid: ", is_instance_valid(res.outline_shell))
		if is_instance_valid(res.outline_shell):
			print("  outline surfaces: ", res.outline_shell.mesh.get_surface_count())
			for i in res.outline_shell.mesh.get_surface_count():
				var mat = res.outline_shell.get_surface_override_material(i)
				print("    [", i, "] color: ", mat.get_shader_parameter("outline_color"), " px: ", mat.get_shader_parameter("outline_pixels"))
		inst.queue_free()
		
	quit(0)
