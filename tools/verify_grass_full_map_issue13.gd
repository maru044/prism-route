extends SceneTree
## Eight actual scene spawn points, with the complete baked candidate index.
const OUT := "res://assets/world/current_map_validation/review/"
var failures: Array[String]=[]
var scene
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	root.size=Vector2i(1920,1080)
	scene=load("res://scenes/map_1021.tscn").instantiate();scene.automation_enabled=true;root.add_child(scene)
	while not scene.test_ready:await process_frame
	var stream=scene.vegetation.volume_streamer
	var index: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(scene.ASSETS+"grass_cells.json"))
	check(stream.store.manifest.get("complete",false),"The full bake is not published")
	check(stream.store.manifest.get("cells",{}).size()==index.cells.size(),"Full bake candidate count mismatch")
	if not failures.is_empty():quit(1);return
	var rows: Array=[]
	for i in range(8):
		await scene.select_spawn(i)
		for j in 3:await physics_frame
		stream.refresh()
		var begin:=Time.get_ticks_msec();var near_ready:=-1.0
		var gpu: Array[float]=[]
		var max_cache:=0
		var visible: Dictionary={}
		while Time.get_ticks_msec()-begin<30000:
			await process_frame
			visible=stream.visible_missing()
			var near: int=visible["0_48"]+visible["48_76"]
			if near==0 and near_ready<0:near_ready=(Time.get_ticks_msec()-begin)/1000.0
			max_cache=maxi(max_cache,stream.store.cache_bytes)
			check(stream.store.cache_bytes<=stream.store.MAX_CACHE_BYTES,"CPU cache exceeded its cap")
			var elapsed: float=(Time.get_ticks_msec()-begin)/1000.0
			if near==0 and visible["76_110"]+visible["110_128"]==0 and elapsed>.5:break
		check(near_ready>=0,"Near grass did not finish at spawn %d"%[i+1])
		check(visible.values().all(func(n):return int(n)==0),"Visible 128m region did not finish at spawn %d"%[i+1])
		for j in 60:
			await process_frame
			var value:=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
			if value>0:gpu.append(value)
		gpu.sort()
		var gpu_mean:=0.0
		for value in gpu:gpu_mean+=value
		gpu_mean/=maxi(gpu.size(),1)
		var row: Dictionary={"spawn":i+1,"name":scene.resolved_spawns[i].name,"near_ready_s":near_ready,"visible_128m_ready_s":(Time.get_ticks_msec()-begin)/1000.0-1.0,"visible":visible,"gpu_mean_ms":gpu_mean,"gpu_p95_ms":0 if gpu.is_empty() else gpu[maxi(0,ceili(gpu.size()*.95)-1)],"max_cpu_cache_mib":max_cache/1048576.0,"stream":stream.metrics(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"render_vram_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,"engine_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0}
		rows.append(row)
		print("FULL_MAP_GRASS_POINT ",JSON.stringify(row))
		if i in [0,5,7]:
			await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"issue13_full_spawn_%d.png"%[i+1])
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"cells":stream.store.manifest.cells.size(),"spawns":rows,"note":"First visits in one session, so nearby points may reuse cache. Readiness uses conservative camera-frustum candidate volumes. GPU figures measured for one second after visible grass is complete, not worst-case profiling of all possible views."}
	var file:=FileAccess.open(OUT+"issue13_full_spawns.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("FULL_MAP_GRASS_VERIFY passed=",failures.is_empty());quit(0 if failures.is_empty() else 1)
