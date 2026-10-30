extends SceneTree
const OUT="res://docs/world_planting_1030/birch/"
const DRAFT="res://.current_map_build/birch_planting_1030/edits.json"
const OFFICIAL="res://assets/world/tree_planting/world_edits.json"
const WORLD=preload("res://scenes/map_1021.tscn")
var world
var failures: Array[String]=[]
var report: Dictionary={}
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func frames(n: int) -> void:
	for i in n:await physics_frame
func capture(name: String,position: Vector3,target: Vector3) -> void:
	world.set_free(true);world.camera.position=position;world.camera.look_at(target)
	await frames(35);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func birch_ids() -> Array[String]:
	var ids: Array[String]=[]
	for row: Dictionary in world.planting.store.all_records().values():
		if row.id.begins_with("lake_birch_1030_"):ids.append(row.id)
	return ids
func check_visual(tree: Node3D) -> void:
	var assets=world.vegetation.birch_assets
	var leaf: MultiMeshInstance3D=tree.visual.get_node("Tree3_LOD0_Leaves")
	check(leaf.multimesh.mesh==assets.leaves[0],"Birch editor fell back to another tree mesh")
	check(leaf.material_override.get_shader_parameter("albedo_texture")==assets.LEAF,"Birch leaf texture missing")
	check(leaf.material_override.shader.resource_path.ends_with("tree_hlod_soft_backlight.gdshader"),"Birch does not use production foliage lighting")
	check(leaf.material_override.get_shader_parameter("species_mid_color")==assets.GREEN_VALUES.species_mid_color,"Generic saturated palette overrode birch")
	check(tree.visual.get_node("Tree3_LOD0_Trunks").material_override.albedo_texture==assets.BARK,"Birch white bark missing")
	for level in [1,2]:
		var node: MultiMeshInstance3D=tree.visual.get_node("Tree3_LOD1_Leaves" if level==1 else "Tree3_LOD2_Impostors")
		check(not node.material_override.get_shader_parameter("use_painted_foliage"),"Birch uses an unrelated painted atlas")
func run() -> void:
	create_timer(240).timeout.connect(func():push_error("Birch verification timed out");quit(1))
	if "--apply" in OS.get_cmdline_user_args():apply_verified_layout();return
	AudioServer.set_bus_mute(0,true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DRAFT.get_base_dir()))
	var reload_check: bool="--reload-check" in OS.get_cmdline_user_args()
	if not reload_check:
		report.official_sha=FileAccess.get_sha256(OFFICIAL)
		report.protected={}
		for path: String in ["assets/world/current_map_validation/tree_layout.json","assets/world/current_map_validation/grass_bake/manifest.json","assets/world/meadow_zone_1030/lake_green_sdf.res","assets/world/meadow_zone_1030/shore_green_sdf.res"]:report.protected[path]=FileAccess.get_sha256("res://"+path)
		check(DirAccess.copy_absolute(ProjectSettings.globalize_path(OFFICIAL),ProjectSettings.globalize_path(DRAFT))==OK,"Cannot prepare isolated birch draft")
	else:report=JSON.parse_string(FileAccess.get_file_as_string(OUT+"report.json"))
	world=WORLD.instantiate();world.automation_enabled=true;world.planting_edits_path=DRAFT
	root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	await frames(12)
	var editor=world.planting;var ui=editor.runtime_editor
	check(editor.load_error.is_empty(),"Planting layout failed to load")
	check(ui.species.item_count==4 and editor.profile.find_species("birch")!=null,"Birch missing from editor selector")
	if reload_check:await verify_reload();return
	report.before_count=editor.store.all_records().size()
	var previous: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OFFICIAL))
	# Plant on the lower grassy slope outside the western lake shore road.
	# Irregular clusters are deliberately separated by open views to the lake.
	var centers: Array[Vector3]=[Vector3(-1150,7,-65),Vector3(-1200,12,20),Vector3(-1220,18,130)]
	var offsets: Array[Vector2]=[Vector2(-10,-5),Vector2(3,3),Vector2(12,-9),Vector2(-4,15),Vector2(17,12)]
	var existing: Array[Vector3]=[]
	for row: Dictionary in editor.store.all_records().values():existing.append(Vector3(row.position[0],row.position[1],row.position[2]))
	var planted: Array[Dictionary]=[]
	for cluster in centers.size():
		var anchor: Vector3=centers[cluster];var best:=INF
		for p: Vector3 in existing:
			if p.y<3. or p.y>28.:continue
			var distance:=Vector2(p.x-anchor.x,p.z-anchor.z).length_squared()
			if distance<best:best=distance;centers[cluster]=p
		anchor=centers[cluster]
		for index in offsets.size():
			var accepted: Dictionary={}
			for attempt in 28:
				var offset: Vector2=offsets[index].rotated(cluster*.73)+Vector2(sin(attempt*2.4),cos(attempt*1.7))*float(attempt)*.85
				var p:=anchor+Vector3(offset.x,0,offset.y)
				var hit: Dictionary=editor.ray(p+Vector3.UP*9.,p-Vector3.UP*12.)
				if not editor.planting_hit(hit):continue
				p=hit.position
				if p.y<2. or p.y>30. or hit.normal.y<.92:continue
				if world.vegetation._grass_coverage(p,hit.normal)<.45:continue
				var blocked:=false
				for other: Vector3 in existing:
					if absf(p.y-other.y)<12. and Vector2(p.x-other.x,p.z-other.z).length()<5.5:blocked=true;break
				if blocked:continue
				accepted=hit;break
			if accepted.is_empty():continue
			var p: Vector3=accepted.position
			var row: Dictionary={"id":"lake_birch_1030_%02d_%02d"%[cluster,index],"species":"birch","palette":"green","position":[p.x,p.y,p.z],"scale":[1.1,.92,1.22,1.02,1.16][(index+cluster)%5],"yaw":fmod(index*2.399+cluster*1.1,TAU),"surface":accepted.collider.get_meta("source_id","")}
			editor.store.edits[row.id]=row;existing.append(p);planted.append(row)
	check(planted.size()>=12,"Too few suitable positions for the planned birch clusters")
	report.planted=planted;report.centers=centers.map(func(p):return [p.x,p.y,p.z])
	check(editor.store.save(DRAFT,editor.profile)==OK,"Birch draft save failed")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DRAFT))
	for old: Dictionary in previous.trees:
		check(saved.trees.any(func(row):return row==old),"An existing hand-edited tree changed")
	check(saved.removed==previous.removed,"Previous tree deletions changed")
	editor.apply_world();editor.enter();ui.change_region(centers[0]);await frames(8)
	var target_id: String=planted[0].id;var tree: Node3D
	for handle: Node3D in editor.trees():
		if handle.tree_id==target_id:tree=handle;break
	check(tree!=null,"New birch not selectable in editor")
	if tree!=null:
		ui.select_tree(tree);check_visual(tree)
		ui.set_mode("move");ui.duplicate_tree();await frames(3)
		check(ui.selected.species.id=="birch","Duplicating birch changed its species")
		ui.undo();await frames(3);check(ui.selected.tree_id==target_id,"Birch duplicate undo failed")
		ui.redo();await frames(3);check(ui.selected.species.id=="birch","Birch duplicate redo failed")
		ui.undo();await frames(3)
		ui.select_tree(ui.selected);ui.species.select(0);ui.apply_assets();await frames(3)
		ui.undo();await frames(3);check(ui.selected.species.id=="birch","Changing species undo lost birch")
		check_visual(ui.selected)
		ui.focus_selected();await frames(15);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"editor.png")
	editor.leave();world.set_review_ui_visible(false)
	await capture("planted_near",centers[0]+Vector3(34,12,38),centers[0]+Vector3(0,7,0))
	await capture("planted_groups",centers[1]+Vector3(100,60,100),centers[1]+Vector3.UP*5)
	report.first_pass=failures.is_empty();await finish(false)
func verify_reload() -> void:
	var editor=world.planting;var assets=world.vegetation.birch_assets
	check(report.first_pass,"Previous birch session failed")
	var ids:=birch_ids()
	check(ids.size()==report.planted.size(),"Reload lost birch records")
	check(world.vegetation.tree_instance_count==int(report.before_count)+ids.size(),"World tree population changed unexpectedly")
	for id: String in ids:
		check(editor.bindings.has(id),"Saved birch did not enter production batches")
		for binding: Dictionary in editor.bindings.get(id,[]):
			var node: MultiMeshInstance3D=binding.node
			check(str(node.name).begins_with("Tree3_"),"Saved birch became a generic tree")
			var row: Dictionary=editor.store.all_records()[id]
			var transform: Transform3D=node.global_transform*node.multimesh.get_instance_transform(binding.index)
			check(transform.origin.distance_to(Vector3(row.position[0],row.position[1],row.position[2]))<.002,"Birch moved after reload")
			if "Trunks" in str(node.name):check(node.material_override.albedo_texture==assets.BARK,"White bark missing from batch")
			else:
				check(node.material_override.shader.resource_path.ends_with("tree_hlod_soft_backlight.gdshader"),"Batch lighting differs from editor")
				check(node.material_override.get_shader_parameter("species_mid_color")==assets.GREEN_VALUES.species_mid_color,"Reload lost birch's muted palette")
	check(assets.leaves[1].get_faces().size()/3==48,"Birch middle LOD should have twelve double-sided cards")
	check(assets.leaves[2].get_faces().size()/3==4,"Birch far LOD should have one double-sided card")
	var bake: Dictionary=world.vegetation.volume_streamer.store.manifest
	check(bake.complete and bake.signature==preload("res://scripts/grass_baked_store.gd").signature(world),"Birch invalidated grass cache")
	world.set_review_ui_visible(false)
	var center:=Vector3(report.centers[0][0],report.centers[0][1],report.centers[0][2])
	await capture("reloaded",center+Vector3(34,12,38),center+Vector3(0,7,0))
	await capture("far",center+Vector3(350,140,80),center+Vector3(0,6,0))
	report.grass_signature=bake.signature;report.after_count=world.vegetation.tree_instance_count
	report.lod_triangles=assets.leaves.map(func(mesh):return mesh.get_faces().size()/3)
	await finish(true)
func finish(reloaded: bool) -> void:
	check(FileAccess.get_sha256(OFFICIAL)==report.official_sha,"Official tree layout changed during verification")
	for path: String in report.protected:check(FileAccess.get_sha256("res://"+path)==report.protected[path],"Protected mask/cache changed: "+path)
	report.passed=failures.is_empty() and reloaded;report.failures=failures;report.reloaded=reloaded;report.draft=DRAFT
	FileAccess.open(OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("BIRCH_VERIFIED first=",report.get("first_pass",false)," reloaded=",reloaded," trees=",report.planted.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)

func apply_verified_layout() -> void:
	report=JSON.parse_string(FileAccess.get_file_as_string(OUT+"report.json"))
	check(report.passed and report.reloaded,"Only a verified reloaded layout may be applied")
	check(FileAccess.get_sha256(OFFICIAL)==report.official_sha,"Official layout changed; merge new user edits before applying")
	if not failures.is_empty():quit(1);return
	var profile: Resource=load("res://assets/world/tree_planting_test/current_map.tres").duplicate()
	profile.test_edits_path=DRAFT
	var store=preload("res://scripts/tree_planting/layout_store.gd").new()
	check(store.open(profile),"Cannot read verified layout")
	if failures.is_empty():check(store.save(OFFICIAL,profile)==OK,"Cannot apply verified layout")
	if failures.is_empty():
		check(FileAccess.get_sha256(OFFICIAL+".bak")==report.official_sha,"Original layout backup mismatch")
		report.applied=true;report.applied_sha=FileAccess.get_sha256(OFFICIAL)
		report.backup=OFFICIAL+".bak"
		FileAccess.open(OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("BIRCH_LAYOUT_APPLIED ",failures.is_empty()," trees=",report.planted.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)
