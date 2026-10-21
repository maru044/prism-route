extends SceneTree
## Final fixed-layout bake against the same Jolt colliders used in gameplay.
const ASSETS := "res://assets/world/current_map_validation/"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene=load("res://scenes/map_1021.tscn").instantiate()
	scene.automation_enabled=true;scene.vegetation_bake_only=true;root.add_child(scene)
	while not scene.test_ready:await physics_frame
	var records: Array=JSON.parse_string(FileAccess.get_file_as_string(ASSETS+"tree_layout.json"))
	var accepted: Array=[];var removed:=0;var adjusted:=0;var max_adjustment:=0.0;var large:=0
	for row: Array in records:
		var p:=Vector3(row[0],row[1],row[2])
		var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,400,p.z),Vector3(p.x,-30,p.z),5);query.hit_back_faces=true
		var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.collider.get_meta("surface_kind", "")!="Terrain" or scene.architectural_band(p,3):removed+=1;continue
		var adjustment:=absf(hit.position.y-p.y)
		# An actual storey mismatch is rejected rather than transferring its tree.
		if adjustment>.5:removed+=1;continue
		if adjustment>.00001:adjusted+=1;max_adjustment=maxf(max_adjustment,adjustment)
		row[1]=hit.position.y
		accepted.append(row)
		if int(row[5])==1:large+=1
	var path:=ASSETS+"tree_layout.json"
	var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(accepted));f.close()
	var meta: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ASSETS+"tree_layout_metadata.json"))
	meta.tree_count=accepted.size();meta.large_tree_count=large;meta.layout_sha256=FileAccess.get_sha256(path)
	meta["physics_conformity"]={"engine":"Jolt","removed":removed,"roots_adjusted":adjusted,"max_height_adjustment_m":max_adjustment,"xz_positions_and_spacing_unchanged":true}
	f=FileAccess.open(ASSETS+"tree_layout_metadata.json",FileAccess.WRITE);f.store_string(JSON.stringify(meta,"  "));f.close()
	print("MAP_1021_TREE_CONFORM ",JSON.stringify(meta.physics_conformity)," count=",accepted.size())
	quit()
