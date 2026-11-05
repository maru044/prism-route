class_name InteractiveFurniture
extends Node3D
## Base class for interactive furniture props with alignment sockets and collision.

@export var furniture_id: String = ""
@export var furniture_name_zh: String = ""
@export var seat_surface_height: float = 0.46

## Sockets / Anchors for motion alignment
var motion_anchors: Dictionary = {}

func _ready() -> void:
	_discover_anchors()

func get_motion_anchor(motion_id: String) -> Transform3D:
	if motion_anchors.has(motion_id):
		var marker: Marker3D = motion_anchors[motion_id]
		return marker.transform
	return Transform3D(Basis(), Vector3(0, 0, 0))

func _discover_anchors() -> void:
	var anchor_root := find_child("MotionAnchors", false, false)
	if anchor_root:
		for marker in anchor_root.get_children():
			if marker is Marker3D:
				motion_anchors[marker.name] = marker
