extends SceneTree
## Export numerical UV/geometry data from the actual imported mesh for authored masks.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var character: Node3D = load("res://scenes/characters/ganyu.tscn").instantiate()
	root.add_child(character)
	var skeleton: Skeleton3D = character.find_child("GeneralSkeleton", true, false)
	var animator: AnimationPlayer = character.find_child("AnimationPlayer", true, false)
	if animator: animator.stop()
	skeleton.reset_bone_poses()
	var rows: Array = []
	var textures := {}
	var path := "res://.godot/character_npr_inputs/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	for node: MeshInstance3D in character.find_children("*", "MeshInstance3D", true, false):
		var transform_value := character.global_transform.affine_inverse() * node.global_transform
		for index in node.mesh.get_surface_count():
			var source: StandardMaterial3D = node.get_active_material(index)
			var arrays := node.mesh.surface_get_arrays(index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var positions: Array = []
			var ns: Array = []
			var uvs: Array = []
			for i in vertices.size():
				var point := transform_value * vertices[i]
				var normal := transform_value.basis.inverse().transposed() * normals[i]
				positions.append([point.x, point.y, point.z])
				ns.append([normal.x, normal.y, normal.z])
				uvs.append([uv[i].x, uv[i].y])
			rows.append({"name": node.mesh.surface_get_name(index), "positions": positions, "normals": ns,
				"uv": uvs, "indices": Array(arrays[Mesh.ARRAY_INDEX]), "texture": source.albedo_texture.resource_name})
			if not textures.has(source.albedo_texture.resource_name):
				textures[source.albedo_texture.resource_name] = true
				source.albedo_texture.get_image().save_png(path + source.albedo_texture.resource_name + ".png")
	var file := FileAccess.open(path + "surfaces.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"surfaces": rows, "character_forward": [0, 0, 1]}, ""))
	file.close()
	character.queue_free()
	await process_frame
	print("NPR_INPUTS_EXPORTED ", rows.size())
	quit()
