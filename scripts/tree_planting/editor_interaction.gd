extends RefCounted
## One pointer gesture is one undo step. Never change the active tool implicitly.
var ui
var dragging:=false
var changed:=false
var kind:="move"
var axis:=""
var before: Dictionary={}
var start_screen:=Vector2.ZERO
var start_transform:=Transform3D.IDENTITY
var start_surface:=""
var grab_point:=Vector3.ZERO
var screen_offset:=Vector2.ZERO
var original: Node3D
var copied:=false
var valid_target:=true

func ground_plane(screen: Vector2,height: float) -> Variant:
	var camera: Camera3D=ui.scene.camera
	return Plane(Vector3.UP,height).intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))

func begin(tree: Node3D,screen: Vector2,tool: String,locked_axis:="",duplicate:=false) -> void:
	if not ui.owns_tree(tree):return
	ui.finish_numeric();ui.select_tree(tree)
	before=ui.snapshot();original=tree;copied=duplicate;kind=tool;axis=locked_axis
	if duplicate:
		var row: Dictionary=tree.to_record();row.id=ui.scene.store.new_id()
		var copy: Node3D=ui.scene.create_tree(row) if ui.integrated else ui.scene.make_tree(tree.position,tree.species,tree.palette,tree.surface_id)
		copy.transform=tree.transform;ui.scene.editable_parent.add_child(copy);ui.scene.active_ids.append(copy.tree_id);ui.select_tree(copy)
	start_transform=ui.selected.transform;start_surface=ui.selected.surface_id;start_screen=screen
	# Dragging a tall crown must keep the cursor's original screen-space offset
	# from the roots; intersecting the crown ray with the floor can miss entirely.
	screen_offset=ui.scene.camera.unproject_position(ui.selected.global_position)-screen
	var anchor: Variant=ground_plane(screen+screen_offset,ui.selected.global_position.y)
	grab_point=anchor if anchor!=null else ui.selected.global_position
	dragging=true;changed=false;valid_target=true

func update(screen: Vector2,fine:=false,snap:=false) -> void:
	if not dragging or not is_instance_valid(ui.selected):return
	var pixels:=screen-start_screen
	if pixels.length()<4. and not changed:return
	var factor:=.15 if fine else 1.
	var tree: Node3D=ui.selected
	if kind=="rotate":
		var angle:=pixels.x*.01*factor
		if axis=="Y":
			var pivot: Vector2=ui.scene.camera.unproject_position(tree.global_position)
			angle=wrapf((screen-pivot).angle()-(start_screen-pivot).angle(),-PI,PI)*factor
		if snap:angle=snappedf(angle,deg_to_rad(15.))
		tree.rotation.y=start_transform.basis.get_euler().y+angle
	elif kind=="scale":
		var size: float=clampf(start_transform.basis.get_scale().x*exp((pixels.x-pixels.y)*.008*factor),.05,10.)
		if snap:size=maxf(.1,snappedf(size,.1))
		tree.scale=Vector3.ONE*size
	else:
		var target: Vector3=start_transform.origin
		if not axis.is_empty():
			var direction: Vector3={"X":Vector3.RIGHT,"Y":Vector3.UP,"Z":Vector3.BACK}[axis]
			var root: Vector3=ui.scene.editable_parent.to_global(start_transform.origin)
			var projected: Vector2=ui.scene.camera.unproject_position(root+direction)-ui.scene.camera.unproject_position(root)
			if projected.length_squared()<.01:return
			var amount:=pixels.dot(projected)/projected.length_squared()*factor
			if snap:amount=snappedf(amount,.5)
			target+=direction*amount
		else:
			var point: Variant=ground_plane(screen+screen_offset,ui.scene.editable_parent.to_global(start_transform.origin).y)
			if point==null:return
			var offset: Vector3=(point-grab_point)*factor;offset.y=0
			if snap:offset=offset.snapped(Vector3(.5,.5,.5))
			target+=offset
		if axis!="Y":
			var p: Vector3=ui.scene.editable_parent.to_global(target)
			var reference_y: float=tree.global_position.y
			var hit: Dictionary=ui.scene.ray(Vector3(p.x,reference_y+2,p.z),Vector3(p.x,reference_y-6,p.z))
			var was_valid:=valid_target;valid_target=ui.scene.planting_hit(hit)
			if not valid_target:
				if was_valid:ui.show_status("此处没有同层可种植地面，位置保持在最后有效处。")
				return
			target=ui.scene.editable_parent.to_local(hit.position);tree.surface_id=hit.collider.get_meta("source_id","")
		tree.position=target
	changed=true;ui.sync_transform_fields()

func finish(commit:=true) -> void:
	if not dragging:return
	dragging=false
	if not commit:
		if copied and is_instance_valid(ui.selected):
			var copy: Node3D=ui.selected;ui.scene.active_ids.erase(copy.tree_id)
			ui.scene.editable_parent.remove_child(copy);copy.queue_free();ui.selected=original if ui.owns_tree(original) else null
		elif is_instance_valid(ui.selected):ui.selected.transform=start_transform;ui.selected.surface_id=start_surface
		ui.refresh_ui()
	elif changed or copied:ui.record_change(before)
	before={};copied=false;original=null;valid_target=true;axis=""
