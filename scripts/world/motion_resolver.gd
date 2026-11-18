class_name MotionResolver
extends RefCounted
## Accurate motion compatibility resolver between character MotionProfiles and world furniture anchors.
## Eliminates fuzzy socket pick, ensuring dual-role MMD animations align strictly to valid sockets or fall back to ground.

static func resolve_motion(
	motion_profile: Dictionary,
	preferred_type: String,
	furniture_list: Array = [],
	ground_transform: Transform3D = Transform3D.IDENTITY
) -> Dictionary:
	var bindings: Dictionary = motion_profile.get("bindings", {})
	if bindings.is_empty():
		return {"found": false, "reason": "empty_motion_profile"}

	if preferred_type in ["", "ground", "ground_service"]:
		return _resolve_ground(bindings, ground_transform)
	if not bindings.has(preferred_type):
		return {"found": false, "reason": "unknown_binding", "binding_key": preferred_type}

	var binding: Dictionary = bindings[preferred_type]
	var required: Array = binding.get("required_anchors", [])
	var contact_name: String = binding.get("contact_anchor", required[0] if not required.is_empty() else "")
	var approach_name: String = binding.get("approach_anchor", "")
	var required_type: String = binding.get("interaction_type", "")
	for furniture in furniture_list:
		if not is_instance_valid(furniture) or required.is_empty():
			continue
		if furniture.has_meta("interaction_type"):
			var furn_type := str(furniture.get_meta("interaction_type"))
			var matches_type := (furn_type == required_type) or (required_type in ["seat", "chair"] and furn_type in ["seat", "chair"])
			if not matches_type:
				continue
		var anchors := {}
		for anchor_name: String in required:
			var matches: Array[Node] = furniture.find_children(anchor_name, "Node3D", true, false)
			if matches.size() != 1 or matches[0].name != anchor_name:
				break
			anchors[anchor_name] = matches[0]
		if anchors.size() != required.size() or not anchors.has(contact_name) or (not approach_name.is_empty() and not anchors.has(approach_name)):
			continue
		var contact: Node3D = anchors[contact_name]
		var approach: Node3D = anchors.get(approach_name)
		return _resolved(preferred_type, binding, contact.global_transform, furniture, contact, approach)

	if binding.get("fallback_to_ground", false):
		return _resolve_ground(bindings, ground_transform)
	return {"found": false, "reason": "anchor_missing_and_fallback_prohibited", "binding_key": preferred_type}

static func _resolve_ground(bindings: Dictionary, target: Transform3D) -> Dictionary:
	if not bindings.has("ground_service"):
		return {"found": false, "reason": "missing_ground_binding"}
	return _resolved("ground_service", bindings["ground_service"], target)

static func _resolved(key: String, binding: Dictionary, target: Transform3D, furniture: Node3D = null,
		contact: Node3D = null, approach: Node3D = null) -> Dictionary:
	var approach_transform := approach.global_transform if approach != null else target
	return {
		"found": true,
		"type": "furniture" if furniture != null else "ground",
		"binding_key": key,
		"binding": binding,
		"furniture": furniture,
		"contact_anchor": contact,
		"approach_anchor": approach,
		"approach_transform": approach_transform,
		"target_transform": target,
		"role_a_motion": binding["role_a_motion"],
		"role_b_motion": binding["role_b_motion"],
		"role_a_target": _role_target(target, binding.get("role_a_placement", {})),
		"role_b_target": _role_target(target, binding.get("role_b_placement", {})),
	}

static func _role_target(contact: Transform3D, placement: Dictionary) -> Transform3D:
	var offset: Array = placement.get("offset", [0, 0, 0])
	var local := Transform3D(Basis(Vector3.UP, deg_to_rad(placement.get("yaw_degrees", 0.0))),
		Vector3(offset[0], offset[1], offset[2]))
	return contact * local
