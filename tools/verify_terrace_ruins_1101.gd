extends SceneTree
const OUT="res://docs/terrace_open_ruins_concepts_1101/game/"
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
func ray(p: Vector3) -> Dictionary:
	var q:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.22,p-Vector3.UP*.4,32)
	q.exclude=[world.character.get_rid()];q.hit_back_faces=true
	return world.get_world_3d().direct_space_state.intersect_ray(q)
func walk(points: Array,label: String) -> void:
	world.free_mode=false;world.character_mode=true;world._sync_actor_controls()
	var hit:=ray(points[0]);check(not hit.is_empty(),"No starting floor: "+label)
	if hit.is_empty():return
	world.character.set_spawn(hit.position+Vector3.UP*.04,0);world.character.test_running=true
	await frames(8)
	var target:=1;var steps:=0;var blocked:=0;var unsupported:=0;var previous: Vector3=world.character.global_position
	while target<points.size() and steps<3500:
		var delta: Vector3=points[target]-world.character.global_position;delta.y=0
		if delta.length()<.34:target+=1;continue
		var local: Vector3=world.character.camera_pivot.global_basis.inverse()*delta.normalized()
		world.character.test_move=Vector2(local.x,local.z)
		await physics_frame;steps+=1
		if steps>6 and not world.character.is_on_floor() and ray(world.character.global_position).is_empty():unsupported+=1
		if world.character.global_position.distance_to(previous)<.001:blocked+=1
		else:blocked=0
		previous=world.character.global_position
		if blocked>100:break
	world.character.test_move=Vector2.ZERO;await frames(4)
	report[label]={"reached":target==points.size(),"waypoints":target,"total":points.size(),"unsupported_frames":unsupported,"physics_steps":steps,"last_position":str(world.character.global_position)}
	check(target==points.size(),"Cannot traverse "+label);check(unsupported<4,"Falling on "+label)
func capture(label: String,eye: Vector3,target: Vector3) -> void:
	world.set_free(true);world.camera.global_position=eye;world.camera.look_at(target)
	world.vegetation.volume_streamer.refresh()
	await frames(100);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+label+".png")==OK,"Capture failed")
func run() -> void:
	create_timer(180).timeout.connect(func():push_error("Terrace review timeout");quit(1))
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true
	root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	await frames(12)
	var feature=world.terrace_ruins
	check(feature.meshes_by_source.size()==31,"Missing imported geometry")
	check(feature.geometry.find_children("*","StaticBody3D",true,false).size()==18,"Missing structure collision")
	for row: Dictionary in feature.manifest.spawns:
		var resolved: Array=world.resolved_spawns.filter(func(p):return p.get("key","")==row.key)
		check(resolved.size()==1 and resolved[0].get("floor_source","")==row.source_id,"Wrong entry floor: "+str(row.key))
	var hashes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/terrace_ruins_1101/import_protected_hashes.json"))
	for path: String in hashes:check(FileAccess.get_sha256("res://"+path)==hashes[path],"Protected asset changed: "+path)
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.planting_edits_path))
	for row: Dictionary in saved.trees:check(world.planting.store.all_records().get(row.id,{})==row,"User tree changed: "+str(row.id))
	var bake: Dictionary=world.vegetation.volume_streamer.store.manifest
	check(not bake.is_empty() and bake.signature==STORE.signature(world),"Existing grass bake invalidated")
	check(world.vegetation.grass_material.get_shader_parameter("use_terrace_grass_cut")==true,"Deck grass mask not bound")
	check(feature.blocks_grass(native(1847.5,160,95.18)),"Deck grass not cut")
	check(not feature.blocks_grass(native(1843.,159.6,95.)),"Planting pocket wrongly cut")
	check(not feature.blocks_grass(native(1847.5,160,35.)),"Lower storey wrongly cut")
	var probes:=0;var max_error:=0.
	for row: Dictionary in feature.manifest.probes:
		for values: Array in row.samples:
			var p: Vector3=world.vec(values);var hit:=ray(p)
			check(not hit.is_empty(),"Floor collision hole: "+str(row.name))
			if not hit.is_empty():
				max_error=maxf(max_error,absf(hit.position.y-p.y))
				check(hit.collider.get_meta("source_id","")==row.id,"Incorrect floor source: "+str(row.name))
			probes+=1
	check(max_error<.04,"Imported floor shifted")
	if not "--capture-only" in OS.get_cmdline_user_args():
		for name: String in feature.manifest.routes:
			var points: Array=[];var route: Array=feature.manifest.routes[name]
			for i in route.size():
				if i%8==0 or i==route.size()-1:points.append(world.vec(route[i]))
			await walk(points,name+"_forward");points.reverse();await walk(points,name+"_reverse")
		await walk([native(1844,146.2,95.18),native(1847.2,151,95.18),native(1847.2,168,95.18),native(1844,173.8,95.18)],"main_deck")
	report.merge({"passed":failures.is_empty(),"failures":failures,"collision_probes":probes,"max_collision_error_m":max_error,"meshes":31,"collision_bodies":18,
		"saved_tree_edits_preserved":saved.trees.size(),"global_grass_bake_preserved":true,"actual_scene":world.scene_file_path})
	if DisplayServer.get_name()!="headless":
		world.set_review_ui_visible(false)
		world.character.set_spawn(native(1847.5,160,95.22),0)
		await capture("main_group",world.vec(feature.manifest.detail_eye),world.vec(feature.manifest.detail_target))
		world.character.set_spawn(native(1862.1,233,92.36),0)
		await capture("secondary_group",native(1884,217,103),native(1860,235,93.7))
		await capture("both_groups",world.vec(feature.manifest.review_eye),world.vec(feature.manifest.review_target))
	var filename:="capture_review.json" if "--capture-only" in OS.get_cmdline_user_args() else "verification.json"
	FileAccess.open(OUT+filename,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TERRACE_RUINS_REVIEW ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
