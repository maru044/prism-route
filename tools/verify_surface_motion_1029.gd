extends SceneTree
## Exercise the shared swept stair helper against Jolt geometry and obstructions.
const MOTION=preload("res://scripts/surface_motion.gd")
var failures: Array[String]=[]
var report: Dictionary={}
var arena: Node3D
var body: CharacterBody3D
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func box(size: Vector3,center: Vector3) -> void:
	var node:=StaticBody3D.new();node.position=center
	var shape:=CollisionShape3D.new();var form:=BoxShape3D.new();form.size=size;shape.shape=form;node.add_child(shape);arena.add_child(node)
func setup() -> void:
	arena=Node3D.new();root.add_child(arena)
	body=CharacterBody3D.new();body.safe_margin=.004;body.floor_snap_length=.45;body.floor_max_angle=deg_to_rad(48)
	var shape:=CollisionShape3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.24;capsule.height=1.45;shape.shape=capsule;shape.position.y=.725;body.add_child(shape);arena.add_child(body)
	body.position=Vector3(0,.04,1)
func tick(direction: Vector3,speed: float) -> void:
	await physics_frame
	body.velocity.x=move_toward(body.velocity.x,direction.x*speed,12./60.)
	body.velocity.z=move_toward(body.velocity.z,direction.z*speed,12./60.)
	body.velocity.y=-.5 if body.is_on_floor() else body.velocity.y-22./60.
	MOTION.move(body,1./60.,.18)
func clear() -> void:
	arena.queue_free();await physics_frame;await physics_frame
func stairs(speed: float) -> void:
	setup();box(Vector3(6,1,20),Vector3(0,-.5,-4))
	for i in 18:
		var h: float=(i+1)*.15;box(Vector3(3,h,.35),Vector3(0,h*.5,-(i+.5)*.35))
	box(Vector3(3,2.7,2),Vector3(0,1.35,-7.3))
	var air:=0;var longest:=0;var reached:=false
	for i in 900:
		await tick(Vector3.FORWARD,speed)
		air=0 if body.is_on_floor() else air+1;longest=maxi(longest,air)
		if body.position.z< -7.2:reached=true;break
	print("ASCENT ",speed," ",body.position)
	check(reached and absf(body.position.y-2.7)<.04,"Stair ascent failed at speed "+str(speed))
	var steps: int=body.get_meta("surface_steps",0)
	check(steps>0 and longest<8,"Stair helper lost floor for too long")
	for i in 900:
		await tick(Vector3.BACK,speed)
		if body.position.z>.8:break
	check(body.position.z>.8 and absf(body.position.y)<.04,"Stair descent failed")
	report[str(speed)]={"ascent":reached,"step_events":steps,"longest_air_ticks":longest,"descent":body.position.z>.8}
	await clear()
func obstruction(ceiling: bool) -> void:
	setup();box(Vector3(6,1,10),Vector3(0,-.5,-3))
	box(Vector3(3,.15 if ceiling else .5,4),Vector3(0,.075 if ceiling else .25,-2))
	if ceiling:box(Vector3(3,.3,4),Vector3(0,1.67,-1.))
	for i in 180:await tick(Vector3.FORWARD,4.2)
	check(body.position.z>.1,"Crossed a low ceiling/high riser")
	report["ceiling" if ceiling else "high_riser"]={"blocked":body.position.z>.1,"position_z":body.position.z}
	await clear()
func gap() -> void:
	setup();box(Vector3(3,1,2),Vector3(0,-.5,1));box(Vector3(3,1,4),Vector3(0,-.5,-3))
	var lowest:=0.;var air:=0
	for i in 100:
		await tick(Vector3.FORWARD,4.2)
		lowest=minf(lowest,body.position.y)
		if not body.is_on_floor():air+=1
	check(lowest< -.1 and air>5,"Step helper bridged an unsupported gap")
	report.gap={"minimum_y":lowest,"air_ticks":air}
	await clear()
func run() -> void:
	Engine.max_fps=0
	await stairs(1.6);await stairs(4.2);await obstruction(false);await obstruction(true);await gap()
	report.passed=failures.is_empty();report.failures=failures
	FileAccess.open("res://docs/initial_ruin_1029/surface_motion_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SURFACE_MOTION_1029 ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
