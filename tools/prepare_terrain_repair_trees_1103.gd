extends SceneTree
## Measure effective planting against the new collision; do not write the save.
const OUT="res://.current_map_build/terrain_repairs_1103/tree_grounding_plan.json"
var world
func _initialize() -> void:call_deferred("run")
static func population_digest(records: Dictionary,skip: Dictionary={},height_independent:=false) -> String:
	var ids:=records.keys();ids.sort();var text:=""
	for id: String in ids:
		if skip.has(id):continue
		var r: Dictionary=records[id]
		var values: Array=[r.id,r.position[0],r.position[2],r.yaw,r.scale,r.species,r.palette]
		if not height_independent:values.append(r.position[1]);values.append(r.get("surface",""))
		text+=JSON.stringify(values,"",true,true)+"\n"
	return text.sha256_text()
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true;world.vegetation_bake_only=true
	root.add_child(world)
	while not world.test_ready:await process_frame
	await physics_frame;await physics_frame
	var planting=world.PLANTING.new();world.add_child(planting);planting.initialize(world)
	assert(planting.load_error.is_empty())
	var records: Dictionary=planting.store.all_records();var changes: Array=[];var reviewed:=0;var skip: Dictionary={};var missing: Array=[]
	var feature=world.terrain_repairs
	for id: String in records:
		var row: Dictionary=records[id];var p: Vector3=world.vec(row.position)
		var support: float=feature.height_at(p)
		if not is_finite(support) or p.y>support+8. or p.y< -8.:continue
		var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,maxf(p.y,support)+3.,p.z),Vector3(p.x,-9.,p.z),16)
		query.hit_back_faces=true
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():missing.append(id);continue
		# A different higher terrace is outside this repair even at the same X/Z.
		if not feature.meshes_by_source.has(hit.collider.get_meta("source_id","")):continue
		if hit.normal.y<.45:continue
		reviewed+=1
		if absf(hit.position.y-p.y)<=.08:continue
		var after: Dictionary=row.duplicate(true);after.position[1]=hit.position.y;after.surface=hit.collider.get_meta("source_id","")
		changes.append({"before":row,"after":after});skip[id]=true
	var plan: Dictionary={"save_sha256":FileAccess.get_sha256(world.planting_edits_path),"changes":changes,
		"reviewed":reviewed,"missing":missing,"effective_count":records.size(),
		"layout_digest":population_digest(records,{},true),"unaffected_digest":population_digest(records,skip),
		"geometry_sha256":feature.manifest.mesh_sha256}
	FileAccess.open(OUT,FileAccess.WRITE).store_string(JSON.stringify(plan,"  ",true,true))
	print("TERRAIN_TREE_PLAN ",JSON.stringify({"reviewed":reviewed,"changed":changes.size(),"missing":missing}));quit(0 if missing.is_empty() else 1)
