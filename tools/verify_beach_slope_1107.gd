extends SceneTree
## Validate the actual main entry, the single replacement body, and shore profiles.
const OUT="res://docs/beach_slope_1107/"
const SOURCE="a2b4d386-d01a-4559-a8f7-28e5c8b93563"
const STORE=preload("res://scripts/grass_baked_store.gd")
var failures: Array[String]=[]
var world
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func settle(seconds: float) -> void:
	var start:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<seconds*1000.:await process_frame
func run() -> void:
	create_timer(180).timeout.connect(func():push_error("Beach verification timeout");quit(1))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	AudioServer.set_bus_mute(0,true)
	world=load("res://scenes/main.tscn").instantiate();world.automation_enabled=true;root.add_child(world)
	while not world.test_ready:await process_frame
	world.set_free(true)
	await physics_frame;await physics_frame
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/beach_slope_1107/manifest.json"))
	var bodies: Array=[]
	for body: StaticBody3D in world.model.find_children("*","StaticBody3D",true,false):
		if body.get_meta("source_id","")==SOURCE:bodies.append(body)
	check(bodies.size()==1,"Expected exactly one sand-bed body")
	var checks: Array=[]
	for profile: Dictionary in manifest.report.profiles:
		for j in profile.xyz.size():
			var xyz: Array=profile.xyz[j]
			var p:=Vector3(float(xyz[0])-1450.,float(xyz[2]),1150.-float(xyz[1]))
			# A ray exactly on an independently tessellated trim can miss its chord.
			# Probe 15 cm inside the ramp; crossing is checked with a capsule below.
			if j==0:
				var next: Array=profile.xyz[1]
				p+=(Vector3(float(next[0])-1450.,0.,1150.-float(next[1]))-p).normalized()*.15
			var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.8,p-Vector3.UP*.8,32)
			var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
			var passed: bool=not hit.is_empty() and (hit.collider.get_meta("source_id","")==SOURCE or absf(p.y)<.001)
			var error: float=absf(hit.position.y-p.y) if not hit.is_empty() else INF
			passed=passed and error<.045
			check(passed,"Shore collision differs from native surface at "+str(p))
			checks.append({"position":p,"error_m":error,"passed":passed})
	check(STORE.signature(world)==world.vegetation.volume_streamer.store.manifest.get("signature","missing"),"Grass bake signature changed")
	check(world.church_ruins.local_grass_cells==12,"Church grass overlay missing")
	var crossings: Array=[]
	for profile: Dictionary in manifest.report.profiles:
		var edge: Array=profile.xyz[0];var next: Array=profile.xyz[1]
		var edge_p:=Vector3(float(edge[0])-1450.,0.,1150.-float(edge[1]))
		var along:=(Vector3(float(next[0])-1450.,0.,1150.-float(next[1]))-edge_p).normalized()
		var start:=edge_p-along*.8
		world.character.set_spawn(start+Vector3.UP*.06,atan2(-along.x,-along.z))
		world.character.set_control_enabled(true);world.character.test_move=Vector2(0,-1)
		var minimum_y:=0.
		for frame in 120:
			await physics_frame
			minimum_y=minf(minimum_y,world.character.global_position.y)
		world.character.test_move=Vector2.ZERO;world.character.set_control_enabled(false)
		var travelled: float=(world.character.global_position-start).dot(along)
		var passed: bool=travelled>2.5 and minimum_y>-.15
		check(passed,"Character could not walk across shoreline at "+str(edge_p))
		crossings.append({"shore":edge_p,"travelled_m":travelled,"minimum_y":minimum_y,"passed":passed})
	var shore: Array=manifest.report.profiles[3].xyz[0]
	var inner: Array=manifest.report.profiles[3].xyz[-1]
	var p:=Vector3(float(shore[0])-1450.,0.,1150.-float(shore[1]))
	var direction:=(Vector3(float(inner[0])-1450.,0.,1150.-float(inner[1]))-p).normalized()
	world.character.set_spawn(p-direction*6.+Vector3.UP*.08,atan2(-direction.x,-direction.z))
	world.camera.global_position=p-direction*9.+Vector3.UP*2.2
	world.camera.look_at(p+direction*36.+Vector3.UP*.15)
	await settle(5.)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"shore.png")
		world.camera.global_position=p-direction*20.+Vector3.UP*22.
		world.camera.look_at(p+direction*22.)
		await settle(2.)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"slope_overview.png")
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"entry":"scenes/main.tscn",
		"replacement_bodies":bodies.size(),"collision_checks":checks,"character_crossings":crossings,"grass_signature_valid":STORE.signature(world)==world.vegetation.volume_streamer.store.manifest.get("signature",""),
		"church_grass_cells":world.church_ruins.local_grass_cells,"triangles":manifest.objects[0].index_count/3}
	FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("BEACH_VALIDATION ",JSON.stringify({"passed":report.passed,"checks":checks.size(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
