extends SceneTree
## Actual 1021 streaming integration; never writes the grass bake or tree layout.
const OUT := "res://.vegetation_art_build/grass_gust/world/"
const EXPECTED_BAKE := "b3f8cc2f8957e6b70ae3f4e2691ecc1debfcfcd1d9a1da524811694b43da4d31"
var failures: Array[String] = []
var report: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await process_frame

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func screenshot(name: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")

func verify_bulk_lod_cache(wind, material: ShaderMaterial) -> void:
	var stream=load("res://scripts/grass_volume_streamer.gd").new()
	stream.vegetation={"grass_material":material}
	var transforms: Array=[];var custom: Array=[]
	for i in 64:
		transforms.append(Transform3D(Basis(Vector3.UP,i*.17)*Basis.from_scale(Vector3(.9,1.1,.9)),Vector3(i*.1,i*.01,-i*.02)))
		custom.append(Color(float(i)/64,.73,.42,float(i%2)))
	var expected: PackedFloat32Array=load("res://scripts/grass_instance_buffer.gd").pack(transforms,custom)
	var node: MultiMeshInstance3D=stream._make_lod_node("CacheRegression",wind.mesh,expected,128,AABB(Vector3(-2,-2,-2),Vector3(12,8,12)))
	root.add_child(node)
	for level in [4,2,1,4]:
		node.multimesh.mesh=wind.lod_meshes[level]
		await frames(2)
		check(node.multimesh.buffer==expected,"LOD cache changed transforms/custom data, including the first seeded instance")
	check(node.get_meta("wind_cpu_cache_bytes")==expected.size()*4,"Runtime cache accounting is incorrect")
	# Exercise the production cache-drop/reload path, not only cached mesh swaps.
	var owner_stream=wind.vegetation.volume_streamer
	var fixture_cell:=Vector3i(999,999,999)
	owner_stream.store.put_data(fixture_cell,{"near":expected,"bytes":expected.size()*4})
	node.set_meta("wind_source",{"cell":fixture_cell,"group":"near","offset":0,"count":64})
	var camera: Camera3D=wind.get_viewport().get_camera_3d()
	node.global_position=camera.global_position
	wind._configure_node(node)
	node.position+=Vector3(300,0,0)
	node.set_meta("wind_bounds",node.global_transform*node.multimesh.custom_aabb)
	wind._update_node_lod(node)
	check(node.get_meta("wind_cpu_cache_bytes")==0 and node.multimesh.mesh==wind.lod_meshes[1],"Far grass retains its extra CPU copy")
	node.position-=Vector3(300,0,0)
	node.set_meta("wind_bounds",node.global_transform*node.multimesh.custom_aabb)
	wind._update_node_lod(node)
	check(node.get_meta("wind_cpu_cache_bytes")==expected.size()*4 and node.multimesh.mesh==wind.mesh,"Near grass cannot recover its detailed mesh")
	check(node.multimesh.buffer==expected,"Far-to-near reload changes grass placement/custom data")
	node.free();stream.free()

func run() -> void:
	root.size = Vector2i(1600, 900)
	Engine.max_fps = 60
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var scene: Node3D = load("res://scenes/map_1021.tscn").instantiate()
	scene.automation_enabled = true
	root.add_child(scene)
	var begin := Time.get_ticks_msec()
	while not scene.test_ready and Time.get_ticks_msec() - begin < 150000:
		await process_frame
	if not scene.test_ready:
		check(false, "World startup timeout")
		quit(1)
		return
	var wind = scene.grass_wind
	var vegetation = scene.vegetation
	var stream = vegetation.volume_streamer
	await verify_bulk_lod_cache(wind,vegetation.grass_material)
	wind.running = false
	var material: ShaderMaterial = vegetation.grass_material
	check(material.shader == wind.SHADER, "World has no accepted gust shader")
	check(material.get_shader_parameter("gust_motion") == 2, "World is not using B")
	check(is_equal_approx(float(material.get_shader_parameter("gust_body_hz")), 0.85), "World uses a different rebound speed")
	check(wind.mode == wind.Mode.AUTO, "World automatic wind is not enabled")
	var signature: String = load("res://scripts/grass_baked_store.gd").signature(scene)
	check(signature == EXPECTED_BAKE and stream.store.manifest.signature == signature, "Wind invalidated the existing bake")
	check(stream.store.manifest.get("complete", false), "Full bake was not reused")
	var arrays: Array = wind.mesh.surface_get_arrays(0)
	check((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() == 30, "World grass lacks bending segments or duplicates its back faces")
	for level: int in [4,2,1]:
		check(wind.lod_meshes[level].surface_get_array_index_len(0)==level*18,"Incorrect grass LOD geometry")
	for parameter: String in ["biome_noise_texture", "biome_noise_scale", "biome_warp_distance", "biome_transition_half_width", "biome_center_x"]:
		check(material.get_shader_parameter(parameter) == scene.terrain_material.get_shader_parameter(parameter), "Shared terrain/grass colors changed")
	# Wind controls are intentionally absent from the compact HUD.
	wind.set_mode(wind.Mode.STRONG)
	wind.advance(3.1)
	check(is_equal_approx(wind.blend, 1.0), "Cannot enable strong wind")
	wind.set_mode(wind.Mode.BREEZE)
	wind.advance(3.1)
	check(is_zero_approx(wind.blend), "Cannot return to breeze")
	wind.set_mode(wind.Mode.AUTO)
	wind.advance(11.1)
	check(is_equal_approx(wind.blend, 1.0), "Automatic wind does not reach strong wind")
	wind.advance(11.0)
	check(is_zero_approx(wind.blend), "Automatic wind does not return to breeze")
	scene.set_review_ui_visible(false)
	check(not scene.spawn_menu.is_visible_in_tree(), "H/no-UI cannot hide the location selector")
	scene.set_review_ui_visible(true)
	check(scene.spawn_menu.is_visible_in_tree(), "Cannot restore the location selector")
	var rows: Array = []
	var extra_cpu_bytes:=0
	for spawn: int in [1, 5, 7]:
		await scene.select_spawn(spawn)
		scene.character.set_physics_process(false)
		scene.set_free(true)
		stream.refresh()
		var start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < 20000:
			await process_frame
			var missing: Dictionary = stream.visible_missing()
			if stream.active.size() > 0 and missing.values().all(func(value):return int(value)==0):
				break
		var checked := 0
		var resident_cpu_bytes:=0
		for chunk: Node3D in stream.active.values():
			for node: MultiMeshInstance3D in chunk.get_children():
				check(node.multimesh.mesh in wind.lod_meshes.values() and node.material_override == material, "Streamed grass did not inherit B")
				check(node.extra_cull_margin >= wind.CULL_MARGIN-0.0001, "New chunks have insufficient wind culling bounds")
				checked += 1
				resident_cpu_bytes+=int(node.get_meta("wind_cpu_cache_bytes",0))
		extra_cpu_bytes=maxi(extra_cpu_bytes,resident_cpu_bytes)
		check(checked > 0, "No streamed grass at spawn %d" % (spawn + 1))
		wind.set_mode(wind.Mode.STRONG)
		wind.advance(3.1)
		wind.elapsed = 0.5
		wind.advance(0.0)
		await screenshot("spawn_%d_strong" % (spawn + 1))
		var timings: Array=[]
		vegetation.set_process(false)
		wind.running = true
		for optimized: bool in [false,true]:
			wind.set_optimized(optimized)
			await frames(30)
			var gpu: Array[float]=[]
			for i in 90:
				await process_frame
				gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
			gpu.sort()
			timings.append({"optimized":optimized,"gpu_median_ms":gpu[45],"gpu_p95_ms":gpu[85],
				"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
		wind.running = false
		vegetation.set_process(true)
		rows.append({"spawn":spawn+1,"chunks":stream.active.size(),"checked_mesh_nodes":checked,"extra_cpu_transform_mib":resident_cpu_bytes/1048576.0,
			"timings":timings,"missing":stream.visible_missing()})
		print("WORLD_WIND_SPAWN ", JSON.stringify(rows.back()))
	# Existing actor footprint is still applied after the new vertex bending.
	await scene.set_character_mode(false)
	await frames(5)
	check(vegetation.grass_interaction.vehicle, "Camper lost its grass interaction")
	check(material.get_shader_parameter("use_grass_interaction"), "World grass no longer responds to actors")
	report = {"passed":failures.is_empty(),"failures":failures,"bake_signature":signature,
		"spawns":rows,"b_mode":true,"rebound_hz":0.85,"bake_reused":true,"extra_cpu_transform_max_mib":extra_cpu_bytes/1048576.0}
	FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WORLD_GRASS_WIND_VERIFY ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
