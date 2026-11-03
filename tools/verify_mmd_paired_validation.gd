extends SceneTree
const SOURCE_A := "res://assets/characters/mmd_validation/loop03_reference.json"
const SOURCE_B := "res://assets/characters/mmd_validation/paired/role_b_blender_reference.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test_fps:=60
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--test-fps="):test_fps=int(argument.trim_prefix("--test-fps="))
	var scene=load("res://scenes/character_mmd_vrm_validation.tscn").instantiate()
	root.add_child(scene)
	for i in 240:
		if scene.initialized: break
		await process_frame
	assert(scene.initialized,"Pair scene initialization failed")
	scene.playing=false
	assert(scene.current_entry=="loop03_pair" and scene.actors.size()==2 and scene.visible_roles.size()==2)
	var a=scene.actors.A
	var b=scene.actors.B
	assert(a.model_resource!=b.model_resource and a.skeleton!=b.skeleton)
	assert(absf(a.duration-b.duration)<0.000001)
	var reference_a=JSON.parse_string(FileAccess.get_file_as_string(SOURCE_A)).reference_frames
	var reference_b=JSON.parse_string(FileAccess.get_file_as_string(SOURCE_B)).reference_frames
	var names:={"上半身":"Spine","上半身2":"Chest","頭":"Head","手首.L":"LeftHand","手首.R":"RightHand","ひざ.L":"LeftLowerLeg","ひざ.R":"RightLowerLeg","足首.L":"LeftFoot","足首.R":"RightFoot"}
	var phase_error:=0.0
	var position_error:=0.0
	var relative_error:=0.0
	var reference_checks:=0
	var relative_checks:=0
	for i in reference_b.size():
		var ra:Dictionary=reference_a[i]
		var rb:Dictionary=reference_b[i]
		assert(int(ra.frame)==int(rb.frame))
		scene.seek_frame(int(rb.frame))
		phase_error=maxf(phase_error,absf(a.time-b.time))
		for original_name in rb.positions:
			var name:String=names.get(original_name,original_name)
			var ia:int=a.skeleton.find_bone(name)
			# Ganyu's humanoid Hips is the MMD center pivot, unlike Keqing's Hips.
			var ib:int=b.skeleton.find_bone("Hips" if original_name=="センター" else name)
			assert(ia>=0 and ib>=0)
			var pa:Vector3=a.skeleton.global_transform*a.skeleton.get_bone_global_pose(ia).origin
			var pb:Vector3=b.skeleton.global_transform*b.skeleton.get_bone_global_pose(ib).origin
			var va:Array=ra.positions_y_up[original_name]
			var vb:Array=rb.positions[original_name]
			var expected_a:=Vector3(va[0],va[1],va[2])
			var expected_b:=Vector3(vb[0],vb[1],vb[2])
			position_error=maxf(position_error,maxf(pa.distance_to(expected_a),pb.distance_to(expected_b)))
			relative_error=maxf(relative_error,(pb-pa).distance_to(expected_b-expected_a))
			reference_checks+=2
			relative_checks+=1
	# Correct partner layers: ground=1, role A proxy=2, role B proxy=4.
	assert(a.environment_mask==5 and b.environment_mask==3)
	assert(scene.role_proxies.A.layer==2 and scene.role_proxies.B.layer==4)
	await physics_frame
	await process_frame
	var query:=PhysicsShapeQueryParameters3D.new()
	var sphere:=SphereShape3D.new()
	sphere.radius=.005
	query.shape=sphere
	query.collision_mask=4
	query.transform=Transform3D(Basis.IDENTITY,scene.role_proxies.B.proxies[0].body.global_position)
	var partner_hits:Array=scene.get_world_3d().direct_space_state.intersect_shape(query,8)
	if partner_hits.is_empty():
		var proxy=scene.role_proxies.B.proxies[0].body
		print("PARTNER_QUERY_DEBUG ",proxy.global_position," server=",PhysicsServer3D.body_get_state(proxy.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM)," layer=",proxy.collision_layer," mask=",proxy.collision_mask," space=",PhysicsServer3D.body_get_space(proxy.get_rid())," world=",scene.get_world_3d().space," shapes=",proxy.get_shape_owners().size())
	assert(not partner_hits.is_empty(),"Partner proxy not present in physics space")
	scene.partner_on=false
	scene._apply_physics()
	await physics_frame
	await process_frame
	var disabled_partner_hits:Array=scene.get_world_3d().direct_space_state.intersect_shape(query,8)
	assert(disabled_partner_hits.is_empty() and a.environment_mask==1 and b.environment_mask==1)
	scene.partner_on=true
	scene._apply_physics()
	var native_steps_a:int=a.simulation_steps
	var native_steps_b:int=b.simulation_steps
	scene.seek_frame(0)
	var physics_checks:=0
	for step in 16*test_fps:
		scene._advance_animation(1.0/float(test_fps))
		await process_frame
		phase_error=maxf(phase_error,absf(a.time-b.time))
		for instance in [a,b]:
			for index in instance.physical_indices:
				var pose:Transform3D=instance.last_physics_globals.get(index,instance.skeleton.get_bone_global_pose(index))
				assert(pose.origin.is_finite() and pose.basis.is_finite())
				physics_checks+=1
	assert(a.simulation_steps>native_steps_a and b.simulation_steps>native_steps_b)
	var pair_chains:=[a.simulation.get_chain_count(),b.simulation.get_chain_count()]
	# A fixed-pose on/off comparison verifies a response, not only a checked box.
	var tail_samples: Array=[]
	for enabled in [false,true]:
		scene.partner_on=enabled
		scene._apply_physics()
		scene.seek_frame(60)
		for i in test_fps: await process_frame
		var tails:Array[Vector3]=[]
		for instance in [a,b]:
			for chain in instance.simulation.get_chain_count():
				tails.append(instance.simulation.get_joint_current_tail(chain,instance.simulation.get_joint_count(chain)-1))
		tail_samples.append(tails)
	var partner_response:=0.0
	for i in tail_samples[0].size(): partner_response=maxf(partner_response,tail_samples[0][i].distance_to(tail_samples[1][i]))
	await scene.select_entry("loop03_role_a")
	scene.playing=false
	assert(scene.visible_roles==["A"] and a.visible and not b.visible)
	assert(not scene.role_proxies.B.enabled and b.simulation.get_chain_count()==0)
	await scene.select_entry("loop03_role_b")
	scene.playing=false
	assert(scene.visible_roles==["B"] and b.visible and not a.visible)
	await scene.select_entry("loop03_pair")
	scene.playing=false
	for frame in [480,0,240,1,479]:
		scene.seek_frame(frame)
		await process_frame
		phase_error=maxf(phase_error,absf(a.time-b.time))
	scene.seek_frame(240)
	scene._advance_animation(.35)
	await process_frame
	phase_error=maxf(phase_error,absf(a.time-b.time))
	var passed:=phase_error<0.000001 and position_error<0.0001 and relative_error<0.0001 and pair_chains==[21,20] and partner_response>.001
	var report:={"passed":passed,"pack":"loop03","roles":2,"profiles":["keqing","ganyu"],"duration":16.0,"master_clock_error_s":phase_error,"source_joint_position_error_m":position_error,"relative_joint_vector_error_m":relative_error,"source_joint_checks":reference_checks,"relative_joint_checks":relative_checks,"native_spring_chains":pair_chains,"physics_bone_frame_checks":physics_checks,"library_entries_tested":3,"partner_collision_masks":[5,3],"contact_fit":"visual_reviewed; local garment overlap remains; not approved as final contact fit"}
	var output:="res://.godot/mmd_paired_validation.json"
	report["partner_query_hits"]=partner_hits.size()
	report["disabled_partner_query_hits"]=disabled_partner_hits.size()
	report["partner_tail_response_m"]=partner_response
	report["test_fps"]=test_fps
	report["large_step_reset_tested"]=true
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):output=argument.trim_prefix("--output=")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("MMD_PAIRED_VALIDATION ",JSON.stringify(report))
	quit(0 if passed else 1)
