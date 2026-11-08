extends SceneTree
## Quantitatively measure Sparkle sleeve motion jitter with and without NPCBody collision.

func _initialize() -> void:
	call_deferred("_run_ab_test")

func _collect_sleeve_bones(skeleton: Skeleton3D) -> Array[int]:
	var indices: Array[int] = []
	for i in range(skeleton.get_bone_count()):
		var bname := skeleton.get_bone_name(i)
		# Huahuo sleeves: yx__* (right sleeve) and zx_0_* (left sleeve)
		if bname.begins_with("yx__") or bname.begins_with("zx_0_") or "袖" in bname:
			indices.append(i)
	return indices

func _sample_run(body_layer: int, run_name: String) -> Dictionary:
	var ruin_scene = load("res://scenes/world/initial_ruin.tscn").instantiate()
	root.add_child(ruin_scene)
	while not ruin_scene.npc_ready:
		await process_frame
	
	ruin_scene.npc_body.collision_layer = body_layer
	var avatar = ruin_scene.avatar
	var skeleton: Skeleton3D = avatar.skeleton
	if skeleton == null and avatar.character != null:
		for child in avatar.character.find_children("*", "Skeleton3D", true, false):
			skeleton = child
			break
			
	var bones := _collect_sleeve_bones(skeleton)
	print("[%s] Found %d sleeve bones" % [run_name, bones.size()])
	
	# Warm up for 30 frames
	for f in 30:
		await process_frame
	
	var bone_trajectories: Dictionary = {}
	for b in bones:
		bone_trajectories[b] = []
	
	# Record 120 frames
	var frame_count := 120
	for f in frame_count:
		await process_frame
		for b in bones:
			var gpos: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(b).origin
			bone_trajectories[b].append(gpos)
	
	# Compute metrics
	var total_variance := 0.0
	var max_frame_delta := 0.0
	var bone_stats: Dictionary = {}
	
	for b in bones:
		var bname := skeleton.get_bone_name(b)
		var positions: Array = bone_trajectories[b]
		var deltas: Array[float] = []
		var max_delta := 0.0
		for i in range(1, positions.size()):
			var d: float = (positions[i] - positions[i-1]).length()
			deltas.append(d)
			if d > max_delta:
				max_delta = d
			if d > max_frame_delta:
				max_frame_delta = d
		
		# Mean and variance of frame delta
		var mean_delta := 0.0
		for d in deltas:
			mean_delta += d
		mean_delta /= float(deltas.size())
		
		var var_delta := 0.0
		for d in deltas:
			var_delta += (d - mean_delta) * (d - mean_delta)
		var_delta /= float(deltas.size())
		
		total_variance += var_delta
		bone_stats[bname] = {
			"mean_frame_delta_m": mean_delta,
			"var_frame_delta": var_delta,
			"max_frame_delta_m": max_delta
		}
	
	ruin_scene.queue_free()
	await process_frame
	await process_frame
	
	return {
		"run_name": run_name,
		"body_layer": body_layer,
		"sleeve_bone_count": bones.size(),
		"total_variance": total_variance,
		"max_frame_delta_m": max_frame_delta,
		"bone_stats": bone_stats
	}

func _run_ab_test() -> void:
	print("--- STARTING SPARKLE SLEEVE JITTER A/B TEST ---")
	
	# Run A: Baseline with NPCBody layer = 32 (ACTOR_SOLID_LAYER)
	var run_a := await _sample_run(32, "Baseline_Layer32")
	print("Run A (Baseline Layer 32): Total Var = " + str(run_a.total_variance) + ", Max Delta = " + str(run_a.max_frame_delta_m) + " m")
	
	# Run B: Diagnostic with NPCBody layer = 0 (No self-collision)
	var run_b := await _sample_run(0, "Diagnostic_Layer0")
	print("Run B (Diagnostic Layer 0): Total Var = " + str(run_b.total_variance) + ", Max Delta = " + str(run_b.max_frame_delta_m) + " m")
	
	# Run C: Proposed Fix with NPCBody layer = 64 (NPC_SOLID_LAYER, avatar mask=33)
	var run_c := await _sample_run(64, "Fix_Layer64")
	print("Run C (Fix Layer 64): Total Var = " + str(run_c.total_variance) + ", Max Delta = " + str(run_c.max_frame_delta_m) + " m")
	
	var var_reduction_pct: float = 0.0
	if run_a.total_variance > 1e-12:
		var_reduction_pct = (1.0 - (run_c.total_variance / run_a.total_variance)) * 100.0
	
	var delta_reduction_pct: float = 0.0
	if run_a.max_frame_delta_m > 1e-6:
		delta_reduction_pct = (1.0 - (run_c.max_frame_delta_m / run_a.max_frame_delta_m)) * 100.0
		
	var summary := {
		"run_a_baseline": run_a,
		"run_b_diag_layer0": run_b,
		"run_c_fix_layer64": run_c,
		"var_reduction_pct": var_reduction_pct,
		"delta_reduction_pct": delta_reduction_pct
	}
	
	var file := FileAccess.open("res://assets/world/initial_ruin_1029/sleeve_ab_jitter_report.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(summary, "  "))
		file.close()
	
	print("--- A/B TEST RESULT ---")
	print("Variance Reduction: " + str(var_reduction_pct) + "%")
	print("Max Frame Delta Reduction: " + str(delta_reduction_pct) + "%")
	print("REPORT SAVED to res://assets/world/initial_ruin_1029/sleeve_ab_jitter_report.json")
	
	quit()
