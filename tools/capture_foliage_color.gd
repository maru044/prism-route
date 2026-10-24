extends SceneTree
const OUT := "res://.vegetation_art_build/color_1024/"
var scene
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await process_frame
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT+name+".png")==OK)
func tap(code: Key) -> void:
	for pressed: bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed
		Input.parse_input_event(event);await frames(1)
func run() -> void:
	root.size=Vector2i(1600,900);Engine.max_fps=60
	if "--grove" in OS.get_cmdline_user_args():
		await capture_grove();return
	scene=load("res://scenes/map_1021.tscn").instantiate();scene.automation_enabled=true;root.add_child(scene)
	while not scene.test_ready:await process_frame
	await scene.select_spawn(1);scene.set_free(true)
	scene.character.set_physics_process(false);scene.character.hide();scene.camper.set_physics_process(false)
	scene.set_review_ui_visible(false)
	var comparison=preload("res://tools/foliage_review_comparison.gd").new()
	comparison.records=scene.foliage_style.records
	var grass: ShaderMaterial=scene.vegetation.grass_material
	var terrain: ShaderMaterial=scene.terrain_material
	var shared: Dictionary={}
	for parameter: String in ["biome_noise_texture","biome_noise_scale","biome_warp_distance","biome_transition_half_width","biome_center_x"]:
		assert(terrain.get_shader_parameter(parameter)==grass.get_shader_parameter(parameter))
		shared[parameter]=str(grass.get_shader_parameter(parameter))
	grass.set_shader_parameter("wind_strength",0.);grass.set_shader_parameter("wind_tone_strength",0.)
	for row: Dictionary in comparison.records:row.parameters.wind_strength=0.
	var signature: String="online grass streamer"
	if "store" in scene.vegetation.volume_streamer:
		signature=load("res://scripts/grass_baked_store.gd").signature(scene)
		assert(signature==scene.vegetation.volume_streamer.store.manifest.signature)
	var views: Array[Dictionary]=[
		{"key":"backlit","eye":Vector3(-458.1884,68.96952,1061.078),"target":Vector3(-436.6996,72.22557,1082.567)},
		{"key":"frontlit","eye":Vector3(-415.2108,68.96952,1104.056),"target":Vector3(-436.6996,72.22557,1082.567)}]
	var measurements: Array=[];var green_count:=0;var flower_count:=0
	for row: Dictionary in comparison.records:
		if row.green:green_count+=1
		else:flower_count+=1
	assert(green_count>0 and flower_count>0)
	for view: Dictionary in views:
		scene.vegetation.set_process(true);scene.camera.global_position=view.eye;scene.camera.look_at(view.target)
		await frames(120);scene.vegetation.set_process(false)
		for mode: int in [0,1,0]:
			comparison.set_green_mode(mode);await frames(16)
			for row: Dictionary in comparison.records:
				if not row.green:
					for parameter: String in ["species_shadow_color","species_mid_color","species_light_color","use_species_palette"]:
						assert(row.material.get_shader_parameter(parameter)==row.parameters[parameter])
			var tag: String=["original","fresh"][mode]
			if mode==0 and measurements.filter(func(r):return r.view==view.key).size()>0:tag="restored"
			await capture(view.key+"_"+tag)
			measurements.append({"view":view.key,"palette":tag,"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	scene.vegetation.set_vegetation_enabled(false)
	scene.camera.global_position=Vector3(-160,1800,2100);scene.camera.look_at(Vector3(-250,15,400));await frames(30)
	for enabled: bool in [false,true]:
		terrain.set_shader_parameter("use_shared_meadow_biome",enabled);await frames(12)
		await capture("ground_shared" if enabled else "ground_legacy")
	var report:={"captures":measurements,"shared_meadow_parameters":shared,
		"ground_dry":str(terrain.get_shader_parameter("ground_dry")),"ground_green":str(terrain.get_shader_parameter("ground_green")),
		"grass_bake_signature":signature,"grass_rebake_required":false,"green_materials":green_count,
		"flower_materials_unchanged":flower_count,"lighting_fill_fixed":comparison.fill_strength,
		"shadow_relief_fixed":comparison.shadow_relief,"offline_comparison":true}
	FileAccess.open(OUT+"runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("FOLIAGE_COLOR_PASS ",JSON.stringify(report));quit()

func capture_grove() -> void:
	scene=load("res://scenes/vegetation_grove_test.tscn").instantiate();root.add_child(scene);await frames(20)
	scene.get_node("OrbitCamera").set_process(false)
	for ui: CanvasLayer in scene.find_children("*","CanvasLayer",true,false):ui.hide()
	scene.get_node("Instructions").hide()
	var comparison=preload("res://tools/foliage_review_comparison.gd").new()
	comparison.records=scene.foliage_style.records
	for row: Dictionary in comparison.records:row.parameters.wind_strength=0.
	var flower: Node3D=scene.find_child("BroadClusteredFlowerTree",true,false)
	for node: GeometryInstance3D in scene.find_children("*","GeometryInstance3D",true,false):node.visible=flower.is_ancestor_of(node)
	var camera:=Camera3D.new();scene.add_child(camera);camera.make_current();camera.fov=44
	var target:=flower.global_position+Vector3(0,7.8,0)
	camera.position=target+Vector3(18,-4,18);camera.look_at(target)
	for mode in 3:
		comparison.set_green_mode(mode);await frames(20);await capture("grove_flower_mode%d"%mode)
	assert(comparison.records.filter(func(r):return r.green).size()>0)
	assert(comparison.records.filter(func(r):return not r.green).size()>0)
	print("FOLIAGE_GROVE_COLOR_PASS materials=",comparison.records.size());quit()
