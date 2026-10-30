extends "res://scripts/tree_planting/editable_tree.gd"
## Editable handle using the exact production meshes, palettes and LOD factory.
var context

func update_pick_shape() -> void:
	super.update_pick_shape()
	# Play-mode overrides share the visual factory but are never editing handles.
	# Visibility does not disable physics bodies, so hidden copies must not pick.
	pick_body.collision_layer=2 if context!=null and get_parent()==context.editable_parent else 0

func refresh_visual() -> void:
	pending_refresh=false;leaf_nodes.clear()
	if not is_inside_tree() or is_queued_for_deletion():return
	if is_instance_valid(visual):remove_child(visual);visual.queue_free()
	if species==null or palette==null or context==null:return
	visual=Node3D.new();visual.name="TreeVisual";add_child(visual)
	canopy_bounds=context.build_visual(self,visual)
	update_pick_shape()
	var body:=StaticBody3D.new();body.name="TrunkCollision";body.collision_layer=32;body.collision_mask=0
	var shape:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=.4;cylinder.height=2.5
	shape.shape=cylinder;shape.position.y=1.25;body.add_child(shape);visual.add_child(body)
