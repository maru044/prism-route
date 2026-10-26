extends SceneTree
## Verify the actual F5 entry uses the accepted B appearance without lab controls.
const FACTORY = preload("res://scripts/characters/mtoon_materials.gd")
const OUT := "res://docs/formal_mtoon_1026/"
var failures: Array[String] = []
var report: Dictionary = {}
var world

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func frames(count: int) -> void:
	for i in count: await physics_frame

func materials(actor: Node3D) -> void:
	check(actor.use_mtoon, "Formal character disabled MToon")
	check(actor.wetness != null and actor.wetness.materials.size() == 10, "Formal wetness controller missing")
	check(actor.mtoon_report.get("converted", 0) == 19, "Not all 19 formal materials converted")
	check(actor.mtoon_report.get("skipped", []).is_empty(), "Formal materials skipped")
	var rows: Array = []
	for mesh: MeshInstance3D in actor.character.find_children("*", "MeshInstance3D", true, false):
		check(not mesh.has_meta("character_npr_outline"), "Experimental outline shell loaded")
		for index in mesh.mesh.get_surface_count():
			var source: Material = mesh.mesh.surface_get_material(index)
			var active: Material = mesh.get_active_material(index)
			check(source is StandardMaterial3D, "Source material mutated")
			check(active is ShaderMaterial, "Formal material is not MToon")
			if not source is StandardMaterial3D or not active is ShaderMaterial: continue
			var name_value: String = mesh.mesh.surface_get_name(index)
			var region := "face" if name_value in ["面1", "面2"] else ("skin" if name_value == "肌" else "body")
			var expected := FACTORY.create_formal(source, region, name_value)
			check(active.shader == expected.shader, "Different shader from formal MToon alpha policy")
			for parameter in ["_Color", "_MainTex", "_ShadeTexture", "_ShadeColor", "_MainTex_ST", "_ShadeToony", "_ReceiveShadowRate", "_AlphaCutoutEnable", "_Cutoff", "_IndirectLightIntensity", "_OutlineWidthMode"]:
				check(active.get_shader_parameter(parameter) == expected.get_shader_parameter(parameter), "B parameter mismatch: " + name_value + " / " + parameter)
			check(active.next_pass == null, "Formal character has experimental outline")
			rows.append({"name": name_value, "shader": active.shader.resource_path, "next_pass": false})
	report.materials = rows
	check(rows.size() == 19, "Wrong formal surface count")

func dependencies() -> void:
	var config := ConfigFile.new()
	check(config.load("res://export_presets.cfg") == OK, "Cannot load export configuration")
	var files: PackedStringArray = config.get_value("preset.0", "export_files")
	for required in ["res://scripts/characters/mtoon_materials.gd", "res://scripts/characters/character_wetness.gd", "res://shaders/characters/wet_mtoon_common.gdshaderinc", "res://shaders/characters/mtoon_prepass_cull_off.gdshader", "res://addons/mtoon/mtoon_cull_off.gdshader", "res://addons/mtoon/mtoon_cutout_cull_off.gdshader", "res://addons/mtoon/mtoon_common.gdshaderinc"]:
		check(required in files, "Missing MToon export dependency: " + required)
	for path in files:
		check(not ("character_shader_lab" in path or "character_shader_world_lab" in path or "character_appearance.gd" in path or "/npr_" in path or "ganyu_appearance.tres" in path or "ganyu_npr/" in path or "/toon_blend" in path or "/toon_opaque" in path), "Experimental dependency entered export: " + path)
	report.export_resource_count = files.size()

func world_checks(capture: bool) -> void:
	world = load("res://scenes/map_1021.tscn").instantiate()
	world.automation_enabled = true
	root.add_child(world)
	var started := Time.get_ticks_msec()
	while not world.test_ready and Time.get_ticks_msec() - started < 150000: await process_frame
	check(world.test_ready, "Formal map startup timeout")
	if not world.test_ready: return
	await frames(45)
	materials(world.character)
	check(world.spawn_index == 8 and world.character_mode, "Cave character spawn changed")
	for control in world.find_children("*", "Control", true, false):
		if control is Label or control is Button or control is CheckBox or control is OptionButton:
			for forbidden in ["实验室", "MToon", "NPR", "Shader", "shader"]:
				check(not forbidden in control.text, "Formal HUD exposes shader controls")
	for path in ["res://scripts/characters/character_appearance.gd", "res://materials/characters/ganyu_appearance.tres", "res://materials/characters/ganyu_npr/face_sdf.png"]:
		check(not ResourceLoader.has_cached(path), "Formal map loaded experimental resources: " + path)
	if capture:
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OUT + "f5_cave.png") == OK, "F5 capture failed")
	await world.select_spawn(3)
	await frames(45)
	check(world.character.is_on_floor(), "Character not grounded on road")
	var start: Vector3 = world.character.global_position
	world.character.test_move = Vector2(0, -1)
	await frames(30)
	var walking: float = world.character.global_position.distance_to(start)
	check(walking > 0.25 and world.character.animation_state == "walk", "Walking regression")
	world.character.test_running = true
	await frames(30)
	check(world.character.animation_state == "run", "Running regression")
	world.character.test_move = Vector2.ZERO
	world.character.test_running = false
	await frames(35)
	world.character.test_jump = true
	await frames(12)
	check(not world.character.is_on_floor(), "Jump regression")
	await frames(80)
	check(world.character.is_on_floor(), "Landing regression")
	await world.select_spawn(1)
	await frames(45)
	await world.set_character_mode(false)
	await frames(40)
	check(not world.character_mode and world.camper.visible, "Camper switch regression")
	await world.set_character_mode(true)
	await frames(45)
	check(world.character_mode and world.character.camera.is_current(), "Character camera return regression")
	materials(world.character)
	if capture:
		world.set_free(true)
		world.character.player.pause()
		world.character.player.seek(0.6, true)
		world.character.visual.rotation.y = 0
		world.set_review_ui_visible(false)
		world.camera.position = world.character.global_position + Vector3(0.20, 1.43, 1.28)
		world.camera.look_at(world.character.global_position + Vector3(0, 1.25, 0))
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "mtoon_close.png")
	report.world = {"cave_spawn": true, "walking_distance_m": walking, "run_jump_land": true, "camper_character_switch": true, "hud_has_no_shader_controls": true, "experimental_resources_not_loaded": true}

func run() -> void:
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/map_1021.tscn", "F5 entry changed")
	dependencies()
	var full_world := "--world" in OS.get_cmdline_user_args()
	if full_world:
		await world_checks("--capture" in OS.get_cmdline_user_args())
	else:
		var actor: Node3D = load("res://scenes/characters/world_ganyu.tscn").instantiate()
		root.add_child(actor)
		actor.set_control_enabled(false)
		materials(actor)
		actor.queue_free()
		await process_frame
	report.passed = failures.is_empty()
	report.failures = failures
	report.full_world = full_world
	report.adapter = RenderingServer.get_video_adapter_name()
	FileAccess.open(OUT + ("world_report.json" if full_world else "logic_report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("FORMAL_MTOON_VERIFY ", JSON.stringify({"passed": report.passed, "failures": failures, "full_world": full_world}))
	if is_instance_valid(world): world.queue_free()
	for i in 3: await process_frame
	quit(0 if failures.is_empty() else 1)
