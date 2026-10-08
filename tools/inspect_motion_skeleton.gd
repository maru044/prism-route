extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var character = load("res://scenes/characters/ganyu.tscn").instantiate()
	root.add_child(character)
	var skeleton: Skeleton3D = character.find_child("GeneralSkeleton", true, false)
	var data = {"path": str(character.get_path_to(skeleton)), "bones": []}
	for i in skeleton.get_bone_count():
		var rest = skeleton.get_bone_rest(i)
		var q = rest.basis.get_rotation_quaternion()
		data.bones.append({"name": skeleton.get_bone_name(i), "parent": skeleton.get_bone_parent(i), "position": [rest.origin.x, rest.origin.y, rest.origin.z], "rotation": [q.x,q.y,q.z,q.w], "scale": [rest.basis.get_scale().x,rest.basis.get_scale().y,rest.basis.get_scale().z]})
	var file = FileAccess.open("res://.godot/motion_target_rest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	print("MOTION_SKELETON ", data.path, " bones=", data.bones.size(), " transform=", skeleton.global_transform)
	quit()
