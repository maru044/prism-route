extends Node
## Run with the exported executable, so source folders cannot mask missing files.
var world
var failures: Array[String]=[]
var report_path: String

func _ready() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok: failures.append(message);push_error(message)
func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame

func run() -> void:
	report_path=OS.get_executable_path().get_base_dir()+"/export_validation.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--export-report="):report_path=arg.trim_prefix("--export-report=")
	check(not OS.has_feature("editor"),"Check must run in the exported release template")
	var asset: String="res://assets/world/current_map_validation/"
	for path in ["metadata.json","tree_layout.json","tree_layout_metadata.json","grass_cells.json","surface_roles.json","grass_bake/manifest.json"]:
		check(FileAccess.file_exists(asset+path),"Missing data: "+path)
	for path in ["current_region.glb","landscape_mask.res","landscape.gdshader"]:
		check(ResourceLoader.exists(asset+path),"Missing resource: "+path)
	for path in ["tree_small_canopy_unlit_8view_v1.png","tree_broad_canopy_unlit_8view_v1.png","tree_upright_canopy_unlit_8view_v1.png"]:
		check(ResourceLoader.exists("res://assets/vegetation/textures/"+path),"Missing tree texture: "+path)
	if not failures.is_empty():finish({});return
	world=get_tree().current_scene
	while not world.test_ready: await get_tree().process_frame
	check(world.water_manager!=null,"Default water manager missing in release")
	if world.water_manager!=null:
		check(world.water_manager.style==2 and world.water_manager.bodies.size()==7,"Formal planar water is not configured in release")
	var stream=world.vegetation.volume_streamer
	check(stream.store.last_error.is_empty(),stream.store.last_error)
	check(stream.store.manifest.get("complete",false),"Complete bake did not open in release")
	check(stream.store.manifest.get("cells",{}).size()==11321,"Wrong baked cell count")
	check(world.vegetation.tree_instance_count==19605,"Wrong tree count")
	var spawns: Array=[]
	for index in [0,2,7]:
		await world.select_spawn(index);await frames(65)
		check(world.character.is_on_floor(),"Actor not grounded at "+str(index+1))
		spawns.append({"index":index+1,"grounded":world.character.is_on_floor()})
	var key:=InputEventKey.new();key.physical_keycode=KEY_C;key.pressed=true
	world._unhandled_input(key)
	while world.switching_actor:await get_tree().physics_frame
	await frames(65)
	check(not world.character_mode and world.camper.is_on_floor(),"C camper switch failed in release")
	var started:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-started<35000:
		await get_tree().process_frame
		if stream.pending_visible_count()==0 and stream.store.reads>0:break
	check(stream.pending_visible_count()==0,"Baked grass still missing after 35 seconds")
	check(stream.store.reads>0 and stream.store.corrupt==0,"Grass did not decode from the packaged bake")
	if DisplayServer.get_name()!="headless":
		world.show_overview()
		for child in world.get_children():
			if child is CanvasLayer:child.hide()
		world.camera.global_position=Vector3(-250,150,1100)
		world.camera.look_at(Vector3(-400,40,600))
		world.vegetation.target=world.camera;stream.refresh()
		started=Time.get_ticks_msec()
		while Time.get_ticks_msec()-started<35000:
			await get_tree().process_frame
			if stream.pending_visible_count()==0:break
		await frames(30);await RenderingServer.frame_post_draw
		check(get_tree().root.get_texture().get_image().save_png(report_path.get_basename()+".png")==OK,"Failed saving release screenshot")
	finish({"engine":Engine.get_version_info().string,"mesh_sha256":world.metadata.mesh_sha256,"objects":world.metadata.objects,"grass_signature":stream.store.manifest.get("signature",""),"baked_cells":stream.store.manifest.get("cells",{}).size(),"baked_reads":stream.store.reads,"corrupt_cells":stream.store.corrupt,"missing_visible":stream.pending_visible_count(),"trees":world.vegetation.tree_instance_count,"spawns":spawns,"camper_grounded":world.camper.is_on_floor(),"renderer":RenderingServer.get_video_adapter_name()})

func finish(report: Dictionary) -> void:
	report["passed"]=failures.is_empty();report["failures"]=failures
	var file:=FileAccess.open(report_path,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(report,"  "))
	print("EXPORT_1021_VALIDATION ",JSON.stringify(report));get_tree().quit(0 if failures.is_empty() else 1)
