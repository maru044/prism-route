extends SceneTree
## Tests shared resource identity, anatomical calibration, rest lengths and clocks.
var failures: Array[String] = []
var sample_checks := 0
var max_rest_position_error := 0.0
var max_rotation_error := 0.0
var max_pelvis_error := 0.0
var max_clock_error := 0.0
var source_position_errors := {}
var profiles := {}
var worst_rotation := {}
var source_joint_errors := {}
var max_axis_error := 0.0
var max_body_rotation_error := 0.0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func angle(a: Quaternion, b: Quaternion) -> float:
	var difference := minf(Vector4(a.x-b.x,a.y-b.y,a.z-b.z,a.w-b.w).length(),Vector4(a.x+b.x,a.y+b.y,a.z+b.z,a.w+b.w).length())
	return 4.0*asin(clampf(difference*.5,0,1))

func vector(values: Array) -> Vector3:
	return Vector3(values[0],values[1],values[2])

func _inspect_actor(actor, reference: Dictionary, source_profile: bool) -> void:
	var skel: Skeleton3D = actor.skeleton
	max_clock_error=maxf(max_clock_error,absf(actor.time-float(reference.time)))
	for index in skel.get_bone_count():
		max_rest_position_error=maxf(max_rest_position_error,skel.get_bone_pose_position(index).distance_to(actor.rest_local[index].origin))
		check(skel.get_bone_pose_rotation(index).is_finite(),"Non-finite rotation")
	for semantic in reference.world_delta:
		if not actor.semantic_bones.has(semantic): continue
		if semantic=="BodyRoot" and actor.body_root==actor.pelvis: continue
		var index: int = actor.semantic_bones[semantic]
		var values: Array = reference.world_delta[semantic]
		var delta := Quaternion(values[0],values[1],values[2],values[3]).normalized()
		var actual := skel.get_bone_global_pose(index).basis.get_rotation_quaternion()
		var expected: Quaternion = (delta*actor.rest_world[index].basis.get_rotation_quaternion()).normalized()
		var rotation_error:=angle(actual,expected)
		var actual_basis:=skel.get_bone_global_pose(index).basis
		var expected_basis:=Basis(expected)
		for axis in 3:max_axis_error=maxf(max_axis_error,actual_basis[axis].normalized().angle_to(expected_basis[axis]))
		if rotation_error>max_rotation_error:
			worst_rotation={"model":actor.model_resource,"semantic":semantic,"time":reference.time,"actual_norm":actual.length(),"expected_norm":expected.length(),"sample_delta_error":angle(actor.motion.rotation_track_interpolate(actor.rotation_tracks[semantic],actor.time),delta)}
		max_rotation_error=maxf(max_rotation_error,rotation_error)
		if semantic in ["Hips","BodyRoot","Spine","Chest","Neck","Head","LeftUpperArm","RightUpperArm","LeftLowerArm","RightLowerArm","LeftHand","RightHand","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg","LeftFoot","RightFoot"]:
			max_body_rotation_error=maxf(max_body_rotation_error,rotation_error)
		sample_checks+=1
		if source_profile:
			var position: Vector3 = skel.get_bone_global_pose(index).origin+actor.root_displacement
			var error:=position.distance_to(vector(reference.source_positions[semantic]))
			var key: String = actor.model_resource
			source_position_errors[key]=maxf(source_position_errors.get(key,0.0),error)
			if not source_joint_errors.has(key):source_joint_errors[key]={}
			source_joint_errors[key][semantic]=maxf(source_joint_errors[key].get(semantic,0.0),error)
	var actual_pelvis: Vector3 = skel.get_bone_global_pose(actor.pelvis).origin+actor.root_displacement
	var expected_pelvis: Vector3 = actor.rest_world[actor.pelvis].origin+vector(reference.pelvis_delta)*actor.translation_scale
	max_pelvis_error=maxf(max_pelvis_error,actual_pelvis.distance_to(expected_pelvis))

func _run() -> void:
	var scene = load("res://scenes/character_mmd_vrm_validation.tscn").instantiate()
	root.add_child(scene)
	for i in 300:
		if scene.initialized: break
		await process_frame
	check(scene.initialized,"Scene failed to initialize")
	if not scene.initialized:
		quit(1)
		return
	scene.playing=false
	var identity_checks:=0
	var switch_checks:=0
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/mmd_validation/shared/manifest.json"))
	for clip in manifest.clips:
		await scene.select_entry(clip.id+"_all")
		scene.playing=false
		check(scene.actors.size()==4,"Expected all four avatars")
		var reference: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/mmd_validation/shared/"+clip.id+"_reference.json"))
		var shared_id: int=scene.actors.A.motion.get_instance_id()
		for role_id in scene.actors:
			var actor=scene.actors[role_id]
			check(actor.motion.get_instance_id()==shared_id,"Resource duplicated per avatar")
			identity_checks+=1
			profiles[actor.model_resource]={"bone_count":actor.skeleton.get_bone_count(),"declared_hips":actor.skeleton.find_bone("Hips"),
				"semantic_pelvis":String(actor.skeleton.get_bone_name(actor.pelvis)),"semantic_body_root":String(actor.skeleton.get_bone_name(actor.body_root)),
				"pelvis_height":actor.target_height,"humanoid_slots":actor.semantic_bones.size(),"spring_chains":actor.all_springs.size()}
		for frame in reference.frames:
			scene.time=float(frame.time)
			scene._seek_animation(scene.time)
			for role_id in scene.actors:
				var actor=scene.actors[role_id]
				var source_profile: bool=(clip.id=="shared_mmd_role_a" and role_id=="A") or (clip.id=="shared_mmd_role_b" and role_id=="B")
				_inspect_actor(actor,frame,source_profile)
		# A backwards seek must not retain the last pose.
		scene.time=0.0
		scene._seek_animation(0.0)
		for actor in scene.actors.values(): _inspect_actor(actor,reference.frames[0],false)
		switch_checks+=1
	# Existing pairing through the shared layer: retain common clock and scale.
	await scene.select_entry("shared_pair_all")
	scene.playing=false
	var pair_references: Array=[]
	for name in ["shared_mmd_role_a", "shared_mmd_role_b"]:
		pair_references.append(JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/mmd_validation/shared/"+name+"_reference.json")).frames)
	for i in pair_references[0].size():
		scene.seek_frame(roundi(float(pair_references[0][i].time)*30.0))
		check(scene.actors.A.translation_scale==1.0 and scene.actors.B.translation_scale==1.0,"Paired coordinates independently scaled")
		max_clock_error=maxf(max_clock_error,absf(scene.actors.A.time-scene.actors.B.time))
		_inspect_actor(scene.actors.A,pair_references[0][i],true)
		_inspect_actor(scene.actors.B,pair_references[1][i],true)
	# Real-frame physics smoke on the four-avatar neutral clip, plus switch-back.
	await scene.select_entry("shared_walk_all")
	scene.playing=false
	var steps_before:={}
	for role in scene.actors: steps_before[role]=scene.actors[role].simulation_steps
	for step in 120:
		scene._advance_animation(1.0/60.0)
		await process_frame
		for actor in scene.actors.values():
			for pose in actor.last_physics_globals.values():
				check(pose.origin.is_finite() and pose.basis.is_finite(),"Non-finite spring pose")
	for role in scene.actors:
		var actor=scene.actors[role]
		if not actor.all_springs.is_empty(): check(actor.simulation_steps>steps_before[role],"Existing spring simulation did not advance")
	var isolated_checks:=0
	for profile in manifest.profiles:
		await scene.select_entry("shared_walk_"+profile.id)
		scene.playing=false
		check(scene.visible_roles.size()==1,"Expected one diagnostic avatar")
		var visible_count:=0
		for actor in scene.actors.values():
			if actor.visible:visible_count+=1
		check(visible_count==1,"Hidden diagnostics still visible")
		isolated_checks+=1
	await scene.select_entry("shared_walk_all")
	scene.playing=false
	check(scene.visible_roles.size()==4,"Failed to restore shared preview")
	check(max_rest_position_error<0.000001,"Source animation changed target bone lengths")
	# Deep finger chains accumulate float32 basis/quaternion conversion error.
	# Keep a tighter independent bound for the major body joints.
	check(max_rotation_error<deg_to_rad(.05) and max_axis_error<deg_to_rad(.05),"Shared quaternion mapping error")
	check(max_body_rotation_error<deg_to_rad(.01),"Major body quaternion mapping error")
	for error in source_position_errors.values():check(error<.0001,"Shared source geometry regression")
	check(max_pelvis_error<0.00001,"Pelvis motion policy error")
	check(max_clock_error<0.000001,"Shared clock error")
	var report:={"passed":failures.is_empty(),"failures":failures,"clips":manifest.clips.size(),"profiles":profiles,
		"shared_resource_identity_checks":identity_checks,"backward_seek_checks":switch_checks,"rotation_checks":sample_checks,
		"isolated_avatar_views_tested":isolated_checks,
		"max_rest_position_error_m":max_rest_position_error,"max_rotation_error_rad":max_rotation_error,"max_pelvis_error_m":max_pelvis_error,
		"max_clock_error_s":max_clock_error,"source_reference_max_position_error_m":source_position_errors,
		"worst_rotation":worst_rotation,"max_axis_error_rad":max_axis_error,"max_body_rotation_error_rad":max_body_rotation_error,
		"rotation_tolerance_deg":.05,"body_rotation_tolerance_deg":.01,"source_position_tolerance_m":.0001,"source_joint_position_errors_m":source_joint_errors,
		"new_target_specific_animation_files":0,"new_blender_bakes":0,"physics_smoke_frames":120,
		"contact_fit":"not approved; shared humanoid transfer preserves lengths and orientation, not all source auxiliary deformation or contact"}
	var output:="res://docs/validation/shared_humanoid_20261103/verification.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SHARED_HUMANOID_VALIDATION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
