extends SceneTree
const ACTOR=preload("res://scenes/characters/shared_humanoid_actor.tscn")
var failures: Array[String]=[]
func _initialize() -> void:Engine.max_fps=0;call_deferred("run")
func lca(a: int,b: int,skeleton: Skeleton3D) -> int:
	var ancestors: Dictionary={}
	while a>=0:ancestors[a]=true;a=skeleton.get_bone_parent(a)
	while b>=0 and not ancestors.has(b):b=skeleton.get_bone_parent(b)
	return b
func run() -> void:
	var reference=load("res://scenes/characters/world_ganyu.tscn").instantiate();root.add_child(reference)
	reference.set_physics_process(false);reference.set_process_unhandled_input(false)
	reference.player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var clips: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/roster/neutral_clips.json")).clips
	var source: Skeleton3D=reference.skeleton;var rows: Array=[]
	for clip: Dictionary in clips:
		reference.player.get_animation(clip.id).loop_mode=Animation.LOOP_NONE
		var actor=ACTOR.instantiate();actor.model_resource="res://assets/characters/mmd_validation/paired/ganyu_physics.vrm";actor.motion_resource=clip.resource;actor.auto_play=false;root.add_child(actor)
		while not actor.ready_for_review:await process_frame
		actor.set_physics_enabled(false,false)
		for modifier in source.get_children():
			if modifier is SkeletonModifier3D:modifier.active=false
		var positions:=0.;var rotations:=0.;var checked:=0
		for fraction in [0.,.031,.1,.2,.333,.5,.65,.8,.91,.99,1.]:
			var time: float=actor.duration*fraction
			reference.player.play(clip.id,0.);source.reset_bone_poses();reference.player.seek(time,true);reference.player.advance(0.);source.force_update_all_bone_transforms()
			actor.sample_time(time)
			for semantic: String in actor.semantic_bones:
				var index:=source.find_bone(semantic)
				if semantic=="Hips":index=lca(source.find_bone("LeftUpperLeg"),source.find_bone("RightUpperLeg"),source)
				if semantic=="BodyRoot":index=lca(lca(source.find_bone("LeftUpperLeg"),source.find_bone("RightUpperLeg"),source),source.find_bone("Spine"),source)
				if index<0 or not actor.rotation_tracks.has(semantic):continue
				var a: Transform3D=source.global_transform*source.get_bone_global_pose(index)
				var b: Transform3D=actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(actor.semantic_bones[semantic])
				positions=maxf(positions,a.origin.distance_to(b.origin))
				rotations=maxf(rotations,a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion()));checked+=1
		var row: Dictionary={"id":clip.formal_id,"formal_resource":clip.formal_resource,"shared_resource":clip.resource,"duration":actor.duration,"bone_pose_checks":checked,"max_position_error_m":positions,"max_rotation_error_rad":rotations}
		rows.append(row);print("FORMAL_POSE_COMPARE ",JSON.stringify(row))
		if positions>.002 or rotations>.003:failures.append("Formal pose differs: "+str(row))
		actor.free()
		if clip.id in ["walk","run"]:
			var animation: Animation=reference.player.get_animation(clip.id);animation.loop_mode=Animation.LOOP_LINEAR
			reference.player.play(clip.id,0.);reference.player.seek(0.,true);reference.player.advance(0.)
			var index:=source.find_bone("Head");var previous: Vector3=source.global_transform*source.get_bone_global_pose(index).origin
			var previous_time:=0.;var wraps:=0;var seam:=0.;var interior:=0.
			for step in 962:
				reference.player.advance(animation.length/240.);source.force_update_all_bone_transforms()
				var point: Vector3=source.global_transform*source.get_bone_global_pose(index).origin
				var time: float=reference.player.current_animation_position
				if time<previous_time:wraps+=1;seam=maxf(seam,point.distance_to(previous))
				else:interior=maxf(interior,point.distance_to(previous))
				previous=point;previous_time=time
			row["actual_world_wraps"]=wraps;row["actual_world_head_wrap_step_m"]=seam;row["actual_world_head_interior_step_m"]=interior
			if wraps<4 or seam>interior*1.2+.0001:failures.append("Formal AnimationPlayer wrap failed: "+str(row))
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"source_scene":"res://scenes/characters/world_ganyu.tscn","clips":rows}
	FileAccess.open("res://docs/character_batch_1104/formal_motion_fidelity.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	quit(0 if failures.is_empty() else 1)
