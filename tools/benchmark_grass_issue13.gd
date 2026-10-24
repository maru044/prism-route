extends SceneTree
## Reproducible real-map delivery benchmark. Camera follows a fixed 18 m/s
## trajectory; this is deliberately distinct from the camper collision test.
const OUT := "res://assets/world/current_map_validation/review/"
var scene
var stream
var records: Array = []
var frames_ms: Array[float] = []
var tick_ms: Array[float] = []
var previous_usec := 0
var sample_clock := 0.0
var stage := "cold"
var start_usec := 0
var phase_frames: Dictionary = {"cold":[],"travel_18mps_camera":[],"revisit":[]}
var phase_ticks: Dictionary = {"cold":[],"travel_18mps_camera":[],"revisit":[]}
var gpu_ms: Array[float] = []
var spikes: Array[Dictionary] = []
var monitor_peaks: Dictionary = {"engine_mib":0.0,"render_vram_mib":0.0,"nodes":0.0,"draw_calls":0.0,"primitives":0.0}

func _initialize() -> void:call_deferred("run")

func run() -> void:
	root.size=Vector2i(1920,1080)
	var args:=OS.get_cmdline_user_args()
	if "--uncapped" in args:
		Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	scene=load("res://scenes/map_1021.tscn").instantiate();scene.automation_enabled=true;root.add_child(scene)
	while not scene.test_ready:await process_frame
	scene.get_node("PerformanceMonitor1021").visible=false
	scene.get_node("PerformanceMonitor1021").set_process(false)
	scene.vegetation.set_process(false)
	if "--baseline" in args:
		scene.vegetation.volume_streamer.free()
		stream=load("res://.current_map_build/grass_streamer_issue13_baseline.gd").new()
		scene.vegetation.add_child(stream);stream.initialize(scene.vegetation,scene)
		scene.vegetation.volume_streamer=stream
	else:stream=scene.vegetation.volume_streamer
	if stream.get("collect_detailed_timings")!=null:stream.collect_detailed_timings=true
	if "--grass-no-profile" in args and stream.get("profiling")!=null:stream.profiling=false
	await scene.select_spawn(7);scene.set_free(true)
	var origin: Vector3=scene.resolved_spawns[7].floor_position+Vector3.UP*4
	var direction:=Vector3(.7,0,-1).normalized()
	scene.camera.position=origin;scene.camera.look_at(origin+direction*100)
	stream.refresh()
	previous_usec=Time.get_ticks_usec();start_usec=previous_usec
	await observe(8.0)
	stage="travel_18mps_camera"
	var travel:=0.0
	while travel<20:
		var delta: float=await sample_frame()
		travel+=delta
		scene.camera.position=origin+direction*minf(travel,20)*18
		var angle:=0.0 if travel<6 else (PI*.5 if travel<12 else PI)
		scene.camera.look_at(scene.camera.position+direction.rotated(Vector3.UP,angle)*100)
	stage="revisit"
	scene.camera.position=origin;scene.camera.look_at(origin+direction*100)
	await observe(5.0)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"issue13_"+tag()+".png")
	var report: Dictionary={"mode":tag(),"trajectory":"360m camera at 18m/s, 90/180-degree turns; NOT a vehicle physics test","resolution":str(root.size),"frame_cap":Engine.max_fps,"performance_hud":false,"frames":summary(frames_ms),"stream_tick":summary(tick_ms),"records":records,"final":stream.metrics(),"phases":{},"gpu":summary(gpu_ms),"timing_note":"stream_tick measures the whole tick, including refresh/sorting/upload; old HUD last_build_ms excluded refresh. Optional instrumentation is enabled in online/baked runs."}
	for key in phase_frames:report.phases[key]={"frames":summary(phase_frames[key]),"stream_tick":summary(phase_ticks[key])}
	report["source_sha256"]={}
	for path in ["scripts/grass_volume_streamer.gd","scripts/grass_baked_store.gd","scripts/grass_instance_buffer.gd","tools/benchmark_grass_issue13.gd"]:report.source_sha256[path]=FileAccess.get_sha256("res://"+path)
	report.frames["fps_1pct_low"]=low_fps(frames_ms)
	report["monitor_peaks"]=monitor_peaks
	for key in phase_frames:report.phases[key].frames["fps_1pct_low"]=low_fps(phase_frames[key])
	spikes.sort_custom(func(a:Dictionary,b:Dictionary):return a.tick_ms>b.tick_ms)
	report["slow_tick_examples"]=spikes.slice(0,32)
	if has_method("delivery_result"):report["continuous"]=call("delivery_result")
	if stream.has_method("profile_report"):report["profile"]=stream.profile_report()
	var file:=FileAccess.open(OUT+"issue13_"+tag()+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("ISSUE13_BENCHMARK ",tag()," frames=",summary(frames_ms)," tick=",summary(tick_ms))
	quit(0 if report.get("continuous",{}).get("near_missing_frames",0)==0 else 1)

func tag() -> String:
	var args:=OS.get_cmdline_user_args()
	var result: String="baseline" if "--baseline" in args else ("online" if "--grass-no-bake" in args else "baked")
	if "--uncapped" in args:result+="_uncapped"
	if "--grass-no-profile" in args:result+="_no_profile"
	if "--full-bake" in args:result+="_full"
	return result

func observe(seconds: float) -> void:
	var elapsed:=0.0
	while elapsed<seconds:elapsed+=await sample_frame()

func sample_frame() -> float:
	await process_frame
	var now:=Time.get_ticks_usec();var delta: float=(now-previous_usec)/1000000.0;previous_usec=now
	var tick_start:=Time.get_ticks_usec();stream.tick(delta)
	var tick: float=(Time.get_ticks_usec()-tick_start)/1000.0
	if tick>3 and stream.get("last_phases") is Dictionary:
		spikes.append({"tick_ms":tick,"stage":stage,"elapsed_s":(now-start_usec)/1000000.0,"phases":stream.last_phases.duplicate(),"commit_ms":stream.last_commit_usec/1000.0})
	scene.vegetation.grass_interaction.update(delta,scene.vegetation.grass_material)
	frames_ms.append(delta*1000);tick_ms.append(tick)
	phase_frames[stage].append(delta*1000);phase_ticks[stage].append(tick)
	var gpu:=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
	if gpu>0:gpu_ms.append(gpu)
	monitor_peaks.engine_mib=maxf(monitor_peaks.engine_mib,Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0)
	monitor_peaks.render_vram_mib=maxf(monitor_peaks.render_vram_mib,Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0)
	monitor_peaks.nodes=maxf(monitor_peaks.nodes,Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	monitor_peaks.draw_calls=maxf(monitor_peaks.draw_calls,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	monitor_peaks.primitives=maxf(monitor_peaks.primitives,Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	sample_clock+=delta
	if sample_clock>=.5:
		sample_clock=0
		var row: Dictionary=stream.metrics().duplicate()
		row["stage"]=stage;row["elapsed_s"]=(now-start_usec)/1000000.0
		row["visible_bands"]=visible_missing()
		records.append(row)
	return delta

func summary(values: Array) -> Dictionary:
	if values.is_empty():return {}
	var ordered:=values.duplicate();ordered.sort()
	var total:=0.0
	for value in values:total+=value
	return {"mean_ms":total/maxi(values.size(),1),"p95_ms":ordered[maxi(0,ceili(ordered.size()*.95)-1)],"p99_ms":ordered[maxi(0,ceili(ordered.size()*.99)-1)],"max_ms":ordered.back()}

func low_fps(values: Array) -> float:
	if values.is_empty():return 0
	var ordered:=values.duplicate();ordered.sort()
	var count:=maxi(1,ceili(ordered.size()*.01));var total:=0.0
	for i in range(ordered.size()-count,ordered.size()):total+=ordered[i]
	return 1000.0/(total/count)

func visible_missing() -> Dictionary:
	var result: Dictionary={"0_48":0,"48_76":0,"76_110":0,"110_128":0}
	var camera: Camera3D=scene.camera
	var planes:=camera.get_frustum()
	for cell: Vector3i in stream.required:
		if stream.active.has(cell) or stream.empty.has(cell):continue
		var low:=Vector3(cell)*24
		var distance:=camera.global_position.distance_to(camera.global_position.clamp(low,low+Vector3.ONE*24))
		if distance>128:continue
		var visible:=true
		for plane in planes:
			if plane.distance_to(low+Vector3.ONE*12)>plane.normal.abs().dot(Vector3.ONE*12):visible=false;break
		if not visible:continue
		var band: String="0_48" if distance<48 else ("48_76" if distance<76 else ("76_110" if distance<110 else "110_128"))
		result[band]+=1
	return result
