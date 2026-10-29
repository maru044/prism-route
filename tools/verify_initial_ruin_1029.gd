extends SceneTree
const WORLD=preload("res://scenes/map_1021.tscn")
const STORE=preload("res://scripts/grass_baked_store.gd")
const OUT="res://docs/initial_ruin_1029/"
var world
var failures: Array[String]=[]
var report: Dictionary={}

func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func frames(n: int) -> void:
	for i in n:await physics_frame
func put_json(name: String,value) -> void:
	FileAccess.open(OUT+name,FileAccess.WRITE).store_string(JSON.stringify(value,"  "))
func ray(a: Vector3,b: Vector3,exclude: Array[RID]=[],mask: int=32) -> Dictionary:
	var q:=PhysicsRayQueryParameters3D.create(a,b,mask);q.hit_back_faces=true;q.exclude=exclude
	return world.get_world_3d().direct_space_state.intersect_ray(q)
func point(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2])
func key_e(echo: bool=false) -> void:
	var event:=InputEventKey.new();event.keycode=KEY_E;event.physical_keycode=KEY_E;event.pressed=true;event.echo=echo
	Input.parse_input_event(event)
	var release:=InputEventKey.new();release.keycode=KEY_E;release.physical_keycode=KEY_E;release.pressed=false;Input.parse_input_event(release)

func geometry_checks() -> void:
	var ruin=world.initial_ruin;var manifest: Dictionary=ruin.planting_mask.manifest
	check(ruin.geometry.find_children("*","MeshInstance3D",true,false).size()==328,"Missing ruin geometry")
	check(ruin.avatar.effect.binding_report.converted==20 and ruin.avatar.effect.binding_report.unsupported.is_empty(),"Keqing material adaptation incomplete")
	check(ruin.avatar.global_position.distance_to(point(manifest.summon_anchor))<.001,"Keqing is not centered on the imported dais")
	var missing:=0;var count:=0;var error:=0.;var overlapping:=0
	for item: Dictionary in manifest.probes:
		for a: Array in item.samples:
			var p:=point(a);var hit: Dictionary={};var excluded: Array[RID]=[]
			# Foundation caps, flooring and copings deliberately overlap. Verify the
			# named CAD component, rather than measuring a different face in front of it.
			for attempt in 12:
				hit=ray(p+Vector3.UP*.12,p-Vector3.UP*.12,excluded,1)
				if hit.is_empty() or hit.collider.get_meta("source_id","")==item.id:break
				excluded.append(hit.collider.get_rid());overlapping+=1;hit={}
			count+=1
			if hit.is_empty():missing+=1
			else:error=maxf(error,absf(hit.position.y-p.y))
	check(missing==0 and error<.025,"Imported ruin collision did not match CAD samples")
	check(InputMap.has_action("interact"),"No interaction action")
	var found_e:=false
	for event in InputMap.action_get_events("interact"):
		if event is InputEventKey and event.physical_keycode==KEY_E:found_e=true
	check(found_e,"Interaction is not bound to physical E")
	check(world.resolved_spawns[8].key=="spawn_cave" and world.resolved_spawns[9].key=="initial_ruin","Existing spawn order changed")
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://scenes/map_1021.tscn","F5 entry changed")
	var bake: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.ASSETS+"grass_bake/manifest.json"))
	check(bake.signature==STORE.signature(world) and bake.get("complete",false),"Grass bake is stale/incomplete")
	check(FileAccess.get_sha256(world.ASSETS+"current_region.glb")==world.metadata.mesh_sha256,"Existing map mesh changed")
	check(FileAccess.get_sha256(world.ASSETS+"tree_layout.json")==FileAccess.get_sha256("res://.current_map_build/initial_ruin_1029_before/tree_layout.json"),"Existing tree records were modified")
	report.geometry={"meshes":328,"source_triangles":manifest.triangles,"collision_samples":count,"missing":missing,"max_height_error_m":error,"overlapping_components_skipped":overlapping,"keqing_surfaces":20,"anchor":manifest.summon_anchor}

func interaction_checks() -> void:
	var ruin=world.initial_ruin;var actor=world.character
	var anchor: Vector3=ruin.avatar.global_position
	var forward:=point(ruin.planting_mask.manifest.forward)
	var near: Vector3=anchor-forward*2.45;near.y=61.05
	key_e();await frames(2);check(ruin.state==ruin.State.HOLOGRAM,"Printing started from outside the trigger")
	actor.set_spawn(near+Vector3.UP*.04,.38);await frames(12)
	check(ruin.nearby and ruin.trigger.overlaps_body(actor),"Player did not enter the interaction collision box")
	check(ruin.can_interact() and ruin.prompt.visible,"No prompt in the interaction area")
	world.set_free(true);key_e();await frames(2)
	check(ruin.state==ruin.State.HOLOGRAM,"Free-camera E started printing")
	world.set_free(false);await frames(3)
	world.character_mode=false;key_e();await frames(2)
	check(ruin.state==ruin.State.HOLOGRAM,"Vehicle mode started printing")
	world.character_mode=true;world._sync_actor_controls();await frames(3)
	var cast_a: Vector3=anchor+Vector3(-1.,.75,0);var cast_b: Vector3=anchor+Vector3(1.,.75,0)
	var before:=ray(cast_a,cast_b,[actor.get_rid()])
	check(ruin.solid_shape.disabled and (before.is_empty() or before.collider!=ruin.solid_body),"Hologram has a solid NPC collision")
	key_e();await frames(4)
	check(ruin.state==ruin.State.PRINTING and ruin.print_count==1,"Physical E did not start printing exactly once")
	key_e();key_e(true);await frames(3)
	check(ruin.print_count==1,"Repeated/held E restarted printing")
	for i in 150:
		if ruin.avatar.effect.materialization_progress>=.4:break
		await frames(1)
	check(ruin.state==ruin.State.PRINTING and ruin.avatar.effect.materialization_progress<1.,"Printing skipped the partial phase")
	check(ruin.solid_shape.disabled,"NPC collision activated before materialization finished")
	for i in 240:
		if ruin.state==ruin.State.PRINTED:break
		await frames(1)
	await frames(3)
	check(ruin.state==ruin.State.PRINTED and ruin.avatar.effect.materialization_progress==1.,"Printing did not finish")
	for material: ShaderMaterial in ruin.avatar.effect.base_materials:check(material.next_pass==null,"Printed character retains a hologram light pass")
	var after:=ray(cast_a,cast_b,[actor.get_rid()])
	check(not ruin.solid_shape.disabled and not after.is_empty() and after.collider==ruin.solid_body,"Printed character is not physically solid")
	key_e();await frames(2);check(ruin.print_count==1,"Printed character can be duplicated by pressing E again")
	actor.set_spawn(near-forward*10.+Vector3.UP*.1,0.);await frames(5)
	check(not ruin.nearby,"Interaction box did not clear after leaving")
	actor.set_spawn(near+Vector3.UP*.04,.38);await frames(8)
	check(ruin.state==ruin.State.PRINTED,"Leaving the area reset the printed state")
	world.set_review_ui_visible(false);check(not ruin.prompt_layer.visible,"H did not hide summon HUD")
	world.set_review_ui_visible(true)
	report.interaction={"key":"E","outside_blocked":true,"free_camera_blocked":true,"vehicle_blocked":true,"area_enter_exit":true,"one_shot_print_count":ruin.print_count,"materialization_seconds":3.5,"completed_solid_collision":true,"printed_state_retained":true}

func local_world(u: float,v: float,y: float) -> Vector3:
	var p: Dictionary=world.initial_ruin.planting_mask.manifest.placement
	var x: float=p.front_center[0]+u*p.right_axis[0]+v*p.long_axis[0]
	var native_y: float=p.front_center[1]+u*p.right_axis[1]+v*p.long_axis[1]
	return Vector3(x-1450.,y,1150.-native_y)

func route_points() -> Array[Vector3]:
	var raw: Array=world.initial_ruin.planting_mask.manifest.placement.approach_nodes
	var points: Array[Vector3]=[]
	for a: Array in raw:points.append(Vector3(float(a[0])-1450.,0.,1150.-float(a[1])))
	var rounded: Array[Vector3]=[points[0]]
	for i in range(1,points.size()-1):
		var incoming:=points[i]-points[i-1];var outgoing:=points[i+1]-points[i]
		var trim:=minf(5.,minf(incoming.length()*.25,outgoing.length()*.25))
		var a:=points[i]-incoming.normalized()*trim;var b:=points[i]+outgoing.normalized()*trim
		rounded.append(a)
		for j in range(1,21):
			var t:=j/20.;rounded.append(a*(1-t)*(1-t)+points[i]*(2*t*(1-t))+b*t*t)
	rounded.append(points[-1])
	var path: Array[Vector3]=[]
	var bridge_start:=Vector3(576-1450.,0,1150+271.5)
	var bridge_steps:=maxi(1,ceili(bridge_start.distance_to(rounded[0])/2.5))
	for i in bridge_steps:path.append(bridge_start.lerp(rounded[0],float(i)/bridge_steps))
	for i in range(rounded.size()-1):
		var count:=maxi(1,ceili(rounded[i].distance_to(rounded[i+1])/2.5))
		for j in count:path.append(rounded[i].lerp(rounded[i+1],float(j)/count))
	path.append(rounded[-1])
	for v: float in [-28.,-27.,-25.,-23.,-21.,-20.7,-18.3,-16.,-14.,-12.,-9.,-6.,-3.,0.,3.,6.,8.,9.,10.4,13.,16.,19.,22.4]:path.append(local_world(0,v,0))
	return path

func walking_check() -> void:
	var actor=world.character;var route:=route_points();var snapped: Array[Vector3]=[]
	for p: Vector3 in route:
		var hit:=ray(Vector3(p.x,70.,p.z),Vector3(p.x,25.,p.z),[actor.get_rid()])
		check(not hit.is_empty(),"Approach has no support at "+str(p))
		if not hit.is_empty():snapped.append(hit.position)
	if snapped.size()!=route.size():return
	# Use the actual gameplay physics delta. Scaling time also scales each
	# capsule sweep and can cross multiple risers in one artificial test tick.
	Engine.time_scale=1.
	actor.set_spawn(snapped[0]+Vector3.UP*.05,0.);actor.camera_pivot.rotation=Vector3.ZERO
	actor.test_running=true;actor.test_move=Vector2.ZERO;await frames(10)
	var reached:=0;var airborne:=0;var longest_air:=0;var max_drop:=0.
	var began:=Time.get_ticks_msec()
	for target: Vector3 in snapped.slice(1):
		var success:=false
		var distance: float=Vector2(target.x-actor.global_position.x,target.z-actor.global_position.z).length()
		var budget:=maxi(120,ceili(distance/2.8*60.)+90)
		for tick in budget:
			var d: Vector3=target-actor.global_position;d.y=0.
			if d.length()<.38:success=true;break
			d=d.normalized();actor.test_move=Vector2(d.x,d.z)
			await frames(1)
			if actor.is_on_floor():airborne=0
			else:airborne+=1;longest_air=maxi(longest_air,airborne)
			max_drop=maxf(max_drop,target.y-actor.global_position.y)
		if not success:
			check(false,"Character stuck on ruin route point %d at %s toward %s"%[reached,actor.global_position,target]);break
		reached+=1
		if reached%25==0:print("INITIAL_RUIN_WALK ",reached,"/",snapped.size()-1)
	actor.test_move=Vector2.ZERO;actor.test_running=false;await frames(8);Engine.time_scale=1.
	check(reached==snapped.size()-1,"Cannot walk from the cave walkway to the summon platform")
	check(actor.is_on_floor() and longest_air<8,"Character lost ground while walking the stairs")
	report.walking={"targets":snapped.size()-1,"reached":reached,"grounded_at_end":actor.is_on_floor(),"longest_airborne_ticks":longest_air,"surface_step_events":actor.get_meta("surface_steps",0),"wall_seconds":(Time.get_ticks_msec()-began)/1000.,"max_target_height_gap_m":max_drop}

func capture(name: String) -> void:
	await frames(10);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+name+".png")==OK,"Screenshot failed: "+name)

func render_checks() -> void:
	var ruin=world.initial_ruin
	await world.select_spawn(9);await frames(12)
	world.set_free(true);world.set_review_ui_visible(false)
	world.camera.position=local_world(-48.,-46.,89.);world.camera.look_at(local_world(0,22,67.));world.camera.fov=52.
	world.vegetation.target=world.camera;world.vegetation.volume_streamer.refresh()
	for i in 500:
		await process_frame
		if world.vegetation.volume_streamer.pending_visible_count()==0:break
	await capture("ruin_exterior")
	world.camera.position=local_world(-.9,19.,63.);world.camera.look_at(ruin.avatar.global_position+Vector3.UP*.8);world.camera.fov=53.
	var site=world.initial_ruin
	site.reset_projection();site.avatar.set_process(false);site.avatar.effect.set_process(false)
	for progress: float in [0.,.5,1.]:
		site.avatar.effect.set_print_progress(progress)
		await capture("keqing_world_%03d"%roundi(progress*100.))
	site.reset_projection();site.avatar.set_process(true);site.avatar.effect.set_process(true)
	world.set_free(false);world.set_review_ui_visible(true)
	var start: Vector3=site.avatar.global_position-point(site.planting_mask.manifest.forward)*2.45
	start.y=61.05;world.character.set_spawn(start+Vector3.UP*.04,.38)
	world.character.camera.h_offset=.55
	await frames(14)
	check(site.can_interact() and site.prompt.visible,"GPU: no E prompt near pedestal")
	await capture("interaction_prompt")
	key_e();await frames(5)
	check(site.state==site.State.PRINTING,"GPU: E did not start printing")
	for i in 180:
		if site.avatar.effect.materialization_progress>=.5:break
		await frames(1)
	site.avatar.effect.playing=false
	await capture("interaction_printing")
	site.avatar.effect.playing=true
	for i in 240:
		if site.state==site.State.PRINTED:break
		await frames(1)
	check(site.state==site.State.PRINTED,"GPU: print did not complete")
	await capture("interaction_complete")
	check(world.vegetation.volume_streamer.store.last_error.is_empty(),"GPU grass cache did not open")
	check(world.vegetation.volume_streamer.store.corrupt==0,"GPU grass cache has corrupt cells")
	report.render={"adapter":RenderingServer.get_video_adapter_name(),"visible_trees":world.vegetation.tree_instance_count,"grass_reads":world.vegetation.volume_streamer.store.reads,"corrupt_cells":world.vegetation.volume_streamer.store.corrupt,"real_E_print_completed":site.state==site.State.PRINTED}

func run() -> void:
	Engine.max_fps=120
	var gpu: bool="--capture" in OS.get_cmdline_user_args()
	root.size=Vector2i(1600,1000)
	world=WORLD.instantiate();world.automation_enabled=true;world.vegetation_bake_only=not gpu;root.add_child(world)
	while not world.test_ready:await process_frame
	await frames(6)
	geometry_checks()
	if gpu:await render_checks()
	else:
		await interaction_checks()
		if failures.is_empty():await walking_check()
	check(report.has("geometry"),"Geometry verification did not finish")
	if not gpu:check(report.has("walking"),"Walking verification did not finish")
	check(report.has("render") if gpu else report.has("interaction"),"Interaction/render verification did not finish")
	report.passed=failures.is_empty();report.failures=failures
	put_json("render_report.json" if gpu else "logic_report.json",report)
	print("INITIAL_RUIN_1029_RESULT ",JSON.stringify(report))
	world.queue_free();await frames(4);quit(0 if failures.is_empty() else 1)
