extends SceneTree
## Real controller/shape regressions: seams, small steps, walls and headroom.
const OUT := "res://assets/world/current_map_validation/review/"
var failures: Array[String]=[]
var rows: Array=[]
var stage: Node3D
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func ticks(n: int) -> void:
	for i in n:await physics_frame
func box(center: Vector3,size: Vector3) -> void:
	var body:=StaticBody3D.new();body.collision_layer=33;body.collision_mask=0
	var mesh:=BoxMesh.new();mesh.size=size
	var shape:=CollisionShape3D.new();shape.shape=mesh.create_trimesh_shape();shape.shape.backface_collision=true
	body.add_child(shape);stage.add_child(body);body.position=center
func actor(kind: String):
	if kind=="character":
		var n=load("res://scenes/characters/world_ganyu.tscn").instantiate()
		n.automation_enabled=true;n.walking_speed=4.0;n.test_move=Vector2(0,-1);n.safe_margin=.004
		return n
	var shell=load("res://scenes/map_1021.tscn").instantiate();var n=shell.get_node("CamperVan");shell.remove_child(n);shell.free()
	n.automation_enabled=true;n.test_throttle=1;n.safe_margin=.006
	return n
func trial(kind: String,scenario: String,enabled: bool) -> void:
	stage=Node3D.new();root.add_child(stage)
	var step:=.08 if kind=="character" else .10
	var cap:=.10 if kind=="character" else .12
	var height:=1.45 if kind=="character" else 2.5
	var floor_offset:=0.0 if kind=="character" else -.2
	var start_z:=3.0 if kind=="character" else 6.0
	if scenario=="seams":
		for i in range(-3,13):
			var top:=.03 if i%2==0 else 0.0
			box(Vector3(0,top-.25,4-i*2),Vector3(8,.5,1.96))
	elif scenario=="gap":
		box(Vector3(0,-.25,8),Vector3(8,.5,16));box(Vector3(0,-.25,-20.12),Vector3(8,.5,40))
	elif scenario=="drop":box(Vector3(0,-.25,8),Vector3(8,.5,16))
	else:
		box(Vector3(0,-.25,8),Vector3(8,.5,16))
		var top:=.7 if scenario in ["wall","fast_wall"] else step
		box(Vector3(0,top-.25,-100),Vector3(8,.5,200))
		if scenario=="ceiling":box(Vector3(0,height+.04+.25,0),Vector3(8,.5,70))
	var n=actor(kind);n.collision_mask=32;n.surface_step_height=cap if enabled else 0.0
	stage.add_child(n);n.set_physics_process(false)
	if kind=="character":n.test_move=Vector2.ZERO
	else:n.test_throttle=0;n.maximum_forward_speed=4.0
	n.global_position=Vector3(0,floor_offset+.005,start_z)
	await ticks(6)
	n.set_physics_process(true);await ticks(20)
	if kind=="character":n.test_move=Vector2(0,-1)
	else:
		n.test_throttle=1
		if scenario.begins_with("fast_"):n.maximum_forward_speed=18.0;n.drive_speed=18.0
	var min_y: float=n.position.y;var max_y: float=n.position.y
	for i in 240:
		await physics_frame;min_y=minf(min_y,n.position.y);max_y=maxf(max_y,n.position.y)
	var end: Vector3=n.position
	var ok:=true
	if scenario in ["seams","gap","step","fast_step"]:ok=end.z< -3 and n.is_on_floor()
	elif scenario in ["wall","fast_wall","ceiling"]:ok=end.z>-.1 and max_y<floor_offset+.20
	elif scenario=="drop":ok=min_y<floor_offset-1.0
	# Baseline records expose whether a controller was already blocked.
	if enabled:check(ok,"Tolerance regression: %s %s end=%s"%[kind,scenario,end])
	rows.append({"actor":kind,"scenario":scenario,"enabled":enabled,"passed":ok,"end":[end.x,end.y,end.z],"grounded":n.is_on_floor(),"min_y":min_y,"max_y":max_y,"surface_steps":n.get_meta("surface_steps",0)})
	print("COLLISION_TOLERANCE ",JSON.stringify(rows[-1]));stage.queue_free();await ticks(2)
func run() -> void:
	Engine.max_fps=0
	for kind in ["character","camper"]:
		for scenario in ["step","seams","gap","wall","ceiling","drop"]:
			if scenario in ["step","seams"]:await trial(kind,scenario,false)
			await trial(kind,scenario,true)
	await trial("camper","fast_step",true)
	await trial("camper","fast_wall",true)
	var settings: Dictionary={}
	for setting in ProjectSettings.get_property_list():
		if "enhanced_internal_edge" in setting.name or "active_edge_threshold" in setting.name:settings[setting.name]=ProjectSettings.get_setting(setting.name)
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"physics":"Jolt","fixed_test_fps":60,"rows":rows,"jolt_edge_settings":settings}
	var file:=FileAccess.open(OUT+"collision_tolerance_fixture.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();quit(0 if failures.is_empty() else 1)
