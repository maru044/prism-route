extends "res://tools/verify_east_earth_pavilion_1102.gd"
## Reload the formal world: validate persistence, ground contact and the installed bake.
func run() -> void:
	create_timer(180).timeout.connect(func():push_error("Planting review timeout");quit(1))
	AudioServer.set_bus_mute(0,true)
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true
	root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	await frames(8)
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/east_earth_pavilion_1102/tree_grounding_plan.json"))
	var grounding: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"tree_grounding_report.json"))
	var expected: Dictionary=plan.effective_before.duplicate(true)
	for change: Dictionary in plan.changes:expected[change.after.id]=change.after
	var actual: Dictionary=world.planting.store.all_records()
	var record_differences: Array=[]
	for id: String in actual:
		if not world.planting.STORE.same_tree(actual[id],expected.get(id,{})):record_differences.append({"id":id,"actual":actual[id],"expected":expected.get(id,{})})
	FileAccess.open("res://.current_map_build/east_earth_pavilion_1102/grounding_record_differences.json",FileAccess.WRITE).store_string(JSON.stringify(record_differences,"  "))
	check(actual.size()==expected.size() and record_differences.is_empty(),"Persisted planting population changed beyond the grounding plan")
	check(FileAccess.get_sha256(world.planting_edits_path)==grounding.after_sha256,"Grounded save was overwritten")
	var max_error:=0.;var changed_sources: Dictionary={};var thin_paving_overlaps:=0
	for change: Dictionary in plan.changes:
		var row: Dictionary=actual[change.after.id];var p: Vector3=world.vec(row.position)
		var hit:=floor_at(p)
		# Tree roots are intentionally grounded in soil or the lower floor.
		# Thin paving/ramp overlays may cross an unchanged X/Z; do not mistake
		# their top face for the selected supporting earth in this contact check.
		if not hit.is_empty() and hit.collider.get_meta("source_id","")!=row.surface:
			thin_paving_overlaps+=1
			var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.4,p-Vector3.UP*.6,32)
			query.hit_back_faces=true;query.exclude=[world.character.get_rid()]
			for i in 12:
				var excluded: Array[RID]=query.exclude;excluded.append(hit.collider.get_rid());query.exclude=excluded
				hit=world.get_world_3d().direct_space_state.intersect_ray(query)
				if hit.is_empty() or hit.collider.get_meta("source_id","")==row.surface:break
		check(not hit.is_empty(),"Tree has no supporting floor: "+row.id)
		if not hit.is_empty():
			max_error=maxf(max_error,absf(p.y-hit.position.y))
			check(absf(p.y-hit.position.y)<.04,"Tree not grounded: "+row.id)
		changed_sources[row.surface]=true
	var feature=world.earth_pavilion
	var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(feature.GRASS_CONFIG))
	var baked: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(feature.GRASS_BAKE))
	check(feature.local_grass_cells==config.cells.size(),"Local grass bake not installed")
	check(baked.signature==STORE.signature(world),"Grass signature invalid")
	var stream=world.vegetation.volume_streamer
	var local_roots:=0;var total_roots:=0;var invalid_local:=0
	for id: String in baked.cells:
		var row: Dictionary=baked.cells[id]
		check(stream.store.manifest.cells[id].resource_path==row.resource_path,"Old grass cache still selected: "+id)
		check(FileAccess.get_sha256(row.resource_path)==row.sha256,"Grass buffer corrupted: "+id)
		if row.root_count==0:continue
		var bytes:=FileAccess.get_file_as_bytes(row.resource_path).decompress(row.raw_bytes,FileAccess.COMPRESSION_ZSTD)
		var roots:=bytes.slice(0,int(row.root_count)*48).to_float64_array()
		var parts:=id.split("_");var origin:=Vector3(float(parts[0]),float(parts[1]),float(parts[2]))*24.
		for i in int(row.root_count):
			var k:=i*6;var p:=origin+Vector3(roots[k],roots[k+2],roots[k+1])
			if feature.affected_xz(p):
				local_roots+=1
				if feature.blocks_grass(p):invalid_local+=1
		total_roots+=row.root_count
	check(invalid_local==0,"Baked grass includes unsupported roots")
	check(local_roots*4==int(baked.pavilion_blades),"Local blade count does not match the bake")
	var protected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/east_earth_pavilion_1102/import_protected_hashes.json"))
	for path: String in protected:
		if path=="assets/world/tree_planting/world_edits.json":continue
		check(FileAccess.get_sha256("res://"+path)==protected[path],"Unrelated resource changed: "+path)
	report={"passed":failures.is_empty(),"failures":failures,"trees_repositioned":plan.changes.size(),
		"tree_max_ground_error_m":max_error,"effective_tree_count":actual.size(),"unrelated_trees_unchanged":true,
		"unchanged_xz_overlaps_thin_paving":thin_paving_overlaps,
		"grass_cells":feature.local_grass_cells,"total_roots":total_roots,"local_blades":local_roots*4,"unsupported_roots":invalid_local,
		"tree_save_sha256":grounding.after_sha256,"geometry_sha256":feature.manifest.mesh_sha256}
	if DisplayServer.get_name()!="headless":
		world.set_review_ui_visible(false)
		for name: String in ["overview","court","entry"]:
			var prefix: String="review" if name=="overview" else name
			await capture("planted_"+name,world.vec(feature.manifest[prefix+"_eye"]),world.vec(feature.manifest[prefix+"_target"]))
	FileAccess.open(OUT+"planting_verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PAVILION_PLANTING_REVIEW ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
