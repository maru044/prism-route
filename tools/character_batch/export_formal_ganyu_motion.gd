extends SceneTree
## Sample the formal controller's actual reviewed clips after its centering step.
const OUT="D:/Prism Route/research/character_batch_20261104/formal_ganyu_motion.json"
func _initialize() -> void:call_deferred("run")
func matrix(value: Transform3D) -> Array:
	var b:=value.basis;var p:=value.origin
	return [b.x.x,b.y.x,b.z.x,p.x,b.x.y,b.y.y,b.z.y,p.y,b.x.z,b.y.z,b.z.z,p.z,0.,0.,0.,1.]
func lca(a: int,b: int,skeleton: Skeleton3D) -> int:
	var ancestors: Dictionary={}
	while a>=0:ancestors[a]=true;a=skeleton.get_bone_parent(a)
	while b>=0 and not ancestors.has(b):b=skeleton.get_bone_parent(b)
	assert(b>=0);return b
func run() -> void:
	var world=load("res://scenes/characters/world_ganyu.tscn").instantiate();root.add_child(world)
	world.set_physics_process(false);world.set_process_unhandled_input(false)
	var skeleton: Skeleton3D=world.skeleton
	for child in skeleton.get_children():
		if child is SkeletonModifier3D:child.active=false
	world.player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var mapping: Dictionary={};var profile:=SkeletonProfileHumanoid.new()
	for i in profile.bone_size:
		var name:=profile.get_bone_name(i);var index:=skeleton.find_bone(name)
		if index>=0 and name!="Root":mapping[name]=index
	var pelvis:=lca(mapping.LeftUpperLeg,mapping.RightUpperLeg,skeleton)
	var body_root:=lca(pelvis,mapping.Spine,skeleton)
	for side in ["Left","Right"]:
		for pair in [["LowerArm","UpperArm","UpperArmTwist"],["Hand","LowerArm","ForearmTwist"]]:
			var index:=skeleton.get_bone_parent(mapping[side+pair[0]])
			while index>=0 and index!=mapping[side+pair[1]]:
				var name:=skeleton.get_bone_name(index)
				if name.contains("捩") or name.to_lower().contains("twist"):mapping[side+pair[2]]=index;break
				index=skeleton.get_bone_parent(index)
	var rest: Array=[];var names: Array=[]
	for i in skeleton.get_bone_count():rest.append(matrix(skeleton.get_bone_global_rest(i)));names.append(skeleton.get_bone_name(i))
	var clips: Array=[]
	for state in ["idle","walk","run"]:
		var id: String=world.MOTIONS[state];var path: String="res://assets/characters/motion_review/"+id+".tres"
		var animation: Animation=world.player.get_animation(state)
		# Sample the intrinsic endpoint, rather than baking a wrapped frame-zero
		# pose into the final interval. The runtime clock handles looping.
		animation.loop_mode=Animation.LOOP_NONE
		var times: Array=[];var poses: Array=[];var count:=ceili(animation.length*120.)+1
		var candidates: Array=[]
		for frame in count:candidates.append(animation.length*float(frame)/float(count-1))
		# Original knots are essential: a uniform grid alone smooths sharp
		# velocity changes when its intervals straddle a reviewed keyframe.
		for track in animation.get_track_count():
			for key in animation.track_get_key_count(track):candidates.append(clampf(animation.track_get_key_time(track,key),0.,animation.length))
		candidates.sort()
		for t: float in candidates:
			if times.is_empty() or t-float(times[-1])>.000001:times.append(t)
		times[-1]=animation.length
		world.player.play(state);world.player.advance(0.)
		for t: float in times:
			skeleton.reset_bone_poses();world.player.seek(t,true);world.player.advance(0.);skeleton.force_update_all_bone_transforms()
			var pose: Array=[]
			for i in skeleton.get_bone_count():pose.append(matrix(skeleton.get_bone_global_pose(i)))
			poses.append(pose)
		clips.append({"state":state,"id":id,"source":path,"source_sha256":FileAccess.get_sha256(path),"duration":animation.length,"times":times,"poses":poses})
		print("FORMAL_GANYU_SOURCE ",state," ",path," length=",animation.length," samples=",times.size())
	var result: Dictionary={"controller":"res://scripts/world_character_controller.gd","scene":"res://scenes/characters/world_ganyu.tscn","centering":"actual world controller _center_clip applied","bones":names,"mapping":mapping,"pelvis":pelvis,"body_root":body_root,"rest":rest,"clips":clips}
	FileAccess.open(OUT,FileAccess.WRITE).store_string(JSON.stringify(result));quit()
