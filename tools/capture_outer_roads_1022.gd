extends SceneTree
## Capture the actual revised map with the matching baked grass enabled.
const OUT := "res://assets/world/current_map_validation/review/"
var world
func _initialize() -> void: call_deferred("run")
func point(p: Array) -> Vector3: return Vector3(p[0]-1450,p[2],1150-p[1])
func run() -> void:
	root.size=Vector2i(1440,900)
	world=load("res://scenes/map_1021.tscn").instantiate()
	world.automation_enabled=true;root.add_child(world)
	while not world.test_ready: await process_frame
	world.show_overview()
	for child in world.get_children():
		if child is CanvasLayer: child.hide()
	var stream=world.vegetation.volume_streamer
	assert(stream.store.last_error.is_empty() and stream.store.manifest.get("complete",false))
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/road_rebuild_1022_inspect.json"))
	var captures: Array=[]
	for i in source.roads.size():
		var road: Dictionary=source.roads[i]
		var index:=int(road.samples.size()*.76)
		var row: Dictionary=road.samples[index]
		var p:=point(row.center)
		var tangent: Vector3=(point(road.samples[index+1].center)-p).normalized()
		var across: Vector3=(point(row.right)-point(row.left)).normalized()
		world.camera.global_position=p+across*37+Vector3.UP*20-tangent*40
		world.camera.look_at(p+tangent*30)
		world.vegetation.target=world.camera
		stream.refresh()
		var start:=Time.get_ticks_msec()
		for frame in 1800:
			await process_frame
			if frame>60 and stream.pending_visible_count()==0:break
			if Time.get_ticks_msec()-start>35000:break
		assert(stream.pending_visible_count()==0,"Visible grass did not finish loading")
		for frame in 30: await process_frame
		await RenderingServer.frame_post_draw
		var name: String="outer_roads_east.png" if i==0 else "outer_roads_west.png"
		assert(root.get_texture().get_image().save_png(OUT+name)==OK)
		captures.append({"image":name,"baked_cells":stream.store.manifest.cells.size(),"active_grass_cells":stream.active.size(),"missing_visible":stream.pending_visible_count()})
	FileAccess.open(OUT+"outer_roads_1022_render.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"mesh_sha256":world.metadata.mesh_sha256,"captures":captures},"  "))
	print("OUTER_ROADS_CAPTURE ",JSON.stringify(captures))
	quit()
