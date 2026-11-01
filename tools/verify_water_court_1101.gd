extends SceneTree
const OUT="res://docs/water_court_1101/game/"
const STORE=preload("res://scripts/grass_baked_store.gd")
var world
var failures: Array[String]=[]
var report: Dictionary={}
func _initialize() -> void:call_deferred("run")
func frames(count: int) -> void:
	for i in count:await physics_frame
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func native(p: Array) -> Vector3:return Vector3(p[0]-1450.,p[2],1150.-p[1])
func ray(a: Vector3,b: Vector3,mask: int=32) -> Dictionary:
	var q:=PhysicsRayQueryParameters3D.create(a,b,mask);q.hit_back_faces=true
	q.exclude=[world.character.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(q)
func floor_at(p: Vector3) -> Dictionary:return ray(p+Vector3.UP*.4,p-Vector3.UP*.6)
func walk(points: Array,label: String) -> void:
	world.free_mode=false;world.character_mode=true;world._sync_actor_controls()
	var floor:=floor_at(points[0]);check(not floor.is_empty(),"Missing ramp start")
	if floor.is_empty():return
	world.character.set_spawn(floor.position+Vector3.UP*.04,0);world.character.test_running=true
	await frames(8)
	var target:=1;var steps:=0;var stuck:=0;var unsupported:=0
	var previous: Vector3=world.character.global_position
	while target<points.size() and steps<2200:
		var offset: Vector3=points[target]-world.character.global_position;offset.y=0
		if offset.length()<.35:target+=1;continue
		var local: Vector3=world.character.camera_pivot.global_basis.inverse()*offset.normalized()
		world.character.test_move=Vector2(local.x,local.z)
		await physics_frame;steps+=1
		if steps>5 and not world.character.is_on_floor() and floor_at(world.character.global_position).is_empty():unsupported+=1
		if world.character.global_position.distance_to(previous)<.001:stuck+=1
		else:stuck=0
		previous=world.character.global_position
		if stuck>100:break
	world.character.test_move=Vector2.ZERO;await frames(5)
	report[label]={"reached":target==points.size(),"physics_steps":steps,"unsupported_frames":unsupported,"waypoints_reached":target,"total":points.size()}
	check(target==points.size(),"Court blocks ramp: "+label);check(unsupported==0,"Fell on ramp: "+label)
func capture(name: String,eye: Vector3,target: Vector3) -> void:
	world.set_free(true);world.camera.global_position=eye;world.camera.look_at(target)
	world.vegetation.volume_streamer.refresh()
	await frames(90);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+name+".png")==OK,"Capture failed")
func run() -> void:
	create_timer(180).timeout.connect(func():push_error("Court verification timeout");quit(1))
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true
	root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	await frames(10)
	var feature=world.water_court;var manifest: Dictionary=feature.manifest
	check(feature.meshes_by_source.size()==31,"Missing court geometry")
	check(feature.geometry.find_children("*","StaticBody3D",true,false).size()==13,"Wrong court collision count")
	var max_bound_error:=0.;var glass_count:=0
	for row: Dictionary in manifest.objects:
		var mesh: MeshInstance3D=feature.meshes_by_source[row.id]
		var actual: AABB=mesh.global_transform*mesh.get_aabb()
		var lo:=Vector3(row.bounds[0][0]-1450.,row.bounds[0][2],1150.-row.bounds[1][1])
		var hi:=Vector3(row.bounds[1][0]-1450.,row.bounds[1][2],1150.-row.bounds[0][1])
		max_bound_error=maxf(max_bound_error,maxf(actual.position.distance_to(lo),actual.end.distance_to(hi)))
		if row.material_key=="glass":
			glass_count+=1
			check(mesh.material_override is ShaderMaterial,"Missing Fresnel glass")
			check(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Opaque glass shadow")
		else:
			var material:=mesh.material_override as StandardMaterial3D
			check(material!=null and absf(material.roughness-manifest.materials[row.material_key].roughness)<.001,"PBR material drift")
	check(max_bound_error<.01,"Imported native placement changed");check(glass_count==6,"Missing glass panes")
	var reflected:=0
	for record: Dictionary in world.water_manager.proxy_records:
		if record.source in feature.meshes_by_source.values():reflected+=1
	check(reflected==25,"Court missing from water reflection")
	var max_floor_error:=0.;var floor_samples:=0;var lake_bed_merges:=0;var shell_foot_joins:=0
	for row: Dictionary in manifest.probes:
		for values: Array in row.samples:
			var p: Vector3=world.vec(values);var hit:=floor_at(p)
			check(not hit.is_empty(),"Missing gallery collision")
			if not hit.is_empty():
				var exclude: Array[RID]=[world.character.get_rid()]
				if hit.collider.get_meta("source_id","")==manifest.bed_id and p.y<0. and hit.position.y>=p.y:
					# The authored broken gallery intentionally sinks into the lake bed.
					lake_bed_merges+=1
					exclude.append(hit.collider.get_rid())
				elif hit.collider.get_meta("source_id","")!=row.id:
					# The connecting deck meets the curved shell's springing foot.
					check(hit.collider.get_meta("water_court",false) and hit.position.y-p.y<=world.character.surface_step_height+.01,"Unexpected obstacle over gallery")
					shell_foot_joins+=1;exclude.append(hit.collider.get_rid())
				if exclude.size()>1:
					var q:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.4,p-Vector3.UP*.6,32)
					q.hit_back_faces=true;q.exclude=exclude
					hit=world.get_world_3d().direct_space_state.intersect_ray(q)
				check(not hit.is_empty(),"Missing submerged gallery collision")
				if not hit.is_empty():
					max_floor_error=maxf(max_floor_error,absf(hit.position.y-p.y))
					check(hit.collider.get_meta("source_id","")==row.id,"Gallery collision changed: "+str({"expected":row.id,"point":p,"hit":hit}))
			floor_samples+=1
	check(max_floor_error<.025,"Gallery floor shifted")
	var minimum_headroom:=INF;var covered:=0
	for row: Dictionary in manifest.site_check.ramp_samples:
		var p:=native(row.point);var floor:=floor_at(p)
		if not floor.is_empty():p.y=maxf(p.y,floor.position.y)
		var hit:=ray(p+Vector3.UP*.05,p+Vector3.UP*20.)
		if not hit.is_empty():minimum_headroom=minf(minimum_headroom,hit.position.y-p.y);covered+=1
	check(covered>30 and minimum_headroom>5.,"Underpass clearance failed")
	var points: Array=[];var max_ramp_error:=0.
	for values: Array in manifest.ramp_route:
		var p: Vector3=world.vec(values);points.append(p);var hit:=floor_at(p)
		check(not hit.is_empty(),"Missing original ramp/lake bed")
		if not hit.is_empty():
			max_ramp_error=maxf(max_ramp_error,absf(hit.position.y-p.y))
			check(hit.collider.get_meta("source_id","") in [manifest.ramp_id,manifest.bed_id],"Court paves over original ramp")
	check(max_ramp_error<.04,"Original ramp collision moved")
	var protected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/water_court_1101/import_protected_hashes.json"))
	for path: String in protected:check(FileAccess.get_sha256("res://"+path)==protected[path],"Protected resource changed: "+path)
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.planting_edits_path))
	for row: Dictionary in saved.trees:check(world.planting.store.all_records().get(row.id,{})==row,"User tree changed: "+str(row.id))
	check(world.vegetation.volume_streamer.store.manifest.signature==STORE.signature(world),"Grass cache invalidated")
	check(not world.review_ui_layers.has(world.initial_ruin.prompt_layer),"Gameplay prompt registered as developer UI")
	var court_spawn: Dictionary={}
	for row: Dictionary in world.resolved_spawns:
		if row.get("key","")=="water_court":court_spawn=row
	check(not court_spawn.is_empty(),"Missing court inspection entry")
	check(world.resolved_spawns[-1].key=="upper_ring","Existing upper-ring preview index changed")
	if not "--capture-only" in OS.get_cmdline_user_args():
		await walk(points,"ramp_forward");points.reverse();await walk(points,"ramp_reverse")
		var flooded:=native([555.,510.,-.59]);var floor:=floor_at(flooded)
		check(not floor.is_empty(),"Missing flooded court floor")
		if not floor.is_empty():
			world.character.set_spawn(floor.position+Vector3.UP*.04,0);await frames(30)
			check(world.character.wetness.contact,"Existing wading effect not active in court")
			report["wading_contact"]=world.character.wetness.contact
	report.merge({"passed":failures.is_empty(),"failures":failures,"actual_scene":world.scene_file_path,
		"meshes":31,"triangles":manifest.triangles,"collision_bodies":13,"glass_panes":glass_count,
		"water_reflectors":reflected,"max_bounds_error_m":max_bound_error,"gallery_floor_samples":floor_samples,"gallery_merges_into_lake_bed":lake_bed_merges,"gallery_shell_foot_joins":shell_foot_joins,
		"max_gallery_floor_error_m":max_floor_error,"minimum_headroom_m":minimum_headroom,"covered_ramp_samples":covered,
		"ramp_samples":points.size(),"max_ramp_error_m":max_ramp_error,"geometry_sha256":manifest.mesh_sha256,
		"protected_resources":protected.size(),"preserved_tree_edits":saved.trees.size(),"preserved_tree_removals":saved.removed.size()})
	if DisplayServer.get_name()!="headless":
		world.set_review_ui_visible(false)
		for name: String in ["overview","court","underpass"]:
			var prefix: String="review" if name=="overview" else name
			await capture(name,world.vec(manifest[prefix+"_eye"]),world.vec(manifest[prefix+"_target"]))
	var filename:="capture_review.json" if "--capture-only" in OS.get_cmdline_user_args() else "verification.json"
	FileAccess.open(OUT+filename,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WATER_COURT_REVIEW ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
