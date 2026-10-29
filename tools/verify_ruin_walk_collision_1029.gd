extends "res://tools/verify_initial_ruin_1029.gd"
## Require continuous grounding and walk/run animation, including downhill travel.
var cases: Array[Dictionary]=[]
func smooth_geometry_checks() -> void:
	var site=world.initial_ruin
	var bodies: Array[Node]=site.walk_geometry.find_children("*","StaticBody3D",true,false)
	check(bodies.size()==6,"Expected six imported collision-only bodies")
	check(site.walk_geometry.find_children("*","MeshInstance3D",true,false).is_empty(),"Collision helper became visible geometry")
	var replaced:=0
	for mesh: MeshInstance3D in site.geometry.find_children("*","MeshInstance3D",true,false):
		for body: StaticBody3D in mesh.get_children():
			if str(body.get_meta("source_id","")) in site.walk_manifest.replaced_actor_collision_ids:
				replaced+=1;check(body.collision_layer==1,"Raw tread still collides with actors")
	check(replaced==206,"Not all raw stair/podium colliders were replaced")
	var missing:=0;var error:=0.;var count:=0
	for item: Dictionary in site.walk_manifest.probes:
		for a: Array in item.samples:
			var p:=point(a);var hit:=ray(p+Vector3.UP*.04,p-Vector3.UP*.04)
			count+=1
			if hit.is_empty() or not hit.collider.get_meta("smooth_ruin_walk",false):missing+=1
			else:error=maxf(error,absf(hit.position.y-p.y))
	check(missing==0 and error<.003,"Smooth collision missed CAD surface samples")
	for body: StaticBody3D in bodies:
		check(body.collision_layer==32 and body.has_meta("walk_role"),"Collision layer/role missing: "+str(body.name))
	report.smooth_geometry={"collision_only_bodies":bodies.size(),"visible_helpers":0,"replaced_actor_colliders":replaced,"top_samples":count,"missing":missing,"max_height_error_m":error,"triangles":site.walk_manifest.triangles}
func snap_route(route: Array[Vector3]) -> Array[Vector3]:
	var result: Array[Vector3]=[]
	for p: Vector3 in route:
		var hit:=ray(Vector3(p.x,70.,p.z),Vector3(p.x,25.,p.z),[world.character.get_rid()])
		check(not hit.is_empty(),"No route floor at "+str(p))
		if not hit.is_empty():result.append(hit.position)
	return result
func walk_case(name: String,route: Array[Vector3],running: bool,helper: bool=false) -> void:
	var actor=world.character
	actor.surface_step_height=.18 if helper else 0.
	actor.test_move=Vector2.ZERO;actor.test_running=running
	actor.set_spawn(route[0]+Vector3.UP*.025,0.);actor.camera_pivot.rotation=Vector3.ZERO
	await frames(35)
	var reached:=0;var airborne:=0;var bad_animation:=0;var ticks:=0
	var start_steps: int=actor.get_meta("surface_steps",0);var max_delta_error:=0.
	for target: Vector3 in route.slice(1):
		var success:=false
		var distance: float=Vector2(target.x-actor.position.x,target.z-actor.position.z).length()
		var budget:=maxi(120,ceili(distance/(4.2 if running else 1.6)*60.)+120)
		for i in budget:
			var d: Vector3=target-actor.position;d.y=0.
			if d.length()<.18:success=true;break
			d=d.normalized();actor.test_move=Vector2(d.x,d.z)
			await frames(1);ticks+=1
			max_delta_error=maxf(max_delta_error,absf(actor.get_physics_process_delta_time()-1./60.))
			if not actor.is_on_floor():airborne+=1
			if actor.animation_state in ["jump_air","jump_start","jump_land"]:bad_animation+=1
		if not success:
			check(false,name+" blocked at "+str(actor.position)+" toward "+str(target));break
		reached+=1
	actor.test_move=Vector2.ZERO;await frames(2)
	var steps: int=actor.get_meta("surface_steps",0)-start_steps
	check(reached==route.size()-1,name+" incomplete")
	check(airborne==0 and bad_animation==0,name+" lost grounding/triggered falling animation")
	check(steps==0,name+" needed the stair-step helper")
	check(max_delta_error<.000001,"Test did not use gameplay 1/60 physics delta")
	var row: Dictionary={"name":name,"speed":4.2 if running else 1.6,"helper_enabled":helper,"targets":route.size()-1,"reached":reached,"airborne_ticks":airborne,"fall_or_land_animation_ticks":bad_animation,"step_helper_events":steps,"physics_ticks":ticks,"physics_delta_error":max_delta_error}
	cases.append(row);print("SMOOTH_WALK_CASE ",JSON.stringify(row))
	actor.surface_step_height=.18
func all_walks() -> void:
	world.initial_ruin.reset_projection();await frames(3)
	var routes: Dictionary={"whole_approach_and_entry":snap_route(route_points())}
	for key: String in ["entry_1","entry_2","internal_1","internal_2","dais"]:
		var path: Array[Vector3]=[]
		for a: Array in world.initial_ruin.walk_manifest.routes[key]:path.append(point(a))
		routes[key]=snap_route(path)
	for key: String in routes:
		for running: bool in [false,true]:
			await walk_case(key+"_up_"+("run" if running else "walk"),routes[key],running)
			var reverse: Array[Vector3]=routes[key].duplicate();reverse.reverse()
			await walk_case(key+"_down_"+("run" if running else "walk"),reverse,running)
	# Also exercise the shipped settings, with the useful small-obstacle helper enabled.
	await walk_case("formal_settings_full_route",routes.whole_approach_and_entry,true,true)
	report.walking={"cases":cases,"all_require_zero_airborne_and_zero_fall_animation":true}
func capture_stairs() -> void:
	var site=world.initial_ruin;site.reset_projection();await frames(3)
	world.set_free(false);world.set_review_ui_visible(false)
	var actor=world.character
	actor.set_spawn(local_world(0,-28.5,55.08),.380506);actor.test_move=Vector2.ZERO;actor.test_running=false
	await frames(35);actor.test_move=Vector2(0,-1)
	for i in 160:
		await frames(1)
		if actor.position.y>56.15:break
	actor.test_move=Vector2.ZERO;await frames(3)
	check(actor.is_on_floor() and not actor.animation_state.begins_with("jump"),"GPU stair preview is airborne")
	await capture("smooth_stairs_gameplay")
	var overlay:=Node3D.new();world.add_child(overlay)
	var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color=Color(.12,1.,.35,.32);material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	for body: StaticBody3D in site.walk_geometry.find_children("*","StaticBody3D",true,false):
		if str(body.get_meta("walk_role",""))!="entry_1":continue
		for shape: CollisionShape3D in body.find_children("*","CollisionShape3D",true,false):
			var mesh:=ArrayMesh.new();var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=shape.shape.get_faces();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			overlay.add_child(node);node.global_transform=shape.global_transform
	await capture("smooth_stairs_collision_overlay")
	overlay.queue_free();world.set_review_ui_visible(true)
	report.stair_capture={"grounded":actor.is_on_floor(),"animation":actor.animation_state,"position":[actor.position.x,actor.position.y,actor.position.z]}
func run() -> void:
	var gpu: bool="--capture" in OS.get_cmdline_user_args()
	Engine.max_fps=120 if gpu else 0;root.size=Vector2i(1600,1000)
	world=WORLD.instantiate();world.automation_enabled=true;world.vegetation_bake_only=not gpu;root.add_child(world)
	while not world.test_ready:await process_frame
	await frames(8);geometry_checks();smooth_geometry_checks()
	if failures.is_empty():
		if gpu:
			if not "--stairs-only-capture" in OS.get_cmdline_user_args():await render_checks()
			else:report.render={"adapter":RenderingServer.get_video_adapter_name(),"stairs_only":true}
			await capture_stairs()
		else:
			await interaction_checks();await all_walks()
	check(report.has("render") if gpu else report.has("walking"),"Verification did not finish")
	if gpu:check(report.has("stair_capture"),"GPU stair capture did not finish")
	report.passed=failures.is_empty();report.failures=failures
	put_json("smooth_stair_capture.json" if "--stairs-only-capture" in OS.get_cmdline_user_args() else ("smooth_collision_render.json" if gpu else "smooth_collision_logic.json"),report)
	print("RUIN_SMOOTH_COLLISION_RESULT ",JSON.stringify(report))
	world.queue_free();await frames(4);quit(0 if failures.is_empty() else 1)
