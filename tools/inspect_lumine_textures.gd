@tool
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://assets/characters/roster/lumine/lumine.vrm")
	var inst: Node3D = scene.instantiate()
	root.add_child(inst)
	var mesh: MeshInstance3D = inst.find_child("荧_mesh", true, false)
	
	for i in [9, 19]:
		var s_name = mesh.mesh.surface_get_name(i)
		var mat = mesh.get_active_material(i)
		var tex: Texture2D = mat.get_shader_parameter("_MainTex")
		print("Surface ", i, " name=", s_name, " tex=", tex)
		if tex != null:
			var img: Image = tex.get_image()
			var p = "C:/Users/PC/.gemini/antigravity/brain/51c58479-72e8-436c-a199-d13ab3cac199/batch09_review/lumine_surf_%d.png" % i
			img.save_png(p)
			print("Saved: ", p, " size=", img.get_size(), " format=", img.get_format())
			
	quit(0)
