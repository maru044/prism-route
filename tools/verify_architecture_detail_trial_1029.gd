extends "res://tools/verify_initial_ruin_1029.gd"
const TRIAL_OUT="res://docs/architecture_detail_trial_1029/"
var trial

func capture_trial(name: String) -> void:
	await frames(16);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(TRIAL_OUT+name+".png")==OK,"Failed capture "+name)

func trial_checks() -> void:
	trial=world.surface_detail_trial
	var groups: Dictionary={};var original_meshes: Array=[];var collision_count: int=world.find_children("*","CollisionShape3D",true,false).size()
	for row: Dictionary in trial.records:
		groups[row.group]=int(groups.get(row.group,0))+1
		original_meshes.append(row.mesh.mesh)
		check(row.mesh.material_override==row.candidate,"Trial material missing on "+row.id)
	check(groups.get("main",0)==3 and groups.get("ruin",0)>0,"Missing intended trial hosts")
	trial.set_enabled(false)
	for row: Dictionary in trial.records:check(row.mesh.material_override==row.baseline,"Disabled trial did not restore exact original material")
	trial.set_enabled(true)
	trial.set_layer("plants",false)
	for material: ShaderMaterial in trial.materials.values():check(not material.get_shader_parameter("plants_enabled") and material.get_shader_parameter("joints_enabled"),"Layer toggles are coupled")
	trial.set_layer("plants",true)
	var original_color: String=trial.settings.plant_color
	trial.settings.plant_color="6699dd";trial.apply()
	var mirrors:=0
	for row: Dictionary in trial.records:
		for reflection_row: Dictionary in world.water_manager.proxy_records:
			if reflection_row.source!=row.mesh:continue
			mirrors+=1
			var mirror: ShaderMaterial=reflection_row.proxy.material_override
			check(mirror.shader.code.contains("procedural_leaf"),"Mirror lost detail shader")
			check(mirror.get_shader_parameter("plant_color")==Color("6699dd"),"Mirror color did not update")
	trial.settings.plant_color=original_color;trial.apply()
	trial.set_enabled(false)
	for row: Dictionary in trial.records:
		for reflection_row: Dictionary in world.water_manager.proxy_records:
			if reflection_row.source==row.mesh:check(not reflection_row.proxy.material_override.shader.code.contains("procedural_leaf"),"Mirror did not restore original material")
	trial.set_enabled(true)
	for i in trial.records.size():check(trial.records[i].mesh.mesh==original_meshes[i],"Trial modified source mesh")
	var first_original: Material=trial.records[0].baseline
	var host_count: int=trial.records.size()
	trial.reload_settings()
	check(trial.records.size()==host_count and trial.records[0].baseline==first_original,"Reload captured trial material as its original")
	check(collision_count==world.find_children("*","CollisionShape3D",true,false).size(),"Trial modified collisions")
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/architecture_trial_before/hashes.json"))
	var unchanged: Array[String]=[]
	for path: String in before:
		if path in ["scripts/map_1021.gd","scripts/water/water_manager.gd","shaders/environment/architecture_details_1029.gdshader","tools/configure_export_1021.gd","export_presets.cfg"]:continue
		check(FileAccess.get_sha256("res://"+path)==before[path],"Trial changed protected source "+path);unchanged.append(path)
	var bake: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.ASSETS+"grass_bake/manifest.json"))
	check(bake.complete and bake.signature==STORE.signature(world),"Visual trial invalidated grass bake")
	report.trial={"hosts":groups,"material_variants":trial.materials.size(),"reflection_hosts":mirrors,"exact_material_restore":true,"independent_layer_controls":true,"source_mesh_identity_unchanged":true,"collision_count":collision_count,"unchanged_files":unchanged,"grass_bake_valid":true}

func run() -> void:
	Engine.max_fps=60;root.size=Vector2i(1600,1000)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TRIAL_OUT))
	world=WORLD.instantiate();world.automation_enabled=true;root.add_child(world)
	while not world.test_ready:await process_frame
	await frames(8);trial_checks()
	world.set_review_ui_visible(false)
	for which in [0,1,2,3]:
		await trial.show_view(which);await frames(30)
		trial.set_enabled(false);await capture_trial("view_"+str(which)+"_before")
		trial.set_enabled(true);await capture_trial("view_"+str(which)+"_after")
	world.set_free(false);world.character_mode=true;world._sync_actor_controls()
	await interaction_checks()
	report.passed=failures.is_empty();report.failures=failures;report.adapter=RenderingServer.get_video_adapter_name()
	FileAccess.open(TRIAL_OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ARCHITECTURE_DETAIL_TRIAL_1029 ",JSON.stringify(report))
	world.queue_free();await frames(3);quit(0 if failures.is_empty() else 1)
