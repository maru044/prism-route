@tool
extends SceneTree

const MODEL_PATH := "res://assets/furniture/prism/prism_geo_chair.glb"

func _init() -> void:
	print("Verifying prism_geo_chair.glb in Godot...")
	if not ResourceLoader.exists(MODEL_PATH):
		print("FAIL: Model not found at " + MODEL_PATH)
		quit(1)
		return
		
	var scene = load(MODEL_PATH).instantiate()
	get_root().add_child(scene)
	
	var mi: MeshInstance3D = null
	for child in scene.get_children():
		if child is MeshInstance3D:
			mi = child
			break
	if not mi and scene is MeshInstance3D:
		mi = scene
		
	if not mi:
		print("FAIL: MeshInstance3D not found!")
		quit(1)
		return
		
	var aabb: AABB = mi.get_aabb()
	print("Mesh AABB: Position = ", aabb.position, ", Size = ", aabb.size)
	print("  Width (X):  %.3f m" % aabb.size.x)
	print("  Height (Y): %.3f m" % aabb.size.y)
	print("  Depth (Z):  %.3f m" % aabb.size.z)
	print("  Min Y:      %.4f m" % aabb.position.y)
	print("  Center X:   %.4f m" % (aabb.position.x + aabb.size.x * 0.5))
	print("  Center Z:   %.4f m" % (aabb.position.z + aabb.size.z * 0.5))
	print("  Surfaces:   %d" % mi.mesh.get_surface_count())
	for i in mi.mesh.get_surface_count():
		var mat = mi.get_surface_override_material(i)
		if not mat:
			mat = mi.mesh.surface_get_material(i)
		print("    Surface %d: Material = %s" % [i, mat.resource_name if mat else "None"])
		
	print("VERIFICATION SUCCESSFUL!")
	quit(0)
