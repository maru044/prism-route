extends SceneTree
## Real imported collision, plantable roots and continuous camper traversal.
const OUT := "res://assets/world/current_map_validation/review/outer_roads_1022.json"
var world
var stream
var failures: Array[String] = []
var rows: Array = []

func _initialize() -> void: call_deferred("run")
func ticks(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message);push_error(message)
func point(native: Array) -> Vector3:
	return Vector3(native[0]-1450,native[2],1150-native[1])

func drive(points: Array[Vector3], reverse: bool) -> Dictionary:
	var path: Array[Vector3] = points.duplicate()
	if reverse: path.reverse()
	# Start/finish inside the strip so the full camper fits on it.
	path = path.slice(3,path.size()-3)
	var direction := path[1]-path[0]
	world._spawn_camper(path[0],atan2(-direction.x,-direction.z))
	await ticks(70)
	var camper = world.camper
	var progress := 0
	var worst := 0.0
	var airborne := 0
	var high_airborne := 0
	var completed := false
	var frame_count := 0
	var still_frames:=0
	var last_position: Vector3=camper.global_position
	for frame in 16000:
		var best := progress
		var closest := INF
		for j in range(maxi(0,progress-2),mini(progress+10,path.size())):
			var distance: float = camper.global_position.distance_to(path[j])
			if distance<closest: closest=distance;best=j
		progress=maxi(progress,best)
		worst=maxf(worst,closest)
		if closest>14:
			check(false,"Camper left road at waypoint %d, position %s"%[progress,str(camper.position)])
			break
		if progress>=path.size()-3:
			completed=true;break
		var target := path[mini(progress+2,path.size()-1)]
		var heading: float = atan2(-(target.x-camper.position.x),-(target.z-camper.position.z))
		var error: float = angle_difference(camper.rotation.y,heading)
		camper.test_throttle=1
		camper.test_steering=clampf(error*2/maxf(absf(camper._steering_yaw_rate()),.2),-1,1)
		await physics_frame
		frame_count=frame+1
		still_frames=still_frames+1 if camper.global_position.distance_to(last_position)<.005 else 0
		last_position=camper.global_position
		if still_frames>120:
			var contacts: Array=[]
			for n in camper.get_slide_collision_count():
				var hit=camper.get_slide_collision(n)
				contacts.append({"normal":str(hit.get_normal()),"point":str(hit.get_position()),"source":hit.get_collider().get_meta("source_id","")})
			print("ROAD_STUCK ",JSON.stringify({"position":str(camper.position),"waypoint":str(path[progress]),"contacts":contacts}))
			break
		airborne=0 if camper.is_on_floor() else airborne+1
		high_airborne=maxi(high_airborne,airborne)
		if frame>200 and camper.drive_speed<1:
			check(false,"Camper unable to build speed");break
	camper.test_throttle=0;camper.test_steering=0;camper.test_braking=true
	await ticks(60)
	camper.test_braking=false
	check(completed,"Road traversal incomplete, waypoint %d/%d"%[progress,path.size()])
	check(high_airborne<10,"Camper lost road support for too long")
	var contacts: Array=[]
	for n in camper.get_slide_collision_count():
		var hit=camper.get_slide_collision(n)
		contacts.append({"normal":str(hit.get_normal()),"point":str(hit.get_position()),"source":hit.get_collider().get_meta("source_id","")})
	return {"reverse":reverse,"completed":completed,"frames":frame_count,"max_waypoint_distance_m":worst,"max_airborne_frames":high_airborne,"end_position":str(camper.position),"waypoint":str(path[progress]),"contacts":contacts}

func run() -> void:
	Engine.max_fps=0
	world=load("res://scenes/map_1021.tscn").instantiate()
	world.automation_enabled=true;world.vegetation_bake_only=true
	root.add_child(world)
	while not world.test_ready: await process_frame
	world.character_mode=false;world._sync_actor_controls()
	var vegetation=load("res://scripts/map_1021_vegetation.gd").new()
	vegetation.world_scene=world;world.add_child(vegetation)
	vegetation.target=world.camper;vegetation.biome_noise_texture=world._noise();vegetation._load_meshes_and_materials()
	stream=load("res://scripts/grass_volume_streamer.gd").new()
	vegetation.add_child(stream);stream.initialize(vegetation,world)
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/road_rebuild_1022_inspect.json"))
	for road: Dictionary in source.roads:
		if "--west-only" in OS.get_cmdline_user_args() and road.id.begins_with("ee277"):continue
		var points: Array[Vector3]=[]
		var probes:=0;var plants:=0;var obstruction:=0;var road_misses:=0
		for i in road.samples.size():
			var sample: Dictionary=road.samples[i]
			var a:=point(sample.left);var b:=point(sample.right)
			points.append((a+b)*.5)
			if i==0 or i==road.samples.size()-1:continue
			for cross in [.08,.29,.5,.71,.92]:
				var p:=a.lerp(b,cross)
				var cell:=Vector3i(floori(p.x/24),floori((p.y-.05)/24),floori(p.z/24))
				for hit: Dictionary in stream.sample_surfaces(cell,p.x,p.z):
					if absf(hit.position.y-p.y)<1.3:plants+=1
				var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*5,p+Vector3.UP*.035,16)
				query.hit_back_faces=true
				if not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty():obstruction+=1
				query=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.6,p-Vector3.UP*.6,8)
				query.hit_back_faces=true
				if world.get_world_3d().direct_space_state.intersect_ray(query).is_empty():road_misses+=1
				probes+=1
		check(plants==0,"Plantable grass remained on road "+str(road.id))
		check(obstruction==0,"Terrain above road "+str(road.id))
		check(road_misses==0,"Road collision missing "+str(road.id))
		var drives: Array=[]
		for reverse in ([true] if "--west-only" in OS.get_cmdline_user_args() else [false,true]):drives.append(await drive(points,reverse))
		rows.append({"id":road.id,"probes":probes,"grass_roots_near_road":plants,"terrain_obstructions":obstruction,"road_misses":road_misses,"drives":drives})
		print("OUTER_ROAD_CHECK ",JSON.stringify(rows[-1]))
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"roads":rows,"mesh_sha256":world.metadata.mesh_sha256}
	FileAccess.open(OUT,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit(0 if failures.is_empty() else 1)
