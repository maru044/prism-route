extends SceneTree
## Validate the final scene transforms and continuous spring state, not only clips.
const OUT="res://docs/character_locomotion_1104/"
const MARKERS=["Hips","Head","Chest","LeftFoot","RightFoot","LeftHand","RightHand"]
var review
var failures: Array[String]=[]
var rows: Array=[]
var test_fps:=60
func _initialize() -> void:Engine.max_fps=0;call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func points() -> Dictionary:
	var actor=review.actor;var result: Dictionary={}
	for name: String in MARKERS:
		result[name]=actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(actor.semantic_bones[name]).origin
	return result
func sample(t: float) -> Dictionary:
	review.time=t;review._process(0.);return points()
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--test-fps="):test_fps=int(argument.trim_prefix("--test-fps="))
	create_timer(240).timeout.connect(func():push_error("Locomotion verification timeout");quit(1))
	review=load("res://scenes/character_roster_review.tscn").instantiate();root.add_child(review)
	while not review.ready_for_review:await process_frame
	review.set_process(false);review.playing=false
	review.profiles.append({"id":"ganyu_reference","label":"甘雨参考","model":"res://assets/characters/mmd_validation/paired/ganyu_physics.vrm"});review.model_select.add_item("甘雨参考")
	var expected_clip_ids: Dictionary={"walk":"A05","run":"A06"};var shared_ids: Dictionary={}
	for index in review.profiles.size():
		if index!=0:await review.select_model(index)
		var actor=review.actor;var id: String=review.profiles[index].id
		for clip_index in [1,2]:
			review.playing=false;review.motion_select.select(clip_index);review.select_motion(clip_index)
			var clip: Dictionary=review.clips[clip_index];var duration: float=actor.duration
			check(clip.formal_id==expected_clip_ids[clip.id],"Unexpected motion source "+str(clip))
			check(clip.npc_enabled,id+" locomotion excluded from acceptance")
			var resource_id: int=actor.motion.get_instance_id()
			if not shared_ids.has(clip.id):shared_ids[clip.id]=resource_id
			check(shared_ids[clip.id]==resource_id,id+" duplicated locomotion resource")
			actor.set_physics_enabled(false,false)
			var pelvis_error:=0.;var low:=Vector3(INF,INF,INF);var high:=-low
			for step in 121:
				var t:=duration*float(step)/120.;var p: Dictionary=sample(t)
				var desired: Vector3=actor.rest_world[actor.pelvis].origin+actor.motion.position_track_interpolate(actor.translation_track,t)*actor.translation_scale
				pelvis_error=maxf(pelvis_error,p.Hips.distance_to(desired));low=low.min(p.Head);high=high.max(p.Head)
			var first: Dictionary=sample(0.);var last: Dictionary=sample(duration);var endpoint_gap:=0.
			for name: String in MARKERS:endpoint_gap=maxf(endpoint_gap,first[name].distance_to(last[name]))
			var epsilon:=duration/1000.;var incoming: Dictionary=sample(duration-epsilon);var outgoing: Dictionary=sample(epsilon);var velocity_gap:=0.
			for name: String in MARKERS:
				velocity_gap=maxf(velocity_gap,((last[name]-incoming[name])/epsilon).distance_to((outgoing[name]-first[name])/epsilon))
			check(pelvis_error<.00002,id+" "+clip.id+" scene cancels pelvis trajectory: "+str(pelvis_error))
			check(endpoint_gap<.00002,id+" "+clip.id+" endpoint position jump: "+str(endpoint_gap))
			check(velocity_gap<.15,id+" "+clip.id+" seam velocity discontinuity: "+str(velocity_gap))
			# Exercise the actual preview clock through several wraps with springs on.
			review.time=duration*.87;review._process(0.);actor.set_physics_enabled(true,true)
			var resets: int=actor.simulation_reset_count;var physics_start: int=actor.simulation_steps
			review.playing=true;var wraps:=0;var seam_step:=0.;var interior_step:=0.;var previous: Dictionary=points()
			for frame in ceili(duration*4.1*float(test_fps)):
				var previous_time: float=review.time;review._process(1./float(test_fps));await process_frame
				var current: Dictionary=points();var wrapped: bool=review.time<previous_time
				if wrapped:wraps+=1
				for name: String in MARKERS:
					var distance: float=current[name].distance_to(previous[name])
					if wrapped:seam_step=maxf(seam_step,distance)
					else:interior_step=maxf(interior_step,distance)
				for bone in actor.physical_indices:check(actor.skeleton.get_bone_global_pose(bone).is_finite(),id+" invalid spring pose")
				previous=current
			review.playing=false
			check(wraps>=4,id+" "+clip.id+" failed to wrap four times")
			check(actor.simulation_reset_count==resets,id+" "+clip.id+" resets springs on automatic wrap")
			check(actor.simulation_steps>physics_start+30,id+" "+clip.id+" springs not stepping")
			check(seam_step<=interior_step*1.2+.0001,id+" "+clip.id+" wrap jump exceeds interior movement")
			var row: Dictionary={"model":id,"clip":clip.id,"source":clip.formal_resource,"pelvis_trajectory_error_m":pelvis_error,"endpoint_marker_gap_m":endpoint_gap,"seam_velocity_gap_m_per_s":velocity_gap,"head_x_range_m":high.x-low.x,"automatic_wraps":wraps,"automatic_wrap_spring_resets":actor.simulation_reset_count-resets,"spring_steps":actor.simulation_steps-physics_start,"wrap_step_max_m":seam_step,"interior_step_max_m":interior_step}
			rows.append(row);print("LOCOMOTION_ACCEPT ",JSON.stringify(row))
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"scene":"res://scenes/character_roster_review.tscn","roster_models":review.profiles.size()-1,"reference_models":1,"test_fps":test_fps,"shared_locomotion_resources":shared_ids.size(),"clips":rows}
	FileAccess.open(OUT+("acceptance.json" if test_fps==60 else "acceptance_"+str(test_fps)+".json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("LOCOMOTION_RESULT ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"cases":rows.size()}));quit(0 if failures.is_empty() else 1)
