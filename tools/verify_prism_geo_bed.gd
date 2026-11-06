@tool
extends SceneTree

func _init() -> void:
	print("Inspecting imported prism_geo_bed.glb...")
	var scene: PackedScene = load("res://assets/furniture/prism/prism_geo_bed.glb")
	if not scene:
		printerr("Failed to load prism_geo_bed.glb")
		quit(1)
		return
	
	var inst: Node3D = scene.instantiate()
	get_root().add_child(inst)
	
	print("Node structure:")
	_dump_nodes(inst, 0)
	
	# Compute bounding box
	var aabb := AABB()
	var first := true
	for mi in _find_mesh_instances(inst):
		var mesh_aabb: AABB = mi.mesh.get_aabb()
		var xform: Transform3D = inst.global_transform.affine_inverse() * mi.global_transform
		var transformed_aabb: AABB = xform * mesh_aabb
		if first:
			aabb = transformed_aabb
			first = false
		else:
			aabb = aabb.merge(transformed_aabb)
			
	print("AABB Dimensions:")
	print("  Width (X):  %.3f m (min: %.3f, max: %.3f)" % [aabb.size.x, aabb.position.x, aabb.end.x])
	print("  Height (Y): %.3f m (min: %.3f, max: %.3f)" % [aabb.size.y, aabb.position.y, aabb.end.y])
	print("  Depth (Z):  %.3f m (min: %.3f, max: %.3f)" % [aabb.size.z, aabb.position.z, aabb.end.z])
	
	quit(0)

func _dump_nodes(node: Node, depth: int) -> void:
	var indent := "  ".repeat(depth)
	var type_str := node.get_class()
	if node is Node3D:
		print("%s- %s (%s) @ pos=(%.3f, %.3f, %.3f), rot_y=%.1f°" % [
			indent, node.name, type_str,
			node.position.x, node.position.y, node.position.z,
			rad_to_deg(node.rotation.y)
		])
	else:
		print("%s- %s (%s)" % [indent, node.name, type_str])
	for child in node.get_children():
		_dump_nodes(child, depth + 1)

func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_mesh_instances(child))
	return result
