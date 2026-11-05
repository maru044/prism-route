extends "res://tools/verify_shared_humanoid_validation.gd"
## Selected-library integration checks, including every clip on all four profiles.

func _run() -> void:
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/mmd_selected/manifest.json"))
	check(manifest.packs.size()==20 and manifest.clips.size()==40,"Selected library count mismatch")
	check(manifest.counts.new_tracks==38 and manifest.counts.reused_tracks==2,"Unexpected per-target or repeated bakes")
	var scene=load("res://scenes/character_mmd_vrm_validation.tscn").instantiate()
	root.add_child(scene)
	for i in 300:
		if scene.initialized:break
		await process_frame
	check(scene.initialized,"Preview did not initialize")
	if not scene.initialized:quit(1);return
	scene.playing=false
	check(scene.scope_select.selected==0 and scene.filtered_entries.size()==20,"Main list must contain twenty groups")
	var group_ids:={}
	for entry in scene.filtered_entries:
		check(not group_ids.has(entry.pack),"Group appears more than once")
		group_ids[entry.pack]=true
	var filtered_counts:=[]
	for people in [1,2,3]:
		scene.category.select(people);scene._filter_entries()
		filtered_counts.append(scene.filtered_entries.size())
	check(filtered_counts==[1,18,1],"Solo/pair/triple group filter failed")
	scene.category.select(0);scene.search.text="Loop 08";scene._filter_entries()
	check(scene.filtered_entries.size()==1,"Group search failed")
	scene.search.text="";scene._filter_entries()
	var group_checks:=0
	var isolated_checks:=0
	var identity_checks:=0
	var physics_steps:=0
	for selected in manifest.packs:
		await scene.select_entry(selected.id+"_all")
		scene.playing=false
		check(scene.actors.size()==selected.roles.size(),"Wrong source-role count")
		check(scene.view_mode.item_count==selected.roles.size()+1,"Role modes duplicated library entries")
		check(scene.ground_body.position.distance_to(scene.preview_floor.position-Vector3(0,.05,0))<.00001,"Ground collider did not follow review stage")
		for actor in scene.actors.values():
			check(actor.translation_scale==1.0,"Group source coordinates independently scaled")
			check(absf(actor.duration-selected.duration)<.00005,"Group duration differs by role")
		if selected.label.contains("Loop 08"):
			check(selected.frame_end==1002 and roundi(scene.duration*30)==1002,"Loop 08 abnormal tail was retained")
		for frame in [0,roundi(selected.frame_end*.5),selected.frame_end]:
			scene.seek_frame(frame)
			for actor in scene.actors.values():max_clock_error=maxf(max_clock_error,absf(actor.time-scene.time))
		var previous_time:float=scene.time
		for mode in range(1,scene.view_mode.item_count):
			scene._on_view_mode(mode)
			var count:=0
			for actor in scene.actors.values():
				if actor.visible:count+=1
			check(count==1 and scene.visible_roles.size()==1,"Isolated role mode failed")
			check(scene.time==previous_time,"View mode changed playback position")
			isolated_checks+=1
		scene._on_view_mode(0)
		check(scene.visible_roles.size()==selected.roles.size(),"Whole-group mode did not restore roles")
		# Real frames on each selected group, including the three-role case.
		scene.seek_frame(roundi(selected.frame_end*.5))
		for step in 12:
			scene._advance_animation(1.0/60.0)
			await process_frame
			for actor in scene.actors.values():
				for pose in actor.last_physics_globals.values():check(pose.origin.is_finite() and pose.basis.is_finite(),"Non-finite selected spring pose")
		for actor in scene.actors.values():
			if not actor.all_springs.is_empty():check(actor.simulation_steps>0,"Selected spring simulation did not advance")
			physics_steps+=actor.simulation_steps
		group_checks+=1
		print("SELECTED_GROUP_CHECK ",selected.id)
	# Every selected source-role resource on all four models, using test-only packs.
	for clip in manifest.clips:
		var selected:Dictionary={}
		for candidate in manifest.packs:
			if candidate.id==clip.pack:selected=candidate
		var roles:=[]
		for i in manifest.profiles.size():
			var profile:Dictionary=manifest.profiles[i]
			roles.append({"id":String.chr(65+i),"label":profile.label,"model":profile.model,"motion":clip.resource,"report":"res://assets/characters/mmd_selected/manifest.json","profile":profile.id,"shared":true,"translation_policy":"shared_world","presentation_offset":[0,0,0]})
		var test_id:String="verify_"+clip.id
		scene.catalog.packs.append({"id":test_id,"label":test_id,"roles":roles,"source_tracks":selected.source_tracks.duplicate(),"duration":clip.duration,"frame_start":0,"frame_end":clip.frames-1,"shared":true})
		# select_entry uses one source label per instantiated role.
		while scene.catalog.packs[-1].source_tracks.size()<roles.size():scene.catalog.packs[-1].source_tracks.append(selected.source_tracks[0])
		scene.catalog.entries.append({"id":test_id,"pack":test_id,"label":test_id,"roles":["A","B","C","D"]})
		await scene.select_entry(test_id)
		scene.playing=false
		var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(clip.reference))
		var resource_id:int=scene.actors.A.motion.get_instance_id()
		var source_profile_id:String="ganyu" if clip.role=="B" else "keqing"
		for i in roles.size():
			var actor=scene.actors[roles[i].id]
			actor.set_physics_enabled(false,false)
			check(actor.motion.get_instance_id()==resource_id,"Animation duplicated for target model")
			check(actor.motion.get_meta("shared_humanoid_schema",0)==1,"Invalid shared motion schema")
			identity_checks+=1
		for frame in reference.frames:
			scene.time=float(frame.time);scene._seek_animation(scene.time)
			for i in roles.size():_inspect_actor(scene.actors[roles[i].id],frame,roles[i].profile==source_profile_id)
		scene.time=0;scene._seek_animation(0)
		for actor in scene.actors.values():_inspect_actor(actor,reference.frames[0],false)
		print("SELECTED_CLIP_CHECK ",clip.id)
	# UI model change: keep the shared resource, clock and isolated view.
	var solo:Dictionary={}
	for selected in manifest.packs:
		if selected.roles.size()==1:solo=selected
	await scene.select_entry(solo.id+"_all")
	scene.playing=false;scene.seek_frame(123)
	var held_motion:Animation=scene.actors.A.motion
	for profile in manifest.profiles:
		await scene.set_role_model("A",profile.id)
		scene.playing=false
		check(scene.actors.A.model_resource==profile.model,"UI model selection failed")
		check(scene.actors.A.motion==held_motion,"UI model selection copied animation")
		check(absf(scene.time-4.1)<.00001 and scene.visible_roles==["A"],"UI model selection lost position or view")
	check(max_rest_position_error<.000001,"Target bone lengths changed")
	check(max_rotation_error<deg_to_rad(.05) and max_axis_error<deg_to_rad(.05),"Shared quaternion mapping error")
	check(max_body_rotation_error<deg_to_rad(.01),"Major body quaternion mapping error")
	check(max_pelvis_error<.00001 and max_clock_error<.000001,"Shared pelvis or clock error")
	for error in source_position_errors.values():check(error<.0001,"Source joint geometry differs from shared result")
	var report:={"passed":failures.is_empty(),"failures":failures,"groups":group_checks,"clips":manifest.clips.size(),"avatar_profiles":manifest.profiles.size(),"resource_identity_checks":identity_checks,"rotation_checks":sample_checks,"isolated_role_mode_checks":isolated_checks,"selected_main_rows":19,"people_filter_counts":filtered_counts,"model_switch_checks":manifest.profiles.size(),"max_rest_position_error_m":max_rest_position_error,"max_rotation_error_rad":max_rotation_error,"max_axis_error_rad":max_axis_error,"max_body_rotation_error_rad":max_body_rotation_error,"max_pelvis_error_m":max_pelvis_error,"max_clock_error_s":max_clock_error,"source_reference_max_position_error_m":source_position_errors,"source_joint_position_errors_m":source_joint_errors,"worst_rotation":worst_rotation,"physics_smoke_frames_per_group":12,"physics_steps_observed":physics_steps,"new_target_specific_animation_files":0,"contact_fit":"not approved; body transfer and finite spring simulation do not guarantee contact or cloth art quality"}
	FileAccess.open("res://docs/validation/mmd_selected_20261103/verification.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SELECTED_LIBRARY_VALIDATION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
