extends SceneTree
## Confirm paint remains available to legacy planting queries but not actors.
const OUT := "res://assets/world/current_map_validation/review/"
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func ray(scene,p: Vector3,mask: int) -> Dictionary:
	var q:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.1,p-Vector3.UP*.5,mask);q.hit_back_faces=true
	return scene.get_world_3d().direct_space_state.intersect_ray(q)
func run() -> void:
	var scene=load("res://scenes/map_1021.tscn").instantiate();scene.automation_enabled=true;scene.vegetation_bake_only=true;root.add_child(scene)
	while not scene.test_ready:await process_frame
	var byid: Dictionary={}
	for row: Dictionary in scene.metadata.object_records:byid[row.id]=row
	var records: Array=[];var bodies:=0
	for n: MeshInstance3D in scene.model.find_children("*","MeshInstance3D",true,false):
		var id:=str(n.name).get_slice("_",1);var row: Dictionary=byid[id]
		for body: StaticBody3D in n.find_children("*","StaticBody3D",true,false):
			bodies+=1
			var legacy:=4 if row.kind=="Water" else (9 if row.kind=="Road" else (17 if row.kind=="Terrain" else 1))
			check((body.collision_layer&31)==legacy,"Planting/query layers changed: "+id)
			if not body.get_meta("nonblocking_road_marking",false):
				check(bool(body.collision_layer&32)==(row.kind!="Water"),"Wall/guardrail lost actor collision: "+id)
				continue
			check((body.collision_layer&32)==0,"Paint still blocks actors: "+id)
			var found:=false;var record: Dictionary={"id":id,"name":row.name}
			var faces:=n.mesh.get_faces()
			for i in range(0,faces.size(),3):
				var a:=faces[i];var b:=faces[i+1];var c:=faces[i+2]
				if absf((b-a).cross(c-a).normalized().y)<.8:continue
				var p: Vector3=n.global_transform*((a+b+c)/3.0)
				var old:=ray(scene,p,1);var solid:=ray(scene,p,32)
				if old.is_empty() or old.collider.get_meta("source_id","")!=id or solid.is_empty():continue
				if solid.collider.get_meta("surface_kind","")!="Road":continue
				record.merge({"legacy_query_hits_marking":true,"actor_query_hits_road":true,"paint_height_m":old.position.y-solid.position.y});found=true;break
			check(found,"No road support beneath marking: "+id);records.append(record)
	check(records.size()>0 and bodies==197,"Collision population changed")
	check(scene.character.collision_mask==32 and scene.camper.collision_mask==32 and scene.camper.ground_query_mask==32,"Actor masks disagree")
	var store=load("res://scripts/grass_baked_store.gd").new()
	var signature: String=store.signature(scene)
	check(store.open(scene.ASSETS+"grass_bake",signature) and store.manifest.cells.size()==11321,"Existing grass bake unexpectedly invalidated")
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"markings":records,"bodies":bodies,"legacy_query_layers_preserved":true,"grass_bake_signature":signature,"grass_baked_cells":store.manifest.get("cells",{}).size(),"character_step_limit_m":scene.character.surface_step_height,"camper_step_limit_m":scene.camper.surface_step_height}
	var file:=FileAccess.open(OUT+"collision_tolerance_layers.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print("COLLISION_LAYER_TEST ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
