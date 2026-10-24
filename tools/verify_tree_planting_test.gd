extends SceneTree
const SCENE := preload("res://scenes/tree_planting_test.tscn")
const STORE := preload("res://scripts/tree_planting/layout_store.gd")
const PROFILE := preload("res://scripts/tree_planting/profile.gd")
const SPECIES := preload("res://scripts/tree_planting/species.gd")
const PALETTE := preload("res://scripts/tree_planting/palette.gd")
const OUT := "res://.vegetation_art_build/tree_planting_test/"
var failures: Array[String]=[]

func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await process_frame
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func reset_test_file(path: String) -> void:
	if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(path+".bak"):DirAccess.remove_absolute(ProjectSettings.globalize_path(path+".bak"))
func floor_body(parent: Node,point: Vector3,kind: String) -> void:
	var body:=StaticBody3D.new();body.position=point;body.set_meta("kind",kind);body.set_meta("source_id",kind)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(50,1,50)
	shape.shape=box;body.add_child(shape);parent.add_child(body)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Engine.max_fps=0
	var baseline_path:="res://assets/world/current_map_validation/tree_layout.json"
	var baseline_sha:=FileAccess.get_sha256(baseline_path)
	var main_scene:=FileAccess.get_sha256("res://scenes/map_1021.tscn")
	var scene=SCENE.instantiate();scene.profile=scene.profile.duplicate()
	scene.profile.test_edits_path=OUT+"edits.json";reset_test_file(scene.profile.test_edits_path)
	root.add_child(scene)
	for i in 600:
		if scene.ready_for_editing:break
		await process_frame
	check(scene.ready_for_editing,"Authoring scene did not become ready")
	if not scene.ready_for_editing:quit(1);return
	await frames(8)
	check(scene.store.baseline.size()==19604,"Legacy layout population changed")
	check(scene.trees().size()>0 and scene.trees().size()<=scene.profile.editable_limit,"Local editable population is invalid")
	check(scene.capture_active(),"Could not capture initial handles")
	check(scene.store.edits.is_empty() and scene.store.removed.is_empty(),"Merely opening the scene changed the layout")
	var first: Node3D=scene.trees()[0];var second: Node3D=scene.trees()[1]
	var first_id: String=first.tree_id;var second_id: String=second.tree_id
	var untouched: Dictionary=scene.store.baseline[scene.trees()[2].tree_id].duplicate(true)
	first.position.x+=4.25;first.palette=scene.profile.find_palette("cherry")
	var copy: Node3D=scene.make_tree(first.position+Vector3(8,0,0),first.species,first.palette)
	copy.rotation=first.rotation;copy.scale=first.scale
	scene.editable_parent.add_child(copy);copy.owner=scene
	var copy_id: String=copy.tree_id
	scene.editable_parent.remove_child(second);second.free()
	check(scene.save_test()==OK,"Could not save independent test layout")
	var reopened=STORE.new();check(reopened.open(scene.profile),"Could not reload saved layout")
	check(reopened.all_records().size()==19604,"Add/delete did not preserve population count")
	check(not reopened.all_records().has(second_id),"Deleted tree returned after reload")
	check(reopened.all_records()[first_id].palette=="cherry","Explicit palette was not saved")
	check(reopened.all_records().has(copy_id),"Duplicate lost its stable ID")
	check(reopened.all_records()[untouched.id]==untouched,"Editing affected a neighbouring tree")
	check(scene.save_test()==OK and FileAccess.file_exists(scene.profile.test_edits_path+".bak"),"Previous test layout was not backed up")
	# Native duplicate keeps the old ID initially; saving must allocate a new ID.
	var native_copy: Node3D=copy.duplicate();scene.editable_parent.add_child(native_copy);native_copy.owner=scene
	check(scene.capture_active() and native_copy.tree_id!=copy.tree_id,"Native duplicate did not get a unique ID")
	await frames(5)
	check(native_copy.get_child_count()==2 and native_copy.has_node("TreeVisual") and native_copy.has_node("TreePickBody"),"Native duplicate duplicated the generated visual or picking body")
	var remembered: Dictionary=scene.store.all_records()[first_id].duplicate(true)
	scene.load_nearby(Vector3(250,40,-30));scene.load_nearby(scene.profile.initial_center)
	check(scene.store.all_records()[first_id]==remembered,"Changing editing region lost an edit")
	# A lower-floor root must never snap to a roof above it; roads are rejected.
	floor_body(scene,Vector3(5000,9.5,5000),"Terrain")
	floor_body(scene,Vector3(5000,29.5,5000),"Structure")
	floor_body(scene,Vector3(5100,9.5,5000),"Road")
	var probe: Node3D=scene.make_tree(Vector3(5000,11,5000),first.species,first.palette)
	scene.add_child(probe)
	await physics_frame;await physics_frame
	var hit: Dictionary=scene.snap_position(probe)
	check(not hit.is_empty() and absf(hit.position.y-10)<0.01,"Snap selected the wrong storey")
	probe.position=Vector3(5100,11,5000)
	check(scene.snap_position(probe).is_empty(),"Snap accepted a road")
	probe.queue_free()
	check(FileAccess.get_sha256(baseline_path)==baseline_sha,"Production tree layout was modified")
	check(FileAccess.get_sha256("res://scenes/map_1021.tscn")==main_scene,"F5 scene was modified")
	# A different profile supports an empty baseline, a new species and new colours.
	var future=PROFILE.new();var asset=SPECIES.new();asset.id="future_tree";asset.display_name="Future tree"
	asset.model=scene.profile.species[0].model;asset.leaf_texture=scene.profile.species[0].leaf_texture
	var color=PALETTE.new();color.id="future_color";color.middle=Color("a2a2ee")
	future.species.assign([asset]);future.palettes.assign([color]);future.test_edits_path=OUT+"future.json"
	reset_test_file(future.test_edits_path)
	var future_store=STORE.new();check(future_store.open(future),"Empty future profile failed")
	var new_id: String=future_store.new_id()
	var row: Dictionary={"id":new_id,"position":[0,0,0],"yaw":0.0,"scale":1.0,"species":"future_tree","palette":"future_color","surface":""}
	var future_rows: Array[Dictionary]=[row];var future_ids: Array[String]=[]
	future_store.capture(future_rows,future_ids);check(future_store.save(future.test_edits_path,future)==OK,"Future species/palette failed to save")
	check(future_store.open(future) and future_store.all_records().has(new_id),"Future profile failed to reload")
	check(future_store.save(baseline_path,scene.profile)!=OK,"Store allowed writing the production baseline")
	var report:={"passed":failures.is_empty(),"failures":failures,"baseline_trees":19604,"local_handles":scene.trees().size(),
		"baseline_unchanged":FileAccess.get_sha256(baseline_path)==baseline_sha,"separate_profiles":true,"stable_ids":true}
	FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	if not DisplayServer.get_name()=="headless":
		await frames(30);await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"preview.png")
	print("TREE_PLANTING_TEST_RESULT ",JSON.stringify(report))
	scene.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
