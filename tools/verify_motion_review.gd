extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://scenes/character_motion_test.tscn").instantiate()
	root.add_child(scene)
	var failures: Array[String] = []
	for i in scene.catalog.size():
		scene._select(i)
		var animation: Animation = scene.player.get_animation(scene.catalog[i].id)
		for track in animation.get_track_count():
			if animation.track_get_key_count(track) == 0: failures.append("Empty track: %s/%d" % [scene.catalog[i].id,track])
			var path:=animation.track_get_path(track)
			if scene.character.get_node_or_null(NodePath(str(path).get_slice(":",0))) != scene.skeleton:
				failures.append("Unresolved track: %s/%d" % [scene.catalog[i].id,track])
			if scene.skeleton.find_bone(str(path).get_slice(":",1))<0:
				failures.append("Unresolved bone: %s/%d" % [scene.catalog[i].id,track])
		for fraction in [0.0,0.25,0.5,0.75,0.999]:
			scene.player.seek(animation.length*fraction,true)
			scene.skeleton.force_update_all_bone_transforms()
			for bone in scene.skeleton.get_bone_count():
				var pose: Transform3D = scene.skeleton.get_bone_global_pose(bone)
				if not pose.is_finite(): failures.append("Invalid pose: "+scene.catalog[i].id)
		print("VERIFIED ",scene.catalog[i].id," tracks=",animation.get_track_count()," keys=",animation.track_get_key_count(0))
	# Exercise the review controls on both source families and a sparse VRMA -> GLB switch.
	scene.search.text="female"
	scene._filter()
	if scene.visible_indices.size()!=2: failures.append("Search failed")
	scene._select(4)
	scene._step(1)
	if scene.selected!=5: failures.append("Filtered next failed")
	var key:=InputEventKey.new()
	key.keycode=KEY_LEFT
	key.pressed=true
	scene._input(key)
	if scene.selected!=4: failures.append("Keyboard switch failed")
	scene._step(1)
	scene._pause()
	if scene.player.is_playing(): failures.append("Pause failed")
	scene._restart()
	if not scene.player.is_playing(): failures.append("Restart failed")
	scene.timeline.value=0.2
	if absf(scene.player.current_animation_position-0.2)>0.001: failures.append("Seek failed")
	scene.looping=false
	scene._apply_loop()
	if scene.player.get_animation("A06").loop_mode!=Animation.LOOP_NONE: failures.append("Loop toggle failed")
	scene._select(41)
	scene._select(0)
	scene.center_motion=false
	scene._center_character()
	scene._set_springs(true)
	scene._set_springs(false)
	print("RESULT clips=",scene.catalog.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)
