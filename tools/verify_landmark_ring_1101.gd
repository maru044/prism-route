extends SceneTree
const OUT="res://docs/landmark_ring_1101/game/"
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
func ray(p: Vector3) -> Dictionary:
	var q:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.3,p-Vector3.UP*.4,32)
	q.hit_back_faces=true;q.exclude=[world.character.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(q)
func walk(points: Array,label: String) -> void:
	world.free_mode=false;world.character_mode=true;world._sync_actor_controls()
	var floor:=ray(points[0]);check(not floor.is_empty(),"Missing crossing deck")
	if floor.is_empty():return
	world.character.set_spawn(floor.position+Vector3.UP*.04,0);world.character.test_running=true
	await frames(8)
	var target:=1;var steps:=0;var stuck:=0;var unsupported:=0;var previous: Vector3=world.character.global_position
	while target<points.size() and steps<2400:
		var offset: Vector3=points[target]-world.character.global_position;offset.y=0
		if offset.length()<.35:target+=1;continue
		var local: Vector3=world.character.camera_pivot.global_basis.inverse()*offset.normalized()
		world.character.test_move=Vector2(local.x,local.z)
		await physics_frame;steps+=1
		if steps>5 and not world.character.is_on_floor() and ray(world.character.global_position).is_empty():unsupported+=1
		if world.character.global_position.distance_to(previous)<.001:stuck+=1
		else:stuck=0
		previous=world.character.global_position
		if stuck>100:break
	world.character.test_move=Vector2.ZERO;await frames(4)
	report[label]={"reached":target==points.size(),"physics_steps":steps,"unsupported_frames":unsupported,"waypoints_reached":target,"total":points.size()}
	check(target==points.size(),"Ring obstructs the bridge: "+label);check(unsupported==0,"Fell on bridge: "+label)
func capture(name: String,eye: Vector3,target: Vector3) -> void:
	world.set_free(true);world.camera.global_position=eye;world.camera.look_at(target)
	world.vegetation.volume_streamer.refresh()
	await frames(110);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+name+".png")==OK,"Capture failed")
func run() -> void:
	create_timer(180).timeout.connect(func():push_error("Ring verification timeout");quit(1))
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true
	root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	await frames(10)
	var feature=world.landmark_ring
	check(feature.meshes_by_source.size()==7,"Missing ring geometry")
	check(feature.geometry.find_children("*","StaticBody3D",true,false).size()==3,"Wrong ring collision count")
	var max_bound_error:=0.
	for row: Dictionary in feature.manifest.objects:
		var mesh: MeshInstance3D=feature.meshes_by_source[row.id]
		check(mesh.material_override==world.island_saddle.materials[row.material_key],"Material is not shared with the original truss")
		var actual: AABB=mesh.global_transform*mesh.get_aabb()
		var lo:=Vector3(row.bounds[0][0]-1450.,row.bounds[0][2],1150.-row.bounds[1][1])
		var hi:=Vector3(row.bounds[1][0]-1450.,row.bounds[1][2],1150.-row.bounds[0][1])
		max_bound_error=maxf(max_bound_error,maxf(actual.position.distance_to(lo),actual.end.distance_to(hi)))
	check(max_bound_error<.03,"Imported ring placement changed")
	var grounded_samples:=0;var minimum_embed:=INF
	if feature.manifest.parameters.has("ground_extension_report"):
		var extension: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/landmark_ring_1101/"+str(feature.manifest.parameters.ground_extension_report)))
		for cap: String in ["new_start_samples","new_end_samples"]:
			for row: Dictionary in extension[cap]:
				var p:=native(row.point);var y: float=row.ground_z
				var q:=PhysicsRayQueryParameters3D.create(Vector3(p.x,y+.5,p.z),Vector3(p.x,y-.5,p.z),16)
				q.hit_back_faces=true
				var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(q)
				check(not hit.is_empty(),"No runtime ground at extended cap")
				if not hit.is_empty():minimum_embed=minf(minimum_embed,hit.position.y-p.y)
				grounded_samples+=1
		check(minimum_embed>.25,"Extended ring cap floats above runtime ground")
	var protected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/landmark_ring_1101/import_protected_hashes.json"))
	for path: String in protected:check(FileAccess.get_sha256("res://"+path)==protected[path],"Protected resource changed: "+path)
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.planting_edits_path))
	for row: Dictionary in saved.trees:check(world.planting.store.all_records().get(row.id,{})==row,"User tree changed: "+str(row.id))
	check(world.vegetation.volume_streamer.store.manifest.signature==STORE.signature(world),"Grass cache invalidated")
	check(not world.review_ui_layers.has(world.initial_ruin.prompt_layer),"Gameplay prompt is registered as developer UI")
	var points: Array=[];var max_deck_error:=0.
	for values: Array in feature.manifest.bridge_crossing_route:
		var p: Vector3=world.vec(values);points.append(p);var hit:=ray(p)
		check(not hit.is_empty(),"Missing bridge collision under hoop")
		if not hit.is_empty():
			max_deck_error=maxf(max_deck_error,absf(hit.position.y-p.y))
			check(hit.collider.get_meta("source_id","")=="0808d32c-6ebc-4105-9258-a0f755ac2752","Ring covers the original deck")
	check(max_deck_error<.04,"Crossing deck shifted")
	if not "--capture-only" in OS.get_cmdline_user_args():
		await walk(points,"bridge_forward");points.reverse();await walk(points,"bridge_reverse")
	report.merge({"passed":failures.is_empty(),"failures":failures,"meshes":7,"triangles":feature.manifest.triangles,"collision_bodies":3,
		"shared_materials":true,"max_bounds_error_m":max_bound_error,"bridge_samples":points.size(),"max_deck_error_m":max_deck_error,
		"preserved_tree_edits":saved.trees.size(),"preserved_tree_removals":saved.removed.size(),"protected_resources":protected.size(),"actual_scene":world.scene_file_path,
		"geometry_sha256":feature.manifest.mesh_sha256,"ring_center_native":feature.manifest.parameters.center_native,
		"grounded_cap_samples":grounded_samples,"minimum_runtime_embed_m":minimum_embed if grounded_samples>0 else 0.})
	if DisplayServer.get_name()!="headless":
		world.set_review_ui_visible(false);world.character.visible=false
		await capture("spawn_view",world.vec(feature.manifest.spawn_eye),world.vec(feature.manifest.spawn_target))
		await capture("ring_and_saddle",world.vec(feature.manifest.review_eye),world.vec(feature.manifest.review_target))
		await capture("site_view",world.vec(feature.manifest.site_eye),world.vec(feature.manifest.site_target))
	var filename:="capture_review.json" if "--capture-only" in OS.get_cmdline_user_args() else "verification.json"
	FileAccess.open(OUT+filename,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("LANDMARK_RING_REVIEW ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
