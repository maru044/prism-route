@tool
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("================ TEST UNIFIED MTOON PIPELINE ================")
	var mtoon_factory = load("res://scripts/characters/mtoon_materials.gd")
	var paths := {
		"ganyu": "res://scenes/characters/ganyu.tscn",
		"stelle": "res://assets/characters/roster/stelle/stelle.vrm",
		"lumine": "res://assets/characters/roster/lumine/lumine.vrm",
		"firefly": "res://assets/characters/roster/firefly/firefly.vrm",
	}
	
	var total_errors := 0
	
	for char_id in paths:
		var scene: PackedScene = load(paths[char_id])
		var inst: Node3D = scene.instantiate()
		root.add_child(inst)
		
		print("\n>>> Testing character: ", char_id, " <<<")
		var rep: Dictionary = mtoon_factory.apply(inst, char_id)
		print("  Converted: ", rep.converted, " Skipped: ", rep.skipped.size(), " Surfaces: ", rep.surfaces.size())
		
		if not rep.skipped.is_empty():
			print("  ERROR: Skipped surfaces: ", rep.skipped)
			total_errors += 1
			
		for s in rep.surfaces:
			var target_sh: String = s.target_shader
			if target_sh.begins_with("toon_") or target_sh.contains("c0"):
				print("  ERROR: Found C0 shader on surface: ", s)
				total_errors += 1
			if not (target_sh.begins_with("wet_mtoon") or target_sh.begins_with("mtoon")):
				print("  ERROR: Non-MToon shader on surface: ", s)
				total_errors += 1
				
		# Inspect specific sensitive surfaces
		if char_id == "lumine":
			for s in rep.surfaces:
				if s.surface_name == "髪+":
					print("  Lumine 髪+ alpha_mode: ", s.alpha_mode, " target_shader: ", s.target_shader)
					if s.alpha_mode != "transparent":
						print("  ERROR: Lumine 髪+ is not transparent!")
						total_errors += 1
				elif s.surface_name == "髪":
					print("  Lumine 髪 alpha_mode: ", s.alpha_mode, " target_shader: ", s.target_shader)
		elif char_id == "stelle":
			for s in rep.surfaces:
				if s.surface_name in ["眼睛1", "新建", "外套"]:
					print("  Stelle ", s.surface_name, " alpha_mode: ", s.alpha_mode, " cull: ", s.cull_mode, " shader: ", s.target_shader)
					
		inst.queue_free()
		
	print("\n================ TEST SUMMARY ================")
	print("Total errors: ", total_errors)
	if total_errors == 0:
		print("UNIFIED MTOON TEST PASSED 100%!")
	quit(0 if total_errors == 0 else 1)
