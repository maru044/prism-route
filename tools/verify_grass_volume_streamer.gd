extends SceneTree
## Real physics/rendering fixture: stacked floors, elevated road, height-boundary
## retention and a full-speed 18 m/s camper route through dense 1012 grass.
const OUT := "res://assets/world/current_map_validation/review/"
const VEG := preload("res://scripts/map_1021_vegetation.gd")
var world
var vegetation
var stream
var actor
var failures: Array[String]=[]
var drive_records: Array=[]

class FixtureWorld extends Node3D:
	const ASSETS := "res://assets/world/current_map_validation/"
	var metadata:Dictionary={"object_records":[]}
	func architectural_band(_point: Vector3,_margin:=0.0) -> bool:return false

func _initialize() -> void:call_deferred("run")

func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)

func frames(count:int) -> void:
	for i in count:await physics_frame

func floor_box(name:String,position:Vector3,size:Vector3,kind:String) -> StaticBody3D:
	var body:=StaticBody3D.new();body.name=name;body.position=position
	body.collision_layer=17 if kind=="Terrain" else 9;body.collision_mask=0
	body.set_meta("surface_kind",kind);body.set_meta("source_id",name)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape)
	var mesh:=MeshInstance3D.new();var visual:=BoxMesh.new();visual.size=size;mesh.mesh=visual
	var material:=StandardMaterial3D.new();material.albedo_color=Color(.21,.27,.09) if kind=="Terrain" else Color(.2,.22,.24);mesh.material_override=material
	body.add_child(mesh);world.add_child(body);return body

func wait_for_cell(cell:Vector3i) -> void:
	var start:=Time.get_ticks_msec()
	while not stream.active.has(cell) and not stream.empty.has(cell):
		if Time.get_ticks_msec()-start>15000:check(false,"Cell did not finish: "+str(cell));return
		await process_frame

func capture(name:String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")

func run() -> void:
	root.size=Vector2i(1600,900)
	world=FixtureWorld.new();root.add_child(world)
	floor_box("Ground",Vector3(0,-.5,0),Vector3(800,1,800),"Terrain")
	floor_box("ElevatedRoad",Vector3(0,8.5,0),Vector3(780,1,8),"Road")
	floor_box("LowRoad",Vector3(100,.6,100),Vector3(8,1,8),"Road")
	var water:=floor_box("Water",Vector3(-100,.3,100),Vector3(8,1,8),"Water");water.collision_layer=4
	var roof:=floor_box("Roof",Vector3(0,23.7,0),Vector3(50,1,50),"Terrain")
	var scene=load("res://scenes/map_1021.tscn").instantiate()
	actor=scene.get_node("CamperVan");scene.remove_child(actor);scene.free()
	actor.automation_enabled=true;actor.position=Vector3(0,9.12,0);actor.rotation.y=-PI/2
	world.add_child(actor);actor.calibrate_wheels();actor.set_respawn_transform(actor.transform)
	var sky:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(.5,.72,.82);env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.6;sky.environment=env;world.add_child(sky)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);world.add_child(sun)
	var texture:=NoiseTexture2D.new();var noise:=FastNoiseLite.new();noise.seed=46129;texture.noise=noise
	vegetation=VEG.new();vegetation.world_scene=world;world.add_child(vegetation)
	vegetation.target=actor;vegetation.biome_noise_texture=texture;vegetation._load_meshes_and_materials()
	vegetation.initialized=true;vegetation._refresh_grass_cells();vegetation.set_grass_actor(actor,true)
	stream=vegetation.volume_streamer;stream.columns.clear();stream.required.clear();stream.queue.clear()
	stream.max_water_y=.8
	# Begin with only three volumes so the identity regression is fast and exact.
	for cell in [Vector3i(0,0,0),Vector3i(0,1,0),Vector3i(0,10,0)]:stream.register_cell(cell)
	await frames(3);stream.refresh()
	var ground_hits: Array=stream.sample_surfaces(Vector3i(0,0,0),2,2)
	var roof_hits: Array=stream.sample_surfaces(Vector3i(0,1,0),2,2)
	check(ground_hits.any(func(h:Dictionary):return absf(h.position.y)<.01),"Ground grass vanished below a road 9 m above it")
	check(roof_hits.any(func(h:Dictionary):return absf(h.position.y-24.2)<.01),"Upper-storey planting was lost")
	check(ground_hits.all(func(h:Dictionary):return absf(h.position.y)<.01),"Grass was placed on a ceiling underside")
	check(stream.sample_surfaces(Vector3i(4,0,4),100,100).is_empty(),"Grass pierced nearby road pavement")
	check(stream.sample_surfaces(Vector3i(-5,0,4),-100,100).is_empty(),"Grass grew under water")
	check(not stream.required.has(Vector3i(0,10,0)),"Vertical distance ignored by sphere selection")
	if "--surface-only" in OS.get_cmdline_user_args():
		print("GRASS_VOLUME_SURFACES ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"ground":ground_hits.size(),"roof":roof_hits.size()}))
		quit(0 if failures.is_empty()else 1);return
	await wait_for_cell(Vector3i(0,0,0));await wait_for_cell(Vector3i(0,1,0))
	check(stream.active.has(Vector3i(0,0,0)),"Ground volume stayed empty")
	var stable_id:int=stream.active[Vector3i(0,0,0)].get_instance_id()
	var blank_frames:=0
	actor.set_physics_process(false)
	for height in [4.9,5.1,9.9,10.1,19.9,20.1,34.9,35.1]:
		actor.position.y=height;stream.refresh()
		for i in 3:
			await process_frame
			if stream.active.is_empty():blank_frames+=1
		check(stream.active.has(Vector3i(0,0,0)) and stream.active[Vector3i(0,0,0)].get_instance_id()==stable_id,"Crossing a height boundary rebuilt all grass")
	check(blank_frames==0,"Height changes produced blank grass frames")
	# A forward request beyond the old 180 m unload radius must remain resident.
	actor.position=Vector3(0,9,0);stream.prediction_velocity=Vector3(18,0,0)
	stream.register_cell(Vector3i(9,0,0));stream.register_cell(Vector3i(-10,0,0));stream.refresh()
	check(stream.required.has(Vector3i(9,0,0)),"Fast vehicle did not prefetch 216 m ahead")
	check(not stream.required.has(Vector3i(-10,0,0)),"Prediction did not distinguish forward and rear")
	var sentinel:=Node3D.new();stream.add_child(sentinel);stream.active[Vector3i(9,0,0)]=sentinel
	stream.refresh();check(stream.active.has(Vector3i(9,0,0)),"Forward-loaded volume was immediately unloaded")
	stream.active.erase(Vector3i(9,0,0));sentinel.queue_free()
	# Warm a full 3D request set, then drive with the actual 1012 camper controller.
	roof.queue_free();await frames(2)
	for cell:Vector3i in stream.active:
		vegetation._remove_chunk_nodes_from_tracking(stream.active[cell]);stream.active[cell].queue_free()
	stream.active.clear();stream.empty.clear();stream.work.clear();stream.columns.clear()
	for x in range(-17,17):
		for z in range(-17,17):stream.register_cell(Vector3i(x,0,z))
	actor.position=Vector3(-180,9.12,0);actor.set_physics_process(true);actor.set_respawn_transform(actor.transform)
	await frames(10);stream.refresh()
	var warm_start:=Time.get_ticks_msec()
	while stream.pending_visible_count()>0:
		if Time.get_ticks_msec()-warm_start>45000:check(false,"Visible grass could not warm within 45 seconds");break
		await process_frame
	var warm_seconds:float=(Time.get_ticks_msec()-warm_start)/1000.0
	await capture("grass_stream_raised_road")
	var start:Vector3=actor.position;var frame_times:Array[float]=[];var frame_count:=0;var ahead_missing_frames:=0;var all_blank_frames:=0
	actor.test_throttle=1
	var drive_start:=Time.get_ticks_msec()
	var last_tick:=Time.get_ticks_usec();var last_record:=0
	while actor.position.x<80 and Time.get_ticks_msec()-drive_start<30000:
		await process_frame
		var now:=Time.get_ticks_usec();frame_times.append((now-last_tick)/1000.0);last_tick=now;frame_count+=1
		if stream.active.is_empty():all_blank_frames+=1
		var missing:=0
		for cell:Vector3i in stream.required:
			var p:Vector3=Vector3(cell)*24+Vector3(12,0,12)-actor.position
			if p.x>0 and p.x<96 and absf(p.z)<36 and not stream.active.has(cell) and not stream.empty.has(cell):missing+=1
		if missing>0 and actor.drive_speed>15:ahead_missing_frames+=1
		if Time.get_ticks_msec()-last_record>500:
			last_record=Time.get_ticks_msec();var row:Dictionary=stream.metrics();row["x"]=actor.position.x;row["forward_96m_missing"]=missing;drive_records.append(row)
	actor.test_throttle=0;actor.test_braking=true
	await frames(40);await capture("grass_stream_driving")
	var travelled:float=actor.position.x-start.x
	check(travelled>240,"Camper did not complete the full-speed route")
	check(all_blank_frames==0,"Driving blanked every grass chunk")
	check(ahead_missing_frames==0,"Forward grass was late at full speed: %d frames"%ahead_missing_frames)
	frame_times.sort()
	var report:Dictionary={"passed":failures.is_empty(),"failures":failures,"engine":Engine.get_version_info().string,"height_boundary_blank_frames":blank_frames,"ground_chunk_identity_preserved":blank_frames==0,"stacked_ground_y":ground_hits.map(func(h:Dictionary):return h.position.y),"stacked_roof_y":roof_hits.map(func(h:Dictionary):return h.position.y),"warm_seconds":warm_seconds,"drive_m":travelled,"drive_frames":frame_count,"driving_blank_frames":all_blank_frames,"full_speed_forward_missing_frames":ahead_missing_frames,"median_frame_ms":frame_times[frame_times.size()/2],"p95_frame_ms":frame_times[int(frame_times.size()*.95)],"records":drive_records}
	var file:=FileAccess.open(OUT+"grass_stream_validation.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("GRASS_VOLUME_VERIFY ",JSON.stringify(report))
	quit(0 if failures.is_empty()else 1)
