extends SceneTree
const OUT="res://docs/character_locomotion_1104/"
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var review=load("res://scenes/character_roster_review.tscn").instantiate();root.add_child(review)
	while not review.ready_for_review:await process_frame
	review.playing=false;review.set_process(false);review.ui.visible=false
	var index: int=review.profiles.find_custom(func(p):return p.id=="shenhe")
	assert(index>=0);await review.select_model(index)
	var reference=review.ACTOR.instantiate();reference.model_resource="res://assets/characters/mmd_validation/paired/ganyu_physics.vrm";reference.motion_resource=review.clips[0].resource;root.add_child(reference)
	while not reference.ready_for_review:await process_frame
	var layer:=CanvasLayer.new();root.add_child(layer)
	for column in 2:
		var label:=Label.new();label.position=Vector2(300 if column==0 else 790,36);label.text="甘雨参考" if column==0 else "申鹤 · 共用动作";label.add_theme_font_size_override("font_size",24);layer.add_child(label)
	review.distance=4.1;review.yaw=0.;review._camera()
	for clip_index in [1,2]:
		review.motion_select.select(clip_index);review.select_motion(clip_index)
		reference.motion=review.actor.motion;reference.duration=review.actor.duration;reference.rotation_tracks=review.actor.rotation_tracks.duplicate();reference.translation_track=review.actor.translation_track
		reference.translation_scale=reference.target_height/float(reference.motion.get_meta("reference_height"))
		review.time=0.;review.actor.seek(0.);reference.seek(0.);reference.position.x=-.55
		for frame in 30:
			review._process(0.);review.actor.position.x=.55;reference.sample_time(0.);await process_frame
		var name: String=review.clips[clip_index].id;var directory:=OUT+"frames_"+name
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		review.playing=true
		for frame in ceili(review.actor.duration*2.*60.):
			review._process(1./60.);review.actor.position.x=.55;reference.sample_time(review.time)
			await process_frame
			if frame%2==0:
				await RenderingServer.frame_post_draw
				assert(root.get_texture().get_image().save_png(directory+("/%04d.png"%frame))==OK)
		review.playing=false;print("LOCOMOTION_CAPTURE ",name)
	quit()
