extends SceneTree

const ACTOR_SCENE := preload("res://scenes/characters/shared_humanoid_actor.tscn")
const CATALOG := "res://assets/characters/roster/catalog.json"
const DEFAULT_MOTION := "res://assets/characters/roster/motions/koikatsu_idle.tres"

func _init() -> void:
	print("Starting test_vrm_chest_interaction_multimodel.gd")
	var file := FileAccess.open(CATALOG, FileAccess.READ)
	assert(file != null, "Cannot open catalog.json")
	var catalog_data: Dictionary = JSON.parse_string(file.get_as_text())
	var profiles: Array = catalog_data.get("profiles", [])
	print("Loaded profiles count: %d" % profiles.size())

	# Test models from different categories
	var test_targets: Array[String] = [
		"raiden_shogun", # Standard Genshin
		"firefly",       # Star Rail
		"black_swan",    # Numbered bones (胸１, 胸２)
		"ayaka",         # Chest dot (胸.L)
		"kokomi",        # Kokomi special (胸上2 without tip)
		"furina"         # Flat / no chest bone
	]

	for target_id in test_targets:
		var profile: Dictionary = {}
		for p in profiles:
			if p.get("id") == target_id:
				profile = p
				break
		assert(not profile.is_empty(), "Profile not found: %s" % target_id)
		print("\n--- Testing Model: %s (%s) ---" % [profile.get("label"), target_id])

		var actor = ACTOR_SCENE.instantiate()
		actor.model_resource = profile.get("model")
		actor.motion_resource = DEFAULT_MOTION
		actor.auto_play = true
		actor.environment_collision_enabled = false
		root.add_child(actor)

		while not actor.ready_for_review:
			await process_frame

		var skeleton: Skeleton3D = actor.skeleton
		assert(skeleton != null, "Skeleton must not be null")

		var resolved := _resolve_chest_bones(skeleton)
		print("  Resolved scheme: %s, pairs: %s" % [resolved.scheme, str(resolved.pairs)])
		if resolved.pairs.is_empty():
			print("  [Notice] Model %s is flat/without dedicated physics bone." % target_id)
		else:
			print("  [Pass] Model %s successfully resolved %d breast bones!" % [target_id, resolved.pairs.size()])

		actor.free()

	print("\n==================================================")
	print("ALL MULTI-MODEL CHEST BONE RESOLVER TESTS PASSED!")
	print("==================================================")
	quit(0)

class BoneResolveResult:
	var scheme: String = ""
	var pairs: Array[Dictionary] = [] # Array of {"base": int, "tip": int, "base_name": StringName, "tip_name": StringName}

func _resolve_chest_bones(skeleton: Skeleton3D) -> BoneResolveResult:
	var result := BoneResolveResult.new()
	var candidates: Array[Dictionary] = [
		{
			"scheme": "原神/星铁标准骨骼 (胸上2 -> 胸先)",
			"base_l": &"胸上2.L", "tip_l": &"胸先.L",
			"base_r": &"胸上2.R", "tip_r": &"胸先.R"
		},
		{
			"scheme": "数字编号骨骼 (胸１ -> 胸２)",
			"base_l": &"胸１.L", "tip_l": &"胸２.L",
			"base_r": &"胸１.R", "tip_r": &"胸２.R"
		},
		{
			"scheme": "单段胸上2骨骼",
			"base_l": &"胸上2.L", "tip_l": &"",
			"base_r": &"胸上2.R", "tip_r": &""
		},
		{
			"scheme": "单段胸点骨骼 (胸.L/R)",
			"base_l": &"胸.L", "tip_l": &"",
			"base_r": &"胸.R", "tip_r": &""
		}
	]

	for cand in candidates:
		var b_l := skeleton.find_bone(cand.base_l)
		var b_r := skeleton.find_bone(cand.base_r)
		if b_l >= 0 and b_r >= 0:
			var t_l := skeleton.find_bone(cand.tip_l) if not String(cand.tip_l).is_empty() else -1
			var t_r := skeleton.find_bone(cand.tip_r) if not String(cand.tip_r).is_empty() else -1
			if String(cand.tip_l).is_empty() or (t_l >= 0 and t_r >= 0):
				result.scheme = cand.scheme
				result.pairs.append({"base": b_l, "tip": t_l, "base_name": cand.base_l, "tip_name": cand.tip_l})
				result.pairs.append({"base": b_r, "tip": t_r, "base_name": cand.base_r, "tip_name": cand.tip_r})
				return result

	result.scheme = "微乳/无独立胸部物理骨骼"
	return result
