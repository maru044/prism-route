extends "res://tools/verify_east_earth_pavilion_1102.gd"
## Inspect the repaired strip in the formal world with the current user planting save.
func native(p: Array) -> Vector3:return Vector3(p[0]-1450.,p[2],1150.-p[1])
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true
	root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	await frames(8)
	var fix: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/east_earth_pavilion_1102/entry_gap_fix.json"))
	var feature=world.earth_pavilion;var max_error:=0.;var previous_holes:=0;var path: Array=[];var window_bases:=0
	for sample: Dictionary in fix.samples:
		var p:=native(sample.point);var hit:=floor_at(p)
		check(not hit.is_empty(),"Entrance strip still has a hole: "+str(p))
		if not hit.is_empty():
			# The v=+0.2 samples lie under existing window plinths (62.10m).
			# Sample the repaired floor below those wall bases separately.
			if hit.collider.get_meta("source_id","")=="5e0c725b-0b01-4052-8023-d722b33fa630" and hit.position.y>p.y+.025:
				window_bases+=1
				check(absf(hit.position.y-62.10)<.005,"Unexpected window base height")
				var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.4,p-Vector3.UP*.6,32)
				query.hit_back_faces=true;query.exclude=[world.character.get_rid(),hit.collider.get_rid()]
				hit=world.get_world_3d().direct_space_state.intersect_ray(query)
				check(not hit.is_empty(),"Missing foundation beneath window base")
			if hit.is_empty():continue
			max_error=maxf(max_error,absf(hit.position.y-p.y))
			check(hit.collider.get_meta("earth_pavilion",false),"Strip still lands on the lower landscape")
		if sample.before_height==null:previous_holes+=1
		# A short real-controller pass spans both sides of the entrance.
		if absf(float(sample.point[1])-865.)<=24. and float(sample.point[1])-865.>=6.:
			# Samples for v=-1 differ by exactly 0.8/1.2m from their adjacent rows.
			var group: int=fix.samples.find(sample)%4
			if group==1:path.append(p)
	check(previous_holes>150 and max_error<.03,"Incorrect entrance finish height")
	if DisplayServer.get_name()=="headless":await walk(path,"entry_strip_forward")
	var protected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/east_earth_pavilion_1102/entry_gap_protected_hashes.json"))
	for file: String in protected:check(FileAccess.get_sha256("res://"+file)==protected[file],"Current user resource changed: "+file)
	var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(feature.GRASS_CONFIG))
	check(feature.local_grass_cells==config.cells.size(),"Updated grass bake was not installed")
	report.merge({"passed":failures.is_empty(),"failures":failures,"floor_samples":fix.samples.size(),"former_holes":previous_holes,
		"existing_window_base_samples":window_bases,
		"remaining_holes":0 if failures.is_empty() else -1,"max_floor_error_m":max_error,"grass_cells":feature.local_grass_cells,
		"tree_save_sha256":FileAccess.get_sha256(world.planting_edits_path),"protected_resources_unchanged":protected.size(),
		"geometry_sha256":feature.manifest.mesh_sha256})
	if DisplayServer.get_name()!="headless":
		world.set_review_ui_visible(false)
		var a:=native(fix.samples[161].point);var b:=native(fix.samples[121].point)
		await capture("entry_gap_closed",a+Vector3.UP*1.8,b+Vector3.UP*.25)
		await capture("entry_gap_overview",world.vec(feature.manifest.entry_eye),world.vec(feature.manifest.entry_target))
	var filename:="entry_gap_verification.json" if DisplayServer.get_name()=="headless" else "entry_gap_capture.json"
	FileAccess.open(OUT+filename,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PAVILION_ENTRY_GAP_REVIEW ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
