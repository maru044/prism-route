extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/character_mmd_validation.tscn").instantiate()
	root.add_child(scene)
	scene.playing = false
	var skeleton: Skeleton3D = scene.skeleton
	var player: AnimationPlayer = scene.player
	var clip := player.get_animation(scene.clip_name)
	var meshes: Array = scene.character.find_children("*", "MeshInstance3D", true, false)
	assert(skeleton.get_bone_count() == 316)
	assert(absf(clip.length - 16.0) < 0.001)
	assert(meshes.size() > 0)
	var reference = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/mmd_validation/loop03_reference.json"))
	var skin_reference = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/mmd_validation/keqing_skin_reference.json"))
	var max_bone_error := 0.0
	var max_bounds_error := 0.0
	var max_weight_error := 0.0
	var vertices := 0
	var surfaces := 0
	var checked_vertices := 0
	var joint_comparisons := 0
	var first_frame_vertices: Array[Vector3] = []
	var max_vertex_motion := 0.0
	var frames_report := []
	var cached_surfaces := []
	for mesh: MeshInstance3D in meshes:
		assert(mesh.skin != null and mesh.get_node(mesh.skeleton) == skeleton)
		var bindings := []
		for bind in mesh.skin.get_bind_count():
			var name := mesh.skin.get_bind_name(bind)
			var index := skeleton.find_bone(name) if not name.is_empty() else mesh.skin.get_bind_bone(bind)
			assert(index >= 0 and index < skeleton.get_bone_count())
			bindings.append({"index": index, "pose": mesh.skin.get_bind_pose(bind)})
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			assert(mesh.get_active_material(surface) != null)
			assert(not points.is_empty() and not weights.is_empty())
			var influences: int = weights.size() / points.size()
			for i in points.size():
				var total := 0.0
				for influence in influences:
					var k: int = i * influences + influence
					assert(joints[k] >= 0 and joints[k] < bindings.size())
					total += weights[k]
				max_weight_error = maxf(max_weight_error, absf(total - 1.0))
			vertices += points.size()
			surfaces += 1
			cached_surfaces.append({"points": points, "weights": weights, "joints": joints, "influences": influences, "bindings": bindings})
	for sample_index in reference.reference_frames.size():
		var sample = reference.reference_frames[sample_index]
		scene.seek_frame(int(sample.frame))
		for name in sample.positions_y_up:
			var values: Array = sample.positions_y_up[name]
			var index := skeleton.find_bone(name)
			assert(index >= 0)
			var actual: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(index).origin
			max_bone_error = maxf(max_bone_error, actual.distance_to(Vector3(values[0], values[1], values[2])))
			joint_comparisons += 1
		var minimum := Vector3(INF, INF, INF)
		var maximum := Vector3(-INF, -INF, -INF)
		var vertex_index := 0
		for surface in cached_surfaces:
			var matrices: Array[Transform3D] = []
			for binding in surface.bindings:
				matrices.append(skeleton.global_transform * skeleton.get_bone_global_pose(binding.index) * binding.pose)
			for i in surface.points.size():
				var point := Vector3.ZERO
				for influence in surface.influences:
					var k: int = i * surface.influences + influence
					point += (matrices[surface.joints[k]] * surface.points[i]) * surface.weights[k]
				assert(point.is_finite())
				minimum = minimum.min(point)
				maximum = maximum.max(point)
				if sample_index == 0: first_frame_vertices.append(point)
				else: max_vertex_motion = maxf(max_vertex_motion, point.distance_to(first_frame_vertices[vertex_index]))
				vertex_index += 1
				checked_vertices += 1
		var expected = skin_reference.frames[sample_index]
		assert(int(expected.frame) == int(sample.frame))
		var a: Array = expected.minimum
		var b: Array = expected.maximum
		var error := maxf(minimum.distance_to(Vector3(a[0], a[1], a[2])), maximum.distance_to(Vector3(b[0], b[1], b[2])))
		max_bounds_error = maxf(max_bounds_error, error)
		frames_report.append({"frame": sample.frame, "skin_bounds_error_m": error})
	var passed := max_bone_error < 0.0001 and max_bounds_error < 0.0001 and max_weight_error < 0.0001 and max_vertex_motion > 0.001
	var report := {"passed": passed, "engine": Engine.get_version_info().string, "model": scene.MODEL, "bones": skeleton.get_bone_count(), "surfaces": surfaces, "imported_vertices_including_uv_splits": vertices, "skin_vertex_frame_checks": checked_vertices, "joint_comparisons": joint_comparisons, "length_seconds": clip.length, "tracks": clip.get_track_count(), "max_bone_position_error_m": max_bone_error, "max_skin_bounds_error_m": max_bounds_error, "max_weight_sum_error": max_weight_error, "max_vertex_motion_m": max_vertex_motion, "frames": frames_report}
	var output := "res://.godot/mmd_character_validation.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("MMD_CHARACTER_VALIDATION ", JSON.stringify(report))
	quit(0 if passed else 1)
