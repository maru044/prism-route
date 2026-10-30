extends "res://tools/verify_meadow_zone_1030.gd"
const SHORE_OUT="res://docs/meadow_zone_1030/shore/"
func capture(name: String,eye: Vector3,target: Vector3) -> void:
	world.set_free(true);world.camera.global_position=eye;world.camera.look_at(target)
	await frames(65);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(SHORE_OUT+name+".png")==OK,"Failed shoreline capture")
func run() -> void:
	create_timer(180).timeout.connect(func():push_error("Shoreline verification timed out");quit(1))
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHORE_OUT))
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true;root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	world.set_review_ui_visible(false);await frames(8)
	var noise_texture: Texture2D=world.vegetation.grass_material.get_shader_parameter("biome_noise_texture");noise_image=noise_texture.get_image()
	var previous: Dictionary=PALETTE.ZONE.duplicate();previous.biome_shore_enabled=false
	var outside_count:=0;var outside_delta:=0.;var initial_count:=0;var initial_delta:=0.;var upper_delta:=0.;var reduced:=0
	var newly_green: Array=[];var changed:=0
	var shore:=Vector3(-1120,2,-80);var nearest:=INF
	for row: Dictionary in world.planting.store.all_records().values():
		var p:=Vector3(row.position[0],row.position[1],row.position[2])
		var old:=green(p,previous);var current:=green(p,PALETTE.ZONE);var delta:=absf(current-old)
		if delta>.00001:changed+=1
		if current<old-.000001:reduced+=1
		if local_weight(p,true)==0.:outside_count+=1;outside_delta=maxf(outside_delta,delta)
		if p.z>=850.:initial_count+=1;initial_delta=maxf(initial_delta,delta)
		if p.y>=60.:upper_delta=maxf(upper_delta,delta)
		if p.y<40 and local_weight(p,true)>.999 and old<.8:
			newly_green.append(current)
			if p.distance_squared_to(Vector3(-1120,2,-80))<nearest:nearest=p.distance_squared_to(Vector3(-1120,2,-80));shore=p
	check(not newly_green.is_empty() and newly_green.all(func(weight):return weight>.939),"Previously yellow lake shore did not turn green")
	check(outside_count>0 and outside_delta<.000001,"Changes escaped the new shoreline outline")
	check(initial_count>0 and initial_delta<.000001,"Initial region changed")
	check(upper_delta<.000001 and reduced==0,"Existing upper colours or previous green areas changed")
	var bake: Dictionary=world.vegetation.volume_streamer.store.manifest
	check(bake.complete and bake.signature==STORE.signature(world),"Shore colour change invalidated grass cache")
	zone(previous,35.)
	await capture("overview_before",Vector3(-160,1800,2100),Vector3(-250,15,400))
	await capture("shore_before",shore+Vector3(40,16,55),shore+Vector3.UP)
	zone(PALETTE.ZONE,35.)
	await capture("overview_after",Vector3(-160,1800,2100),Vector3(-250,15,400))
	await capture("shore_after",shore+Vector3(40,16,55),shore+Vector3.UP)
	for parameter: String in PALETTE.BIOME_PARAMETERS:check(world.terrain_material.get_shader_parameter(parameter)==world.vegetation.grass_material.get_shader_parameter(parameter),"Ground/grass colour masks differ")
	for row: Dictionary in world.foliage_style.records:
		if row.green:
			for parameter: String in PALETTE.BIOME_PARAMETERS:check(row.material.get_shader_parameter(parameter)==world.vegetation.grass_material.get_shader_parameter(parameter),"Green foliage mask differs")
	var hashes: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/lake_shore_before/hashes.json"))
	for path: String in hashes:check(FileAccess.get_sha256("res://"+path)==hashes[path],"Protected layout/cache or previous lake mask changed: "+path)
	var report={"passed":failures.is_empty(),"failures":failures,"newly_green_shore_samples":newly_green.size(),"changed_samples":changed,"outside_samples":outside_count,"outside_maximum_change":outside_delta,"initial_samples":initial_count,"initial_maximum_change":initial_delta,"upper_terrace_maximum_change":upper_delta,"previous_green_reductions":reduced,"grass_signature":bake.signature,"tree_count":world.vegetation.tree_instance_count,"capture_root":str(shore),"previous_lake_mask_unchanged":true}
	FileAccess.open(SHORE_OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("LAKE_SHORE_VERIFIED ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
