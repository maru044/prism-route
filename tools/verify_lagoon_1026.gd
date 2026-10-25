extends SceneTree
## Verify the imported mesh/Jolt floor and both lagoon exits in the F5 scene.
const OUT := "res://assets/world/current_map_validation/review/"
const TERRAIN := "9ed1bc59-e9fa-4024-8095-564d74c4c87c"
const EXIT_IDS := ["e5841b7a-99aa-430f-bef8-daad1ce4bdb8", "3ece7c15-82db-4301-920c-2f1cd7097101"]
var world
var failures: Array[String] = []
var report: Dictionary = {}

func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func point(x: float,y: float,z: float) -> Vector3:return Vector3(x-1450,z,1150-y)
func frames(n: int) -> void:
	for i in n:await physics_frame
func ray(a: Vector3,b: Vector3,mask: int=32,target: String="") -> Dictionary:
	var q:=PhysicsRayQueryParameters3D.create(a,b,mask);q.hit_back_faces=true
	if not target.is_empty():
		var excluded: Array[RID]=[]
		for node in world.model.find_children("*","StaticBody3D",true,false):
			if node.get_meta("source_id","")!=target:excluded.append(node.get_rid())
		q.exclude=excluded
	return world.get_world_3d().direct_space_state.intersect_ray(q)
func smooth(t: float) -> float:return t*t*t*(10.-15.*t+6.*t*t)
func route(which: int,t: float) -> Vector3:
	if which==0:
		var blend:=1-smooth(clampf(t*230/20,0,1))
		return point(1070+3*pow(sin(PI*t),2),470+230*t,-.69+(3.61056050653505+.69)*smooth(t)+(.69-.2851707874)*blend)
	return point(600-9*pow(sin(PI*t),2),500+240*t,-.69+(4.75711483891773+.69)*smooth(t))

func geometry_check() -> void:
	var probes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"lagoon_1026_probes.json"))
	var beds: Dictionary={}
	for name: String in probes:
		var count:=0;var error:=0.
		for p: Array in probes[name].samples:
			var q:=point(p[0],p[1],0)
			var h:=ray(q+Vector3.UP*.09,q+Vector3.DOWN*1.5,32,probes[name].id)
			check(not h.is_empty(),"Missing lake floor: "+name+str(p))
			if h.is_empty():continue
			check(h.collider.get_meta("source_id","")==probes[name].id,"Wrong lake bed source: "+name+str(p))
			check(h.collider.get_meta("surface_kind","")=="Sand","Lake bed became plantable")
			error=maxf(error,absf(h.position.y-float(p[2])))
			check(h.position.y<-.1,"Lake bed intersects water")
			count+=1
		check(error<.08,"Lake bed meshing error exceeds tolerance")
		beds[name]={"probes":count,"maximum_height_error_m":error}
	var supported:=0
	for x: float in [780.,800.,825.,850.,875.,900.,925.,950.,975.,1000.,1025.,1050.]:
		for y: float in [470.,480.,490.,499.,501.]:
			var q:=point(x,y,0);var h:=ray(q+Vector3.UP*7,q+Vector3.DOWN*3,16)
			check(not h.is_empty(),"Unfilled shore gap: "+str([x,y]))
			if h.is_empty():continue
			check(h.normal.y>.7,"Wrong shore support: "+str([x,y]))
			supported+=1
	var exits: Array=[]
	for which in 2:
		var count:=0;var max_error:=0.
		for i in range(1,60):
			var t:=i/60.;var q:=route(which,t)
			var tangent: Vector3=(route(which,minf(1,t+.001))-route(which,maxf(0,t-.001))).normalized()
			var side:=Vector3(-tangent.z,0,tangent.x).normalized()
			for lateral: float in [-3.,0.,3.]:
				var p: Vector3=q+side*lateral
				var h:=ray(p+Vector3.UP*.35,p+Vector3.DOWN*.6)
				check(not h.is_empty(),"Missing exit floor "+str([which,t,lateral]))
				if h.is_empty():continue
				max_error=maxf(max_error,absf(h.position.y-p.y))
				var ceiling:=ray(h.position+Vector3.UP*.12,h.position+Vector3.UP*2.3)
				if not ceiling.is_empty():
					if not report.has("blocked"):report.blocked=[]
					report.blocked.append({"which":which,"t":t,"side":lateral,"id":ceiling.collider.get_meta("source_id",""),"floor_source":h.collider.get_meta("source_id",""),"floor_y":h.position.y,"hit_y":ceiling.position.y})
				check(ceiling.is_empty(),"Blocked lagoon exit "+str([which,t,lateral]))
				count+=1
		check(max_error<.6,"Exit landing changed elevation")
		exits.append({"probes":count,"maximum_height_difference_m":max_error})
	report.geometry={"beds":beds,"shore_supported_samples":supported,"exits":exits}

func walk(which: int,reverse: bool=false) -> Dictionary:
	var actor=world.character
	var targets: Array[Vector3]=[]
	if which==0:targets.append(point(1070,469.5,-.2851707874))
	for i in range(1,40):targets.append(route(which,i/40.))
	if reverse:targets.reverse()
	actor.global_position=targets[0]+Vector3.UP*.08;actor.velocity=Vector3.ZERO
	await frames(30);actor.test_running=true
	var reached:=0;var air:=0;var longest_air:=0
	for i in range(1,targets.size()):
		var goal:=targets[i];var success:=false
		for frame in 300:
			var delta: Vector3=goal-actor.global_position;delta.y=0
			if delta.length()<.25:success=true;break
			var local: Vector3=actor.camera_pivot.global_basis.inverse()*delta.normalized()
			actor.test_move=Vector2(local.x,local.z).normalized()
			await physics_frame
			air=0 if actor.is_on_floor()else air+1;longest_air=maxi(longest_air,air)
			if actor.global_position.y< -5:break
		actor.test_move=Vector2.ZERO
		if not success:
			var hits: Array=[]
			for n in actor.get_slide_collision_count():
				var collision=actor.get_slide_collision(n)
				hits.append({"source":collision.get_collider().get_meta("source_id",""),"normal":str(collision.get_normal()),"position":str(collision.get_position())})
			report["walk_blocked_"+str(which)+str(reverse)]={"position":str(actor.global_position),"goal":str(goal),"collisions":hits,"velocity":str(actor.velocity),"move":str(actor.test_move)}
			check(false,"Exit walking blocked: "+str([which,i]));break
		reached+=1
	actor.test_running=false;await frames(30)
	check(reached==targets.size()-1 and actor.is_on_floor() and longest_air<=2,"Exit floor discontinuity: "+str(which))
	return {"exit":which,"reverse":reverse,"waypoints_reached":reached,"waypoints":targets.size()-1,"longest_air_frames":longest_air,"grounded":actor.is_on_floor()}

func render_check() -> void:
	var stream=world.vegetation.volume_streamer
	check(stream.use_baked and stream.store.last_error.is_empty(),"Stale/missing grass bake")
	check(stream.store.manifest.get("complete",false),"Grass bake incomplete")
	report.grass={"signature":stream.store.manifest.get("signature",""),"cells":stream.store.manifest.get("cells",{}).size()}
	world.set_free(true)
	world.character.hide();world.camper.hide()
	for layer in world.get_children():
		if layer is CanvasLayer:layer.hide()
	var views: Array=[
		{"name":"lagoon_1026_south","eye":point(1070,488,2.4),"target":point(1072,600,5)},
		{"name":"lagoon_1026_ramp","eye":point(600,540,5),"target":point(591,650,4)},
		{"name":"lagoon_1026_north","eye":point(1380,1090,160),"target":point(850,1350,0)}]
	for view: Dictionary in views:
		world.camera.position=view.eye;world.camera.look_at(view.target);world.camera.make_current()
		world.vegetation.target=world.camera;stream.refresh()
		for frame in 1800:
			await process_frame
			if frame>60 and stream.pending_visible_count()==0:break
		check(stream.pending_visible_count()==0,"Grass streaming unfinished at "+view.name)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OUT+view.name+".png")==OK,"Capture failed")
	check(stream.store.corrupt==0,"Corrupt baked grass")
	report.grass.corrupt=stream.store.corrupt

func run() -> void:
	Engine.max_fps=0;root.size=Vector2i(1600,900)
	var capture:= "--capture" in OS.get_cmdline_user_args()
	world=load("res://scenes/map_1021.tscn").instantiate()
	world.automation_enabled=true;world.vegetation_bake_only=not capture;root.add_child(world)
	while not world.test_ready:await process_frame
	await frames(30)
	check(world.metadata.objects==202,"Wrong imported map version")
	check(world.character_mode and not world.camper.visible,"Initial camper should be absent")
	geometry_check()
	if capture:await render_check()
	else:
		report.walks=[]
		for which in 2:
			for reverse: bool in [false,true]:report.walks.append(await walk(which,reverse))
	report.merge({"passed":failures.is_empty(),"failures":failures,"mesh_sha256":world.metadata.mesh_sha256,"objects":world.metadata.objects,"capture":capture})
	FileAccess.open(OUT+"lagoon_1026_%s.json"%("render"if capture else"physics"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("LAGOON_1026_RESULT ",JSON.stringify(report));quit(0 if failures.is_empty()else 1)
