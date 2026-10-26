extends SceneTree
## Exercise real MToon materials, water absorption and dry appearance in Forward+.
const FACTORY = preload("res://scripts/characters/mtoon_materials.gd")
const OUT := "res://docs/water_character_1027/"
var scene
var failures: Array[String] = []
var report: Dictionary = {}
var entries: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func frames(count: int) -> void:
	for i in count: await process_frame
func shot(name_value: String) -> Image:
	await frames(8)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	check(image.save_png(OUT + name_value + ".png") == OK, "Capture failed: " + name_value)
	return image
func mode(formal: bool) -> void:
	for entry in entries:
		entry.mesh.set_surface_override_material(entry.index, entry.formal if formal else entry.legacy)
func difference(a: Image, b: Image) -> Dictionary:
	var aa := a.get_data(); var bb := b.get_data()
	var total := 0.0; var changed := 0
	for i in range(0, aa.size(), 4):
		var maximum := 0
		for c in 3:
			var value := absi(int(aa[i+c])-int(bb[i+c]))
			total += value
			maximum = maxi(maximum, value)
		if maximum > 5: changed += 1
	return {"mean_rgb_error":total/(a.get_width()*a.get_height()*3.0*255.0), "changed_pixels":changed}

func inspect() -> void:
	var counts := {"opaque":0, "cutout":0, "blend":0}
	for mesh: MeshInstance3D in scene.character.character.find_children("*", "MeshInstance3D", true, false):
		for index in mesh.mesh.get_surface_count():
			var source: StandardMaterial3D = mesh.mesh.surface_get_material(index)
			var active: ShaderMaterial = mesh.get_active_material(index)
			var name_value: String = mesh.mesh.surface_get_name(index)
			var region := "face" if name_value in ["面1","面2"] else ("skin" if name_value == "肌" else "body")
			var legacy := FACTORY.create(source, region)
			entries.append({"mesh":mesh, "index":index, "name":name_value, "formal":active, "legacy":legacy})
			check(source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS, "Imported source alpha mutated")
			if name_value == "脸红":
				counts.blend += 1
				check(active.shader.resource_path.ends_with("mtoon_prepass_cull_off.gdshader"), "Continuous blush alpha lost")
			elif name_value in ["服","肌"]:
				counts.cutout += 1
				check(active.shader.resource_path.ends_with("mtoon_cutout_cull_off.gdshader"), "Cloth/skin holes made opaque")
				check(active.get_shader_parameter("_AlphaCutoutEnable") == 1.0, "Alpha holes disabled")
			else:
				counts.opaque += 1
				check(active.shader.resource_path.ends_with("mtoon_cull_off.gdshader"), "Solid material remains transparent: " + name_value)
			for parameter in ["_Color","_ShadeColor","_ShadeToony","_IndirectLightIntensity","_ReceiveShadowRate","_MainTex","_ShadeTexture","_MainTex_ST","_OutlineWidthMode","_Cutoff"]:
				check(active.get_shader_parameter(parameter) == legacy.get_shader_parameter(parameter), "Lighting or texture changed: " + name_value + " / " + parameter)
	check(counts == {"opaque":16,"cutout":2,"blend":1}, "Unexpected material distribution")
	report.materials = counts
	var skeleton: Skeleton3D = scene.character.skeleton
	var mesh: MeshInstance3D = entries[0].mesh
	report.blend_shapes = []
	for i in mesh.mesh.get_blend_shape_count(): report.blend_shapes.append(mesh.mesh.get_blend_shape_name(i))
	check(skeleton.get_bone_count() > 0 and mesh.mesh.get_blend_shape_count() == 60, "Skeleton or morph targets changed")

func dry_appearance() -> void:
	for row: Dictionary in scene.water.bodies: row.mesh.hide()
	scene.character.global_position = Vector3(0,1.0,4)
	scene.camera.position = scene.character.global_position + Vector3(0,1.40,1.15)
	scene.camera.look_at(scene.character.global_position + Vector3(0,1.37,0))
	scene.character.visual.rotation.y = 0
	report.dry_face = []
	var neutral: Image
	for angle in [0,75,180]:
		scene.character.visual.rotation_degrees.y = angle
		mode(false)
		var before := await shot("dry_face_" + str(angle) + "_before")
		mode(true)
		var after := await shot("dry_face_" + str(angle) + "_after")
		if angle == 0: neutral = after
		var delta := difference(before, after)
		delta.angle = angle
		report.dry_face.append(delta)
		check(delta.mean_rgb_error < 0.015, "Dry face changed substantially: " + str(angle))
	scene.character.visual.rotation.y = 0
	var mesh: MeshInstance3D = entries[0].mesh
	report.expressions = []
	for expression in ["照れ","まばたき"]:
		var index := mesh.find_blend_shape_by_name(expression)
		check(index >= 0, "Expression missing: " + expression)
		if index < 0: continue
		mesh.set_blend_shape_value(index,1.0)
		var label := "blush" if expression == "照れ" else "blink"
		mode(false); var old_expression := await shot("dry_"+label+"_before")
		mode(true); var new_expression := await shot("dry_"+label+"_after")
		var delta := difference(old_expression,new_expression)
		delta.expression = expression
		delta.response_pixels = difference(neutral,new_expression).changed_pixels
		report.expressions.append(delta)
		check(delta.mean_rgb_error < 0.015, "Expression appearance changed: " + expression)
		check(delta.response_pixels > 10, "Expression does not visibly respond: " + expression)
		mesh.set_blend_shape_value(index,0.0)
	scene.camera.position = scene.character.global_position + Vector3(0,1.10,2.5)
	scene.camera.look_at(scene.character.global_position + Vector3(0,.9,0))
	mode(false); var before := await shot("dry_body_before")
	mode(true); var after := await shot("dry_body_after")
	report.dry_body = difference(before,after)
	check(report.dry_body.mean_rgb_error < 0.015, "Dry body changed substantially")

func water_coverage() -> void:
	# Exclude the actor's ground shadow from the silhouette-based pixel mask.
	for entry in entries: entry.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.character.global_position = Vector3(0,-.56,20)
	scene.camera.position = Vector3(0,1.1,23.5)
	scene.camera.look_at(scene.character.global_position+Vector3(0,.7,0))
	mode(true)
	# Derive the character silhouette without water, using the same geometry and pose.
	var silhouette := await shot("silhouette_character")
	scene.character.hide()
	var background := await shot("silhouette_background")
	scene.character.show()
	for row: Dictionary in scene.water.bodies: row.mesh.show()
	scene.water._process(1.0)
	mode(false); var old_normal := await shot("water_before")
	mode(true); var new_normal := await shot("water_after")
	for row: Dictionary in scene.water.bodies:
		row.material.set_shader_parameter("shallow_color",Color(1,0,1))
		row.material.set_shader_parameter("deep_color",Color(1,0,1))
		row.material.set_shader_parameter("absorption",8.0)
	mode(false); var old_probe := await shot("water_probe_before")
	mode(true); var new_probe := await shot("water_probe_after")
	var mask_a := silhouette.get_data(); var mask_b := background.get_data()
	var old_a := old_normal.get_data(); var old_b := old_probe.get_data()
	var new_a := new_normal.get_data(); var new_b := new_probe.get_data()
	var samples := 0; var old_changed := 0; var new_changed := 0
	var upper_samples := 0; var upper_changed := 0
	var width := silhouette.get_width(); var height := silhouette.get_height()
	# Camera projection is expressed in the stretched viewport's logical pixels.
	var pixel_scale := float(height)/root.get_visible_rect().size.y
	var waterline := int(scene.camera.unproject_position(Vector3(0,0,20)).y*pixel_scale)
	var foot := int(scene.camera.unproject_position(Vector3(0,-.5,20)).y*pixel_scale)
	for y in range(height):
		for x in range(width):
			var i := (y*width+x)*4
			var silhouette_delta := 0
			var old_delta := 0; var new_delta := 0
			for c in 3:
				silhouette_delta = maxi(silhouette_delta,absi(int(mask_a[i+c])-int(mask_b[i+c])))
				old_delta = maxi(old_delta,absi(int(old_a[i+c])-int(old_b[i+c])))
				new_delta = maxi(new_delta,absi(int(new_a[i+c])-int(new_b[i+c])))
			if silhouette_delta < 30: continue
			if y > waterline+10 and y < foot-5:
				samples += 1
				if old_delta > 12: old_changed += 1
				if new_delta > 12: new_changed += 1
			elif y < waterline-15:
				upper_samples += 1
				if new_delta > 12: upper_changed += 1
	report.coverage = {"submerged_samples":samples,"legacy_affected":old_changed,"formal_affected":new_changed,"above_water_samples":upper_samples,"above_water_affected":upper_changed}
	check(samples > 100, "No submerged character pixels tested")
	check(new_changed > samples*.75, "Water absorption does not affect most submerged character pixels")
	check(old_changed < samples*.15, "Legacy comparison does not reproduce the reported defect")
	check(upper_changed < maxi(10,int(upper_samples*.01)), "Water tint leaks above the surface")
	for row: Dictionary in scene.water.bodies:
		var settings: Dictionary = scene.water.PROFILES.SETTINGS[row.profile]
		row.material.set_shader_parameter("shallow_color",settings.shallow)
		row.material.set_shader_parameter("deep_color",settings.deep)
		row.material.set_shader_parameter("absorption",settings.absorption)
	scene.water.wind_override = 1.0
	scene.water._process(0.0)
	for row: Dictionary in scene.water.bodies:
		check(row.material.get_shader_parameter("wind_strength") == 0.0, "Strong water wind effects re-enabled")
	scene.water.interaction.add_event(Vector3(0,0,20),"shallow_test",scene.water.clock-.4)
	scene.water._process(0.0)
	check(scene.water.bodies[0].material.get_shader_parameter("event_count") == 1, "Character ripple event lost")
	await shot("water_ripples_after")
	scene.water.interaction.reset()
	report.depths = []
	for z in [4,12,20]:
		var feet: float = scene.bed_height(z)+.04
		scene.character.global_position = Vector3(0,feet,z)
		scene.camera.position = Vector3(0,feet+1.66,z+3.5)
		scene.camera.look_at(scene.character.global_position+Vector3(0,.7,0))
		scene.water._process(0.0)
		mode(false); await shot("depth_"+str(z)+"_before")
		mode(true); await shot("depth_"+str(z)+"_after")
		report.depths.append({"feet_y":feet,"water_y":0.0})

func ray(a: Vector3, b: Vector3, mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(a,b,mask)
	query.hit_back_faces = true
	return scene.get_world_3d().direct_space_state.intersect_ray(query)

func world_checks() -> void:
	scene = load("res://scenes/map_1021.tscn").instantiate()
	scene.automation_enabled = true
	root.add_child(scene)
	var start := Time.get_ticks_msec()
	while not scene.test_ready and Time.get_ticks_msec()-start < 150000: await process_frame
	check(scene.test_ready,"Formal map startup timeout")
	if not scene.test_ready: return
	check(scene.spawn_index == 8 and scene.character_mode,"Formal cave spawn changed")
	check(scene.water_manager.bodies.size() == 7,"Formal water count changed")
	check(scene.character.collision_mask == 32,"Water became a solid character floor")
	inspect()
	scene.set_free(true); scene.set_review_ui_visible(false)
	scene.grass_wind.running = false
	scene.grass_wind.blend = 0.0; scene.grass_wind.advance(0.0)
	var probes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/current_map_validation/review/lagoon_1026_probes.json"))
	report.lagoons = []
	for name_value in ["south","north"]:
		var chosen := {}; var chosen_water := {}
		for sample: Array in probes[name_value].samples:
			var p := Vector3(float(sample[0])-1450,0,1150-float(sample[1]))
			var water_hit := ray(p+Vector3.UP*.1,p-Vector3.UP*.1,4)
			if water_hit.is_empty() or not ray(p+Vector3.UP*.1,p+Vector3.UP*3.0,32).is_empty(): continue
			var floor_hit := ray(p-Vector3.UP*.02,p-Vector3.UP*1.5,32)
			if floor_hit.is_empty(): continue
			if chosen.is_empty() or floor_hit.position.y < chosen.position.y:
				chosen = floor_hit; chosen_water = water_hit
		check(not chosen.is_empty(),"No open lake bed for character: "+name_value)
		if chosen.is_empty(): continue
		scene.character.process_mode = Node.PROCESS_MODE_INHERIT
		scene.character.set_spawn(chosen.position+Vector3.UP*.04,PI)
		await frames(3)
		scene.character.player.pause(); scene.character.player.seek(.6,true)
		scene.character.visual.rotation.y = 0
		scene.character.process_mode = Node.PROCESS_MODE_DISABLED
		scene.camera.position = scene.character.global_position+Vector3(0,1.66,3.5)
		scene.camera.look_at(scene.character.global_position+Vector3(0,.7,0))
		var manager = scene.water_manager
		manager.interaction.reset(); manager.set_process(true)
		await frames(20)
		manager.set_process(false); manager._process(1.0)
		mode(false); await shot("world_"+name_value+"_before")
		mode(true); await shot("world_"+name_value+"_after")
		manager.wind_override = 1.0; manager._process(0.0)
		for row: Dictionary in manager.bodies:
			check(row.material.get_shader_parameter("wind_strength") == 0.0,"Formal map re-enabled water wind")
		check(absf(chosen_water.position.y) < .001,"Unexpected world water level")
		report.lagoons.append({"name":name_value,"position":str(scene.character.global_position),"water_id":chosen_water.collider.get_meta("source_id",""),"water_y":chosen_water.position.y})
		manager.set_process(true)
	check(report.lagoons.size() == 2,"Both real lagoons were not exercised")
	mode(true)

func finish(world_case: bool) -> void:
	report.passed = failures.is_empty(); report.failures = failures
	report.adapter = RenderingServer.get_video_adapter_name()
	report.driver = RenderingServer.get_current_rendering_driver_name()
	report.msaa = root.msaa_3d
	FileAccess.open(OUT+("world_report.json" if world_case else "render_report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CHARACTER_WATER_VERIFY ",JSON.stringify({"passed":report.passed,"failures":failures,"world":world_case,"coverage":report.get("coverage",{}),"lagoons":report.get("lagoons",[])}))
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	root.size = Vector2i(1280,900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if "--world" in OS.get_cmdline_user_args():
		await world_checks()
		finish(true)
		return
	scene = load("res://scenes/water_1026_test.tscn").instantiate()
	root.add_child(scene)
	while not scene.test_ready: await process_frame
	scene.hud.hide()
	scene.set_view(0)
	scene.character.set_spawn(Vector3(0,scene.bed_height(20)+.04,20),PI)
	for i in 45: await physics_frame
	scene.character.player.pause(); scene.character.player.seek(.6,true)
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.character.visual.rotation.y = 0
	scene.water.interaction.reset(); scene.water._process(1.0)
	inspect()
	await dry_appearance()
	await water_coverage()
	finish(false)
