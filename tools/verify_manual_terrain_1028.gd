extends SceneTree
## Imported geometry, Jolt collision, fixed roots, walking and final baked visuals.
const ASSETS := "res://assets/world/current_map_validation/"
const OUT := ASSETS+"review/"
var world
var failures: Array[String]=[]
var report: Dictionary={}
var probes: Array=[]
var exclusions: Dictionary={}

func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func frames(count: int) -> void:
	for i in count:await physics_frame
func point(p: Array) -> Vector3:return Vector3(p[0]-1450,p[2],1150-p[1])
func ray(a: Vector3,b: Vector3,target: String="",mask: int=32) -> Dictionary:
	var q:=PhysicsRayQueryParameters3D.create(a,b,mask);q.hit_back_faces=true
	if not target.is_empty():
		if not exclusions.has(target):
			var bodies: Array[RID]=[]
			for body in world.model.find_children("*","StaticBody3D",true,false):
				if body.get_meta("source_id","")!=target:bodies.append(body.get_rid())
			exclusions[target]=bodies
		q.exclude=exclusions[target]
	return world.get_world_3d().direct_space_state.intersect_ray(q)

func geometry_check() -> void:
	var rows: Array=[]
	for patch: Dictionary in probes:
		var count:=0;var error:=0.;var missing:=0
		for p: Array in patch.samples:
			var q:=point(p);var hit:=ray(q+Vector3.UP*.12,q+Vector3.DOWN*.3,patch.id)
			if hit.is_empty():missing+=1;continue
			error=maxf(error,absf(hit.position.y-q.y));count+=1
			check(hit.collider.get_meta("surface_kind","")=="Terrain","Wrong material/collider classification: "+patch.name)
		check(missing==0 and error<.025,"Imported hill geometry mismatch: "+patch.name)
		rows.append({"id":patch.id,"samples":count,"missing":missing,"max_height_error_m":error})
		var found:=false
		for mesh: MeshInstance3D in world.model.find_children("*","MeshInstance3D",true,false):
			if str(mesh.name).ends_with(patch.id):
				found=true;check(mesh.material_override==world.terrain_material,"Manual hill did not use landscape material")
		check(found,"Missing rendered hill: "+patch.name)
	report.geometry=rows

func tree_check() -> void:
	var records: Array=JSON.parse_string(FileAccess.get_file_as_string(ASSETS+"tree_layout.json"))
	var original: Array=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/manual_terrain_1028_before/tree_layout.json"))
	var original_by_xz: Dictionary={}
	for r: Array in original:original_by_xz[str([r[0],r[2]])]=r
	var invalid:=0;var changed_layout:=0;var error:=0.;var sources: Dictionary={}
	for r: Array in records:
		var p:=Vector3(r[0],r[1],r[2]);var hit:=ray(Vector3(p.x,400,p.z),Vector3(p.x,-30,p.z),"",5)
		if hit.is_empty() or hit.collider.get_meta("surface_kind","")!="Terrain" or world.architectural_band(hit.position,3):invalid+=1;continue
		error=maxf(error,absf(hit.position.y-p.y))
		var sid: String=hit.collider.get_meta("source_id","");sources[sid]=sources.get(sid,0)+1
		var old: Array=original_by_xz.get(str([r[0],r[2]]),[]).duplicate()
		if old.is_empty():changed_layout+=1
		else:
			old[1]=r[1]
			if old!=r:changed_layout+=1
	check(invalid==0 and error<.03,"Fixed trees did not follow the new ground")
	check(changed_layout==0,"Fixed tree spacing/species/rotation changed")
	var manual_counts: Dictionary={}
	for patch: Dictionary in probes:manual_counts[patch.id]=sources.get(patch.id,0)
	report.trees={"count":records.size(),"removed":original.size()-records.size(),"invalid_roots":invalid,"max_root_error_m":error,"changed_horizontal_layout":changed_layout,"manual_terrain_tree_counts":manual_counts}

func route_for_patch(patch: Dictionary) -> Array[Vector3]:
	for i in range(0,patch.samples.size(),maxi(1,patch.samples.size()/90)):
		var p: Array=patch.samples[i]
		if p[3]<.9:continue
		var start:=point(p)
		for direction: Vector3 in [Vector3.RIGHT,Vector3.FORWARD,-Vector3.RIGHT,Vector3.BACK]:
			var route: Array[Vector3]=[]
			for distance: float in [0.,3.,6.,9.,12.]:
				var q: Vector3=start+direction*distance
				var hit:=ray(q+Vector3.UP*5,q+Vector3.DOWN*5)
				if hit.is_empty() or hit.collider.get_meta("source_id","")!=patch.id or hit.normal.y<.82:break
				if not route.is_empty() and absf(hit.position.y-route[-1].y)>2.:break
				route.append(hit.position)
			if route.size()==5:return route
	return []

func walk_patch(patch: Dictionary) -> Dictionary:
	var route:=route_for_patch(patch)
	check(route.size()==5,"No gentle test route on "+patch.name)
	if route.size()!=5:return {"id":patch.id,"reached":0}
	var actor=world.character
	actor.set_control_enabled(true);actor.set_spawn(route[0]+Vector3.UP*.06,0)
	actor.test_move=Vector2.ZERO;actor.test_running=false;await frames(20)
	check(actor.is_on_floor(),"Character did not settle on "+patch.name)
	var reached:=0;var air:=0;var longest_air:=0
	actor.test_running=true
	for i in range(1,route.size()):
		var success:=false
		for frame in 180:
			var delta: Vector3=route[i]-actor.global_position;delta.y=0
			if delta.length()<.25:success=true;break
			var local: Vector3=actor.camera_pivot.global_basis.inverse()*delta.normalized()
			actor.test_move=Vector2(local.x,local.z).normalized()
			await physics_frame
			air=0 if actor.is_on_floor() else air+1;longest_air=maxi(longest_air,air)
		actor.test_move=Vector2.ZERO
		if not success:break
		reached+=1
	actor.test_running=false;await frames(15)
	check(reached==4 and longest_air<=2 and actor.is_on_floor(),"Character walking failed on "+patch.name)
	return {"id":patch.id,"reached":reached,"waypoints":4,"horizontal_route_m":12,"longest_air_frames":longest_air,"grounded":actor.is_on_floor()}

func capture_views() -> void:
	var stream=world.vegetation.volume_streamer
	check(stream.use_baked and stream.store.last_error.is_empty(),"Grass bake missing or stale")
	check(stream.store.manifest.get("complete",false),"Grass bake is incomplete")
	world.set_free(true);world.character.hide();world.camper.hide()
	for child in world.get_children():
		if child is CanvasLayer:child.hide()
	var views: Array=[
		{"name":"manual_terrain_1028_user_hill","eye":[1270.,575.,160.],"target":[960.,900.,18.]},
		{"name":"manual_terrain_1028_east","eye":[2240.,620.,125.],"target":[1940.,960.,58.]},
		{"name":"manual_terrain_1028_west","eye":[430.,740.,100.],"target":[135.,1100.,40.]},
		{"name":"manual_terrain_1028_overview","eye":[2150.,-650.,1000.],"target":[1100.,700.,25.]}]
	var captures: Array=[]
	for view: Dictionary in views:
		world.camera.position=point(view.eye);world.camera.look_at(point(view.target));world.camera.make_current()
		world.vegetation.target=world.camera;stream.refresh()
		for frame in 1800:
			await process_frame
			if frame>60 and stream.pending_visible_count()==0:break
		check(stream.pending_visible_count()==0,"Visible grass unfinished: "+view.name)
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OUT+view.name+".png")==OK,"Capture failed")
		captures.append(view.name)
	check(stream.store.corrupt==0,"Corrupt grass cells")
	report.render={"captures":captures,"baked_cells":stream.store.manifest.get("cells",{}).size(),"signature":stream.store.manifest.get("signature",""),"corrupt":stream.store.corrupt}

func run() -> void:
	Engine.max_fps=0;root.size=Vector2i(1600,900)
	var capture: bool="--capture" in OS.get_cmdline_user_args()
	probes=JSON.parse_string(FileAccess.get_file_as_string(OUT+"manual_terrain_1028_probes.json"))
	world=load("res://scenes/map_1021.tscn").instantiate()
	world.automation_enabled=true;world.vegetation_bake_only=not capture;root.add_child(world)
	while not world.test_ready:await process_frame
	await frames(30)
	check(world.metadata.objects==208 and probes.size()==6,"Wrong imported terrain version")
	check(world.character_mode and not world.camper.visible,"Default character mode changed")
	check(world.resolved_spawns[world.spawn_index].key=="spawn_cave" and world.character.is_on_floor(),"Default cave spawn failed")
	if capture and "--capture-only" in OS.get_cmdline_user_args():
		report=JSON.parse_string(FileAccess.get_file_as_string(OUT+"manual_terrain_1028_render.json"))
		check(report.get("mesh_sha256","")==world.metadata.mesh_sha256,"Capture-only report belongs to another mesh")
	else:
		geometry_check();tree_check()
	if capture:await capture_views()
	else:
		report.walks=[]
		for patch: Dictionary in probes:report.walks.append(await walk_patch(patch))
	report.merge({"passed":failures.is_empty(),"failures":failures,"capture":capture,"objects":world.metadata.objects,"triangles":world.metadata.triangles,"mesh_sha256":world.metadata.mesh_sha256})
	var path:=OUT+"manual_terrain_1028_"+("render" if capture else "physics")+".json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("MANUAL_TERRAIN_1028_RESULT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
