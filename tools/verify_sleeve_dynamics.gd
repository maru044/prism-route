extends SceneTree
## Capture native modifier poses before Skeleton3D restores animation poses.
var posed: Array[Transform3D] = []
var processed := 0
var scene: Node
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _record() -> void:
	posed.clear()
	for i in scene.skeleton.get_bone_count():
		posed.append(scene.skeleton.get_bone_global_pose(i))
	processed += 1

func _run() -> void:
	var capture := "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1440, 1000)
	var reports: Array = []
	var tiles: Array[Image] = []
	for model in ["keqing", "huahuo"]:
		var path := "res://scenes/character_huahuo_import_test.tscn" if model == "huahuo" else "res://scenes/character_model_import_test.tscn"
		scene = load(path).instantiate()
		root.add_child(scene)
		await process_frame
		await process_frame
		var controller = scene.character.find_child("VRMSpringBoneController", true, false)
		var simulation = scene.skeleton.get_node_or_null("VRMSpringBoneSimulation")
		if simulation == null or controller == null:
			failures.append(model + " missing simulation")
			scene.free()
			continue
		simulation.modification_processed.connect(_record)
		var chains: Array = controller.spring_bones
		var collider_count: int = controller.collider_groups[0].colliders.size()
		var samples: Array = []
		for id in ["A01", "A05", "A06", "A25", "A30"]:
			for i in scene.catalog.size():
				if scene.catalog[i].id == id: scene._select(i)
			scene.player.pause()
			scene.player.seek(scene.catalog[scene.selected].duration * .35, true)
			scene._center_character()
			scene.yaw = .7 if id == "A30" else .22
			scene.camera_target = Vector3(0, .65 if id == "A30" else .8, 0)
			scene.distance = 2.8
			scene._update_camera()
			scene._set_springs(false)
			await process_frame
			await process_frame
			if simulation.active: failures.append(model + " disabled modifier still active")
			scene.skeleton.force_update_all_bone_transforms()
			var rigid: Array[Transform3D] = []
			for bone in scene.skeleton.get_bone_count():
				rigid.append(scene.skeleton.get_bone_global_pose(bone))
			if capture and id in ["A01", "A05", "A30"]:
				tiles.append(await _capture(model, id, "rigid"))
			scene._set_springs(true)
			var old_processed := processed
			for frame in 180: await process_frame
			if not simulation.active or processed == old_processed: failures.append(model + " simulation did not run")
			var movements: Array = []
			var max_length_error := 0.0
			for chain in chains:
				var tip: int = scene.skeleton.find_bone(chain.joint_nodes[-1])
				movements.append(posed[tip].origin.distance_to(rigid[tip].origin))
				for i in range(1, chain.joint_nodes.size()):
					var a: int = scene.skeleton.find_bone(chain.joint_nodes[i - 1])
					var b: int = scene.skeleton.find_bone(chain.joint_nodes[i])
					var original_length := rigid[a].origin.distance_to(rigid[b].origin)
					max_length_error = maxf(max_length_error, absf(posed[a].origin.distance_to(posed[b].origin) - original_length))
			for transform in posed:
				if not transform.is_finite(): failures.append(model + " invalid simulated pose")
			if max_length_error > .001: failures.append(model + " sleeve segment stretched")
			if movements.max() < .01: failures.append(model + " sleeve still rigid")
			samples.append({"motion": id, "tip_displacements_m": movements, "max_length_error_m": max_length_error})
			if capture and id in ["A01", "A05", "A30"]:
				tiles.append(await _capture(model, id, "dynamic"))
		# Continuous walking/running, including loop seams and action switches.
		for id in ["A05", "A06"]:
			for i in scene.catalog.size():
				if scene.catalog[i].id == id: scene._select(i)
			for frame in 240:
				await process_frame
				for transform in posed:
					if not transform.is_finite(): failures.append(model + " invalid moving pose")
		# Switch variants while disabled; the new native modifier must stay off.
		scene._set_springs(false)
		scene._switch_variant(1)
		scene._switch_variant(0)
		await process_frame
		await process_frame
		if scene.skeleton.get_node("VRMSpringBoneSimulation").active:
			failures.append(model + " variant switch lost disabled state")
		reports.append({"model": model, "chains": chains.size(), "colliders": collider_count,
			"samples": samples})
		scene.free()
	if capture:
		var contact := Image.create(2100, 1500, false, Image.FORMAT_RGB8)
		for i in tiles.size():
			contact.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, tiles[i].get_size()), Vector2i((i % 4) * 525, (i / 4) * 500))
		contact.save_png(ProjectSettings.globalize_path("res://.model_import_build/sleeves_comparison.png"))
	var report := {"godot": Engine.get_version_info().string, "models": reports, "failures": failures}
	FileAccess.open("res://.model_import_build/sleeves_validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("SLEEVE_RESULT ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _capture(model: String, motion: String, mode: String) -> Image:
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.save_png(ProjectSettings.globalize_path("res://.model_import_build/%s_%s_sleeves_%s.png" % [model, motion, mode]))
	var tile := picture.get_region(Rect2i(390, 0, picture.get_width() - 390, picture.get_height()))
	tile.resize(525, 500, Image.INTERPOLATE_LANCZOS)
	return tile
