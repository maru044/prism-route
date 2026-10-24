extends SceneTree
## Full-density north-hill view. All variants are temporary and restored;
## this diagnostic does not change the project's rendering defaults.
const OUT := "res://assets/world/current_map_validation/review/"
var scene
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1920,1080)
	scene=load("res://scenes/map_1021.tscn").instantiate();scene.automation_enabled=true;root.add_child(scene)
	while not scene.test_ready:await process_frame
	scene.get_node("PerformanceMonitor1021").visible=false;scene.get_node("PerformanceMonitor1021").set_process(false)
	await scene.select_spawn(5)
	var vegetation=scene.vegetation;var stream=vegetation.volume_streamer
	stream.refresh();var start:=Time.get_ticks_msec()
	while stream.visible_missing().values().any(func(n):return int(n)>0) and Time.get_ticks_msec()-start<30000:await process_frame
	assert(stream.visible_missing().values().all(func(n):return int(n)==0))
	vegetation.set_process(false);vegetation.set_physics_process(false)
	var grass: Array=[];grass.append_array(vegetation.grass_lod0_nodes);grass.append_array(vegetation.grass_lod1_nodes)
	var trees: Array=[];trees.append_array(vegetation.tree_lod0_nodes);trees.append_array(vegetation.tree_lod1_nodes);trees.append_array(vegetation.tree_lod2_nodes)
	var flags: Dictionary={}
	for node in grass+trees:flags[node]=node.visible
	var env: Environment=scene.find_children("*","WorldEnvironment",true,false)[0].environment
	var ssao:=env.ssao_enabled;var msaa:=root.msaa_3d
	var lights: Array=scene.find_children("*","DirectionalLight3D",true,false)
	var shadows: Dictionary={}
	for light in lights:shadows[light]=light.shadow_enabled
	var grass_mat: ShaderMaterial=vegetation.grass_material
	var noise_wind=grass_mat.get_shader_parameter("use_noise_wind")
	var strength=grass_mat.get_shader_parameter("wind_strength")
	var skip=grass_mat.get_shader_parameter("skip_invisible_grass")
	var rows: Array=[]
	for mode: String in ["baseline","legacy_vertices","grass_off","trees_off","grass_simple_wind_zero_amplitude","ssao_off","shadows_off","msaa_2x","1600x900","baseline_end"]:
		for node in grass+trees:node.visible=flags[node]
		env.ssao_enabled=ssao;root.msaa_3d=msaa;root.size=Vector2i(1920,1080)
		for light in lights:light.shadow_enabled=shadows[light]
		grass_mat.set_shader_parameter("use_noise_wind",noise_wind);grass_mat.set_shader_parameter("wind_strength",strength)
		grass_mat.set_shader_parameter("skip_invisible_grass",skip)
		if mode=="legacy_vertices":grass_mat.set_shader_parameter("skip_invisible_grass",false)
		if mode=="grass_off":
			for node in grass:node.visible=false
		if mode=="trees_off":
			for node in trees:node.visible=false
		if mode=="grass_simple_wind_zero_amplitude":grass_mat.set_shader_parameter("use_noise_wind",false);grass_mat.set_shader_parameter("wind_strength",0.0)
		if mode=="ssao_off":env.ssao_enabled=false
		if mode=="shadows_off":
			for light in lights:light.shadow_enabled=false
		if mode=="msaa_2x":root.msaa_3d=Viewport.MSAA_2X
		if mode=="1600x900":root.size=Vector2i(1600,900)
		for i in 30:await process_frame
		var gpu: Array[float]=[]
		for i in 90:
			await process_frame
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		gpu.sort();var total:=0.0
		for value in gpu:total+=value
		var row: Dictionary={"variant":mode,"gpu_mean_ms":total/gpu.size(),"gpu_p95_ms":gpu[ceili(gpu.size()*.95)-1],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"engine_primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"render_vram_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,"resolution":str(root.size)}
		rows.append(row);print("ISSUE13_GPU_VARIANT ",JSON.stringify(row))
	var report: Dictionary={"scene":"spawn 6, north hill, fixed camera, complete visible baked grass","skip_invisible_grass":skip,"samples_per_variant":90,"warmup_frames":30,"variants":rows,"defaults_changed":false,"note":"Diagnostic toggles only; grass-off/trees-off are attribution probes, not accepted optimizations. Zero-amplitude simple wind skips noise sampling but does not remove all vertex arithmetic. Timings include sky/wind time variation; baseline_end bounds temporal drift."}
	var file:=FileAccess.open(OUT+"issue13_gpu_ab.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();quit()
