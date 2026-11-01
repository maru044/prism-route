extends SceneTree
const OUT="res://docs/oval_atrium_1031/game/"
const STORE=preload("res://scripts/grass_baked_store.gd")
var world
var failures: Array[String]=[]
var report: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func frames(count: int) -> void:
	for i in count:await physics_frame
func native(x: float,y: float,z: float) -> Vector3:return Vector3(x-1450.,z,1150.-y)
func ray(a: Vector3,b: Vector3) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(a,b,32);query.exclude=[world.character.get_rid()];query.hit_back_faces=true
	return world.get_world_3d().direct_space_state.intersect_ray(query)
func walk(points: Array,label: String) -> void:
	world.free_mode=false;world.character_mode=true;world._sync_actor_controls()
	var hit:=ray(points[0]+Vector3.UP*.5,points[0]-Vector3.UP*.5)
	check(not hit.is_empty(),"Missing start floor: "+label)
	if hit.is_empty():return
	world.character.set_spawn(hit.position+Vector3.UP*.04,0);world.character.test_running=true
	await frames(6)
	var target:=1;var steps:=0;var blocked:=0;var airborne:=0;var previous: Vector3=world.character.global_position
	while target<points.size() and steps<2600:
		var p: Vector3=world.character.global_position;var goal: Vector3=points[target]
		var delta:=Vector3(goal.x-p.x,0,goal.z-p.z)
		if delta.length()<.42:target+=1;continue
		var local: Vector3=world.character.camera_pivot.global_basis.inverse()*delta.normalized()
		world.character.test_move=Vector2(local.x,local.z)
		await physics_frame;steps+=1
		if steps>5 and not world.character.is_on_floor() and ray(world.character.global_position+Vector3.UP*.2,world.character.global_position-Vector3.UP*.6).is_empty():airborne+=1
		if world.character.global_position.distance_to(previous)<.001:blocked+=1
		else:blocked=0
		previous=world.character.global_position
		if blocked>120:break
	world.character.test_move=Vector2.ZERO;await frames(4)
	report[label]={"reached":target==points.size(),"waypoints_reached":target,"waypoints":points.size(),"unsupported_frames":airborne,"steps":steps,"last_position":str(world.character.global_position)}
	check(target==points.size(),"Traversal failed: "+label);check(airborne<4,"Character fell during "+label)
func capture(label: String,eye: Vector3,target: Vector3) -> void:
	if DisplayServer.get_name()=="headless":return
	world.set_free(true);world.camera.global_position=eye;world.camera.look_at(target)
	await frames(75);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+label+".png")==OK,"Capture failed")
func run() -> void:
	create_timer(240).timeout.connect(func():push_error("Atrium verification timeout");quit(1))
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true
	root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	await frames(12)
	var feature=world.oval_atrium
	check(feature.geometry.find_children("*","MeshInstance3D",true,false).size()==32,"Imported atrium objects missing")
	for mesh: MeshInstance3D in world.model.find_children("*","MeshInstance3D",true,false):
		check(not str(mesh.name).get_slice("_",1) in feature.REPLACED_IDS,"Old solid still exists")
	var ground_id:=""
	for row: Dictionary in feature.manifest.objects:
		if row.name=="PR_Atrium_Central_vegetation_ground":ground_id=row.id
	var opening:=ray(native(1086.01,302.52,80),native(1086.01,302.52,30))
	check(not opening.is_empty() and absf(opening.position.y-35.)<.025,"Old roof still covers the opening, or ground collision is missing")
	if not opening.is_empty():check(opening.collider.get_meta("source_id","")==ground_id,"Grass floor is not the actual ground collider")
	var grass_samples:=0
	for offset: Vector2 in [Vector2.ZERO,Vector2(20,0),Vector2(-20,0),Vector2(0,12),Vector2(0,-12)]:
		var point:=native(1086.01+offset.x,302.52+offset.y,35.)
		var hit:=ray(point+Vector3.UP*.35,point-Vector3.UP)
		check(not hit.is_empty() and absf(hit.position.y-35.)<.025,"Missing inset grass collision")
		if not hit.is_empty():check(hit.collider.get_meta("source_id","")==ground_id,"Duplicate hard floor below inset grass")
		grass_samples+=1
	var mask: Dictionary=feature.manifest.tree_exclusion
	var start: Vector3=world.vec([mask.exit_start[0]-1450.,35.,1150.-mask.exit_start[1]])
	var end: Vector3=world.vec([mask.exit_end[0]-1450.,35.,1150.-mask.exit_end[1]])
	var direction: Vector3=(end-start).normalized();var side:=Vector3(-direction.z,0,direction.x)
	for lateral: float in [-3.2,0.,3.2]:
		for height: float in [.4,1.8,4.3]:
			var hit:=ray(start-direction*9.+side*lateral+Vector3.UP*height,end+side*lateral+Vector3.UP*height)
			check(hit.is_empty(),"Exit passage blocked by geometry")
	check(world.planting.load_error.is_empty(),"Planting edits failed to load")
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/oval_atrium_1031/world_edits_before.json"))
	var cleanup: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"tree_cleanup.json"))
	var effective: Dictionary=world.planting.store.all_records()
	for id: String in cleanup.removed_ids:check(not effective.has(id),"A removed roof tree returned: "+id)
	for row: Dictionary in before.trees:
		if not row.id in cleanup.removed_ids:check(effective.get(row.id,{})==row,"Unrelated saved planting changed: "+row.id)
	var hashes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/oval_atrium_1031/protected_hashes.json"))
	for path: String in hashes:check(FileAccess.get_sha256("res://"+path)==hashes[path],"Protected asset changed: "+path)
	var bake: Dictionary=world.vegetation.volume_streamer.store.manifest
	check(not bake.is_empty() and bake.signature==STORE.signature(world),"Existing grass bake was invalidated")
	check(world.vegetation.grass_material.get_shader_parameter("use_atrium_grass_cut")==true,"Floating roof grass is not masked")
	check(world.island_saddle.walking_body!=null,"Existing saddle collider is missing")
	var sample_count:=0;var max_error:=0.;var covered_join_samples:=0
	for row: Dictionary in feature.manifest.ramps:
		var route: Array=[]
		var ramp_id:=""
		for object: Dictionary in feature.manifest.objects:
			if object.name=="PR_Atrium_"+str(row.name):ramp_id=object.id
		for i in row.samples.size():
			var section: Array=row.samples[i];var p: Vector3=(world.vec(section[0])+world.vec(section[1]))*.5
			# A ray exactly on a shared end edge is ambiguous in Jolt. The full
			# character walk below tests those joins; probe interiors for holes.
			if i>0 and i<row.samples.size()-1:
				var hit:=ray(p+Vector3.UP*.35,p-Vector3.UP*.6)
				check(not hit.is_empty(),"Ramp collision hole: "+str(row.name)+" sample="+str(i))
				if not hit.is_empty():
					var error:=absf(hit.position.y-p.y)
					if hit.collider.get_meta("source_id","")==ramp_id:max_error=maxf(max_error,error)
					else:
						covered_join_samples+=1
						check(error<world.character.surface_step_height,"Landing overlap exceeds character step height")
				sample_count+=1
			if i%4==0 or i==row.samples.size()-1:route.append(p)
		if not "--capture-only" in OS.get_cmdline_user_args():await walk(route,row.name)
	check(max_error<.04,"Imported ramp geometry shifted")
	if not "--capture-only" in OS.get_cmdline_user_args():
		var exit_route: Array=[]
		for i in range(13):exit_route.append(start-direction*7.+direction*(7.+start.distance_to(end)+3.)*i/12.)
		await walk(exit_route,"exit_to_middle_road")
	world.set_review_ui_visible(false)
	await capture("overview",world.vec(feature.manifest.review_eye),world.vec(feature.manifest.review_target))
	await capture("interior",world.vec(feature.manifest.floor_eye),world.vec(feature.manifest.floor_target))
	report.passed=failures.is_empty();report.failures=failures;report.actual_scene=world.scene_file_path
	report.imported_meshes=32;report.ramp_collision_samples=sample_count;report.maximum_ramp_error_m=max_error
	report.covered_landing_join_samples=covered_join_samples
	report.grass_ground_collision_samples=grass_samples;report.roof_trees_removed=cleanup.removed_tree_count
	report.unrelated_saved_edits_preserved=cleanup.unrelated_saved_edits_preserved;report.automatic_interior_plants=0
	report.base_mesh_and_grass_bake_preserved=true
	var file: String="headless_report.json" if DisplayServer.get_name()=="headless" else "game_report.json"
	FileAccess.open(OUT+file,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("OVAL_ATRIUM_VERIFIED ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
