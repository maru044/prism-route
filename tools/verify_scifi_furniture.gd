@tool
extends SceneTree

const CATALOG_PATH := "res://assets/furniture/scifi/furniture_catalog.json"

func _init() -> void:
	print("==================================================")
	print("    GODOT SCI-FI FURNITURE VERIFICATION SUITE     ")
	print("==================================================")
	
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if not file:
		printerr("FAILED: Cannot open ", CATALOG_PATH)
		quit(1)
		return
		
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	var furniture_list: Array = data.get("furniture", [])
	print("Loaded catalog with ", furniture_list.size(), " furniture items.\n")
	
	var all_passed := true
	
	for item in furniture_list:
		var item_id: String = item.get("id", "")
		var item_name: String = item.get("name_zh", "")
		var res_path: String = item.get("file", "")
		print("--------------------------------------------------")
		print("VERIFYING: [", item_id, "] ", item_name)
		print("Path: ", res_path)
		
		var scene: PackedScene = load(res_path)
		if not scene:
			printerr("  ❌ FAILED: Unable to load resource ", res_path)
			all_passed = false
			continue
			
		var root: Node = scene.instantiate()
		if not root or not (root is Node3D):
			printerr("  ❌ FAILED: Root is not Node3D")
			all_passed = false
			continue
			
		var root_3d := root as Node3D
		if not root_3d.transform.is_equal_approx(Transform3D.IDENTITY):
			printerr("  ❌ FAILED: Root transform is not IDENTITY: ", root_3d.transform)
			all_passed = false
			
		# Find MeshInstance3D
		var mesh_instance: MeshInstance3D = null
		for child in root_3d.get_children():
			if child is MeshInstance3D:
				mesh_instance = child as MeshInstance3D
				break
				
		if not mesh_instance:
			printerr("  ❌ FAILED: No MeshInstance3D found in scene")
			all_passed = false
			continue
			
		if not mesh_instance.transform.is_equal_approx(Transform3D.IDENTITY):
			printerr("  ❌ FAILED: Mesh transform is not IDENTITY: ", mesh_instance.transform)
			all_passed = false
			
		var aabb := mesh_instance.get_aabb()
		var mesh := mesh_instance.mesh
		var faces := mesh.get_faces() if mesh else PackedVector3Array()
		
		var center_x := aabb.position.x + aabb.size.x * 0.5
		var center_z := aabb.position.z + aabb.size.z * 0.5
		var min_y := aabb.position.y
		var max_y := aabb.position.y + aabb.size.y
		
		print("  Width (X):  %.3f m (Span [%.3f, %.3f], Center X: %.4f)" % [aabb.size.x, aabb.position.x, aabb.position.x + aabb.size.x, center_x])
		print("  Height (Y): %.3f m (Ground Contact Y: %.4f, Max Y: %.3f)" % [aabb.size.y, min_y, max_y])
		print("  Depth (Z):  %.3f m (Span [%.3f, %.3f], Center Z: %.4f)" % [aabb.size.z, aabb.position.z, aabb.position.z + aabb.size.z, center_z])
		print("  Faces: %d, Surfaces: %d" % [faces.size() / 3, mesh.get_surface_count() if mesh else 0])
		
		# Ground contact check
		if abs(min_y) > 0.005:
			printerr("  ❌ FAILED: Ground contact Y is not 0.0! min_y = ", min_y)
			all_passed = false
		else:
			print("  ✓ Ground Contact: PERFECT (Y = %.4f)" % min_y)
			
		# Center X check
		if abs(center_x) > 0.01:
			printerr("  ❌ FAILED: Center X is not 0.0! center_x = ", center_x)
			all_passed = false
		else:
			print("  ✓ Origin X Centering: PERFECT (Center X = %.4f)" % center_x)
			
		# Center Z check
		if abs(center_z) > 0.01:
			printerr("  ❌ FAILED: Center Z is not 0.0! center_z = ", center_z)
			all_passed = false
		else:
			print("  ✓ Origin Z Centering: PERFECT (Center Z = %.4f)" % center_z)
			
		# Facing check for chairs/sofas
		if item.category in ["chair", "sofa", "armchair"]:
			var top_zs: Array[float] = []
			for f in faces:
				if f.y > max_y - 0.15:
					top_zs.append(f.z)
			if top_zs.size() > 0:
				var avg_top_z := 0.0
				for z in top_zs: avg_top_z += z
				avg_top_z /= top_zs.size()
				print("  Backrest Top Z Avg: %.3f (Expected < 0 for forward +Z facing towards front camera)" % avg_top_z)
				if avg_top_z >= 0:
					printerr("  ❌ FAILED: Backrest is in front (facing -Z instead of +Z)")
					all_passed = false
				else:
					print("  ✓ Facing Direction: PERFECT (Backrest at -Z, Seat opening faces +Z towards camera)")
					
		root.queue_free()
		
	print("\n==================================================")
	if all_passed:
		print("  🎉 ALL 5 SCI-FI FURNITURE ASSETS PASSED VERIFICATION!")
		print("==================================================")
		quit(0)
	else:
		printerr("  ❌ SOME FURNITURE ASSETS FAILED VERIFICATION.")
		print("==================================================")
		quit(1)
