extends SceneTree
const SCENE := preload("res://scenes/tree_planting_test.tscn")
const STORE := preload("res://scripts/tree_planting/layout_store.gd")
const OUT := "res://.vegetation_art_build/tree_planting_test/"
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func frames(count: int) -> void:
	for i in count:await process_frame
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var baseline_path:="res://assets/world/current_map_validation/tree_layout.json"
	var baseline_sha:=FileAccess.get_sha256(baseline_path)
	var main_sha:=FileAccess.get_sha256("res://scenes/map_1021.tscn")
	var scene=SCENE.instantiate();scene.profile=load(scene.profile_path).duplicate()
	scene.profile.test_edits_path=OUT+"runtime_edits.json"
	for suffix: String in ["",".bak"]:
		if FileAccess.file_exists(scene.profile.test_edits_path+suffix):DirAccess.remove_absolute(scene.profile.test_edits_path+suffix)
	root.add_child(scene)
	for i in 1200:
		if scene.ready_for_editing and scene.runtime_editor!=null:break
		await process_frame
	if scene.runtime_editor==null:push_error("Runtime editor did not start");quit(1);return
	await frames(12);await physics_frame;await physics_frame
	for item: Node3D in scene.trees():
		for leaf: MeshInstance3D in item.leaf_nodes:
			var material:=leaf.material_override as ShaderMaterial
			check(material.get_shader_parameter("species_biome_tint")==item.palette.follow_world_biome,"Planting palette biome opt-in is wrong")
			if item.palette.follow_world_biome:
				for parameter: String in preload("res://scripts/foliage_style.gd").BIOME_PARAMETERS:
					check(material.get_shader_parameter(parameter)==scene.profile.terrain_material.get_shader_parameter(parameter),"Planting tree uses a different world zone")
	var ui=scene.runtime_editor
	check(ui.panel.is_visible_in_tree(),"Runtime controls are not visible")
	check(ui.region.item_count==10 and ui.species.item_count==3 and ui.palette.item_count==6,"Configuration selectors are incomplete")
	var tree: Node3D=scene.trees()[0];var id: String=tree.tree_id
	ui.select_tree(tree);ui.focus_selected();await frames(4)
	var point: Vector3=tree.global_transform*tree.canopy_bounds.get_center()
	var screen: Vector2=scene.camera.unproject_position(point)
	var picked: Node3D=ui.pick_tree(screen)
	var pick_worked: bool=picked!=null
	check(pick_worked,"Screen ray could not select a visible canopy")
	ui.select_tree(tree)
	var original: String=tree.palette.id
	ui.palette.select(1);ui.apply_assets()
	check(tree.palette.id=="cherry","Runtime palette control failed")
	ui.undo();check(ui.selected.palette.id==original,"Undo did not restore the old colour")
	ui.redo();check(ui.selected.palette.id=="cherry","Redo did not restore the changed colour")
	var x: float=ui.selected.position.x
	ui.values.X.value=x+3.5
	check(absf(ui.selected.position.x-x-3.5)<0.051,"Position field failed")
	ui.values["旋转 °"].value=37;ui.values["大小"].value=1.25
	check(absf(ui.selected.rotation_degrees.y-37)<0.01 and absf(ui.selected.scale.x-1.25)<0.01,"Rotation/scale fields failed")
	var count: int=scene.trees().size()
	ui.duplicate_tree();check(scene.trees().size()==count+1,"Duplicate failed")
	ui.undo();check(scene.trees().size()==count,"Duplicate undo failed")
	ui.redo();check(scene.trees().size()==count+1,"Duplicate redo failed")
	ui.delete_tree();check(scene.trees().size()==count,"Delete failed")
	ui.undo();check(scene.trees().size()==count+1,"Delete undo failed")
	await frames(5);await physics_frame
	var hit: Dictionary=scene.snap_position(ui.selected)
	check(not hit.is_empty(),"Runtime terrain ray missed the current floor")
	if not hit.is_empty():
		ui.move_to_hit(hit);check(ui.mode=="select","Move did not finish in selection mode")
		ui.set_mode("place");ui.palette.select(2);ui.place_at_hit(hit)
		check(scene.trees().size()==count+2 and ui.selected.palette.id=="gold","Click placement did not use the selected palette")
		check(ui.mode=="place","Repeated planting mode was lost")
	ui.save_layout()
	check(not scene.dirty_session,"Saving did not clear the dirty indicator")
	var reopened=STORE.new();check(reopened.open(scene.profile),"Saved runtime edits could not be reloaded")
	check(reopened.all_records()[id].palette=="cherry","Edited colour did not survive saving")
	var remembered: Dictionary=reopened.all_records()[id].duplicate(true)
	ui.change_region(Vector3(250,40,-30));ui.change_region(scene.profile.initial_center)
	check(STORE.same_tree(scene.store.all_records()[id],remembered),"Region switch lost a saved edit")
	check(ui.history.is_empty(),"Region switch kept invalid local undo actions")
	check(FileAccess.get_sha256(baseline_path)==baseline_sha and FileAccess.get_sha256("res://scenes/map_1021.tscn")==main_sha,"Production map/layout changed")
	scene.dirty_session=true;ui.request_close();check(ui.close_dialog.visible,"Unsaved session did not request save before exit")
	ui.close_dialog.hide()
	if not DisplayServer.get_name()=="headless":
		await frames(25);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"runtime_preview.png")
	var report:={"passed":failures.is_empty(),"failures":failures,"runtime_ui":true,"pick_ray":pick_worked,
		"undo_redo":true,"save_reload":true,"production_unchanged":true}
	FileAccess.open(OUT+"runtime_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TREE_PLANTING_RUNTIME_RESULT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
