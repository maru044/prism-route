extends "res://tools/verify_water_court_1101.gd"
## Real controller traversal and unchanged-map integration of the buried court.
var output_dir:="res://docs/concepts/coastal_sunken_archive_1103/game/"
func capture_view(name:String,view:Dictionary) -> void:
	world.set_free(true);world.camera.global_position=world.vec(view.eye);world.camera.look_at(world.vec(view.target))
	world.camera.fov=rad_to_deg(2.0*atan(12.0/float(view.lens)))
	world.vegetation.volume_streamer.refresh()
	await frames(45);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output_dir+name+".png")==OK,"Screenshot failed")
func run() -> void:
	Engine.max_fps=0
	create_timer(240).timeout.connect(func():push_error("Sunken court verification timeout");quit(1))
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var capture_mode:bool="--capture-sunken" in OS.get_cmdline_user_args()
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true;world.vegetation_bake_only=not capture_mode
	root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	await frames(10)
	var feature=world.sunken_archive;var manifest:Dictionary=feature.manifest
	check(feature.meshes_by_source.size()==95,"Missing native geometry")
	check(feature.colonly_ramps==1,"Missing authored -colonly stair ramp")
	var ramp_samples:=0
	for values:Array in manifest.routes.stairs.slice(0,16):
		var hit:=floor_at(world.vec(values))
		check(not hit.is_empty() and hit.collider.get_meta("smooth_stair_ramp",false),"Stair query did not hit -colonly ramp")
		if not hit.is_empty():check(hit.normal.y>.97,"Stair ramp has a riser or steep collision normal")
		ramp_samples+=1
	var duplicates:=0
	for mesh in world.model.find_children("*","MeshInstance3D",true,false):
		if str(mesh.name).get_slice("_",1) in feature.REPLACED_IDS:duplicates+=1
	check(duplicates==0,"Untrimmed base terrain remains in the rooms")
	var floor_checks:=0;var covered:=0;var minimum_headroom:=INF
	for values:Array in manifest.routes.gallery:
		var p:Vector3=world.vec(values);var hit:=floor_at(p)
		check(not hit.is_empty() and absf(hit.position.y-p.y)<.05,"Gallery floor mismatch")
		var up:=ray(p+Vector3.UP*.3,p+Vector3.UP*10)
		if not up.is_empty():
			minimum_headroom=minf(minimum_headroom,up.position.y-p.y);covered+=1
		floor_checks+=1
	check(covered>12 and minimum_headroom>3.5,"Gallery ceiling or burial blocks the interior")
	var spawn_checks:=0
	for proposal:Dictionary in world.resolved_spawns:
		check(proposal.has("floor_position"),"A map spawn did not resolve")
		spawn_checks+=1
	if capture_mode:
		check(feature.courtyard_grass.multimesh.mesh==world.vegetation.grass_mesh,"Courtyard uses a different grass model")
		check(feature.courtyard_grass.material_override==world.vegetation.grass_material,"Courtyard uses a different grass material")
		check(feature.courtyard_grass.multimesh.instance_count==1500,"Missing project grass instances")
		world.set_review_ui_visible(false)
		for name:String in ["overview","entry","court","gallery","coast"]:await capture_view(name,manifest.views[name])
	else:
		var stairs:Array=[];var gallery:Array=[];var approach:Array=[]
		for p:Array in manifest.routes.stairs:stairs.append(world.vec(p))
		for p:Array in manifest.routes.gallery:gallery.append(world.vec(p))
		for p:Array in manifest.routes.entry_landing:approach.append(world.vec(p))
		await walk(stairs,"stairs_down");stairs.reverse();await walk(stairs,"stairs_up")
		await walk(gallery,"gallery_forward");gallery.reverse();await walk(gallery,"gallery_reverse")
		await walk(approach,"short_entry_landing")
	report.merge({"passed":failures.is_empty(),"failures":failures,"native_meshes":feature.meshes_by_source.size(),"colonly_stair_ramps":feature.colonly_ramps,"smooth_ramp_surface_samples":ramp_samples,"replaced_hosts":feature.REPLACED_IDS.size(),"obsolete_host_meshes":duplicates,"gallery_floor_samples":floor_checks,"covered_samples":covered,"minimum_headroom_m":minimum_headroom,"map_spawns_checked":spawn_checks,"capture_mode":capture_mode,"external_long_path":false,"courtyard_project_grass_instances":1500 if capture_mode else 0},true)
	FileAccess.open(output_dir+("render_report.json" if capture_mode else "verification.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SUNKEN_ARCHIVE_VALIDATION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
