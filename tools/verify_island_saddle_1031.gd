extends SceneTree
const OUT="res://docs/island_saddle_1030/game/"
const STORE=preload("res://scripts/grass_baked_store.gd")
var world
var failures: Array[String]=[]
var report: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func frames(n: int) -> void:
	for i in n:await physics_frame
func ray(p: Vector3,mask: int=32) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.3,p-Vector3.UP*.5,mask)
	query.exclude=[world.character.get_rid()];query.hit_back_faces=true
	return world.get_world_3d().direct_space_state.intersect_ray(query)
func traverse(route: Array,label: String) -> void:
	world.free_mode=false;world.character_mode=true;world._sync_actor_controls()
	var start: Vector3=route[0]
	var ground:=ray(start)
	check(not ground.is_empty(),"Missing traversal starting floor: "+label)
	if ground.is_empty():return
	world.character.set_spawn(ground.position+Vector3.UP*.04,0)
	world.character.test_running=true
	await frames(12)
	var target:=1;var unsupported:=0;var steps:=0;var blocked_frames:=0;var previous: Vector3=world.character.global_position
	while target<route.size() and steps<6000:
		var p: Vector3=world.character.global_position
		var goal: Vector3=route[target]
		var offset:=Vector3(goal.x-p.x,0,goal.z-p.z)
		if offset.length()<.35:
			target+=1;continue
		var local: Vector3=world.character.camera_pivot.global_basis.inverse()*offset.normalized()
		world.character.test_move=Vector2(local.x,local.z)
		await physics_frame;steps+=1
		if steps>5 and not world.character.is_on_floor() and ray(world.character.global_position).is_empty():unsupported+=1
		if world.character.global_position.distance_to(previous)<.001:blocked_frames+=1
		else:blocked_frames=0
		previous=world.character.global_position
		if blocked_frames>180:break
	world.character.test_move=Vector2.ZERO
	await frames(8)
	var reached:=target==route.size()
	report[label]={"reached":reached,"unsupported_frames":unsupported,"physics_steps":steps,"waypoints_reached":target,"waypoints_total":route.size(),"last_position":str(world.character.global_position)}
	check(reached,"Could not traverse "+label);check(unsupported<4,"Character fell on "+label)
func capture(label: String,eye: Vector3,target: Vector3) -> void:
	if DisplayServer.get_name()=="headless":return
	world.set_free(true);world.camera.global_position=eye;world.camera.look_at(target)
	for i in 90:await physics_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+label+".png")==OK,"Capture failed")
func run() -> void:
	create_timer(240).timeout.connect(func():push_error("Saddle verification timed out");quit(1))
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true
	root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	await frames(12)
	var feature=world.island_saddle
	check(feature.geometry.find_children("*","MeshInstance3D",true,false).size()==feature.manifest.objects.size(),"Imported CAD geometry missing")
	check(feature.walking_body!=null,"Continuous skin collision missing")
	if feature.manifest.has("partial_glass"):
		check(not feature.walking_body.get_parent().visible,"Hidden continuous collider is still rendered")
		var glass_count:=0
		for mesh: MeshInstance3D in feature.geometry.find_children("*","MeshInstance3D",true,false):
			if mesh.get_meta("saddle_material","")!="contact_glass":continue
			glass_count+=1
			check(mesh.visible and mesh.get_child_count()==0,"Glass render skin unexpectedly changes collision")
			check(mesh.material_override.albedo_color.a<.5,"Contact glazing is not transparent")
		check(glass_count==1,"Partial contact glazing missing")
		report.partial_glass={"fraction":feature.manifest.partial_glass.glass_fraction,
			"collision_geometry_sha256":feature.manifest.collision_geometry_sha256,"visual_glass_meshes":glass_count}
	check(world.planting.load_error.is_empty(),"Existing planting edits did not load")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.planting_edits_path))
	check(world.planting.store.edits.size()==saved.trees.size(),"Saved planting edit count changed")
	check(world.planting.store.removed.size()==saved.removed.size(),"Saved tree removals changed")
	for row: Dictionary in saved.trees:
		var effective: Dictionary=world.planting.store.all_records().get(row.id,{})
		check(effective==row,"Existing planted tree changed: "+row.id)
	var protected_path: String="res://.current_map_build/saddle_import_1031_before/hashes.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--protected-hashes="):protected_path=argument.trim_prefix("--protected-hashes=")
	var hashes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(protected_path))
	for path: String in hashes:check(FileAccess.get_sha256("res://"+path)==hashes[path],"Protected source changed: "+path)
	var bake: Dictionary=world.vegetation.volume_streamer.store.manifest
	check(not bake.is_empty() and bake.complete and bake.signature==STORE.signature(world),"Existing grass cache invalidated")
	var route: Array=[]
	for p: Array in feature.manifest.route:route.append(world.vec(p))
	var misses:=0;var max_error:=0.
	for i in route.size():
		var point: Vector3=route[i]
		var hit:=ray(point)
		if hit.is_empty():misses+=1;continue
		max_error=maxf(max_error,absf(hit.position.y-point.y))
		check(hit.collider.get_meta("source_id","")==feature.manifest.walking_surface_id,"Walking route collision comes from wrong object")
	check(misses==0 and max_error<.05,"Imported walking surface has missing or shifted collision")
	var pre: Vector3=route[0]-(route[1]-route[0]).normalized()*1.8
	var post: Vector3=route[-1]+(route[-1]-route[-2]).normalized()*2.
	route.push_front(pre);route.append(post)
	var capture_only: bool="--capture-only" in OS.get_cmdline_user_args()
	if not capture_only:
		await traverse(route,"road_to_roof")
		route.reverse();await traverse(route,"roof_to_road")
	world.set_review_ui_visible(false)
	await capture("overview",world.vec(feature.manifest.review_eye),world.vec(feature.manifest.review_target))
	await capture("connection",Vector3(-315,79,550),Vector3(-240,64,680))
	await capture("glass_detail",Vector3(-350,104,545),Vector3(-230,64,655))
	report.passed=failures.is_empty();report.failures=failures
	report.meshes=feature.manifest.objects.size();report.walking_collision_samples=route.size()-2;report.maximum_collision_error_m=max_error
	report.planting={"edits":world.planting.store.edits.size(),"removed":world.planting.store.removed.size(),"preserved":true}
	report.grass_signature=bake.get("signature","");report.actual_scene=world.scene_file_path
	report.mode="render_review" if capture_only else "physics_and_planting"
	var report_name: String="headless_report.json" if DisplayServer.get_name()=="headless" else "game_report.json"
	FileAccess.open(OUT+report_name,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ISLAND_SADDLE_VERIFIED ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
