extends SceneTree
const STORE=preload("res://scripts/grass_baked_store.gd")
const OUT="res://docs/upper_ring_pavilion_1030/game/"
var world
var failures: Array[String]=[]
var report: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value:failures.append(message);push_error(message)
func frames(n: int) -> void:
	for i in n:await physics_frame
func capture(name: String,eye: Vector3,target: Vector3) -> void:
	world.set_free(true);world.camera.global_position=eye;world.camera.look_at(target)
	for i in 90:
		await physics_frame
		if world.vegetation.volume_streamer.pending_visible_count()==0 and i>20:break
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+name+".png")==OK,"Capture failed: "+name)
func floor_at(p: Vector3) -> Vector3:
	var q:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*2,p-Vector3.UP*4,32)
	q.exclude=[world.character.get_rid()];q.hit_back_faces=true
	var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(q)
	check(not hit.is_empty(),"Missing approach ground")
	return p if hit.is_empty() else hit.position
func walk(a: Vector3,b: Vector3,label: String) -> void:
	world.free_mode=false;world.character_mode=true;world._sync_actor_controls()
	world.character.set_spawn(floor_at(a)+Vector3.UP*.04,0)
	world.character.test_running=true;await frames(16)
	var start: Vector3=world.character.global_position
	var unsupported:=0;var reached:=false
	for i in 1050:
		var p: Vector3=world.character.global_position
		var offset:=Vector3(b.x-p.x,0,b.z-p.z)
		if offset.length()<.6:reached=true;break
		var direction: Vector3=world.character.camera_pivot.global_basis.inverse()*offset.normalized()
		world.character.test_move=Vector2(direction.x,direction.z)
		await physics_frame
		if i>5 and not world.character.is_on_floor():
			var q:=PhysicsRayQueryParameters3D.create(world.character.global_position+Vector3.UP*.1,world.character.global_position-Vector3.UP*.4,32)
			q.exclude=[world.character.get_rid()]
			if world.get_world_3d().direct_space_state.intersect_ray(q).is_empty():unsupported+=1
	world.character.test_move=Vector2.ZERO;await frames(12)
	check(reached,"Could not traverse "+label);check(unsupported<4,"Unsupported falling on "+label)
	report[label]={"reached":reached,"unsupported_frames":unsupported,"distance":Vector2(world.character.global_position.x-start.x,world.character.global_position.z-start.z).length()}
func run() -> void:
	create_timer(220).timeout.connect(func():push_error("Upper ring verification timed out");quit(1))
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true
	root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	await frames(8)
	var ring=world.upper_ring;var mask=ring.planting_mask
	check(world.scene_file_path=="res://scenes/map_1021.tscn","Wrong review entry")
	check(ring.geometry.find_children("*","MeshInstance3D",true,false).size()==539,"CAD objects missing")
	check(ring.tree_records.size()==4,"Wrong courtyard tree count")
	var tree_report: Array=[]
	for i in ring.tree_records.size():
		var row: Dictionary=ring.tree_records[i];var p: Vector3=row.position
		var polygon:=PackedVector2Array()
		for v: Array in ring.manifest.planting_beds[int(row.bed)]:polygon.append(Vector2(v[0],v[1]))
		check(Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon),"Tree is outside its planter: "+row.name)
		var nodes: Array=ring.tree_nodes[i].find_children("*","MultiMeshInstance3D",true,false)
		var leaf: MultiMeshInstance3D
		for node: MultiMeshInstance3D in nodes:
			if "LOD0_Leaves" in str(node.name):leaf=node;break
		check(leaf!=null,"Missing production crown: "+row.name)
		var transform: Transform3D=leaf.multimesh.get_instance_transform(0)
		check(absf(transform.basis.x.length()-float(row.scale))<.001,"Tree visual scale differs from requested: "+row.name)
		if i==0:check(is_equal_approx(float(row.scale),1.5),"Hero is not 1.5x")
		var crown: AABB=transform*leaf.multimesh.mesh.get_aabb()
		var inside_court:=true
		for j in 8:
			var corner:=crown.get_endpoint(j)
			if Vector2(corner.x,corner.z).distance_to(mask.center)>37.6:inside_court=false
		check(inside_court,"Tree crown intersects the ring roof footprint: "+row.name)
		var q:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.2,p-Vector3.UP*.2,1)
		q.hit_back_faces=true
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(q)
		check(not hit.is_empty() and absf(hit.position.y-p.y)<.02,"Tree root is not on planter soil: "+row.name)
		tree_report.append({"name":row.name,"scale":row.scale,"position":str(p),"crown_height":crown.size.y,"inside_courtyard":inside_court})
	report.trees=tree_report
	var checked:=0;var max_error:=0.
	for row: Dictionary in ring.manifest.probes:
		for sample: Array in row.samples:
			var p: Vector3=world.vec(sample)
			var q:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.055,p-Vector3.UP*.055,16 if row.category=="terrain" else 1)
			q.hit_back_faces=true
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(q)
			check(not hit.is_empty(),"Missing imported collision: "+str(row.name))
			if not hit.is_empty():max_error=maxf(max_error,absf(hit.position.y-p.y))
			checked+=1
	check(max_error<.04,"Imported collision drift")
	report.collision={"samples":checked,"maximum_height_error":max_error}
	var bake: Dictionary=world.vegetation.volume_streamer.store.manifest
	check(not bake.is_empty() and bake.signature==STORE.signature(world) and bake.complete,"Stale or incomplete turf bake")
	check(world.vegetation.volume_streamer.store.corrupt==0,"Corrupt grass cells")
	var center: Vector3=world.vec(ring.manifest.center);var front: Vector3=world.vec(ring.manifest.front)
	await walk(center+front*83,center+front*30,"front_entry")
	await walk(center-front*83,center-front*30,"rear_entry")
	# Representative raised hill slope, independent of the architectural apron.
	var route: Array=ring.manifest.routes.RearRoadConnection
	await walk(world.vec(route[16]),world.vec(route[24]),"road_connection")
	world.set_review_ui_visible(false)
	var hero: Vector3=ring.tree_records[0].position
	var away:=Vector3(hero.x-center.x,0,hero.z-center.z).normalized()
	await capture("courtyard",center-away*30+Vector3.UP*7,hero+Vector3.UP*7)
	await capture("exterior",center+front*125+Vector3.UP*45,center+Vector3.UP*3)
	await capture("overview",Vector3(-1290,260,1470),center+Vector3.UP*1)
	await capture("cave_landmark",Vector3(659.75-1450,34.8,1150+361.53),center+Vector3.UP*3)
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/upper_ring_import_1030_before/hashes.json"))
	for path: String in before:check(FileAccess.get_sha256("res://"+path)==before[path],"Protected source asset changed: "+path)
	report.actual_scene=world.scene_file_path;report.passed=failures.is_empty();report.failures=failures
	report.grass_signature=bake.signature;report.grass_cells=bake.cells.size()
	FileAccess.open(OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("UPPER_RING_VERIFIED ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
