extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var model_path := "res://scenes/characters/ganyu.tscn"
	var output_path := "res://.godot/motion_target_rest.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--model="): model_path = argument.trim_prefix("--model=")
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
	var character = load(model_path).instantiate()
	root.add_child(character)
	var skeleton: Skeleton3D = character.find_child("GeneralSkeleton", true, false)
	var data = {"path": str(character.get_path_to(skeleton)), "bones": []}
	for i in skeleton.get_bone_count():
		var rest = skeleton.get_bone_rest(i)
		var q = rest.basis.get_rotation_quaternion()
		data.bones.append({"name": skeleton.get_bone_name(i), "parent": skeleton.get_bone_parent(i), "position": [rest.origin.x, rest.origin.y, rest.origin.z], "rotation": [q.x,q.y,q.z,q.w], "scale": [rest.basis.get_scale().x,rest.basis.get_scale().y,rest.basis.get_scale().z]})
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	print("MOTION_SKELETON ", data.path, " bones=", data.bones.size(), " transform=", skeleton.global_transform)
	quit()
