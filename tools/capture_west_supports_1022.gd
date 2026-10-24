extends SceneTree
## Render the actual imported support geometry, including the current grass bake.
const OUT := "res://assets/world/current_map_validation/review/"
var world
func _initialize() -> void: call_deferred("run")
func point(p: Array) -> Vector3: return Vector3(p[0]-1450,p[2],1150-p[1])
func vector(p: Array) -> Vector3: return Vector3(p[0],p[2],-p[1])
func run() -> void:
	root.size=Vector2i(1440,900)
	var structure_only:= "--structure-only" in OS.get_cmdline_user_args()
	world=load("res://scenes/map_1021.tscn").instantiate()
	world.automation_enabled=true;world.vegetation_bake_only=structure_only
	root.add_child(world)
	while not world.test_ready: await process_frame
	world.show_overview()
	for child in world.get_children():
		if child is CanvasLayer: child.hide()
	var stream= null if structure_only else world.vegetation.volume_streamer
	if not structure_only:
		assert(stream.store.last_error.is_empty() and stream.store.manifest.get("complete",false))
	var views: Array=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/west_supports_1022_views.json"))
	var captures: Array=[]
	for index in [2,0,3,4]:
		var row: Dictionary=views[index]
		var p:=point(row.p);var a:=vector(row.a);var n:=vector(row.n)
		var ground: float=float(row.ground) if row.ground!=null else p.y-14
		world.camera.global_position=p+n*62-a*38
		world.camera.global_position.y=ground+7
		var target:=p;target.y=(p.y+ground)*.5
		if not structure_only and index==2:
			# Stay inside the existing road's tree-free projection to see the piers.
			world.camera.global_position=p+n*7-a*36
			world.camera.global_position.y=ground+6
			target=p+a*20;target.y=(p.y+ground)*.5+3
		if not structure_only and index in [0,3]:
			world.camera.global_position.y+=22
		if index==4:
			world.camera.global_position=p+n*72-a*48+Vector3.UP*25
			target=p+Vector3.DOWN*7
		world.camera.look_at(target)
		if not structure_only:
			world.vegetation.target=world.camera;stream.refresh()
			var started:=Time.get_ticks_msec()
			for frame in 1800:
				await process_frame
				if frame>60 and stream.pending_visible_count()==0:break
				if Time.get_ticks_msec()-started>35000:break
			assert(stream.pending_visible_count()==0,"Visible grass did not finish loading")
		for frame in 30: await process_frame
		await RenderingServer.frame_post_draw
		var name: String="west_supports_%04d%s.png"%[int(row.s),"_structure" if structure_only else ""]
		assert(root.get_texture().get_image().save_png(OUT+name)==OK)
		captures.append({"image":name,"station_m":row.s,"structure_only":structure_only,"missing_visible":0 if structure_only else stream.pending_visible_count()})
	var report: Dictionary={"passed":true,"mesh_sha256":world.metadata.mesh_sha256,"captures":captures}
	if not structure_only:
		report["grass_signature"]=stream.store.manifest.signature
		report["baked_cells"]=stream.store.manifest.cells.size()
	FileAccess.open(OUT+"west_supports_1022_render%s.json"%("_structure" if structure_only else ""),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WEST_SUPPORTS_CAPTURE ",JSON.stringify(captures));quit()
