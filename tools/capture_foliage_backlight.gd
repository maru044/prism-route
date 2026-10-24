extends SceneTree
## Matched original/candidate/restore captures in the actual 1021 scene.
const OUT := "res://.vegetation_art_build/backlight_1024/"
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
	scene=load("res://scenes/map_1021.tscn").instantiate();scene.automation_enabled=true;root.add_child(scene)
	while not scene.test_ready:await process_frame
	await scene.select_spawn(1)
	await scene.set_character_mode(false)
	scene.set_free(true);scene.character.set_physics_process(false);scene.camper.set_physics_process(false)
	scene.set_review_ui_visible(false)
	var comparison=preload("res://tools/foliage_review_comparison.gd").new()
	comparison.records=scene.foliage_style.records
	comparison.set_green_mode(0)
	assert(comparison.records.size()>0)
	var grass: ShaderMaterial=scene.vegetation.grass_material
	assert(grass.shader.resource_path=="res://assets/vegetation/shaders/vegetation_wind.gdshader")
	grass.set_shader_parameter("wind_strength",0.);grass.set_shader_parameter("wind_tone_strength",0.)
	for row: Dictionary in comparison.records:row.parameters.wind_strength=0.
	var signature: String="online grass streamer"
	if "store" in scene.vegetation.volume_streamer:
		signature=load("res://scripts/grass_baked_store.gd").signature(scene)
		assert(signature==scene.vegetation.volume_streamer.store.manifest.signature)
	var point: Vector3=scene.resolved_spawns[1].floor_position
	var closest:=INF;var focus:=point;var scale:=1.
	for row: Array in scene.vegetation._read_tree_records():
		var p:=Vector3(row[0],row[1],row[2])
		if int(row[5])!=1 or absf(p.y-point.y)>12:continue
		var palette: int=scene.vegetation._palette_for_cell(Vector2i(floori(p.x/128.),floori(p.z/128.)))
		if palette!=0:continue
		var distance:=p.distance_to(point)
		if distance<closest:closest=distance;focus=p;scale=float(row[4])
	assert(closest<1000)
	var sun: DirectionalLight3D=scene.find_children("*","DirectionalLight3D",true,false)[0]
	var towards_sun:=Vector3(sun.global_basis.z.x,0,sun.global_basis.z.z).normalized()
	var crown:=focus+Vector3.UP*8.5*scale
	var views: Array[Dictionary]=[
		{"key":"bridge","eye":point+Vector3(-10,6,8),"target":point+Vector3(-80,10,-100)},
		{"key":"backlit","eye":crown-towards_sun*28.*scale-Vector3.UP*3.*scale,"target":crown},
		{"key":"frontlit","eye":crown+towards_sun*28.*scale-Vector3.UP*3.*scale,"target":crown}]
	var reports: Array=[]
	for view: Dictionary in views:
		scene.vegetation.set_process(true)
		scene.camera.global_position=view.eye;scene.camera.look_at(view.target)
		await frames(120);scene.vegetation.set_process(false)
		for enabled: bool in [false,true,false]:
			comparison.set_candidate(enabled);await frames(16)
			var tag: String="b_soft" if enabled else ("a_original" if reports.filter(func(r):return r.view==view.key).is_empty() else "a_restore")
			await capture(view.key+"_"+tag)
			reports.append({"view":view.key,"mode":tag,"camera":str(view.eye),"target":str(view.target),"materials":comparison.records.size(),"draws":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	assert(grass.shader.resource_path=="res://assets/vegetation/shaders/vegetation_wind.gdshader")
	var original_hashes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"baseline_shader_hashes.json"))
	for file: String in original_hashes:assert(FileAccess.get_sha256("res://assets/vegetation/shaders/"+file)==original_hashes[file])
	await tap(KEY_H);assert(scene.review_ui_visible)
	await tap(KEY_H);assert(not scene.review_ui_visible)
	FileAccess.open(OUT+"runtime.json",FileAccess.WRITE).store_string(JSON.stringify({"captures":reports,"grass_bake_signature":signature,"original_shaders_unchanged":true,"grass_shader_unchanged":true,"fill":comparison.fill_strength,"relief":comparison.shadow_relief},"  "))
	print("FOLIAGE_BACKLIGHT_CAPTURE_PASS ",JSON.stringify(reports));quit()
