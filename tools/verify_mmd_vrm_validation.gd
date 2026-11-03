extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test_fps := 60
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--test-fps="): test_fps = int(argument.trim_prefix("--test-fps="))
	var actor = load("res://scenes/characters/keqing_mmd_vrm.tscn").instantiate()
	actor.auto_play = false
	root.add_child(actor)
	await actor.initialized
	var skeleton: Skeleton3D = actor.skeleton
	var simulation = actor.simulation
	var reference = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/mmd_validation/keqing_vrm_reference.json"))
	actor.set_physics_enabled(false, false)
	var max_position_error := 0.0
	var max_rotation_error := 0.0
	var max_solver_position_error := 0.0
	var comparisons := 0
	for sample in reference:
		actor.seek(float(sample.frame) / 30.0)
		for name in sample.bones:
			var actual := skeleton.get_bone_global_pose(skeleton.find_bone(name))
			var expected = sample.bones[name]
			var p: Array = expected.position
			var q: Array = expected.rotation
			max_position_error = maxf(max_position_error, actual.origin.distance_to(Vector3(p[0],p[1],p[2])))
			max_rotation_error = maxf(max_rotation_error, actual.basis.get_rotation_quaternion().angle_to(Quaternion(q[0],q[1],q[2],q[3])))
			comparisons += 1
	var solver_reference = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/mmd_validation/loop03_reference.json"))
	var names := {"上半身":"Spine","上半身2":"Chest","頭":"Head","手首.L":"LeftHand","手首.R":"RightHand","ひざ.L":"LeftLowerLeg","ひざ.R":"RightLowerLeg","足首.L":"LeftFoot","足首.R":"RightFoot"}
	for sample in solver_reference.reference_frames:
		actor.seek(float(sample.frame)/30.0)
		for source_name in sample.positions_y_up:
			var name: String = names.get(source_name,source_name)
			var index := skeleton.find_bone(name)
			assert(index>=0)
			var values: Array = sample.positions_y_up[source_name]
			var actual := skeleton.get_bone_global_pose(index).origin
			max_solver_position_error = maxf(max_solver_position_error,actual.distance_to(Vector3(values[0],values[1],values[2])))
	actor.set_physics_enabled(true, true)
	actor.seek(0.0)
	for i in 45: await process_frame
	var chain_count: int = simulation.get_chain_count()
	print("SPRING_COUNTS ", chain_count, " joints=", simulation.get_joint_count(0))
	var rest_rotations := {}
	var max_spring_angle := 0.0
	var max_segment_length_error := 0.0
	var max_collider_penetration := 0.0
	var worst_collision := {}
	var bone_checks := 0
	for index in actor.physical_indices:
		rest_rotations[index] = skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
	for step in 16 * test_fps:
		actor.advance_animation(1.0 / float(test_fps))
		await process_frame
		for index in actor.physical_indices:
			var pose := skeleton.get_bone_global_pose(index)
			assert(pose.origin.is_finite() and pose.basis.is_finite(), "Unstable spring")
			var rotation: Quaternion = actor.last_physics_rotations.get(index, skeleton.get_bone_pose_rotation(index))
			max_spring_angle = maxf(max_spring_angle, rotation.angle_to(rest_rotations[index]))
			bone_checks += 1
		if step % maxi(1,test_fps / 5) == 0:
			for chain in chain_count:
				var spring = actor.active_springs[chain]
				for joint in simulation.get_joint_count(chain):
					var index := skeleton.find_bone(spring.joint_nodes[joint])
					var next := skeleton.find_bone(spring.joint_nodes[joint+1])
					var current: Vector3 = simulation.get_joint_current_tail(chain,joint)
					assert(current.is_finite())
					var origin: Vector3 = actor.last_physics_globals[index].origin
					var length := skeleton.get_bone_global_rest(index).origin.distance_to(skeleton.get_bone_global_rest(next).origin)
					max_segment_length_error = maxf(max_segment_length_error,absf(current.distance_to(origin)-length))
					for group in spring.collider_groups:
						for collider in group.colliders:
							var pose := skeleton.get_bone_global_pose(skeleton.find_bone(collider.bone))
							var a: Vector3 = pose * collider.offset
							var b: Vector3 = pose * collider.tail if collider.is_capsule else a
							var ab := b-a
							var closest := a+ab*clampf((current-a).dot(ab)/maxf(ab.length_squared(),0.00000001),0,1)
							var hit_radius: float = spring.hit_radius_scale * (1.0 if spring.hit_radius.is_empty() else spring.hit_radius[joint])
							var radius: float = collider.radius + hit_radius
							var penetration := radius-current.distance_to(closest)
							if penetration > max_collider_penetration:
								max_collider_penetration = penetration
								worst_collision = {"spring":spring.comment,"joint":joint,"collider_bone":collider.bone,"time":actor.time}
	var end_tails := []
	for chain in chain_count:
		var tail: Vector3 = simulation.get_joint_current_tail(chain,simulation.get_joint_count(chain)-1)
		end_tails.append([tail.x,tail.y,tail.z])
	actor.set_physics_enabled(true,false)
	var hair_only: int = simulation.get_chain_count()
	actor.set_physics_enabled(false,true)
	var clothes_only: int = simulation.get_chain_count()
	actor.set_physics_enabled(false,false)
	var disabled: int = simulation.get_chain_count()
	actor.set_physics_enabled(true,true)
	var seek_checks := 0
	for value in [16.0,0.0,8.0,0.2,15.9]:
		actor.seek(value)
		for i in 30: await process_frame
		for index in actor.physical_indices:
			assert(actor.last_physics_globals[index].origin.is_finite())
			seek_checks += 1
	var passed := max_position_error < 0.0001 and max_solver_position_error < 0.0001 and max_rotation_error < 0.002 and chain_count == 21 and max_spring_angle > 0.001 and max_segment_length_error < 0.0001 and max_collider_penetration < 0.005 and hair_only==4 and clothes_only==17 and disabled==0
	var report := {"test_fps":test_fps,"position_error_m":max_position_error,"rotation_error_rad":max_rotation_error,"body_comparisons":comparisons,"spring_chains":chain_count,"spring_angle_rad":max_spring_angle,"physics_bone_frame_checks":bone_checks,"bones":skeleton.get_bone_count(),"max_spring_length_error_m":max_segment_length_error,"max_body_collider_penetration_m":max_collider_penetration,"worst_collision":worst_collision,"hair_only_chains":hair_only,"clothes_only_chains":clothes_only,"disabled_chains":disabled,"seek_bone_checks":seek_checks,"simulation_steps":actor.simulation_steps,"end_tails":end_tails,"passed":passed}
	var output := "res://.godot/mmd_vrm_validation.json"
	report["source_solver_position_error_m"] = max_solver_position_error
	report["collision_clearance_passed"] = max_collider_penetration < 0.005
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	var summary := report.duplicate()
	summary.erase("end_tails")
	print("MMD_VRM_VALIDATION ",JSON.stringify(summary))
	quit(0 if report.passed else 1)
