extends SceneTree
## Same deterministic 324 m camera trajectory before/after a streaming fix.
## Does not modify grass bake, layout, or the user's running editor/game.
const OUT := "res://.vegetation_art_build/grass_gust/streaming/"
var scene
var stream
var records: Array=[]
var ticks: Array=[]
var frames_ms: Array=[]
var commits: Array=[]
var gpu: Array=[]
var spikes: Array=[]
var previous:=0
var label:="cold"
var tag:="baseline"
var cpu_cache_peak:=0
func _initialize() -> void:call_deferred("run")
func summary(values: Array) -> Dictionary:
	if values.is_empty():return {}
	var ordered:=values.duplicate();ordered.sort();var total:=0.0
	for value in values:total+=value
	return {"mean":total/values.size(),"p95":ordered[ceili(values.size()*.95)-1],"p99":ordered[ceili(values.size()*.99)-1],"max":ordered.back()}
func sample() -> float:
	await process_frame
	var now:=Time.get_ticks_usec();var delta: float=(now-previous)/1000000.0;previous=now
	var start:=Time.get_ticks_usec();stream.tick(delta);var cost: float=(Time.get_ticks_usec()-start)/1000.0
	ticks.append(cost);frames_ms.append(delta*1000);commits.append(stream.last_commit_usec/1000.0)
	gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	if cost>5:spikes.append({"tick_ms":cost,"phase":label,"parts":stream.last_phases.duplicate()})
	if ticks.size()%30==0:
		var row: Dictionary=stream.metrics();row["phase"]=label;records.append(row)
		cpu_cache_peak=maxi(cpu_cache_peak,scene.grass_wind.resident_cpu_cache_bytes)
	return delta
func observe(seconds: float) -> void:
	var elapsed:=0.0
	while elapsed<seconds:elapsed+=await sample()
func run() -> void:
	root.size=Vector2i(1600,900);Engine.max_fps=60
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):tag=arg.trim_prefix("--tag=")
	scene=load("res://scenes/map_1021.tscn").instantiate();scene.automation_enabled=true;root.add_child(scene)
	while not scene.test_ready:await process_frame
	scene.set_review_ui_visible(false);scene.get_node("PerformanceMonitor1021").set_process(false)
	scene.vegetation.set_process(false);stream=scene.vegetation.volume_streamer;stream.collect_detailed_timings=true
	await scene.select_spawn(5);scene.set_free(true)
	var origin: Vector3=scene.resolved_spawns[5].floor_position+Vector3.UP*4
	var direction:=Vector3(-1,0,1).normalized()
	scene.camera.position=origin;scene.camera.look_at(origin+direction*100);stream.refresh()
	previous=Time.get_ticks_usec();await observe(8)
	label="travel_18mps";var travel:=0.0
	while travel<18:
		travel+=await sample();scene.camera.position=origin+direction*minf(travel,18)*18
	label="revisit";scene.camera.position=origin;await observe(5)
	spikes.sort_custom(func(a,b):return a.tick_ms>b.tick_ms)
	var signature: String=load("res://scripts/grass_baked_store.gd").signature(scene)
	var passed: bool=signature==stream.store.manifest.signature and stream.store.corrupt==0
	var report: Dictionary={"passed":passed,"bake_signature":signature,"cpu_transform_cache_peak_mib":cpu_cache_peak/1048576.0,"tag":tag,"resolution":str(root.size),"trajectory":"north grass, 324m at 18m/s camera; 8s cold + 18s travel + 5s revisit","tick_ms":summary(ticks),"frame_ms":summary(frames_ms),"commit_ms":summary(commits),"gpu_ms":summary(gpu),"wind_profile":scene.grass_wind.profile,"stream_profile":stream.profile_totals,"slow_examples":spikes.slice(0,12),"records":records,"final":stream.metrics()}
	FileAccess.open(OUT+tag+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("STREAM_WIND_PROFILE ",JSON.stringify({"tag":tag,"tick":report.tick_ms,"commit":report.commit_ms,"wind":report.wind_profile,"parts":report.stream_profile}))
	quit(0 if passed else 1)
