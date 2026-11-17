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

	# 1. Attempt preferred furniture interaction first
	if bindings.has(preferred_type):
		var binding: Dictionary = bindings[preferred_type]
		var req_anchors: Array = binding.get("required_anchors", [])
		if not req_anchors.is_empty():
			for furn_obj in furniture_list:
				if furn_obj == null or not is_instance_valid(furn_obj):
					continue
				var has_all_anchors := true
				var primary_anchor: Node3D = null
				var approach_anchor: Node3D = null

				for req_name: String in req_anchors:
					var has_anchor: bool = false
					var a_node: Node3D = null
					if furn_obj.has_method("has_motion_anchor"):
						has_anchor = furn_obj.has_motion_anchor(req_name)
						if has_anchor and furn_obj.has_method("get_motion_anchor_node"):
							a_node = furn_obj.get_motion_anchor_node(req_name)
					if not has_anchor:
						a_node = furn_obj.get_node_or_null(req_name)
						if a_node != null and is_instance_valid(a_node):
							has_anchor = true

					if not has_anchor or a_node == null:
						has_all_anchors = false
						break

					if primary_anchor == null and req_name != "Anchor_Front":
						primary_anchor = a_node
					elif req_name == "Anchor_Front":
						approach_anchor = a_node

				if has_all_anchors and primary_anchor != null:
					return {
						"found": true,
						"type": "furniture",
						"binding_key": preferred_type,
						"binding": binding,
						"furniture": furn_obj,
						"contact_anchor": primary_anchor,
						"approach_anchor": approach_anchor,
						"target_transform": primary_anchor.global_transform,
						"role_a_motion": binding.get("role_a_motion", ""),
						"role_b_motion": binding.get("role_b_motion", "")
					}

		# If required anchors not found on furniture, check if fallback to ground is allowed
		if binding.get("fallback_to_ground", false) and bindings.has("ground_service"):
			var ground_binding: Dictionary = bindings["ground_service"]
			return {
				"found": true,
				"type": "ground",
				"binding_key": "ground_service",
				"binding": ground_binding,
				"furniture": null,
				"contact_anchor": null,
				"approach_anchor": null,
				"target_transform": ground_transform,
				"role_a_motion": ground_binding.get("role_a_motion", ""),
				"role_b_motion": ground_binding.get("role_b_motion", "")
			}
		else:
			# Crucial: Strictly refuse fallback when fallback_to_ground is false!
			return {
				"found": false,
				"reason": "anchor_missing_and_fallback_prohibited",
				"binding_key": preferred_type
			}

	# 2. Check for explicit ground interaction ONLY when requested or no specific preferred type
	if preferred_type == "ground" or preferred_type == "ground_service" or preferred_type.is_empty():
		if bindings.has("ground_service"):
			var ground_binding: Dictionary = bindings["ground_service"]
			return {
				"found": true,
				"type": "ground",
				"binding_key": "ground_service",
				"binding": ground_binding,
				"furniture": null,
				"contact_anchor": null,
				"approach_anchor": null,
				"target_transform": ground_transform,
				"role_a_motion": ground_binding.get("role_a_motion", ""),
				"role_b_motion": ground_binding.get("role_b_motion", "")
			}

	return {"found": false, "reason": "no_compatible_anchors_or_motions"}
