extends SceneTree
var OUT="res://docs/character_locomotion_1104/before.json"
func _initialize() -> void:call_deferred("run")
func run() -> void:
	if "--after" in OS.get_cmdline_user_args():OUT="res://docs/character_locomotion_1104/after.json"
	var review=load("res://scenes/character_roster_review.tscn").instantiate();root.add_child(review)
	while not review.ready_for_review:await process_frame
	review.playing=false;review.set_process(false)
	review.profiles[0]={"id":"ganyu","label":"甘雨参考","model":"res://assets/characters/mmd_validation/paired/ganyu_physics.vrm"}
	await review.select_model(0);review.actor.set_physics_enabled(false,false)
	var rows: Array=[]
	for clip in review.clips.size():
		review.motion_select.select(clip);review.select_motion(clip)
		var actor=review.actor;var animation: Animation=actor.motion
		var rotation_gaps: Array=[];var position_gap:=0.;var preview_error:=0.;var samples: Array=[]
		for track in animation.get_track_count():
			if animation.track_get_type(track)==Animation.TYPE_ROTATION_3D:
				var a:=animation.rotation_track_interpolate(track,0.);var b:=animation.rotation_track_interpolate(track,animation.length)
				var gap:=2.*acos(clampf(absf(a.dot(b)),0.,1.))
				if gap>.0001:rotation_gaps.append({"bone":str(animation.track_get_path(track)),"degrees":rad_to_deg(gap)})
			elif animation.track_get_type(track)==Animation.TYPE_POSITION_3D:
				position_gap=animation.position_track_interpolate(track,0.).distance_to(animation.position_track_interpolate(track,animation.length))
		for fraction in [0.,.1,.25,.5,.75,.9,1.]:
			review.time=animation.length*fraction;review._process(0.)
			var actual: Vector3=actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(actor.pelvis).origin
			var expected: Vector3=actor.rest_world[actor.pelvis].origin+animation.position_track_interpolate(actor.translation_track,review.time)*actor.translation_scale
			preview_error=maxf(preview_error,actual.distance_to(expected))
			samples.append({"fraction":fraction,"actual_pelvis":[actual.x,actual.y,actual.z],"expected_pelvis":[expected.x,expected.y,expected.z]})
		rotation_gaps.sort_custom(func(a,b):return a.degrees>b.degrees)
		var row: Dictionary={"id":review.clips[clip].formal_id,"length":animation.length,"endpoint_position_gap_m":position_gap,"worst_rotation_gaps":rotation_gaps.slice(0,8),"preview_pelvis_max_error_m":preview_error,"samples":samples}
		rows.append(row);print("LOCOMOTION_BEFORE ",JSON.stringify(row))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	FileAccess.open(OUT,FileAccess.WRITE).store_string(JSON.stringify({"clips":rows},"  ")+"\n");quit()
