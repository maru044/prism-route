class_name InteractiveFurniture
extends Node3D
## Base class for interactive furniture props with alignment sockets and collision.

@export var furniture_id: String = ""
@export var furniture_name_zh: String = ""
@export var seat_surface_height: float = 0.46

## Sockets / Anchors for motion alignment
var motion_anchors: Dictionary = {}

func _ready() -> void:
	_discover_anchors(self)

func has_motion_anchor(anchor_name: String) -> bool:
	if motion_anchors.is_empty():
		_discover_anchors(self)
	if motion_anchors.has(anchor_name):
		return true
	for k in motion_anchors:
		if k.to_lower() == anchor_name.to_lower() or k.to_lower().contains(anchor_name.to_lower()):
			return true
	return false

func get_motion_anchor_node(anchor_name: String) -> Node3D:
	if motion_anchors.is_empty():
		_discover_anchors(self)
	if motion_anchors.has(anchor_name):
		return motion_anchors[anchor_name]
	for k in motion_anchors:
		if k.to_lower() == anchor_name.to_lower() or k.to_lower().contains(anchor_name.to_lower()):
			return motion_anchors[k]
	return null

func get_motion_anchor(anchor_name: String, in_global_space: bool = true) -> Transform3D:
	var node := get_motion_anchor_node(anchor_name)
	if node and is_instance_valid(node):
		if in_global_space:
			return node.global_transform if node.is_inside_tree() else (global_transform * node.transform)
		return (global_transform.affine_inverse() * node.global_transform) if node.is_inside_tree() else node.transform
	push_warning("[InteractiveFurniture] Motion anchor not found: %s on %s" % [anchor_name, name])
	return Transform3D.IDENTITY

func _discover_anchors(node: Node) -> void:
	if node != self and (node is Node3D) and node.name.begins_with("Anchor_"):
		motion_anchors[node.name] = node
		var short_name := node.name.trim_prefix("Anchor_").to_lower()
		motion_anchors[short_name] = node
	for child in node.get_children():
		_discover_anchors(child)
