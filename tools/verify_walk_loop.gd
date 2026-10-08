extends SceneTree
## Check the actual wrap in AnimationPlayer, not just the extrema of one cycle.

func _initialize() -> void:
	call_deferred("_run")

func _points(scene: Node3D) -> Dictionary:
	scene.skeleton.force_update_all_bone_transforms()
	scene._center_character()
	var values={}
	for name in ["Head","Chest","LeftFoot","RightFoot","LeftHand","RightHand"]:
		values[name]=scene.skeleton.global_transform*scene.skeleton.get_bone_global_pose(scene.skeleton.find_bone(name)).origin
	return values

func _angle(a: Quaternion,b: Quaternion) -> float:
	return rad_to_deg(2.0*acos(clampf(absf(a.normalized().dot(b.normalized())),0.0,1.0)))

func _measure(scene: Node3D,index: int,previous: bool,speed: float=1.0) -> Dictionary:
	scene.player.speed_scale=speed
	scene.compare_old_walk=false
	scene.compare_old_loop=previous
	scene._select(index)
	var animation: Animation=scene.player.get_animation(scene._animation_key())
	animation.loop_mode=Animation.LOOP_NONE
	scene.player.pause()
	scene.player.seek(0,true)
	var first=_points(scene)
	scene.player.seek(animation.length,true)
	var last=_points(scene)
	var endpoint_position_error:=0.0
	for name in first: endpoint_position_error=maxf(endpoint_position_error,first[name].distance_to(last[name]))
	var endpoint_angle_error:=0.0
	for track in animation.get_track_count():
		if animation.track_get_type(track)==Animation.TYPE_ROTATION_3D:
			endpoint_angle_error=maxf(endpoint_angle_error,_angle(animation.track_get_key_value(track,0),animation.track_get_key_value(track,animation.track_get_key_count(track)-1)))
	animation.loop_mode=Animation.LOOP_LINEAR
	scene.player.play(scene._animation_key())
	scene.player.seek(0,true)
	var points=_points(scene)
	var seam_max:=0.0
	var interior_max:=0.0
	var velocity_error:=0.0
	var incoming={}
	var dt:=animation.length/(240.0*speed)
	var previous_time:=0.0
	var wraps:=0
	var after_wrap:=false
	for step in range(1,240*4+2):
		scene.player.advance(dt)
		var current=_points(scene)
		var wrapped: bool=scene.player.current_animation_position<previous_time
		if wrapped: wraps+=1
		for name in points:
			var delta: Vector3=current[name]-points[name]
			if wrapped:
				seam_max=maxf(seam_max,delta.length())
				incoming[name]=delta/dt
			elif after_wrap and incoming.has(name):
				velocity_error=maxf(velocity_error,incoming[name].distance_to(delta/dt))
			else: interior_max=maxf(interior_max,delta.length())
		points=current
		after_wrap=wrapped
		previous_time=scene.player.current_animation_position
	return {"endpoint_position_error_m":endpoint_position_error,"endpoint_local_rotation_error_degrees":endpoint_angle_error,"wrap_step_max_m":seam_max,"interior_step_max_m":interior_max,"wrap_velocity_difference_m_per_s":velocity_error,"cycles_tested":wraps,"samples_per_cycle":240,"speed_scale":speed}

func _run() -> void:
	var scene=load("res://scenes/character_motion_test.tscn").instantiate()
	root.add_child(scene)
	scene.player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var report={"clips":{}}
	var failed:=false
	for index in [4,38]:
		var before=_measure(scene,index,true)
		var after=_measure(scene,index,false)
		report.clips[scene.catalog[index].id]={"before":before,"after":after}
		failed=failed or after.endpoint_position_error_m>0.00001 or after.endpoint_local_rotation_error_degrees>0.06
		failed=failed or after.wrap_step_max_m>after.interior_step_max_m*1.2 or after.wrap_velocity_difference_m_per_s>0.15
		failed=failed or after.cycles_tested<4
		print(scene.catalog[index].id," BEFORE ",before," AFTER ",after)
		if index==38:
			var slow=_measure(scene,index,false,0.65)
			report.clips[scene.catalog[index].id].after_at_speed_0_65=slow
			failed=failed or slow.cycles_tested<4 or slow.wrap_velocity_difference_m_per_s>0.15
	var file=FileAccess.open("res://.godot/walk_loop_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("WALK_LOOP ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
