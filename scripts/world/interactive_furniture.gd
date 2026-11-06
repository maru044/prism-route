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

func get_motion_anchor(anchor_name: String) -> Transform3D:
	if motion_anchors.has(anchor_name):
		var node: Node3D = motion_anchors[anchor_name]
		return global_transform.affine_inverse() * node.global_transform
	for k in motion_anchors:
		if k.to_lower().contains(anchor_name.to_lower()):
			return global_transform.affine_inverse() * motion_anchors[k].global_transform
	return Transform3D(Basis(), Vector3.ZERO)

func _discover_anchors(node: Node) -> void:
	if node != self and (node is Node3D) and node.name.begins_with("Anchor_"):
		motion_anchors[node.name] = node
		var short_name := node.name.trim_prefix("Anchor_").to_lower()
		motion_anchors[short_name] = node
	for child in node.get_children():
		_discover_anchors(child)
