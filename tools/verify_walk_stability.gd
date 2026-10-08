extends SceneTree
## Measure rendered world-space sway over a complete cycle, including centering.

func _initialize() -> void:
	call_deferred("_run")

func _measure(scene: Node3D, index: int, before: bool) -> Dictionary:
	scene.compare_old_walk=before
	scene.center_motion=true
	scene._select(index)
	scene.player.pause()
	var bones=["Head","Chest","LeftFoot","RightFoot"]
	var minimum={}
	var maximum={}
	for bone in bones:
		minimum[bone]=INF
		maximum[bone]=-INF
	for frame in 121:
		scene.player.seek(scene.catalog[index].duration*frame/120.0,true)
		scene.skeleton.force_update_all_bone_transforms()
		scene._center_character()
		for bone in bones:
			var local: Vector3=scene.skeleton.get_bone_global_pose(scene.skeleton.find_bone(bone)).origin
			var x: float=(scene.skeleton.global_transform*local).x
			minimum[bone]=minf(minimum[bone],x)
			maximum[bone]=maxf(maximum[bone],x)
	var spans={}
	for bone in bones: spans[bone]=maximum[bone]-minimum[bone]
	return spans

func _run() -> void:
	var scene=load("res://scenes/character_motion_test.tscn").instantiate()
	root.add_child(scene)
	var report={"metric":"peak_to_peak_world_x_meters", "samples_per_cycle":121, "clips":{}}
	var failed:=false
	for index in [4,38]:
		var before=_measure(scene,index,true)
		var after=_measure(scene,index,false)
		report.clips[scene.catalog[index].id]={"before":before,"after":after}
		print(scene.catalog[index].id," BEFORE ",before," AFTER ",after)
		failed=failed or after.Chest>=before.Chest or after.LeftFoot>=before.LeftFoot or after.RightFoot>=before.RightFoot
		if index==4: failed=failed or after.Head>0.03 or after.Chest>0.01
	# Comparison mode must not alter the accepted running animations.
	for index in [5,39]:
		var before=_measure(scene,index,true)
		var after=_measure(scene,index,false)
		report.clips[scene.catalog[index].id]={"before":before,"after":after}
		for bone in before: failed=failed or absf(before[bone]-after[bone])>0.00001
		print(scene.catalog[index].id," UNCHANGED ",after)
	var file=FileAccess.open("res://.godot/walk_stability_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("WALK_STABILITY ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
