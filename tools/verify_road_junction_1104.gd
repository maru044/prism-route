extends SceneTree
## Drive the actual camper through both turns, both entries and the coastal road.
const OUT="res://docs/road_junction_1104/"
var world
var failures: Array[String]=[]
var rows: Array=[]
func _initialize() -> void:call_deferred("run")
func ticks(n: int) -> void:
	for i in n:await physics_frame
func native(p: Array) -> Vector3:return Vector3(p[0]-1450.,p[2],1150.-p[1])
func height(p: Vector3) -> Vector3:
	var q:=PhysicsRayQueryParameters3D.create(Vector3(p.x,80,p.z),Vector3(p.x,40,p.z),8)
	q.hit_back_faces=true
	var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():failures.append("Road missing at "+str(p));return p
	return hit.position
func contacts() -> Array:
	var result: Array=[]
	for i in world.camper.get_slide_collision_count():
		var c=world.camper.get_slide_collision(i)
		result.append({"source":str(c.get_collider().get_meta("source_id","")),"normal":str(c.get_normal())})
	return result
func drive(label: String,path: Array[Vector3],speed: float) -> void:
	var camper=world.camper
	camper.maximum_forward_speed=speed
	var direction:=path[1]-path[0]
	world._spawn_camper(path[0],atan2(-direction.x,-direction.z))
	await ticks(70)
	var progress:=0;var worst:=0.;var airborne:=0;var max_airborne:=0;var stuck:=0
	var completed:=false;var last: Vector3=camper.position;var count:=0
	for frame in 2400:
		var closest:=INF;var best:=progress
		for j in range(maxi(0,progress-2),mini(progress+14,path.size())):
			var d: float=camper.position.distance_to(path[j])
			if d<closest:closest=d;best=j
		progress=maxi(progress,best);worst=maxf(worst,closest)
		if progress>=path.size()-3:completed=true;break
		if closest>6:break
		var target:=path[mini(progress+5,path.size()-1)]
		var heading: float=atan2(-(target.x-camper.position.x),-(target.z-camper.position.z))
		var error: float=angle_difference(camper.rotation.y,heading)
		camper.test_throttle=1.;camper.test_steering=clampf(error*2./maxf(absf(camper._steering_yaw_rate()),.2),-1.,1.)
		await physics_frame
		count=frame+1
		stuck=stuck+1 if camper.position.distance_to(last)<.005 else 0;last=camper.position
		airborne=0 if camper.is_on_floor() else airborne+1;max_airborne=maxi(max_airborne,airborne)
		if stuck>120:break
	var row: Dictionary={"route":label,"completed":completed,"speed_limit_mps":speed,"frames":count,
		"max_path_distance_m":worst,"max_airborne_frames":max_airborne,"contacts":contacts(),"end_position":str(camper.position)}
	rows.append(row);print("JUNCTION_DRIVE ",JSON.stringify(row))
	if not completed or max_airborne>=10:failures.append(label+" failed")
	camper.test_throttle=0.;camper.test_steering=0.;camper.test_braking=true;await ticks(50);camper.test_braking=false
func run() -> void:
	Engine.max_fps=0
	create_timer(240).timeout.connect(func():push_error("Junction verification timeout");quit(1))
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true;world.vegetation_bake_only=true
	root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	world.character_mode=false;world._sync_actor_controls()
	var routes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"routes.json"))
	if "--capture-only" in OS.get_cmdline_user_args():routes={}
	for label: String in routes:
		var path: Array[Vector3]=[]
		for p: Array in routes[label]:path.append(height(native(p)))
		await drive(label,path,18. if label.begins_with("coast") else 8.)
	var capture:=""
	if DisplayServer.get_name()!="headless":
		world.set_free(true);world.set_review_ui_visible(false)
		world.camera.position=native([1702.7393,808.7012,75.8041]);world.camera.look_at(native([1663.1492,746.2864,51.5107]))
		await ticks(30);await RenderingServer.frame_post_draw
		capture=OUT+"game.png";root.get_texture().get_image().save_png(capture)
	if "--capture-only" in OS.get_cmdline_user_args():quit();return
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"drives":rows,"capture":capture,"scene":world.scene_file_path}
	FileAccess.open(OUT+"verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("JUNCTION_REPORT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
