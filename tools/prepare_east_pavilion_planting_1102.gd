extends SceneTree
## Read-only plan: project existing trees onto earth or the court floor, never onto ramps.
const OUT="res://.current_map_build/east_earth_pavilion_1102/tree_grounding_plan.json"
var world
func _initialize() -> void:call_deferred("run")
func ground(p: Vector3, floor_ids: Array) -> Dictionary:
	var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,125.,p.z),Vector3(p.x,0.,p.z),32)
	query.hit_back_faces=true;query.exclude=[world.character.get_rid()]
	for i in 20:
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():return {}
		var body: CollisionObject3D=hit.collider
		if (body.get_meta("surface_kind","")=="Terrain" or body.get_meta("source_id","") in floor_ids) and hit.normal.y>.45:return hit
		var excluded: Array[RID]=query.exclude;excluded.append(body.get_rid());query.exclude=excluded
	return {}
func run() -> void:
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true;world.vegetation_bake_only=true
	root.add_child(world)
	while not world.test_ready:await process_frame
	await physics_frame;await physics_frame
	var planting=world.PLANTING.new();world.add_child(planting);planting.initialize(world)
	assert(planting.load_error.is_empty())
	var feature=world.earth_pavilion;var floors: Array=[]
	for row: Dictionary in feature.manifest.objects:
		if row.name.ends_with("Lower_continuous_floor") or row.name.ends_with("Daylit_atrium_paving"):floors.append(row.id)
	var before: Dictionary=planting.store.all_records().duplicate(true);var changes: Array=[];var reviewed: Array=[];var missing: Array=[]
	for id: String in before:
		var row: Dictionary=before[id];var p:=Vector3(row.position[0],row.position[1],row.position[2])
		if p.y<40. or p.y>105. or not feature.affected_xz(p):continue
		var hit:=ground(p,floors)
		if hit.is_empty():missing.append(id);continue
		var record: Dictionary=row.duplicate(true)
		record.position[1]=hit.position.y
		record.surface=hit.collider.get_meta("source_id","")
		reviewed.append({"id":id,"old_y":p.y,"ground_y":hit.position.y,"source_id":record.surface})
		if absf(hit.position.y-p.y)>.12:changes.append({"before":row,"after":record})
	var report: Dictionary={"save_sha256":FileAccess.get_sha256(world.planting_edits_path),"effective_before":before,
		"changes":changes,"reviewed":reviewed,"missing":missing,"geometry_sha256":feature.manifest.mesh_sha256}
	FileAccess.open(OUT,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PAVILION_TREE_GROUNDING_PLAN ",JSON.stringify({"reviewed":reviewed.size(),"changes":changes.size(),"missing":missing}));quit(0 if missing.is_empty() else 1)
