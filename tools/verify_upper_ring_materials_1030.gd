extends SceneTree
const OUT="res://docs/upper_ring_pavilion_1030/game/"
const STORE=preload("res://scripts/grass_baked_store.gd")
var world
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func capture(label: String,eye: Vector3,target: Vector3) -> void:
	world.set_free(true);world.camera.global_position=eye;world.camera.look_at(target)
	for i in 80:await physics_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+"materials_"+label+".png")==OK,"Capture failed: "+label)
func run() -> void:
	create_timer(180).timeout.connect(func():push_error("Material review timed out");quit(1))
	AudioServer.set_bus_mute(0,true)
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true
	root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	world.set_review_ui_visible(false)
	var ring=world.upper_ring;var optical=ring.material_set
	check(optical.glass_meshes.size()==114,"Glass panes missing")
	check(optical.water_mesh!=null,"Pool surface missing")
	check(ring.tree_records.size()==4 and ring.tree_records[0].scale==1.5,"Courtyard trees changed")
	var bake: Dictionary=world.vegetation.volume_streamer.store.manifest
	check(bake.complete and bake.signature==STORE.signature(world),"Grass cache changed")
	var original=load("res://assets/world/upper_ring_1030/pavilion.glb").instantiate()
	var original_pool: MeshInstance3D=original.find_child(str(optical.water_mesh.name),true,false)
	var body: StaticBody3D=optical.water_mesh.get_child(0)
	var faces: PackedVector3Array=body.get_child(0).shape.get_faces()
	check(faces==original_pool.mesh.get_faces(),"Pool collision changed")
	original.free()
	var center: Vector3=world.vec(ring.manifest.center);var front: Vector3=world.vec(ring.manifest.front)
	var hero: Vector3=ring.tree_records[0].position
	var away:=Vector3(hero.x-center.x,0,hero.z-center.z).normalized()
	var pool: Vector3=optical.water_mesh.global_transform*optical.water_mesh.get_aabb().get_center()
	pool.y=70.2
	await capture("courtyard",center-away*30+Vector3.UP*7,hero+Vector3.UP*7)
	await capture("exterior",center+front*113+Vector3.UP*26,center+Vector3.UP*3)
	await capture("pool",pool+Vector3(-10,8,12),pool)
	await capture("pool_grazing",pool+Vector3(-9,1.5,10),pool)
	# Choose a window on the near facade for repeatable material inspection.
	var pane: MeshInstance3D=optical.glass_meshes[0];var score:=-INF
	for candidate: MeshInstance3D in optical.glass_meshes:
		var p: Vector3=candidate.global_transform*candidate.get_aabb().get_center()
		var d:=Vector3(p.x-center.x,0,p.z-center.z)
		var s:=d.dot(front)
		if s>score:score=s;pane=candidate
	var pane_center: Vector3=pane.global_transform*pane.get_aabb().get_center()
	var radial:=Vector3(pane_center.x-center.x,0,pane_center.z-center.z).normalized()
	var tangent:=Vector3(-radial.z,0,radial.x)
	await capture("glass_front",pane_center+radial*8,pane_center)
	await capture("glass_grazing",pane_center+radial*2+tangent*10,pane_center)
	var hashes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/upper_ring_materials_1030_before/hashes.json"))
	for path: String in hashes:check(FileAccess.get_sha256("res://"+path)==hashes[path],"Protected asset changed: "+path)
	var report={"passed":failures.is_empty(),"failures":failures,"scene":world.scene_file_path,"glass_panes":optical.glass_meshes.size(),"pool_collision_unchanged":faces.size(),"probe_origin":str(optical.probe.position+optical.probe.origin_offset),"glass_f0":pow((1.5-1.)/(1.5+1.),2.),"water_f0":pow((1.333-1.)/(1.333+1.),2.),"grass_signature":bake.signature,"palette":optical.settings}
	FileAccess.open(OUT+"materials_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("UPPER_RING_MATERIALS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
