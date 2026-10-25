extends CanvasLayer
## Independent, read-only performance HUD. Sampling never walks the world scene.
const UPDATE_SECONDS := 0.25
const WINDOW_USEC := 5_000_000
const TEXT := Color("e0e9ef")
const MUTED := Color("9baebd")
const ACCENT := Color("83ddcb")
const WARNING := Color("ffcc80")
var world_scene
var panel: PanelContainer
var values: Dictionary = {}
var frame_times: Array[float] = []
var timestamps: Array[int] = []
var sample_elapsed := 0.0
var previous_usec := 0
var collecting := false
var render_cpu_sum := 0.0
var render_gpu_sum := 0.0
var render_samples := 0
var stream_sum := 0.0
var stream_peak := 0.0
var stream_samples := 0
var stream_phases: Dictionary = {}
var refresh_cost_ms := 0.0
var graph: FrameGraph
var viewport_rid: RID

class FrameGraph extends Control:
	var samples := PackedFloat32Array()
	func _draw() -> void:
		for threshold in [16.667,33.333]:
			var y: float = size.y*(1.0-threshold/50.0)
			draw_line(Vector2(0,y),Vector2(size.x,y),Color(0.55,0.66,0.72,0.25))
		if samples.size()<2: return
		var points := PackedVector2Array()
		for i in samples.size():
			points.append(Vector2(float(i)/(samples.size()-1)*size.x,size.y*(1-clampf(samples[i]/50.0,0,1))))
		draw_polyline(points,Color(0,0,0,.8),3.0,true)
		draw_polyline(points,Color("83ddcb"),1.3,true)

func _ready() -> void:
	name="PerformanceMonitor1021";layer=40
	viewport_rid=get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid,true)
	var root_control := Control.new();add_child(root_control)
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter=Control.MOUSE_FILTER_IGNORE
	panel=PanelContainer.new();root_control.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left=20;panel.offset_right=450;panel.offset_bottom=-20
	panel.grow_vertical=Control.GROW_DIRECTION_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color=Color.TRANSPARENT
	style.content_margin_left=14;style.content_margin_right=14
	style.content_margin_top=10;style.content_margin_bottom=10
	panel.add_theme_stylebox_override("panel",style)
	var box := VBoxContainer.new();box.add_theme_constant_override("separation",3);panel.add_child(box)
	var title := _label("性能监视",18,ACCENT);box.add_child(title)
	var grid := GridContainer.new();grid.columns=2
	grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",2)
	box.add_child(grid)
	_add_row(grid,"fps","FPS / 帧时间 · 近5秒")
	_add_row(grid,"percentiles","帧时间 P95 / P99 · 近5秒")
	_add_row(grid,"hitches","慢帧 >33 / >50 ms · 近5秒")
	_add_row(grid,"frame_cap","帧率上限 / VSync")
	graph=FrameGraph.new();graph.custom_minimum_size=Vector2(0,38);box.add_child(graph)
	box.add_child(_label("帧时间 · 近5秒 · 横线 16.7 / 33.3 ms · 顶部50",12,MUTED))
	var details := GridContainer.new();details.columns=2
	details.add_theme_constant_override("h_separation",10);details.add_theme_constant_override("v_separation",2)
	box.add_child(details)
	_add_row(details,"process","引擎处理 / 物理 · ms")
	_add_row(details,"render","渲染 CPU / GPU · ms")
	_add_row(details,"draws","Draw calls / 渲染对象")
	_add_row(details,"primitives","渲染图元 / 帧")
	_add_row(details,"memory","引擎内存 / 峰值 · MiB")
	_add_row(details,"vram","渲染显存分配 · MiB")
	_add_row(details,"vram_parts","↳ 纹理 / 缓冲 · MiB")
	_add_row(details,"objects","节点 / 资源 / 孤立节点")
	_add_row(details,"physics","物理活动体 / 碰撞对 / 岛")
	_add_row(details,"grass","草块 · 常驻 / 排队 / 采样中")
	_add_row(details,"pending","↳ 近处候选待加载草块")
	_add_row(details,"stream_time","草流加载 · 均值 / 峰值 ms")
	_add_row(details,"stream_budget","↳ 每帧目标预算 · ms")
	_add_row(details,"stream_total","草块 · 累计生成 / 卸载")
	_add_row(details,"throughput","草块进入 / 完成 · 每秒")
	_add_row(details,"ages","排队P95 / 最久可见缺口 · s")
	_add_row(details,"visible","视锥缺块 · 0–48 / 48–76 / 76–128")
	_add_row(details,"sampling","射线 / 遮罩 / 数学 · ms")
	_add_row(details,"upload","提交当前 / 历史峰值 · ms")
	_add_row(details,"cpu_cache","草数据缓存 MiB / 命中 / 磁盘读")
	_add_row(details,"lod_cpu_cache","↳ LOD实例CPU副本 · MiB")
	_add_row(details,"source","草数据 · 烘焙 / 候选格")
	_add_row(details,"refresh","面板刷新 · ms / Hz")
	box.add_child(_label("显存为引擎分配量；CPU / GPU 耗时不可直接相加",12,MUTED))
	for child in root_control.find_children("*","Control",true,false):
		child.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_fit_panel()
	panel.minimum_size_changed.connect(_fit_panel)

func _exit_tree() -> void:
	if viewport_rid.is_valid():RenderingServer.viewport_set_measure_render_time(viewport_rid,false)

func _label(text: String,font_size: int,color: Color=TEXT) -> Label:
	var label := Label.new();label.text=text
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_outline_color",Color(0,0,0,.85))
	label.add_theme_constant_override("outline_size",2)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,.95))
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",1)
	return label

func _add_row(grid: GridContainer,key: String,caption: String) -> void:
	grid.add_child(_label(caption,14,MUTED))
	var label := _label("—",14)
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(label);values[key]=label

func _fit_panel() -> void:
	panel.offset_top=-20-panel.get_combined_minimum_size().y

func _stream():
	if world_scene==null or world_scene.vegetation==null:return null
	return world_scene.vegetation.volume_streamer

func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	if world_scene==null or not world_scene.test_ready:
		previous_usec=now
		return
	# Startup model loading is not a gameplay frame. Teleports and later stalls are.
	if not collecting:
		collecting=true;previous_usec=now
		return
	frame_times.append((now-previous_usec)/1000.0);timestamps.append(now);previous_usec=now
	while not timestamps.is_empty() and now-timestamps[0]>WINDOW_USEC:
		timestamps.pop_front();frame_times.pop_front()
	render_cpu_sum+=RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
	render_gpu_sum+=RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
	render_samples+=1
	var stream=_stream()
	if stream!=null:
		var ms: float=stream.last_build_usec/1000.0
		stream_sum+=ms;stream_peak=maxf(stream_peak,ms);stream_samples+=1
		var phases=stream.get("last_phases")
		if phases is Dictionary:
			for key in phases:stream_phases[key]=float(stream_phases.get(key,0))+float(phases[key])
	sample_elapsed+=delta
	if sample_elapsed<UPDATE_SECONDS:return
	sample_elapsed=0
	var start := Time.get_ticks_usec()
	_refresh()
	refresh_cost_ms=(Time.get_ticks_usec()-start)/1000.0
	render_cpu_sum=0;render_gpu_sum=0;render_samples=0
	stream_sum=0;stream_peak=0;stream_samples=0
	stream_phases.clear()

func _set_value(key: String,text: String,warn: bool=false) -> void:
	var label: Label=values[key];label.text=text
	label.add_theme_color_override("font_color",WARNING if warn else TEXT)

func _monitor(which: Performance.Monitor) -> float:
	return Performance.get_monitor(which)

func _refresh() -> void:
	var sorted := frame_times.duplicate();sorted.sort()
	var total := 0.0;var over33 := 0;var over50 := 0
	for ms in frame_times:
		total+=ms
		if ms>1000.0/30.0:over33+=1
		if ms>50:over50+=1
	var average := total/maxi(frame_times.size(),1)
	_set_value("fps","%.1f / %.2f ms" % [1000.0/maxf(average,.001),average],average>1000.0/45)
	var p95: float=sorted[maxi(ceili(sorted.size()*.95)-1,0)]
	var p99: float=sorted[maxi(ceili(sorted.size()*.99)-1,0)]
	_set_value("percentiles","%.2f / %.2f ms" % [p95,p99],p99>33.333)
	_set_value("hitches","%d / %d" % [over33,over50],over50>0)
	var vsync_modes := {DisplayServer.VSYNC_DISABLED:"关闭",DisplayServer.VSYNC_ENABLED:"开启",DisplayServer.VSYNC_ADAPTIVE:"自适应",DisplayServer.VSYNC_MAILBOX:"Mailbox"}
	_set_value("frame_cap","%s / %s" % [str(Engine.max_fps) if Engine.max_fps>0 else "无限",vsync_modes.get(DisplayServer.window_get_vsync_mode(),"未知")])
	# Bin to 100 chronological peaks so single-frame hitches remain visible.
	var peaks := PackedFloat32Array();var bin_count := mini(frame_times.size(),100)
	for i in bin_count:
		var peak := 0.0
		for j in range(i*frame_times.size()/bin_count,(i+1)*frame_times.size()/bin_count):peak=maxf(peak,frame_times[j])
		peaks.append(peak)
	graph.samples=peaks;graph.queue_redraw()
	_set_value("process","%.2f / %.2f" % [_monitor(Performance.TIME_PROCESS)*1000,_monitor(Performance.TIME_PHYSICS_PROCESS)*1000])
	var gpu := render_gpu_sum/maxi(render_samples,1)
	_set_value("render","%.2f / %s" % [render_cpu_sum/maxi(render_samples,1),"%.2f"%gpu if gpu>0 else "不可用"])
	_set_value("draws","%s / %s" % [_count(_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),_count(_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))])
	_set_value("primitives",_count(_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	_set_value("memory","%.0f / %.0f" % [_monitor(Performance.MEMORY_STATIC)/1048576,_monitor(Performance.MEMORY_STATIC_MAX)/1048576])
	_set_value("vram","%.0f" % (_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576))
	_set_value("vram_parts","%.0f / %.0f" % [_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576,_monitor(Performance.RENDER_BUFFER_MEM_USED)/1048576])
	_set_value("objects","%s / %s / %s" % [_count(_monitor(Performance.OBJECT_NODE_COUNT)),_count(_monitor(Performance.OBJECT_RESOURCE_COUNT)),_count(_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))])
	var active_bodies := _monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	var pairs := _monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)
	var islands := _monitor(Performance.PHYSICS_3D_ISLAND_COUNT)
	# This Jolt build returns zero even for a freely falling active rigid body.
	# Keep real physics timing above; do not misrepresent unsupported counters.
	if ProjectSettings.get_setting("physics/3d/physics_engine")=="Jolt Physics" and active_bodies+pairs+islands==0:
		_set_value("physics","未提供 (Jolt)")
	else:
		_set_value("physics","%s / %s / %s" % [_count(active_bodies),_count(pairs),_count(islands)])
	var stream=_stream()
	if stream!=null:
		var m: Dictionary=stream.metrics()
		_set_value("grass","%d / %d / %d" % [m.active,m.queued,int(m.building)])
		_set_value("pending",str(m.pending_visible),m.pending_visible>0)
		_set_value("stream_time","%.2f / %.2f" % [stream_sum/maxi(stream_samples,1),stream_peak])
		_set_value("stream_budget","%.1f" % ((stream.DRIVING_BUDGET_USEC if stream.prediction_velocity.length()>6 else stream.BASE_BUDGET_USEC)/1000.0))
		_set_value("stream_total","%d / %d" % [m.built,m.unloaded])
		if not m.has("visible"):return
		_set_value("throughput","%.1f / %.1f" % [m.incoming_per_s,m.completed_per_s])
		_set_value("ages","%.1f / %.1f" % [m.queue_p95_s,m.oldest_visible_s],m.oldest_visible_s>1)
		_set_value("visible","%d / %d / %d" % [m.visible["0_48"],m.visible["48_76"],m.visible["76_110"]+m.visible["110_128"]])
		var ray: float=stream_phases.get("terrain_ray_usec",0)+stream_phases.get("water_ray_usec",0)+stream_phases.get("clearance_ray_usec",0)
		var divisor: float=maxi(stream_samples,1)*1000.0
		_set_value("sampling","%.2f / %.2f / %.2f" % [ray/divisor,stream_phases.get("mask_usec",0)/divisor,stream_phases.get("math_usec",0)/divisor])
		if not stream.collect_detailed_timings or not stream.profiling:_set_value("sampling","F6 开启细分计时")
		_set_value("upload","%.2f / %.2f" % [m.commit_ms,m.max_commit_ms])
		_set_value("cpu_cache","%.0f / %d / %d" % [m.cache.cache_mib,m.cache.cache_hits,m.cache.disk_reads])
		var wind=world_scene.get("grass_wind")
		_set_value("lod_cpu_cache","%.1f" % (wind.resident_cpu_cache_bytes/1048576.0) if wind!=null else "—")
		_set_value("source","%d / %d" % [m.cache.baked_cells,m.indexed_cells],m.cache.baked_cells<m.indexed_cells)
	_set_value("refresh","%.2f / 4" % refresh_cost_ms)

func _count(number: float) -> String:
	var digits := str(int(number));var result := ""
	for i in digits.length():
		if i>0 and (digits.length()-i)%3==0:result+=" "
		result+=digits[i]
	return result
