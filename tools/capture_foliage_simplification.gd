extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var scene = load("res://scenes/tree_lod_transition_test.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.vegetation.set_small_tree_filtering_enabled(false)
	scene.camera.set_process(false)
	scene.set_process(false)
	scene.get_node("HUD/Status").hide()
	var heading: Label = scene.get_node("HUD/Instructions")
	for nodes in [scene.vegetation.tree_lod0_nodes, scene.vegetation.tree_lod1_nodes, scene.vegetation.tree_lod2_nodes]:
		for node in nodes:
			if not node.name.begins_with("Tree0"):
				node.hide()
			if node.material_override is ShaderMaterial:
				node.material_override.set_shader_parameter("wind_strength", 0.0)
	var env: Environment = scene.get_node("WorldEnvironment").environment
	var sun: DirectionalLight3D = scene.get_node("Sun")
	var small_mats: Array[ShaderMaterial] = []
	var original_textures: Dictionary = {}
	for nodes in [scene.vegetation.tree_lod0_nodes, scene.vegetation.tree_lod1_nodes, scene.vegetation.tree_lod2_nodes]:
		for node in nodes:
			if node.name.begins_with("Tree0") and node.material_override is ShaderMaterial:
				var material: ShaderMaterial = node.material_override
				small_mats.append(material)
				original_textures[material] = material.get_shader_parameter("albedo_texture")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.vegetation_art_build/simplification"))
	for view in ["near", "player", "mid", "transition", "far"]:
		var target := Vector3(-11, 3.7, 0)
		scene.camera.fov = 36.0
		scene.camera.position = Vector3(-11, 4.3, 14) if view == "near" else Vector3(-11, 1.7, 28)
		if view == "mid":
			scene.camera.position = Vector3(-11, 5, 150)
			scene.camera.fov = 12.0
		elif view == "transition":
			scene.camera.position = Vector3(-11, 5, 305)
			scene.camera.fov = 6.0
		elif view == "far":
			scene.camera.position = Vector3(-11, 5, 370)
			scene.camera.fov = 5.0
		scene.camera.look_at(target)
		var modes := ["baseline", "candidate"] if view in ["transition", "far"] else ["baseline", "no_ssao", "no_sun_shadow", "no_angle_fade", "mip_raw", "mip_coverage", "shader_only", "candidate"]
		for mode in modes:
			env.ssao_enabled = mode != "no_ssao"
			sun.shadow_enabled = mode != "no_sun_shadow"
			for material in small_mats:
				var original: Texture2D = original_textures[material]
				var key := "leaf" if "leaf_clusters" in original.resource_path else ("canopy" if "8view" in original.resource_path else "clump")
				material.set_shader_parameter("use_view_angle_fade", key == "leaf" and mode != "no_angle_fade")
				material.set_shader_parameter("albedo_texture", original)
				if mode in ["mip_raw", "mip_coverage", "candidate"]:
					var suffix := "raw" if mode == "mip_raw" else "coverage"
					material.set_shader_parameter("albedo_texture", load("res://assets/vegetation/textures/filtered_lod/%s_%s.res" % [key, suffix]))
				var smooth: bool = mode in ["shader_only", "candidate"] and key != "canopy"
				material.set_shader_parameter("canopy_smoothing_strength", (0.62 if key == "leaf" else 0.35) if smooth else 0.0)
				material.set_shader_parameter("canopy_color_uniformity", 0.85 if smooth else 0.0)
				material.set_shader_parameter("canopy_base_color", Color(91.0/255.0, 120.0/255.0, 75.0/255.0) if key == "leaf" else Color(106.8/255.0, 131.6/255.0, 94.1/255.0))
				material.set_shader_parameter("tree_canopy_center_local", Vector3(0.011, 3.672, -0.049))
				material.set_shader_parameter("tree_canopy_radii_local", Vector3(3.850, 2.568, 2.883))
			heading.text = "SMALL TREE DIAGNOSTIC / %s / %s\nOriginal geometry and texture; fixed camera, sun and wind." % [view, mode]
			for frame in 30:
				await process_frame
			await RenderingServer.frame_post_draw
			var path := "res://.vegetation_art_build/simplification/%s_%s.png" % [view, mode]
			var error := root.get_texture().get_image().save_png(path)
			if error != OK:
				quit(1)
				return
			print("FOLIAGE_DIAGNOSTIC ", path)
	# Exercise the view-dependent crown approximation with a continuous orbit
	# and restored wind, not only still images at one camera position.
	for material in small_mats:
		SmallTreeFiltering.apply(material, int(material.get_meta("small_tree_lod")), true)
		material.set_shader_parameter("wind_strength", 0.075)
	scene.camera.fov = 36.0
	for frame in 120:
		var angle := lerpf(-0.5, 0.5, float(frame) / 119.0)
		scene.camera.position = Vector3(-11 + sin(angle) * 14, 4.3, cos(angle) * 14)
		scene.camera.look_at(Vector3(-11, 3.7, 0))
		await process_frame
		if frame in [0, 59, 119]:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.vegetation_art_build/simplification/motion_%d.png" % frame)
	print("FOLIAGE_MOTION_COMPLETE 120 frames, continuous orbit and wind")
	quit()
