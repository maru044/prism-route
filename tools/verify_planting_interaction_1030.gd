extends SceneTree
const WORLD=preload("res://scenes/map_1021.tscn")
const OUT="res://docs/world_planting_1030/interaction/"
var world
var ui
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func frames(n:=3) -> void:
	for i in n:await physics_frame
func key(code: int,ctrl:=false,shift:=false) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true;event.ctrl_pressed=ctrl;event.shift_pressed=shift
	root.push_input(event,true);await frames(2)
	event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames(2)
func pointer(p: Vector2,down: bool,alt:=false) -> void:
	var event:=InputEventMouseButton.new();event.position=p;event.global_position=p;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.alt_pressed=alt
	root.push_input(event,true);await frames(2)
func motion(p: Vector2,shift:=false,ctrl:=false) -> void:
	var event:=InputEventMouseMotion.new();event.position=p;event.global_position=p;event.button_mask=MOUSE_BUTTON_MASK_LEFT;event.shift_pressed=shift;event.ctrl_pressed=ctrl
	root.push_input(event,true);await frames(1)
func handle(id: String) -> Node3D:
	for tree: Node3D in world.planting.trees():
		if tree.tree_id==id:return tree
	return null
func canopy(tree: Node3D) -> Vector2:return world.camera.unproject_position(tree.global_transform*tree.canopy_bounds.get_center())
func run() -> void:
	create_timer(180).timeout.connect(func():push_error("Interaction verification timed out");quit(1))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	AudioServer.set_bus_mute(0,true)
	world=WORLD.instantiate();world.automation_enabled=true
	world.planting_edits_path="res://.current_map_build/planting_feel_%d.json"%Time.get_ticks_usec()
	root.add_child(world);current_scene=world
	while not world.test_ready:await process_frame
	await frames(6);world.planting.enter();ui=world.planting.runtime_editor
	var center:=Vector3(-940,70.08,1035);ui.change_region(center);await frames(6)
	var hero_id:="ring_HeroBroad";var tree: Node3D=handle(hero_id)
	var neighbour: Node3D=handle("ring_CompanionB");var neighbour_instance:=neighbour.get_instance_id()
	var start: Transform3D=tree.transform
	world.camera.position=center+Vector3(-22,12,24);world.camera.look_at(tree.global_position+Vector3.UP*7)
	ui.select_tree(tree);ui.set_mode("move");await frames(4)
	# Repeated click placement retains the same tool and selection.
	var hit: Dictionary=world.planting.ray(center+Vector3.UP*2,center-Vector3.UP*2)
	ui.move_to_hit(hit);check(ui.mode=="move" and ui.selected.tree_id==hero_id,"Move reset the tool or selection")
	ui.move_to_hit(hit);ui.undo();await frames(2)
	check(tree.transform.is_equal_approx(start),"Click move undo failed")
	check(handle("ring_CompanionB").get_instance_id()==neighbour_instance,"Undo rebuilt unrelated trees")
	# Actual viewport pointer events: tall-crown dragging, no initial jump,
	# several motion samples, and release over the GUI.
	var p:=canopy(tree);var cursor: int=ui.cursor
	await pointer(p,true)
	check(ui.gesture.dragging and tree.transform.is_equal_approx(start),"Pointer press jumped or failed to begin dragging")
	for i in range(1,6):await motion(p+Vector2(i*12.,0))
	await pointer(Vector2(65,500),false)
	check(not ui.gesture.dragging and ui.cursor==cursor+1,"Drag was not one undo step or got stuck over the sidebar")
	check(tree.position.distance_to(start.origin)>.4 and ui.mode=="move","Tall-crown drag failed or changed the tool")
	ui.undo();check(tree.transform.is_equal_approx(start),"One undo did not restore the complete drag")
	# Axis movement: X must not move Z, Y must retain horizontal coordinates.
	var axis_start: Vector3=tree.position
	ui.gesture.begin(tree,canopy(tree),"move","X");ui.gesture.update(canopy(tree)+Vector2(40,0));ui.gesture.finish()
	check(absf(tree.position.z-axis_start.z)<.001,"X handle moved the other horizontal axis")
	ui.undo()
	ui.gesture.begin(tree,canopy(tree),"move","Y");ui.gesture.update(canopy(tree)+Vector2(0,-35));ui.gesture.finish()
	check(absf(tree.position.x-axis_start.x)<.001 and absf(tree.position.z-axis_start.z)<.001 and tree.position.y>axis_start.y,"Vertical handle did not isolate elevation")
	ui.undo()
	# Rotation snapping and cancellation do not add history or alter the tool.
	await key(KEY_E);p=canopy(tree);cursor=ui.cursor
	ui.gesture.begin(tree,p,"rotate");ui.gesture.update(p+Vector2(37,0),false,true)
	check(absf(rad_to_deg(tree.rotation.y-start.basis.get_euler().y)-15.)<.02,"Rotation did not snap to 15 degrees")
	await key(KEY_ESCAPE)
	check(tree.transform.is_equal_approx(start) and ui.cursor==cursor and ui.mode=="rotate","Escape failed to cancel only the current gesture")
	var pivot: Vector2=ui.gizmo.endpoints().root
	await pointer(pivot+Vector2(55,0),true);await motion(pivot+Vector2(0,55));await pointer(pivot+Vector2(0,55),false)
	check(absf(rad_to_deg(tree.rotation.y-start.basis.get_euler().y)-90.)<.1,"Rotation ring is not interactive")
	ui.undo()
	await key(KEY_R);p=canopy(tree);ui.gesture.begin(tree,p,"scale");ui.gesture.update(p+Vector2(35,-35));ui.gesture.finish()
	check(tree.scale.x>start.basis.get_scale().x and ui.mode=="scale","Scale tool failed")
	await key(KEY_Z,true);check(tree.transform.is_equal_approx(start),"Ctrl+Z failed")
	await key(KEY_Z,true,true);check(tree.scale.x>start.basis.get_scale().x,"Ctrl+Shift+Z failed")
	ui.undo()
	pivot=ui.gizmo.endpoints().root
	await pointer(pivot+Vector2(55,-55),true);await motion(pivot+Vector2(75,-75));await pointer(pivot+Vector2(75,-75),false)
	check(tree.scale.x>start.basis.get_scale().x,"Scale handle is not interactive")
	ui.undo()
	# Alt-drag clones and transforms in one history entry; cancel leaves no copy.
	ui.set_mode("move");var count: int=world.planting.trees().size();p=canopy(tree);cursor=ui.cursor
	await pointer(p,true,true);await motion(p+Vector2(50,0));await pointer(p+Vector2(50,0),false)
	check(world.planting.trees().size()==count+1 and ui.cursor==cursor+1,"Alt-drag was not a single copy-and-move operation")
	ui.undo();await frames(2);check(world.planting.trees().size()==count,"Alt-drag undo did not remove only the copy")
	ui.select_tree(tree);p=canopy(tree);ui.gesture.begin(tree,p,"move","",true);ui.gesture.update(p+Vector2(35,0));ui.gesture.finish(false)
	check(world.planting.trees().size()==count and ui.selected==tree,"Cancelled Alt-drag left a copy or lost the original selection")
	# Numeric edits coalesce; text focus protects scene shortcuts.
	cursor=ui.cursor
	for i in range(1,7):ui.values.X.value=start.origin.x+float(i)*.2
	ui.finish_numeric();check(ui.cursor==cursor+1,"Numeric scrub generated multiple undo steps")
	ui.undo();check(tree.transform.is_equal_approx(start),"Numeric edit needed more than one undo")
	ui.set_mode("scale");ui.values.X.get_line_edit().grab_focus()
	var event:=InputEventKey.new();event.keycode=KEY_W;event.pressed=true;ui._input(event)
	check(ui.mode=="scale","Typing into a numeric field switched tools")
	get_root().gui_release_focus()
	ui.palette.select(1);ui.palette.item_selected.emit(1);await frames(3)
	check(tree.palette.id=="cherry","Palette selection still requires a separate Apply click")
	ui.undo();await frames(3)
	ui.set_mode("place");var original_scale: float=tree.scale.x
	ui.values["大小"].value=1.2;ui.values["旋转 °"].value=75.
	check(is_equal_approx(tree.scale.x,original_scale) and is_equal_approx(ui.placement_scale,1.2),"Placement settings modified the previously selected tree")
	ui.set_mode("scale")
	# Delete and duplicate retain the active tool. Undo reuses unrelated handles.
	ui.delete_tree();check(ui.mode=="scale","Delete reset the active tool")
	ui.undo();await frames(3);tree=handle(hero_id);ui.select_tree(tree)
	check(handle("ring_CompanionB").get_instance_id()==neighbour_instance,"Delete undo rebuilt the entire region")
	ui.duplicate_tree();check(ui.mode=="scale","Duplicate changed the active tool");ui.undo();await frames(3)
	tree=handle(hero_id);ui.select_tree(tree)
	# Returning from play retains tool, selection, view and undo history.
	var remembered_cursor: int=ui.cursor;var remembered_camera: Transform3D=world.camera.global_transform
	world.planting.leave();await frames(4);world.planting.enter();await frames(6)
	check(ui.mode=="scale" and ui.selected.tree_id==hero_id and ui.cursor==remembered_cursor,"Play/edit switching lost tool, selection or history")
	check(world.camera.global_transform.is_equal_approx(remembered_camera),"Returning to editing moved the camera")
	tree=ui.selected
	# Loading what's already in view must not teleport or reset the tool.
	world.camera.position=center+Vector3(-20,18,20);world.camera.look_at(center)
	var view: Transform3D=world.camera.global_transform;ui.load_from_view();await frames(6)
	check(world.camera.global_transform.is_equal_approx(view) and ui.mode=="scale","Load nearby moved the camera or reset the tool")
	tree=handle(hero_id);ui.select_tree(tree)
	var orientation: Basis=world.camera.basis;ui.focus_selected()
	check(world.camera.basis.is_equal_approx(orientation),"Focus changed the viewing direction unexpectedly")
	ui.navigation="look";ui.looking=true;await key(KEY_W)
	check(ui.mode=="scale","Camera flight key switched the active tool")
	ui.stop_navigation(false)
	ui.values["大小"].get_line_edit().grab_focus();ui.values["大小"].get_line_edit().text="9.00"
	await key(KEY_ESCAPE)
	check(absf(tree.scale.x-start.basis.get_scale().x)<.001,"Escape committed unfinished numeric text")
	var water: MeshInstance3D=world.upper_ring.material_set.water_mesh
	var pool: Vector3=water.global_transform*water.get_aabb().get_center()
	var water_hit: Dictionary=world.planting.ray(pool+Vector3.UP*2,pool-Vector3.UP*2)
	check(not world.planting.planting_hit(water_hit),"Placement accepted the reflecting pool as soil")
	# Save commits unfinished numeric text rather than silently saving old values.
	ui.values["大小"].get_line_edit().grab_focus();ui.values["大小"].get_line_edit().text="1.70"
	check(world.planting.save_test()==OK,"Save failed")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.planting.profile.test_edits_path))
	check(saved.trees.any(func(row):return row.id==hero_id and absf(float(row.scale)-1.7)<.001),"Save lost unfinished numeric text")
	get_root().gui_release_focus();ui.set_mode("move");ui.focus_selected();await frames(20);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"editor.png")
	var report={"passed":failures.is_empty(),"failures":failures,"pointer_drag":true,"gesture_undo":true,"incremental_undo":true,"axis_handles":true,"alt_drag":true,"numeric_transaction":true,"persistent_tools_and_mode_switch":true,"save_unsubmitted_field":true,"scene":world.scene_file_path}
	FileAccess.open(OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PLANTING_INTERACTION_VERIFIED ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
