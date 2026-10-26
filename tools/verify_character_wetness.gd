extends SceneTree
## Real water query/state transitions plus matched MToon wet/dry rendered evidence.
const FACTORY = preload("res://scripts/characters/mtoon_materials.gd")
const OUT := "res://docs/character_wetness_1027/"
var scene
var actor
var wet
var failures: Array[String] = []
var report: Dictionary = {}
var capture := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func frames(count: int) -> void:
	for i in count: await process_frame
func physics_frames(count: int) -> void:
	for i in count: await physics_frame
func place(p: Vector3) -> void:
	actor.global_position = p
	wet.reset()
func maximum() -> float:
	return wet.metrics().max_wetness
func shot(name_value: String) -> Image:
	await frames(8); await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image(); image.convert(Image.FORMAT_RGBA8)
	check(image.save_png(OUT+name_value+".png") == OK,"Capture failed: "+name_value)
	return image
func difference(a: Image,b: Image, rect: Rect2i = Rect2i()) -> Dictionary:
	if rect.has_area(): a = a.get_region(rect); b = b.get_region(rect)
	var aa := a.get_data(); var bb := b.get_data(); var total := 0.0; var changed := 0
	for i in range(0,aa.size(),4):
		var maximum_delta := 0
		for c in 3:
			var delta := absi(int(aa[i+c])-int(bb[i+c]))
			total += delta; maximum_delta = maxi(maximum_delta,delta)
		if maximum_delta > 2: changed += 1
	return {"mean":total/(a.get_width()*a.get_height()*3.0*255),"changed":changed}

func states() -> void:
	check(wet != null and wet.materials.size() == 10,"Expected ten moisture-responsive surfaces")
	place(Vector3(0,1.0,-28)); wet.advance(.5)
	check(not wet.contact and maximum() == 0,"Dry land becomes wet")
	place(Vector3(0,3.6,-13)); wet.advance(.5)
	check(not wet.contact and maximum() == 0,"Bridge becomes wet from water below")
	place(Vector3(-35,-.56,20)); wet.advance(.5)
	check(not wet.contact and maximum() == 0,"World Y<0 outside water becomes wet")
	place(Vector3(-23.5,-.56,20)); wet.advance(.3)
	check(wet.contact and wet.water_id == "shallow_test" and maximum() > .99,"Stationary immersion did not wet the actor")
	check(wet.levels[5] > .99 and wet.levels[12] == 0.0,"Wetness is not local to immersed height")
	report.immersed = wet.metrics()
	actor.global_position.x = -25.5; wet.advance(1.0)
	check(not wet.contact and maximum() > .85 and maximum() < 1.0,"Shore exit did not retain moisture")
	report.shore_1s = wet.metrics()
	wet.advance(6.0)
	check(maximum() > .45 and maximum() < .55,"Drying did not progress independently of movement")
	report.shore_7s = wet.metrics()
	wet.advance(7.1)
	check(maximum() == 0.0,"Actor does not return fully dry")
	place(Vector3(0,-1.0,20)); wet.advance(.3)
	check(wet.levels[10] > .99,"Deeper entry did not reach the higher bands")
	actor.global_position.y = -.2; wet.advance(7.0)
	check(wet.levels[2] > .99 and wet.levels[10] > .45 and wet.levels[10] < .55,"Shallow wading refreshes the entire body instead of just immersed bands")
	actor.global_position.y = .5; wet.advance(.1)
	check(not wet.contact and maximum() > .9,"Jumping out instantly clears moisture")
	actor.global_position = Vector3(-35,1.0,-28); wet.advance(.1)
	check(maximum() == 0.0,"Teleport retains stale moisture")
	place(Vector3(0,-.56,20)); wet.advance(.3)
	actor.reset_to_respawn()
	check(maximum() == 0.0,"Explicit respawn retains stale moisture")
	# Independent actor/material instances, including hidden-actor drying policy.
	var other = load("res://scenes/characters/world_ganyu.tscn").instantiate()
	root.add_child(other); other.set_control_enabled(false); other.hide()
	other.wetness.set_physics_process(false)
	other.global_position = Vector3(-35,1,-28); other.wetness.reset()
	place(Vector3(-23.5,-.56,20)); wet.advance(.3)
	check(other.wetness.metrics().max_wetness == 0.0,"Wet state leaked into a second actor")
	for material in wet.materials:
		check(not material in other.wetness.materials,"Responsive material shared between actors")
	check(wet.process_mode == Node.PROCESS_MODE_PAUSABLE,"Hidden-actor drying does not obey the pause policy")
	other.queue_free(); await frames(1)
	actor.global_position.x = -25.5
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	wet.set_physics_process(true)
	await physics_frames(35)
	check(maximum() < .99 and maximum() > .8,"Hidden character did not continue drying")
	var paused_value := maximum()
	paused = true; await frames(10)
	check(maximum() == paused_value,"Wetness continues advancing while the game is paused")
	paused = false
	actor.process_mode = Node.PROCESS_MODE_INHERIT
	wet.set_physics_process(false)
	report.state_checks = {"dry_land":true,"bridge":true,"negative_y_without_water":true,"stationary_immersion":true,"local_depth_history":true,"jump_exit":true,"gradual_drying":true,"teleport_respawn":true,"instance_isolation":true,"hidden_drying":true,"pause":true}
	wet.reset()

func render_checks() -> void:
	scene.hud.hide(); scene.set_view(0)
	actor.player.pause(); actor.player.seek(.6,true)
	actor.visual.rotation.y = 0
	# Keep the water collision bodies in the physics space while freezing motion.
	scene.set_process(false)
	scene.water.set_process(false); scene.water.set_physics_process(false)
	for modifier: SkeletonModifier3D in actor.character.find_children("*","SkeletonModifier3D",true,false):
		modifier.active = false
	wet.set_physics_process(false)
	for row: Dictionary in scene.water.bodies: row.mesh.hide()
	place(Vector3(0,1,4))
	scene.camera.position = actor.global_position+Vector3(0,1.05,2.1)
	scene.camera.look_at(actor.global_position+Vector3(0,.9,0))
	var entries: Array[Dictionary] = []
	for mesh: MeshInstance3D in actor.character.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var source: StandardMaterial3D = mesh.mesh.surface_get_material(i)
			var name_value: String = mesh.mesh.surface_get_name(i)
			var region := "face" if name_value in ["面1","面2"] else ("skin" if name_value == "肌" else "body")
			entries.append({"mesh":mesh,"index":i,"active":mesh.get_active_material(i)})
			mesh.set_surface_override_material(i,FACTORY.create(source,region,FACTORY.FORMAL_GANYU_ALPHA[name_value]))
	var upstream_dry := await shot("dry_upstream")
	for entry in entries: entry.mesh.set_surface_override_material(entry.index,entry.active)
	var extension_dry := await shot("dry_extension")
	report.dry_parity = difference(upstream_dry,extension_dry)
	check(report.dry_parity.mean < .0001,"Zero moisture changes the accepted MToon baseline")
	# A dry-land review platform next to the real small-scene water boundary.
	var platform := MeshInstance3D.new(); var box := BoxMesh.new()
	box.size = Vector3(6,.4,7); platform.mesh = box
	var ground := StandardMaterial3D.new(); ground.albedo_color = Color(.60,.53,.37); ground.roughness = 1.0
	platform.material_override = ground; scene.add_child(platform); platform.position = Vector3(-26.8,-.85,20)
	place(Vector3(-23.5,-.56,20)); wet.advance(.3)
	actor.global_position.x = -25.5; wet.advance(.1)
	report.shore_render_state = wet.metrics()
	check(maximum() > .9,"Review platform did not receive a real wet state")
	scene.camera.position = actor.global_position+Vector3(0,1.15,2.1)
	scene.camera.look_at(actor.global_position+Vector3(0,.85,0))
	var wet_image := await shot("shore_wet")
	var glosses: Array[float] = []
	for material in wet.materials:
		glosses.append(material.get_shader_parameter("wet_gloss")); material.set_shader_parameter("wet_gloss",0.0)
	var no_gloss := await shot("shore_no_gloss")
	report.gloss = difference(wet_image,no_gloss)
	check(report.gloss.changed > 5,"Wet light response has no visible effect")
	for i in wet.materials.size(): wet.materials[i].set_shader_parameter("wet_gloss",glosses[i])
	wet.advance(6.9); var half_dry := await shot("shore_drying_7s")
	wet.advance(7.1); var dry := await shot("shore_dry_14s")
	report.wet_to_dry = difference(wet_image,dry)
	report.half_to_dry = difference(half_dry,dry)
	check(report.wet_to_dry.changed > 50,"Wet diffuse changes are invisible")
	check(report.half_to_dry.mean > 0.0 and report.half_to_dry.mean < report.wet_to_dry.mean,"Rendered drying does not converge")
	wet.reset(); var reset_dry := await shot("shore_reset_dry")
	check(difference(dry,reset_dry).mean < .00001,"Fully dried appearance differs from reset")
	# The water surface remains responsible for absorption; wet film cannot glow underwater.
	for row: Dictionary in scene.water.bodies: row.mesh.show()
	place(Vector3(0,-.56,20)); wet.advance(.3)
	scene.camera.position = actor.global_position+Vector3(0,1.66,3.5)
	scene.camera.look_at(actor.global_position+Vector3(0,.7,0))
	scene.water.interaction.reset(); scene.water._process(1.0)
	await shot("immersed_wet")
	report.rendered = true

func world_checks() -> void:
	scene = load("res://scenes/map_1021.tscn").instantiate()
	scene.automation_enabled = true; root.add_child(scene)
	var started := Time.get_ticks_msec()
	while not scene.test_ready and Time.get_ticks_msec()-started < 150000: await process_frame
	check(scene.test_ready,"Formal map startup timeout")
	if not scene.test_ready: return
	check(scene.spawn_index == 8,"Initial cave spawn changed")
	actor = scene.character; wet = actor.wetness
	check(maximum() == 0.0,"Cave spawn is wet")
	await scene._water_review_view(3)
	await physics_frames(45)
	check(actor.is_on_floor() and wet.contact and maximum() > .99,"Real stationary lagoon immersion does not wet the actor")
	report.world_immersed = wet.metrics()
	var start_position: Vector3 = actor.global_position
	if capture:
		scene.set_review_ui_visible(false); scene.set_free(true)
		scene.camera.position = actor.global_position+Vector3(.8,1.55,2.7)
		scene.camera.look_at(actor.global_position+Vector3(0,.8,0))
		await shot("world_immersed")
		scene.set_free(false)
	actor.test_jump = true
	await physics_frames(10)
	check(not actor.is_on_floor() and actor.global_position.y > start_position.y+.3,"Real jump exit failed")
	check(not wet.contact and maximum() > .8,"Real jump exit lost residual moisture")
	report.world_jump = wet.metrics()
	if capture:
		scene.set_free(true)
		scene.camera.position = actor.global_position+Vector3(.8,1.55,2.7)
		scene.camera.look_at(actor.global_position+Vector3(0,.8,0))
		await shot("world_jump_wet")
	wet.set_physics_process(false)
	wet.advance(14.1)
	check(maximum() == 0.0,"Real actor does not dry after exit")
	actor.reset_to_respawn()
	check(maximum() == 0.0,"Real actor reset did not clear moisture")
	check(scene.water_manager.bodies.size() == 7,"Formal water count changed")
	scene.water_manager.wind_override = 1.0; scene.water_manager._process(0.0)
	for row: Dictionary in scene.water_manager.bodies:
		check(row.material.get_shader_parameter("wind_strength") == 0.0,"Water wind effect was re-enabled")
	report.world_checks = {"dry_cave":true,"standing_in_water":true,"jump_out":true,"retained_moisture":true,"dry_and_reset":true,"water_wind_still_disabled":true}

func performance_checks() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	scene.hud.hide(); scene.set_view(0); scene.set_process(false)
	scene.water.set_process(false); scene.water.set_physics_process(false)
	scene.water.reflection.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for row: Dictionary in scene.water.bodies: row.mesh.hide()
	actor.player.pause(); actor.player.seek(.6,true)
	for modifier: SkeletonModifier3D in actor.character.find_children("*","SkeletonModifier3D",true,false): modifier.active = false
	place(Vector3(0,1,4)); actor.visual.rotation.y = 0
	scene.camera.position = actor.global_position+Vector3(0,1.05,2.1)
	scene.camera.look_at(actor.global_position+Vector3(0,.9,0))
	var entries: Array[Dictionary] = []
	for mesh: MeshInstance3D in actor.character.find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var name_value: String = mesh.mesh.surface_get_name(i)
			var region := "face" if name_value in ["面1","面2"] else ("skin" if name_value == "肌" else "body")
			entries.append({"mesh":mesh,"index":i,"wet":mesh.get_active_material(i),"upstream":FACTORY.create(mesh.mesh.surface_get_material(i),region,FACTORY.FORMAL_GANYU_ALPHA[name_value])})
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	report.performance = []
	for label in ["upstream","dry_extension","fully_wet_extension"]:
		for entry in entries: entry.mesh.set_surface_override_material(entry.index,entry.upstream if label == "upstream" else entry.wet)
		wet.levels.fill(1.0 if label == "fully_wet_extension" else 0.0); wet._sync()
		await frames(60)
		var samples := PackedFloat64Array(); var total := 0.0
		for i in 120:
			await process_frame
			var ms := RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
			samples.append(ms); total += ms
		samples.sort()
		report.performance.append({"case":label,"samples":samples.size(),"main_gpu_mean_ms":total/samples.size(),"main_gpu_p95_ms":samples[113],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	place(Vector3(0,-.56,20))
	var cpu_samples := PackedFloat64Array(); var cpu_total := 0.0
	for i in 600:
		var started := Time.get_ticks_usec(); wet.advance(1.0/60.0)
		var elapsed := float(Time.get_ticks_usec()-started)
		cpu_samples.append(elapsed); cpu_total += elapsed
	cpu_samples.sort()
	report.wetness_cpu = {"samples":600,"mean_us":cpu_total/600.0,"p95_us":cpu_samples[569],"water_queries_hz":15,"rays_per_query":5,"responsive_materials":wet.materials.size()}
	report.performance_conditions = {"actor_count":1,"resolution":str(root.get_texture().get_size()),"msaa":root.msaa_3d,"water_and_mirror_disabled":true,"warmup_frames":60,"uncapped":true,"wet_case":"All height bands forced wet to exercise the full-body shader; state transitions are verified separately."}

func finish(world_case: bool) -> void:
	report.passed = failures.is_empty(); report.failures = failures
	report.adapter = RenderingServer.get_video_adapter_name()
	var file_name := "world_report.json" if world_case else ("performance_report.json" if "--performance" in OS.get_cmdline_user_args() else ("render_report.json" if capture else "logic_report.json"))
	FileAccess.open(OUT+file_name,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CHARACTER_WETNESS_VERIFY ",JSON.stringify({"passed":report.passed,"failures":failures,"world":world_case,"dry":report.get("dry_parity",{}),"gloss":report.get("gloss",{}),"wet_to_dry":report.get("wet_to_dry",{})}))
	quit(0 if failures.is_empty() else 1)

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if "--world" in OS.get_cmdline_user_args():
		await world_checks()
		finish(true)
		return
	scene = load("res://scenes/water_1026_test.tscn").instantiate(); root.add_child(scene)
	while not scene.test_ready: await process_frame
	actor = scene.character; actor.set_control_enabled(false)
	wet = actor.wetness; wet.set_physics_process(false)
	if "--performance" in OS.get_cmdline_user_args():
		await performance_checks()
		finish(false)
		return
	await states()
	if capture: await render_checks()
	finish(false)
