extends SceneTree
## Exercise reflection lifetimes without touching the player's saved world.
const WATER=preload("res://scripts/water/water_manager.gd")
const OUT="res://docs/performance_cpu_1102/proxy_lifecycle.json"
var water
var stage: Node3D
var failures: Array[String]=[]
var mesh:=BoxMesh.new()

func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func source_at(p: Vector3) -> MeshInstance3D:
	var source:=MeshInstance3D.new();source.mesh=mesh;stage.add_child(source);source.position=p
	water.register_reflector(source,Color.WHITE)
	return source
func record_for(source: Node) -> Dictionary:
	for row: Dictionary in water.proxy_records:
		if row.source==source:return row
	return {}
func settle(eye: Vector3) -> void:
	for i in 256:
		water._update_tree_proxies();water._update_proxy_visibility(eye,.25)
		if water.metrics().visibility_pending==0:break
func consistent(eye: Vector3) -> void:
	var visible:=0
	for row: Dictionary in water.proxy_records:
		check(is_instance_valid(row.source) and is_instance_valid(row.proxy),"Freed node retained in live registry")
		var box: AABB=row.bounds
		var distance: float=eye.distance_to(eye.clamp(box.position,box.end))
		if not row.source.is_visible_in_tree() or distance>=water.reflection_radius+20.:
			check(not row.proxy.visible,"Invisible or out-of-range source still reflected")
		elif distance<water.reflection_radius:
			check(row.proxy.visible,"Nearby visible source missing from reflection")
		if row.proxy.visible:visible+=1
	check(visible==water.reflected_objects,"Visible proxy count drifted")

func run() -> void:
	stage=Node3D.new();root.add_child(stage)
	water=WATER.new();root.add_child(water);water.initialize(Environment.new(),Callable())
	water.set_process(false);water.set_physics_process(false)
	var a:=source_at(Vector3(0,2,0));var b:=source_at(Vector3(400,2,0))
	settle(Vector3.ZERO);consistent(Vector3.ZERO)
	var passes: int=water.visibility_passes
	for i in 180:water._update_proxy_visibility(Vector3.ZERO,1./60.)
	check(water.visibility_passes==passes and water.visibility_scanned==0,"Stationary camera still scans static records")
	stage.hide();check(not record_for(a).proxy.visible,"Ancestor hide left a stale reflection")
	stage.show();settle(Vector3.ZERO);check(record_for(a).proxy.visible,"Ancestor show failed to restore reflection")
	settle(Vector3(400,0,0));consistent(Vector3(400,0,0))
	# Registering again must replace the previous proxy and signal connections.
	water.register_reflector(b,Color.WHITE);settle(Vector3(400,0,0))
	check(water.proxy_records.size()==2,"Duplicate registration accumulated proxies")
	var old: Dictionary=record_for(a);a.free()
	check(not old.alive and water.proxy_records.size()==1,"Immediate free was not removed synchronously")
	var parent:=Node3D.new();stage.add_child(parent)
	var dynamic:=MultiMeshInstance3D.new();dynamic.name="EditableLOD1"
	dynamic.multimesh=MultiMesh.new();dynamic.multimesh.transform_format=MultiMesh.TRANSFORM_3D
	dynamic.multimesh.mesh=mesh;dynamic.multimesh.instance_count=1
	parent.add_child(dynamic);water.register_tree_nodes([dynamic],true)
	settle(Vector3.ZERO)
	parent.position=Vector3(8,3,5);parent.rotation.y=.4;parent.scale=Vector3.ONE*1.4
	settle(Vector3.ZERO)
	var moving: Dictionary=record_for(dynamic)
	check(moving.proxy.global_transform.is_equal_approx(dynamic.global_transform),"Editable proxy lost move/rotation/scale")
	parent.hide();check(not moving.proxy.visible,"Hidden play override is still reflected")
	parent.show();settle(Vector3.ZERO);check(moving.proxy.visible,"Play override show is stale")
	parent.queue_free();await process_frame;await process_frame
	check(not moving.alive and water.metrics().dynamic_proxies==0,"Queued handle deletion left a dynamic proxy")
	# Remove/reparent also exits the tree and must not leave references behind.
	stage.remove_child(b);check(water.proxy_records.is_empty(),"Reparenting retained a detached source")
	stage.add_child(b);water.register_reflector(b,Color.WHITE);settle(Vector3(400,0,0))
	# Mutate the registry while a budgeted visibility pass holds its snapshot.
	for i in 1200:source_at(Vector3(i%40*4,2,i/40*4))
	water.visibility_clock=1.;water._update_proxy_visibility(Vector3.ZERO,.016)
	for child in stage.get_children().slice(1,601):child.free()
	settle(Vector3.ZERO);consistent(Vector3.ZERO)
	water.apply_style(water.Style.SKY)
	check(water.reflected_objects==0,"Disabling planar reflections left visible proxies")
	water.apply_style(water.Style.PLANAR);settle(Vector3.ZERO);consistent(Vector3.ZERO)
	# Stop processing, then delete the manager before its sources (shutdown order).
	water.free();stage.free();await process_frame
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"stationary_no_rescan":true,
		"ancestor_visibility":true,"move_rotate_scale":true,"direct_and_queued_free":true,
		"duplicate_and_reparent":true,"delete_during_budgeted_pass":true,"style_switch":true}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	FileAccess.open(OUT,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WATER_PROXY_LIFECYCLE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
