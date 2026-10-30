extends SceneTree
const OUT="res://docs/world_planting_1030/lifetime/"
const OFFICIAL="res://assets/world/tree_planting/world_edits.json"
var world
var failures: Array[String]=[]
var protected_sha: String
var save_path: String
func _initialize() -> void:call_deferred("run")
func frames(n:=4) -> void:
	for i in n:await physics_frame
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func handle(id: String) -> Node3D:
	for tree: Node3D in world.planting.trees():
		if tree.tree_id==id:return tree
	return null
func run() -> void:
	create_timer(180).timeout.connect(func():push_error("Planting lifetime test timed out");quit(1))
	AudioServer.set_bus_mute(0,true)
	protected_sha=FileAccess.get_sha256(OFFICIAL)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	save_path="res://.current_map_build/planting_lifetime_%d.json"%Time.get_ticks_usec()
	check(DirAccess.copy_absolute(ProjectSettings.globalize_path(OFFICIAL),ProjectSettings.globalize_path(save_path))==OK,"Cannot prepare isolated saved layout")
	world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true;world.planting_edits_path=save_path
	root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	await frames()
	var editor=world.planting;var ui=editor.runtime_editor
	editor.enter();ui.change_region(Vector3(-1200,13,20));await frames()
	var tree: Node3D
	for candidate: Node3D in editor.trees():
		if editor.store.baseline.has(candidate.tree_id):tree=candidate;break
	check(tree!=null,"No existing editable tree near the lake")
	if tree==null:quit(1);return
	var id: String=tree.tree_id
	ui.select_tree(tree);ui.values["大小"].value=tree.scale.x+.07;ui.finish_pending()
	check(editor.save_test()==OK,"Initial edited save failed");await frames()
	var play_copy: Node3D=editor.overrides[id]
	check(not play_copy.visible,"Original modified tree is doubled in editing")
	check(play_copy.pick_body.collision_layer==0,"Hidden play copy still intercepts editor selection rays")
	ui.select_tree(play_copy)
	check(ui.selected==null,"Editor accepted a play copy owned by the wrong parent")
	# This used to queue_free the play copy while leaving it in overrides;
	# remove_child first failed, then the next save assigned a freed instance.
	ui.delete_tree();await frames()
	check(is_instance_valid(play_copy),"Deleting rejected selection freed a play copy")
	check(editor.save_test()==OK,"Save after rejected selection failed");await frames()
	ui.select_tree(handle(id));ui.set_mode("move")
	var target: Vector3=ui.selected.global_transform*ui.selected.canopy_bounds.get_center()
	world.camera.position=target+Vector3(16,4,22);world.camera.look_at(target);await frames()
	var picked: Node3D=ui.pick_tree(world.camera.unproject_position(target))
	check(picked!=null and picked.get_parent()==editor.editable_parent,"Actual picking did not return an owned editable handle")
	for iteration in 3:
		ui.select_tree(handle(id));ui.delete_tree();await frames()
		check(editor.save_test()==OK,"Delete then save failed");await frames()
		check(editor.store.removed.has(id) and not editor.overrides.has(id),"Deleted tree left a stale play override")
		ui.undo();await frames();check(handle(id)!=null,"Undo failed after delete/save")
		check(editor.save_test()==OK,"Undo then save failed");await frames()
		ui.redo();await frames();check(editor.save_test()==OK,"Redo then save failed");await frames()
		ui.undo();await frames()
	# A stale external reference must also be harmless when rebuilding sources.
	var stale:=Node3D.new();editor.add_child(stale);editor.overrides["regression_stale"]=stale;stale.free()
	editor.set_source_visible("regression_stale",false)
	ui.select_tree(stale);ui.delete_tree()
	check(ui.selected==null,"A freed object was accepted as an editor selection")
	var stale_rebuild:=Node3D.new();editor.add_child(stale_rebuild);editor.overrides["regression_rebuild"]=stale_rebuild;stale_rebuild.free()
	editor.apply_world();await frames()
	check(not editor.overrides.has("regression_stale") and not editor.overrides.has("regression_rebuild"),"Dead override reference was not removed")
	for iteration in 3:
		ui.change_region(Vector3(-415,63,910));await frames()
		ui.change_region(Vector3(-1200,13,20));await frames()
		editor.leave();await frames();editor.enter();await frames()
	check(editor.save_test()==OK,"Save after repeated region/mode changes failed")
	check(FileAccess.get_sha256(OFFICIAL)==protected_sha,"User's official saved layout changed")
	var report={"passed":failures.is_empty(),"failures":failures,"working_save":save_path,"official_sha256":protected_sha,"delete_save_undo_redo_cycles":3,"region_mode_cycles":3,"stale_override_recovery":true,"exclusive_pick_ownership":true}
	FileAccess.open(OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PLANTING_LIFETIME_VERIFIED ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
