extends SceneTree
const OUT="res://docs/church_performance_1105/"
var world
var rows: Array=[]
var tag:="before"
func _initialize() -> void:call_deferred("run")
func summary(values: Array) -> Dictionary:
	values.sort();var total:=0.
	for v in values:total+=float(v)
	return {"mean":total/values.size(),"p95":values[ceili(values.size()*.95)-1],"max":values.back(),"samples":values.size()}
func settle(seconds: float) -> void:
	var start:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<seconds*1000.:await process_frame
func measure(label: String) -> void:
	await settle(.7)
	var values: Dictionary={"frame_ms":[],"gpu_ms":[],"render_cpu_ms":[],"physics_ms":[],"draws":[],"primitives":[]}
	var start:=Time.get_ticks_usec();var previous:=start
	while Time.get_ticks_usec()-start<2500000:
		await process_frame
		var now:=Time.get_ticks_usec();values.frame_ms.append((now-previous)/1000.);previous=now
		values.gpu_ms.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		values.render_cpu_ms.append(RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()))
		values.physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.)
		values.draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		values.primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var row: Dictionary={"label":label,"grass":world.vegetation.volume_streamer.metrics(),"water":world.water_manager.metrics()}
	for key: String in values:row[key]=summary(values[key])
	rows.append(row);print("CHURCH_PROFILE ",label," frame=",row.frame_ms.mean," gpu=",row.gpu_ms.mean," draws=",row.draws.mean)
	FileAccess.open(OUT+tag+".json",FileAccess.WRITE).store_string(JSON.stringify({"variants":rows,"adapter":RenderingServer.get_video_adapter_name(),"resolution":[root.size.x,root.size.y],"tag":tag},"  ")+"\n")
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tag="):tag=argument.trim_prefix("--tag=")
	create_timer(200).timeout.connect(func():push_error("Church profile timeout");quit(1))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT));AudioServer.set_bus_mute(0,true)
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true;root.add_child(world)
	while not world.test_ready:await process_frame
	world.set_free(true)
	var spawn: Vector3=world.vec(world.church_ruins.manifest.spawn_godot)
	var forward: Vector3=world.vec(world.church_ruins.manifest.spawn_look_direction_godot)
	world.camera.global_position=spawn+Vector3.UP*1.7;world.camera.look_at(spawn+forward*20.+Vector3.UP*3.)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	await settle(9.)
	for attempt in 12:
		if world.vegetation.volume_streamer.queue.is_empty() and world.vegetation.volume_streamer.work.is_empty():break
		await settle(1.)
	await measure("church_entry")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+tag+"_entry.png")
	world.church_ruins.visible=false;await measure("church_hidden");world.church_ruins.visible=true
	var glass: Array=[]
	for mesh: MeshInstance3D in world.church_ruins.geometry.find_children("*","MeshInstance3D",true,false):
		if mesh.material_override.resource_name.contains("glass"):glass.append(mesh);mesh.visible=false
	await measure("glass_hidden")
	for mesh: MeshInstance3D in glass:mesh.visible=true
	world.vegetation.volume_streamer.visible=false;await measure("grass_hidden");world.vegetation.volume_streamer.visible=true
	world.camera.global_position=spawn-forward*30.+Vector3.UP*24.;world.camera.look_at(spawn+forward*17.+Vector3.UP*3.)
	await settle(4.);await measure("church_overview")
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+tag+"_overview.png")
	quit()
