extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/character_model_import_test.tscn").instantiate()
	root.add_child(scene)
	var failures: Array[String] = []
	var results: Array = []
	for variant in [0, 1, 0]:
		scene._switch_variant(variant)
		for i in scene.catalog.size():
			scene._select(i)
			var animation: Animation = scene.player.get_animation(scene.catalog[i].id)
			for track in animation.get_track_count():
				var path := animation.track_get_path(track)
				if scene.character.get_node_or_null(NodePath(str(path).get_slice(":", 0))) != scene.skeleton or scene.skeleton.find_bone(str(path).get_slice(":", 1)) < 0:
					failures.append("Unresolved track: " + str(path))
			for fraction in [0.0, 0.25, 0.5, 0.75, 0.999]:
				scene.player.seek(animation.length * fraction, true)
				scene.skeleton.force_update_all_bone_transforms()
				for bone in scene.skeleton.get_bone_count():
					if not scene.skeleton.get_bone_global_pose(bone).is_finite(): failures.append("Invalid pose")
			results.append({"variant": variant, "id": scene.catalog[i].id, "tracks": animation.get_track_count()})
	# A model comparison must retain the paused pose, speed, and selected clip.
	scene.player.speed_scale = 0.5
	scene._pause()
	scene.player.seek(0.2, true)
	scene._switch_variant(1)
	if scene.player.is_playing() or absf(scene.player.current_animation_position - 0.2) > 0.001 or scene.player.speed_scale != 0.5:
		failures.append("Variant switch lost playback state")
	var report := {"godot": Engine.get_version_info().string, "bones": scene.skeleton.get_bone_count(), "clips": scene.catalog.size(), "checks": results, "failures": failures}
	FileAccess.open("res://.model_import_build/godot_validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("MODEL_IMPORT_RESULT ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
