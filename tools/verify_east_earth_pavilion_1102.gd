extends SceneTree
const OUT="res://docs/east_earth_pavilion_1102/game/"
const STORE=preload("res://scripts/grass_baked_store.gd")
var world
var failures: Array[String]=[]
var report: Dictionary={}
func _initialize() -> void:call_deferred("run")
func frames(count: int) -> void:
	for i in count:await physics_frame
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func ray(a: Vector3,b: Vector3,mask: int=32) -> Dictionary:
	var q:=PhysicsRayQueryParameters3D.create(a,b,mask);q.hit_back_faces=true
	q.exclude=[world.character.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(q)
func floor_at(p: Vector3) -> Dictionary:return ray(p+Vector3.UP*.4,p-Vector3.UP*.6)
func walk(points: Array,label: String) -> void:
	world.free_mode=false;world.character_mode=true;world._sync_actor_controls()
	var floor:=floor_at(points[0]);check(not floor.is_empty(),"Missing route start: "+label)
	if floor.is_empty():return
	world.character.set_spawn(floor.position+Vector3.UP*.04,0);world.character.test_running=true
	await frames(8)
	var target:=1;var steps:=0;var stuck:=0;var unsupported:=0
	var previous: Vector3=world.character.global_position
	while target<points.size() and steps<5000:
		var offset: Vector3=points[target]-world.character.global_position;offset.y=0
		if offset.length()<.32:target+=1;continue
		var local: Vector3=world.character.camera_pivot.global_basis.inverse()*offset.normalized()
		world.character.test_move=Vector2(local.x,local.z)
		await physics_frame;steps+=1
		if steps>5 and not world.character.is_on_floor() and floor_at(world.character.global_position).is_empty():unsupported+=1
		if world.character.global_position.distance_to(previous)<.001:stuck+=1
		else:stuck=0
		previous=world.character.global_position
		if stuck>100:break
	world.character.test_move=Vector2.ZERO;await frames(5)
	report[label]={"reached":target==points.size(),"physics_steps":steps,"unsupported_frames":unsupported,"waypoints_reached":target,"total":points.size(),"final_position":str(world.character.global_position)}
	check(target==points.size(),"Blocked route: "+label);check(unsupported==0,"Unsupported route: "+label)
func capture(name: String,eye: Vector3,target: Vector3) -> void:
	world.set_free(true);world.camera.global_position=eye;world.camera.look_at(target)
	world.vegetation.volume_streamer.refresh()
	await frames(90);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+name+".png")==OK,"Capture failed")
func run() -> void:
	create_timer(240).timeout.connect(func():push_error("Pavilion verification timeout");quit(1))
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true
	root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	await frames(10)
	var feature=world.earth_pavilion;var manifest: Dictionary=feature.manifest
	check(feature.meshes_by_source.size()==89,"Missing reviewed pavilion geometry")
	check(feature.geometry.find_children("*","StaticBody3D",true,false).size()==47,"Wrong collision count")
	var bounds_error:=0.;var glass_count:=0;var terrain_count:=0
	for row: Dictionary in manifest.objects:
		var mesh: MeshInstance3D=feature.meshes_by_source[row.id]
		var actual: AABB=mesh.global_transform*mesh.get_aabb()
		var lo:=Vector3(row.bounds[0][0]-1450.,row.bounds[0][2],1150.-row.bounds[1][1])
		var hi:=Vector3(row.bounds[1][0]-1450.,row.bounds[1][2],1150.-row.bounds[0][1])
		bounds_error=maxf(bounds_error,maxf(actual.position.distance_to(lo),actual.end.distance_to(hi)))
		if row.material_key=="glass":
			glass_count+=1;check(mesh.material_override is ShaderMaterial,"Missing Fresnel glass")
			check(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Opaque glass shadow")
		elif row.material_key=="grass":
			terrain_count+=1
			check(mesh.material_override.get_shader_parameter("force_green_meadow"),"Turf palette not green")
		else:
			var material:=mesh.material_override as StandardMaterial3D
			check(material!=null and absf(material.roughness-manifest.materials[row.material_key].roughness)<.001,"PBR material drift")
	check(bounds_error<.01,"Native placement changed");check(glass_count==28 and terrain_count==7,"Material inventory changed")
	for mesh: MeshInstance3D in world.model.find_children("*","MeshInstance3D",true,false):
		check(not str(mesh.name).contains(feature.REPLACED_IDS[0]),"Old uncut hill still present")
	var reflected:=0
	for record: Dictionary in world.water_manager.proxy_records:
		if record.source in feature.meshes_by_source.values():reflected+=1
	check(reflected==61,"Pavilion missing from water reflection")
	var max_floor_error:=0.;var minimum_headroom:=INF;var samples:=0
	for label: String in manifest.routes:
		var route: Array=[]
		for values: Array in manifest.routes[label]:
			var p: Vector3=world.vec(values);route.append(p);var hit:=floor_at(p)
			check(not hit.is_empty(),"Missing floor on "+label+": "+str(p))
			if not hit.is_empty():
				max_floor_error=maxf(max_floor_error,absf(hit.position.y-p.y))
				var above:=ray(hit.position+Vector3.UP*.06,hit.position+Vector3.UP*5.)
				if not above.is_empty():minimum_headroom=minf(minimum_headroom,above.position.y-hit.position.y)
			samples+=1
		if not "--capture-only" in OS.get_cmdline_user_args():
			await walk(route,label+"_forward");route.reverse();await walk(route,label+"_reverse")
	check(max_floor_error<.06,"Imported floor geometry shifted")
	check(minimum_headroom>2.2,"Interior obstructed by old terrain or structure")
	var protected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/east_earth_pavilion_1102/import_protected_hashes.json"))
	for path: String in protected:check(FileAccess.get_sha256("res://"+path)==protected[path],"Protected resource changed: "+path)
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.planting_edits_path))
	for row: Dictionary in saved.trees:check(world.planting.store.all_records().get(row.id,{})==row,"User tree changed: "+str(row.id))
	check(world.vegetation.volume_streamer.store.manifest.signature==STORE.signature(world),"Global grass bake invalidated")
	check(not world.review_ui_layers.has(world.initial_ruin.prompt_layer),"Gameplay prompt registered as developer UI")
	check(world.resolved_spawns[-1].key=="upper_ring","Existing upper-ring preview index changed")
	var spawn_found:=false
	for row: Dictionary in world.resolved_spawns:
		if row.get("key","")=="earth_pavilion":spawn_found=true
	check(spawn_found,"Missing direct inspection entry")
	var middle: Vector3=world.vec(manifest.routes.hall[-1])
	check(feature.blocks_grass(middle+Vector3.UP*12.),"Obsolete roots remain above excavated court")
	check(manifest.grass_support.outside_samples>0,"Grass cut lost its local footprint")
	var support: Dictionary=manifest.grass_support
	var outside_point:=Vector3(support.origin_xz[0]+.1,62.,support.origin_xz[1]+.1)
	check(not feature.blocks_grass(outside_point),"Grass cut leaks outside the excavation")
	report.merge({"passed":failures.is_empty(),"failures":failures,"actual_scene":world.scene_file_path,"meshes":89,
		"triangles":manifest.triangles,"collision_bodies":47,"glass_panes":glass_count,"terrain_surfaces":terrain_count,
		"water_reflectors":reflected,"max_bounds_error_m":bounds_error,"floor_samples":samples,
		"max_floor_error_m":max_floor_error,"minimum_headroom_below_5m":minimum_headroom if is_finite(minimum_headroom) else "none",
		"protected_resources":protected.size(),"preserved_tree_edits":saved.trees.size(),"preserved_tree_removals":saved.removed.size(),"geometry_sha256":manifest.mesh_sha256})
	if DisplayServer.get_name()!="headless":
		world.set_review_ui_visible(false)
		for name: String in ["overview","court","entry"]:
			var prefix: String="review" if name=="overview" else name
			await capture(name,world.vec(manifest[prefix+"_eye"]),world.vec(manifest[prefix+"_target"]))
	var filename:="capture_review.json" if "--capture-only" in OS.get_cmdline_user_args() else "verification.json"
	FileAccess.open(OUT+filename,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("EARTH_PAVILION_REVIEW ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
