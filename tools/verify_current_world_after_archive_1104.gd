extends SceneTree
var world
var failures: Array[String]=[]
var spawns: Array=[]
var vehicles: Array=[]
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await physics_frame
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func toggle() -> void:
	var event:=InputEventKey.new();event.physical_keycode=KEY_C;event.pressed=true
	world._unhandled_input(event)
	while world.switching_actor:await physics_frame
	await frames(65)
func run() -> void:
	create_timer(180).timeout.connect(func():push_error("Archive verification timed out");quit(1))
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://scenes/map_1021.tscn","F5 entry changed")
	world=load("res://scenes/main.tscn").instantiate();world.automation_enabled=true
	root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	check(world.get_script().resource_path=="res://scripts/map_1021.gd","main alias loads wrong world")
	check(world.vegetation!=null and world.vegetation.tree_instance_count>19000,"Shared vegetation did not initialize")
	check(world.planting.load_error.is_empty(),"Planting save did not load")
	check(world.resolved_spawns.size()==19,"Current world spawns are missing")
	check(load("res://assets/world/cliff_b_test/architecture.tres")!=null,"Shared architecture material missing")
	check(load("res://assets/world/map_1012_test/water.gdshader")!=null,"Shared water shader missing")
	for i in world.resolved_spawns.size():
		var row: Dictionary=world.resolved_spawns[i]
		await world.select_spawn(i);await frames(70)
		var actor=world.character;var start: Vector3=actor.position
		check(actor.is_on_floor(),"Character lacks floor: "+str(row.key))
		check(absf(start.y-row.floor_position.y)<.5,"Wrong character storey: "+str(row.key))
		actor.test_move=Vector2(0,-1);await frames(100);actor.test_move=Vector2.ZERO;await frames(15)
		var moved: float=Vector2(actor.position.x-start.x,actor.position.z-start.z).length()
		check(moved>1.2 and actor.is_on_floor(),"Character walk failed: "+str(row.key))
		spawns.append({"key":row.key,"walk_m":moved,"grounded":actor.is_on_floor()})
		# The original eight road/terrain locations permit vehicles; appended
		# architecture review locations are deliberately not vehicle test starts.
		if str(row.key) not in ["south_roof","south_bridge","south_gallery","south_middle","south_waterfront","north_hill","north_lagoon","north_ramp"]:continue
		await world.select_spawn(i);await frames(20);await toggle()
		check(not world.character_mode and world.camper.is_on_floor(),"Camper switch failed: "+str(row.key))
		var p: Vector3=world.camper.position
		world.camper.test_throttle=1.;await frames(50);world.camper.test_throttle=0.;world.camper.test_braking=true;await frames(30);world.camper.test_braking=false
		var distance:=Vector2(world.camper.position.x-p.x,world.camper.position.z-p.z).length()
		check(distance>2 and world.camper.is_on_floor(),"Camper driving failed: "+str(row.key))
		vehicles.append({"key":row.key,"drive_m":distance,"grounded":world.camper.is_on_floor()})
		await toggle()
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"entry":"res://scenes/main.tscn","script":world.get_script().resource_path,
		"trees":world.vegetation.tree_instance_count,"spawns":spawns,"vehicles":vehicles,"engine":Engine.get_version_info().string}
	FileAccess.open("res://docs/legacy_world_archive_1104_runtime.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("ARCHIVE_RUNTIME_REPORT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
