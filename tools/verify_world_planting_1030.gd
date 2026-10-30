extends SceneTree
const OUT="res://docs/world_planting_1030/"
const WORLD=preload("res://scenes/map_1021.tscn")
const STORE=preload("res://scripts/grass_baked_store.gd")
var world
var failures: Array[String]=[]
var report: Dictionary={}
var save_path: String
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func frames(n: int) -> void:
	for i in n:await physics_frame
func open_world() -> void:
	world=WORLD.instantiate();world.automation_enabled=true;world.planting_edits_path=save_path
	root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	await frames(12)
func find_handle(id: String) -> Node3D:
	for tree: Node3D in world.planting.trees():
		if tree.tree_id==id:return tree
	return null
func native_visible(id: String) -> bool:
	for binding: Dictionary in world.planting.bindings.get(id,[]):
		if binding.node.multimesh.get_instance_transform(binding.index).basis.x.length()>.01:return true
	return false
func capture(name: String) -> void:
	await frames(28);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func hotkey() -> void:
	var event:=InputEventKey.new();event.keycode=KEY_F4;event.physical_keycode=KEY_F4;event.pressed=true
	root.push_input(event,true);await frames(3)
	event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames(3)
func run() -> void:
	create_timer(240).timeout.connect(func():push_error("World planting verification timed out");quit(1))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.current_map_build/world_planting_1030/"))
	save_path="res://.current_map_build/world_planting_1030/edits_%d.json"%Time.get_ticks_usec()
	AudioServer.set_bus_mute(0,true)
	if "--reload-check" in OS.get_cmdline_user_args():await reload_check();return
	var protected: Dictionary={}
	for path: String in ["assets/world/current_map_validation/tree_layout.json","assets/world/current_map_validation/current_region.glb","assets/world/current_map_validation/grass_bake/manifest.json","assets/world/upper_ring_1030/manifest.json"]:protected[path]=FileAccess.get_sha256("res://"+path)
	await open_world()
	var editor=world.planting;var ui=editor.runtime_editor
	var initial_count: int=editor.store.all_records().size()
	check(initial_count==19418 and world.vegetation.tree_instance_count==initial_count,"Initial production population changed")
	check(not editor.active and not ui.visible,"Editor should start closed in F5")
	var bake: Dictionary=world.vegetation.volume_streamer.store.manifest
	check(bake.complete and bake.signature==STORE.signature(world),"Tree editing invalidated the grass bake")
	var actor_position: Vector3=world.character.global_position
	await hotkey();check(editor.active and ui.panel.is_visible_in_tree(),"F4 failed to enter editing")
	check(world.character.process_mode==Node.PROCESS_MODE_DISABLED,"Character is not paused while editing")
	var center:=Vector3(-940,70.08,1035)
	ui.change_region(center);await frames(8)
	var hero_id: String="ring_"+str(world.upper_ring.manifest.trees[0].name)
	var deleted_id: String="ring_"+str(world.upper_ring.manifest.trees[1].name)
	var hero: Node3D=find_handle(hero_id)
	check(hero!=null and find_handle(deleted_id)!=null,"Authored courtyard trees are not editable")
	check(not native_visible(hero_id),"Editable tree is doubled by the original batch")
	var natural: Node3D
	for tree: Node3D in editor.trees():
		if tree.tree_id.begins_with("base_"):natural=tree;break
	check(natural!=null,"Existing random trees are missing from editing")
	var natural_id: String=natural.tree_id
	ui.select_tree(natural);ui.values.X.value=natural.position.x+1.
	editor.capture_active();check(editor.store.edits.has(natural_id),"Existing random tree cannot be edited")
	editor.restore_selected();await frames(3);editor.capture_active()
	check(not editor.store.edits.has(natural_id),"Restoring a random tree left an unnecessary override")
	var visual: MultiMeshInstance3D=hero.visual.find_child("*LOD0_Leaves",true,false)
	check(visual.multimesh.mesh==world.vegetation.tree_large_broad_leaf_mesh,"Editable tree differs from production mesh")
	check(visual.material_override.shader.resource_path.ends_with("tree_hlod_soft_backlight.gdshader"),"Editor uses different foliage rendering")
	ui.select_tree(hero);ui.focus_selected();await frames(4)
	var point: Vector3=hero.global_transform*hero.canopy_bounds.get_center()
	check(ui.pick_tree(world.camera.unproject_position(point))!=null,"Screen selection ray missed the courtyard tree")
	ui.select_tree(hero)
	var old_x: float=hero.position.x
	ui.values.X.value=old_x+2.5;ui.values["大小"].value=1.65;ui.values["旋转 °"].value=25
	ui.palette.select(1);ui.apply_assets();await frames(5)
	check(hero.palette.id=="cherry" and is_equal_approx(hero.scale.x,1.65),"Tree controls failed")
	ui.undo();await frames(3);check(ui.selected.palette.id=="green","Undo did not restore palette")
	ui.redo();await frames(3);check(ui.selected.palette.id=="cherry","Redo did not restore palette")
	await hotkey();await frames(5)
	check(not editor.active and editor.overrides.has(hero_id),"Unsaved changes missing in play mode")
	check(not FileAccess.file_exists(save_path) and editor.dirty_session,"Mode switch unexpectedly saved or lost dirty state")
	check(world.character.global_position.distance_to(actor_position)<.2,"Mode switch moved the player")
	check(not native_visible(hero_id),"Modified tree duplicates its old position")
	# Restore a modified tree all the way back to the original native batch.
	await hotkey();ui.change_region(center);await frames(4)
	ui.select_tree(find_handle(hero_id));editor.restore_selected();await frames(4)
	await hotkey();await frames(4)
	check(native_visible(hero_id) and not editor.overrides.has(hero_id),"Restoring the baseline left the original tree invisible")
	await hotkey();ui.change_region(center);await frames(4)
	ui.select_tree(find_handle(hero_id));ui.values.X.value=old_x+2.5;ui.values["大小"].value=1.65
	ui.palette.select(1);ui.apply_assets();await frames(3)
	ui.select_tree(find_handle(deleted_id));ui.delete_tree();ui.undo();await frames(3)
	check(find_handle(deleted_id)!=null,"Delete undo failed")
	ui.redo();await frames(3);check(find_handle(deleted_id)==null,"Delete redo failed")
	var hit: Dictionary=editor.ray(center+Vector3.UP*2,center-Vector3.UP*2)
	check(editor.planting_hit(hit),"Real courtyard floor is not plantable")
	ui.species.select(0);ui.palette.select(2);ui.place_at_hit(hit);await frames(4)
	var added_id: String=ui.selected.tree_id
	ui.values["大小"].value=1.1
	ui.duplicate_tree();await frames(3);ui.undo();await frames(3)
	check(editor.active_ids.has(added_id),"Duplicate undo lost the added tree")
	check(editor.save_test()==OK and FileAccess.file_exists(save_path),"Save and apply failed")
	check(not editor.dirty_session,"Save did not clear dirty state")
	check(editor.save_test()==OK and FileAccess.file_exists(save_path+".bak"),"Previous save backup missing")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(saved.trees.size()==2 and saved.removed==[deleted_id],"Sparse save contains unchanged population or lost edits")
	ui.select_tree(find_handle(hero_id));ui.focus_selected()
	await capture("editing")
	ui.change_region(Vector3(250,40,-30));ui.change_region(center);await frames(5)
	check(find_handle(deleted_id)==null and find_handle(added_id)!=null,"Region switch resurrected a deleted tree or lost an added tree")
	check(is_equal_approx(find_handle(hero_id).scale.x,1.65),"Region switch lost edited scale")
	await hotkey();await frames(6)
	check(world.world_audio.tree_grid.values().reduce(func(total,list):return total+list.size(),0)==initial_count,"Ambient tree grid does not use the edited population")
	check(editor.overrides.size()==2 and not native_visible(deleted_id),"Play mode has incorrect visual overrides")
	# Repeated switching must not leave stale reflection references or handles.
	for iteration in 3:
		await hotkey();await frames(4);await hotkey();await frames(4)
	check(editor.trees().is_empty() and editor.overrides.size()==2,"Repeated mode switching accumulated editable trees")
	world.set_free(true);world.camera.position=center+Vector3(-20,7,20);world.camera.look_at(center+Vector3.UP*7)
	world.set_review_ui_visible(false);await capture("playing")
	report.first_session={"population":initial_count,"edited_records":saved.trees.size(),"deleted_records":saved.removed.size(),"active_handles_after_play":editor.trees().size(),"grass_signature":bake.signature}
	report.expected={"hero_id":hero_id,"deleted_id":deleted_id,"added_id":added_id,"hero":editor.store.all_records()[hero_id]}
	report.protected=protected;report.working_save=save_path
	report.first_session_passed=failures.is_empty();report.failures=failures;report.passed=false
	FileAccess.open(OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WORLD_PLANTING_SESSION ",JSON.stringify(report.first_session)," failures=",failures);quit(0 if failures.is_empty() else 1)

func reload_check() -> void:
	report=JSON.parse_string(FileAccess.get_file_as_string(OUT+"report.json"))
	save_path=report.working_save
	check(report.first_session_passed,"Previous editing session failed")
	await open_world()
	var editor=world.planting
	var hero_id: String=report.expected.hero_id;var deleted_id: String=report.expected.deleted_id;var added_id: String=report.expected.added_id
	check(editor.store.removed.has(deleted_id) and not editor.bindings.has(deleted_id),"Restart resurrected a deleted tree")
	check(editor.bindings.has(added_id),"Added tree was not rendered after restart")
	check(is_equal_approx(float(editor.rendered_records[hero_id].scale),1.65),"Restart lost edited scale")
	check(absf(float(editor.rendered_records[hero_id].position[0])-float(report.expected.hero.position[0]))<.001,"Restart lost edited position")
	check(world.vegetation.tree_instance_count==int(report.first_session.population),"Restart duplicated or lost trees")
	for id: String in [hero_id,added_id]:
		var expected: Dictionary=editor.store.all_records()[id]
		for binding: Dictionary in editor.bindings[id]:
			var transform: Transform3D=binding.node.global_transform*binding.node.multimesh.get_instance_transform(binding.index)
			check(transform.origin.distance_to(Vector3(expected.position[0],expected.position[1],expected.position[2]))<.002,"Reloaded mesh is at a different position from saved data")
			check(absf(transform.basis.x.length()-float(expected.scale))<.001,"Reloaded mesh has a different scale from saved data")
	await hotkey();editor.runtime_editor.change_region(Vector3(-940,70.08,1035));await frames(6)
	check(find_handle(deleted_id)==null and find_handle(added_id)!=null,"Reopened editor disagrees with play population")
	editor.runtime_editor.select_tree(find_handle(hero_id));editor.runtime_editor.focus_selected();await capture("reloaded")
	for path: String in report.protected:check(FileAccess.get_sha256("res://"+path)==report.protected[path],"Protected source changed: "+path)
	report.passed=failures.is_empty();report.failures=failures;report.save_reload=true;report.shared_scene=world.scene_file_path;report.working_save=save_path
	FileAccess.open(OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WORLD_PLANTING_VERIFIED ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
