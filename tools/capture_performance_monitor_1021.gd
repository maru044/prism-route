extends SceneTree
## Real-render smoke check, including bottom-left anchoring and mouse pass-through.
const OUT := "res://assets/world/current_map_validation/review/"
var scene
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1600,900)
	scene=load("res://scenes/map_1021.tscn").instantiate()
	scene.automation_enabled=true;root.add_child(scene)
	while not scene.test_ready:await process_frame
	await scene.select_spawn(7);await scene.set_character_mode(false)
	var monitor=scene.get_node("PerformanceMonitor1021")
	assert(not monitor.visible and not monitor.is_processing(), "Performance monitoring must start disabled")
	scene.settings_panel.open()
	scene.settings_panel._show_monitor.button_pressed=true
	scene.settings_panel.close()
	await create_timer(8).timeout
	assert(monitor.collecting and monitor.frame_times.size()>10)
	assert(monitor.values.fps.text!="—" and monitor.values.grass.text!="—")
	assert(monitor.panel.get_theme_stylebox("panel").bg_color.a==0,"Performance panel background must be transparent")
	scene.settings_panel._show_details.button_pressed=true
	assert(scene.vegetation.volume_streamer.collect_detailed_timings,"Settings did not enable detailed profiling")
	scene.settings_panel._show_details.button_pressed=false
	var report: Dictionary={"metrics":{},"layouts":[]}
	for key in monitor.values:report.metrics[key]=monitor.values[key].text
	for resolution in [Vector2i(1600,900),Vector2i(1280,720)]:
		root.size=resolution
		await create_timer(.6).timeout
		await RenderingServer.frame_post_draw
		var rect: Rect2=monitor.panel.get_global_rect()
		var viewport_size: Vector2=monitor.panel.get_viewport_rect().size
		assert(rect.position.y>240,"Performance panel overlaps the existing controls")
		assert(absf(rect.end.y-(viewport_size.y-20))<2,"Panel is not anchored to the bottom")
		assert(rect.position.x>=0 and rect.end.x<=viewport_size.x)
		for child in monitor.find_children("*","Control",true,false):
			assert(child.mouse_filter==Control.MOUSE_FILTER_IGNORE)
		report.layouts.append({"window":str(resolution),"panel":str(rect),"viewport":str(viewport_size)})
		root.get_texture().get_image().save_png(OUT+"performance_monitor_%d.png"%resolution.x)
	var file:=FileAccess.open(OUT+"performance_monitor.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	scene.settings_panel._show_monitor.button_pressed=false
	assert(not monitor.visible and not monitor.is_processing(), "Performance monitoring kept sampling")
	print("PERFORMANCE_MONITOR_OK ",JSON.stringify(report));quit()
