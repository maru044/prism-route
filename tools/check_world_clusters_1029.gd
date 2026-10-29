extends Node
const OUT="res://docs/world_leaf_clusters_v6_1029/"
const STORE=preload("res://scripts/grass_baked_store.gd")
var world
var failures: Array[String]=[]
func check(value: bool,message: String) -> void:
	if not value:failures.append(message);push_error(message)
func frames(n: int) -> void:
	for i in n:await get_tree().physics_frame
func capture(name: String) -> void:
	await frames(10);await RenderingServer.frame_post_draw
	check(get_tree().root.get_texture().get_image().save_png(OUT+name+".png")==OK,"Capture failed: "+name)
func run() -> void:
	get_tree().create_timer(120).timeout.connect(func():get_tree().quit(1))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await frames(3)
	var trial=world.surface_detail_trial;var layer=trial.cluster_layer
	check(get_tree().current_scene==world,"Verification did not load the real map")
	check(layer.report.clusters.main>0 and layer.report.clusters.ruin>0,"Missing cliff or ruin leaf cards")
	var visible_clusters: Dictionary={"main":0,"ruin":0}
	for node: MultiMeshInstance3D in layer.batches:
		var group: String=node.get_meta("placement_rows")[0].group
		var group_enabled: bool=bool(trial.settings.get("cliff_plants_enabled",true)) if group=="main" else bool(trial.settings.get("ruin_plants_enabled",true))
		check(node.visible==(trial.enabled and bool(trial.settings.plants_enabled) and group_enabled),"Plant host switch ignored: "+group)
		if node.visible:visible_clusters[group]+=node.multimesh.visible_instance_count
	var preview_entry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/architecture_details_1029/preview_entry.json"))
	check(layer.report.texture_sha256==preview_entry.texture_sha256,"World texture differs from the reviewed preview")
	check(layer.report.shader==preview_entry.shader,"World shader differs from the reviewed preview")
	check(layer.report.factory_sha256==FileAccess.get_sha256("res://scripts/world/wall_leaf_clusters.gd"),"World shared factory differs")
	check(layer.find_children("*","CollisionShape3D",true,false).is_empty(),"Leaf cards added collisions")
	for node: MultiMeshInstance3D in layer.batches:
		check(node.material_override==layer.material and node.layers&(1<<19)!=0,"Leaf batches missing shared material or reflection layer")
		for i in node.multimesh.instance_count:
			var basis: Basis=node.multimesh.get_instance_transform(i).basis
			check(absf(basis.x.length()-basis.y.length())<.0001 and basis.x.length()<=2.201*float(trial.settings.plant_scale),"Cluster scale differs from small preview")
	for material: ShaderMaterial in trial.materials.values():check(not material.get_shader_parameter("plants_enabled"),"Old leaf scatter is still enabled")
	await capture("startup_world_v6")
	world.set_review_ui_visible(false)
	await trial.show_view(3);await capture("ruin_overview")
	await trial.show_view(1)
	for scale_value in [1.,1.35,1.6]:
		trial.set_cluster_scale(scale_value);await capture("ruin_scale_%.2f"%scale_value)
	trial.set_cluster_scale(1.35);await capture("ruin_close")
	trial.settings.environment_look_enabled=false;trial.settings.surface_look_enabled=false;trial.apply();await capture("ruin_original_surface_light")
	check(is_equal_approx(world.water_manager.main_environment.tonemap_exposure,.82),"Environment toggle did not restore exposure")
	trial.settings.environment_look_enabled=true;trial.settings.surface_look_enabled=true;trial.apply()
	check(layer.material.get_shader_parameter("use_biome_palette") and layer.material.get_shader_parameter("species_biome_tint"),"Wall foliage did not inherit environment tint")
	trial.set_layer("plants",false);await capture("ruin_without_clusters")
	for node: MultiMeshInstance3D in layer.batches:check(not node.visible,"Leaf toggle left a batch visible")
	trial.set_layer("plants",true)
	await trial.show_view(4);await capture("cliff_close")
	trial.set_layer("plants",false);await capture("cliff_without_clusters");trial.set_layer("plants",true)
	await trial.show_view(2);await capture("cliff_walkway")
	trial.set_enabled(false)
	for row: Dictionary in trial.records:check(row.mesh.material_override==row.baseline,"Disabled trial did not restore source material")
	trial.set_enabled(true)
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/foliage_v6_before/protected_hashes.json"))
	var unchanged: Dictionary={}
	for path: String in before:
		unchanged[path]=FileAccess.get_sha256("res://"+path)==before[path];check(unchanged[path],"Modified source asset: "+path)
	var bake: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.ASSETS+"grass_bake/manifest.json"))
	check(bake.complete and bake.signature==STORE.signature(world),"Grass bake invalidated")
	# Exercise the existing E trigger once with the new projection receivers active.
	world.set_free(false);world.character_mode=true;world._sync_actor_controls()
	var ruin=world.initial_ruin;var forward: Vector3=world.vec(ruin.planting_mask.manifest.forward)
	var near: Vector3=ruin.avatar.global_position-forward*2.45;near.y=61.09
	world.character.set_spawn(near,.38);await frames(14)
	check(ruin.can_interact(),"Summon prompt is no longer reachable")
	var event:=InputEventKey.new();event.keycode=KEY_E;event.physical_keycode=KEY_E;event.pressed=true;Input.parse_input_event(event)
	var release:=InputEventKey.new();release.keycode=KEY_E;release.physical_keycode=KEY_E;release.pressed=false;Input.parse_input_event(release)
	await frames(240);check(ruin.state==ruin.State.PRINTED and ruin.print_count==1,"E materialization regressed")
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"actual_scene":world.scene_file_path,"window_title":world.get_window().title,"revision":trial.settings.revision,"clusters":layer.report,"visible_clusters":visible_clusters,"unchanged_assets":unchanged,"grass_bake_valid":true,"summon_print_count":ruin.print_count,"adapter":RenderingServer.get_video_adapter_name()}
	var placements: Array=[]
	for row: Dictionary in layer.placements:placements.append({"group":row.group,"source_id":row.source_id,"top":[row.top.x,row.top.y,row.top.z],"normal":[row.normal.x,row.normal.y,row.normal.z],"size":row.size,"cell":row.cell,"mirror":row.mirror,"role":row.role,"path_id":row.path_id})
	FileAccess.open(OUT+"placements.json",FileAccess.WRITE).store_string(JSON.stringify(placements,"  "))
	FileAccess.open(OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WORLD_LEAF_CLUSTERS_VERIFIED ",JSON.stringify(report));get_tree().quit(0 if failures.is_empty() else 1)
