extends SceneTree
var OUT: String="res://docs/character_batch_1104/"
var catalog_resource: String="res://assets/characters/roster/first_batch.json"
var review
var failures: Array[String]=[]
var rows: Array=[]
var resource_ids: Dictionary={}
var test_fps:=60
func _initialize() -> void:Engine.max_fps=0;call_deferred("run")
func frames(n: int) -> void:
	for i in n:await process_frame
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func finite_pose(actor) -> float:
	var maximum:=0.
	for i in actor.skeleton.get_bone_count():
		var pose: Transform3D=actor.skeleton.get_bone_global_pose(i)
		check(pose.is_finite(),"Non-finite bone "+str(i))
		check(pose.origin.length()<8.,"Exploded bone "+str(i))
		var parent: int=actor.skeleton.get_bone_parent(i)
		if parent<0:continue
		var p: Transform3D=actor.skeleton.get_bone_global_pose(parent)
		var a: Transform3D=actor.rest_world[i];var b: Transform3D=actor.rest_world[parent]
		maximum=maxf(maximum,absf(p.origin.distance_to(pose.origin)-a.origin.distance_to(b.origin)))
	return maximum
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--test-fps="):test_fps=int(argument.trim_prefix("--test-fps="))
		if argument.begins_with("--catalog="):catalog_resource=argument.trim_prefix("--catalog=")
		if argument.begins_with("--out="):OUT=argument.trim_prefix("--out=").trim_suffix("/")+"/"
	create_timer(240).timeout.connect(func():push_error("Roster verification timeout");quit(1))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	AudioServer.set_bus_mute(0,true)
	if "--existing-review" in OS.get_cmdline_user_args():await existing_review();return
	var registered: Array=load("res://scripts/character_mmd_vrm_validation.gd").available_profiles()
	var registered_ids: Dictionary={}
	for row: Dictionary in registered:registered_ids[row.id]=true
	for id in ["keqing","ganyu","hutao","huahuo","yae_miko","raiden_shogun","furina","jingliu","miyabi"]:check(registered_ids.has(id),"Missing avatar registration "+id)
	for profile: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(catalog_resource)).profiles:check(registered_ids.has(profile.id),"Missing batch registration "+str(profile.id))
	review=load("res://scenes/character_roster_review.tscn").instantiate();review.catalog_resource=catalog_resource;root.add_child(review);current_scene=review
	while not review.ready_for_review:await process_frame
	review.playing=false
	var capture_only: bool="--capture-only" in OS.get_cmdline_user_args()
	for index in review.profiles.size():
		if index!=0:await review.select_model(index)
		var actor=review.actor;var id: String=review.profiles[index].id
		var springs: int=actor.all_springs.size();var materials: Dictionary={};var meshes:=0;var morphs:=0
		for mesh: MeshInstance3D in actor.character.find_children("*","MeshInstance3D",true,false):
			if not mesh.mesh is ArrayMesh:continue
			meshes+=1;morphs+=mesh.mesh.get_blend_shape_count()
			for i in mesh.mesh.get_surface_count():
				var material: Material=mesh.get_active_material(i)
				check(material!=null,id+" missing material")
				var key:=material.get_class();materials[key]=int(materials.get(key,0))+1
		check(meshes>0 and morphs>0,id+" missing geometry/morphs")
		check(springs>0 and actor.simulation!=null,id+" physics not loaded")
		var hair_count:=0
		for spring in actor.all_springs:
			if spring.group.to_lower().contains("hair") or spring.comment.begins_with("Hair"):hair_count+=1
		actor.set_physics_enabled(true,false);check(actor._active_springs.size()==hair_count,id+" hair switch")
		actor.set_physics_enabled(false,true);check(actor._active_springs.size()==springs-hair_count,id+" clothes switch")
		actor.set_physics_enabled(false,false);check(actor._active_springs.is_empty(),id+" physics off switch")
		actor.set_physics_enabled(true,true)
		var max_length_error:=0.;var checks:=0
		if not capture_only:
			for clip in review.clips.size():
				review.motion_select.select(clip);review.select_motion(clip)
				var key: String=review.clips[clip].id;var instance_id: int=actor.motion.get_instance_id()
				if not resource_ids.has(key):resource_ids[key]=instance_id
				check(resource_ids[key]==instance_id,id+" duplicated shared clip "+key)
				for frame in 90:
					review.time=fmod(float(frame)/float(test_fps),actor.duration)
					await process_frame
					if frame%5==0:max_length_error=maxf(max_length_error,finite_pose(actor));checks+=1
				for t in [actor.duration,0.,actor.duration*.5]:actor.seek(t);await frames(3);max_length_error=maxf(max_length_error,finite_pose(actor))
			check(actor.simulation_steps>30,id+" simulation not stepping")
			check(max_length_error<.001,id+" spring/bone segment drift")
		var captures: Array=[]
		if DisplayServer.get_name()!="headless":
			var rigid: bool="--rigid" in OS.get_cmdline_user_args()
			var walk: bool="--walk" in OS.get_cmdline_user_args()
			var running: bool="--run" in OS.get_cmdline_user_args()
			var clip_index:=2 if running else (1 if walk else 0)
			review.motion_select.select(clip_index);review.select_motion(clip_index);review.time=review.actor.duration*.3 if running else (.35 if walk else .6)
			if index==0 and not rigid and not walk and not running:
				await frames(15);await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"preview_ui.png")
			review.ui.visible=false
			if rigid:actor.set_physics_enabled(false,false)
			for view in [0.,PI*.5]:
				review.yaw=view;review._camera();await frames(45);await RenderingServer.frame_post_draw
				var name: String=id+("_rigid" if rigid else ("_run" if running else ("_walk" if walk else "")))+("_front.png" if view==0. else "_side.png")
				check(root.get_texture().get_image().save_png(OUT+name)==OK,"Capture failed "+name);captures.append(name)
			review.ui.visible=true
		var row: Dictionary={"id":id,"bones":actor.skeleton.get_bone_count(),"meshes":meshes,"morphs":morphs,"material_classes":materials,
			"hair_chains":hair_count,"clothes_chains":springs-hair_count,"physics_steps":actor.simulation_steps,"pose_checks":checks,"max_segment_error_m":max_length_error,"captures":captures}
		rows.append(row);print("ROSTER_CHECK ",JSON.stringify(row))
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"models":rows,"shared_clips":resource_ids.size(),"registered_avatars":registered.size(),"test_fps":test_fps,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_video_adapter_name(),"scene":"res://scenes/character_roster_review.tscn","catalog":catalog_resource,"motions":review.clips,"grounding_enabled":review.grounding.button_pressed}
	var filename:="visual_rigid.json" if "--rigid" in OS.get_cmdline_user_args() else ("visual_run.json" if "--run" in OS.get_cmdline_user_args() else ("visual_walk.json" if "--walk" in OS.get_cmdline_user_args() else "visual.json"))
	var runtime_file:="runtime.json" if test_fps==60 else "runtime_"+str(test_fps)+".json"
	FileAccess.open(OUT+(filename if capture_only else runtime_file),FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("ROSTER_RESULT ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"models":rows.size()}));quit(0 if failures.is_empty() else 1)

func existing_review() -> void:
	var scene=load("res://scenes/character_mmd_vrm_validation.tscn").instantiate();root.add_child(scene);current_scene=scene
	while not scene.initialized:await process_frame
	check(scene.current_pack=="shared_walk","Expected neutral existing-review sample")
	scene.playing=false
	var profiles: Array=JSON.parse_string(FileAccess.get_file_as_string(catalog_resource)).profiles
	for profile: Dictionary in profiles:
		await scene.set_role_model("A",profile.id);scene.playing=false;scene.seek_frame(10);await frames(30)
		var actor=scene.actors.A
		check(actor.model_resource==profile.model,"Existing selector did not load "+str(profile.id))
		check(actor.motion.get_instance_id()==scene.actors.B.motion.get_instance_id(),"Existing viewer duplicated shared walk")
		check(absf(actor.time-scene.actors.B.time)<.00001,"Existing viewer clock differs")
		for i in actor.skeleton.get_bone_count():check(actor.skeleton.get_bone_global_pose(i).is_finite(),"Existing viewer invalid pose")
		rows.append({"id":profile.id,"model":actor.model_resource,"bones":actor.skeleton.get_bone_count(),"shared_motion_identity":true,"time":actor.time})
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"models":rows,"available_profiles":scene.avatar_profiles.size(),"entry":scene.current_entry,"catalog":catalog_resource}
	FileAccess.open(OUT+"existing_review.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("EXISTING_ROSTER_RESULT ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
