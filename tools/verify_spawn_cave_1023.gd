extends SceneTree
## Check the actual imported/Jolt scene, then optionally capture the full bake.
const OUT := "res://assets/world/current_map_validation/review/"
const CAVE := "f03d5707-4703-58a3-9c33-96106ea052be"
const ROOF := "577d868b-7597-4058-83f8-4b630606b305"
var world
var failures: Array[String]=[]
var report: Dictionary={}
var route: Dictionary

func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func frames(count: int) -> void:
	for i in count:await physics_frame
func point(p: Array) -> Vector3:return Vector3(p[0]-1450,p[2],1150-p[1])
func serial(p: Vector3) -> Array:return [p.x,p.y,p.z]
func ray(a: Vector3,b: Vector3) -> Dictionary:
	var q:=PhysicsRayQueryParameters3D.create(a,b,world.ACTOR_SOLID_LAYER);q.hit_back_faces=true
	return world.get_world_3d().direct_space_state.intersect_ray(q)

func walk_route() -> Dictionary:
	var actor=world.character
	var reached:=0;var total_frames:=0;var longest_air:=0;var air:=0
	actor.test_running=true
	for row: Array in route.native_waypoints:
		var goal:=point(row);var success:=false
		for frame in 500:
			var delta: Vector3=goal-actor.global_position;delta.y=0
			if delta.length()<.22:success=true;break
			var local: Vector3=actor.camera_pivot.global_basis.inverse()*delta.normalized()
			actor.test_move=Vector2(local.x,local.z).normalized()
			await physics_frame;total_frames+=1
			air=0 if actor.is_on_floor()else air+1;longest_air=maxi(longest_air,air)
			if actor.position.y<30:break
		actor.test_move=Vector2.ZERO
		if not success:check(false,"Cave exit route blocked at waypoint %d"%reached);break
		reached+=1
	actor.test_running=false;await frames(20)
	check(reached==route.native_waypoints.size(),"Incomplete cave-to-roof walk")
	check(actor.is_on_floor(),"Roof return is not grounded")
	check(longest_air<=2,"Character lost floor along the new path")
	return {"waypoints_reached":reached,"waypoints":route.native_waypoints.size(),"physics_frames":total_frames,"longest_air_frames":longest_air,"end_position":serial(actor.position)}

func material_and_headroom() -> Dictionary:
	var q:=point(route.mouth);var inward:=Vector3(route.inward[0],0,-route.inward[1])
	var expected: Material=load("res://assets/world/cliff_b_test/architecture.tres")
	var checked:=0;var min_head:=INF
	for depth in [1.,3.,5.,8.,12.,15.,18.]:
		var p: Vector3=q+inward*float(depth)
		var floor_hit:=ray(p+Vector3.UP*.5,p+Vector3.DOWN)
		check(not floor_hit.is_empty(),"Missing cave floor")
		if floor_hit.is_empty():continue
		check(floor_hit.collider.get_meta("source_id","")==CAVE,"Cave floor was classified as planting")
		check(floor_hit.collider.get_meta("surface_kind","")=="Structure","Cave floor is not architectural")
		var ceiling:=ray(p+Vector3.UP*.1,p+Vector3.UP*5)
		check(not ceiling.is_empty(),"Missing cave roof")
		if not ceiling.is_empty():
			check(ceiling.collider.get_meta("source_id","")==CAVE,"Cave ceiling lost architectural role")
			min_head=minf(min_head,ceiling.position.y-floor_hit.position.y)
		checked+=1
	for mesh: MeshInstance3D in world.model.find_children("*","MeshInstance3D",true,false):
		var id:=str(mesh.name).get_slice("_",1)
		if id in [CAVE,"9713e301-b5a7-4acb-821d-d98484bc52de","4b6d5fc4-59f9-490c-9eaf-ecc252b3de46","66bd60fa-4f5b-458a-aa30-ad164b0f5d70"]:
			check(mesh.material_override==expected,"Cave facility uses a grass material")
	check(min_head>2.9,"Cave center headroom too small")
	return {"floor_and_ceiling_probes":checked,"minimum_center_headroom_m":min_head,"cave_material":"architecture.tres","roof_id":ROOF}

func roots_check() -> Dictionary:
	var rows: Array=JSON.parse_string(FileAccess.get_file_as_string(world.ASSETS+"tree_layout.json"))
	var bad:=0;var roof_count:=0;var max_error:=0.
	for row: Array in rows:
		var p:=Vector3(row[0],row[1],row[2]);var x:=p.x+1450.;var y:=1150.-p.z
		if x<291 or x>736 or y> -220 or y< -484:continue
		var hit:=ray(Vector3(p.x,100,p.z),Vector3(p.x,-1,p.z))
		if hit.is_empty()or hit.collider.get_meta("surface_kind","")!="Terrain":bad+=1;continue
		max_error=maxf(max_error,absf(hit.position.y-p.y))
		if hit.collider.get_meta("source_id","")==ROOF:roof_count+=1
	check(bad==0 and max_error<.035,"Trees failed to follow the raised roof")
	return {"raised_roof_trees":roof_count,"invalid_roots":bad,"maximum_root_error_m":max_error}

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+name+".png")==OK,"Capture failed")

func settle_stream() -> void:
	var stream=world.vegetation.volume_streamer
	for i in 1800:
		await process_frame
		if i>45 and stream.pending_visible_count()==0:return
	check(false,"Visible grass did not finish streaming")

func baked_roots_check() -> Dictionary:
	var stream=world.vegetation.volume_streamer
	var q:=point(route.mouth);var inward:=Vector3(route.inward[0],0,-route.inward[1])
	var cells:=0;var roots:=0;var inside:=0;var on_architecture:=0;var side_seam_contacts:=0
	var architecture_hits: Dictionary={};var examples: Array=[]
	for id: String in stream.store.manifest.cells:
		var parts:=id.split("_")
		var origin:=Vector3(int(parts[0]),int(parts[1]),int(parts[2]))*24.
		if origin.x< -910 or origin.x> -760 or origin.z<1370 or origin.z>1550 or origin.y<24 or origin.y>48:continue
		var row: Dictionary=stream.store.manifest.cells[id]
		if int(row.root_count)==0:continue
		var compressed:=FileAccess.get_file_as_bytes(world.ASSETS+"grass_bake/"+id+".grass")
		var raw:=compressed.decompress(int(row.raw_bytes),FileAccess.COMPRESSION_ZSTD)
		var values:=raw.slice(0,int(row.root_count)*48).to_float64_array()
		cells+=1
		for i in int(row.root_count):
			var p:=origin+Vector3(values[i*6],values[i*6+2],values[i*6+1]);roots+=1
			var delta:=p-q;var depth:=delta.dot(inward)
			var across:=delta.dot(Vector3(inward.z,0,-inward.x))
			if depth>0 and depth<20 and absf(across)<2 and p.y>32.9 and p.y<36.5:inside+=1
			var hit:=ray(p+Vector3.UP*.06,p+Vector3.DOWN*.06)
			if not hit.is_empty() and hit.collider.get_meta("surface_kind","")=="Structure":
				# A steep road side meeting Terrain within the sampler's 5 mm
				# host clearance is an edge contact, not a covering walkable deck.
				# Keep this count visible; do not exempt horizontal paving.
				if hit.normal.y<.7 and absf(hit.position.y-p.y)<.005:
					side_seam_contacts+=1
					continue
				on_architecture+=1
				var hit_id: String=hit.collider.get_meta("source_id","")
				architecture_hits[hit_id]=architecture_hits.get(hit_id,0)+1
				if examples.size()<10:examples.append({"root":serial(p),"source":hit_id,"hit_height":hit.position.y,"normal":serial(hit.normal)})
	check(inside==0,"Baked grass roots exist inside the cave")
	check(on_architecture==0,"Baked grass roots exist on architectural surfaces")
	return {"cells_checked":cells,"roots_checked":roots,"roots_inside_cave":inside,"roots_on_architecture":on_architecture,"side_seam_contacts":side_seam_contacts,"architecture_hits":architecture_hits,"examples":examples}

func run() -> void:
	Engine.max_fps=0;root.size=Vector2i(1600,1000)
	var capture: bool="--capture" in OS.get_cmdline_user_args()
	route=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/spawn_cave_1023_route.json"))
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true;world.vegetation_bake_only=not capture;root.add_child(world)
	while not world.test_ready:await process_frame
	await frames(45)
	check(world.resolved_spawns[world.spawn_index].key=="spawn_cave","F5 did not start in the cave")
	check(world.character_mode and not world.camper.visible,"Camper exists at the initial spawn")
	check(world.character.is_on_floor()and absf(world.character.position.y-33.)<.15,"Initial spawn snapped to the roof")
	report.material=material_and_headroom();report.trees=roots_check()
	report.default_spawn=serial(world.character.position)
	print("SPAWN_CAVE_WALK_BEGIN")
	report.walk=await walk_route()
	world.character.reset_to_respawn();await frames(35)
	check(absf(world.character.position.y-33.)<.15 and world.character.is_on_floor(),"Character reset missed the cave floor")
	var spawn_checks:=0
	if not capture:
		for i in world.resolved_spawns.size():
			await world.select_spawn(i);await frames(35)
			check(world.character.is_on_floor(),"Existing spawn not grounded: %d"%i)
			check(absf(world.character.position.y-world.resolved_spawns[i].floor_position.y)<.25,"Wrong spawn storey")
			spawn_checks+=1
	else:
		await world.select_spawn(8);await frames(45);await settle_stream()
		var stream=world.vegetation.volume_streamer
		check(stream.use_baked and stream.store.last_error.is_empty(),"Grass bake is stale")
		check(stream.store.corrupt==0,"Corrupt grass cells")
		report.grass={"signature":stream.store.manifest.signature,"baked_cells":stream.store.manifest.cells.size(),"missing_visible":stream.pending_visible_count(),"corrupt":stream.store.corrupt}
		report.grass_roots=baked_roots_check()
		await shot("spawn_cave_1023_character")
		world.set_free(true)
		for child in world.get_children():
			if child is CanvasLayer:child.hide()
		world.camera.position=point([679.,-343.,41.]);world.camera.look_at(point([647.,-369.,34.]))
		world.vegetation.target=world.camera;stream.refresh();await settle_stream();await frames(30)
		await shot("spawn_cave_1023_exterior")
		world.camera.position=point([646.,-373.,36.]);world.camera.look_at(point([588.,-289.,35.]))
		stream.refresh();await settle_stream();await frames(30)
		await shot("spawn_cave_1023_roof_return")
	report.merge({"passed":failures.is_empty(),"failures":failures,"mesh_sha256":world.metadata.mesh_sha256,"objects":world.metadata.objects,"triangles":world.metadata.triangles,"spawn_checks":spawn_checks,"capture":capture})
	FileAccess.open(OUT+"spawn_cave_1023_%s.json"%("render"if capture else"validation"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SPAWN_CAVE_RESULT ",JSON.stringify(report));quit(0 if failures.is_empty()else 1)
