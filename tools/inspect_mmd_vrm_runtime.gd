extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var model = load("res://assets/characters/import_tests_local/keqing/keqing_fixed.vrm").instantiate()
	root.add_child(model)
	await process_frame
	await process_frame
	var skel: Skeleton3D = model.find_child("GeneralSkeleton", true, false)
	var sim = skel.get_node_or_null("VRMSpringBoneSimulation")
	var methods := []
	if sim:
		for method in ClassDB.class_get_method_list("VRMSpringBoneSimulation", true):
			methods.append(method.name)
	print("VRM_RUNTIME ", JSON.stringify({"simulation": sim != null, "methods": methods, "skeleton_has_advance": skel.has_method("advance"), "properties": ClassDB.class_get_enum_constants("Skeleton3D", "ModifierCallbackModeProcess"), "modifiers": skel.get_children().map(func(n): return [n.name, n.get_class()])}))
	quit()
