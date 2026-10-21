extends SceneTree
## Focused regression against the actual CAD world and actual camper physics.
const OUT := "res://assets/world/current_map_validation/review/"
var failures:Array[String]=[]
var scene

func _initialize() -> void:call_deferred("run")
func check(ok:bool,message:String) -> void:
	if not ok:failures.append(message);push_error(message)
func frames(count:int) -> void:
	for i in count:await physics_frame

func run() -> void:
	root.size=Vector2i(1600,900)
	scene=load("res://scenes/map_1021.tscn").instantiate();scene.automation_enabled=true;root.add_child(scene)
	while not scene.test_ready:await process_frame
	await scene.select_spawn(1);await scene.set_character_mode(false);await frames(30)
	var stream=scene.vegetation.volume_streamer
	stream.refresh()
	# Actual fixed-layout root roughly 20 m below the elevated bridge.
	var lower:=Vector3(-203.37573,39.5049438,1182.29857)
	var cell:=Vector3i(floori(lower.x/24),floori(lower.y/24),floori(lower.z/24))
	check(stream.required.has(cell),"Actual bridge omitted the lower planting volume")
	var hits:Array=stream.sample_surfaces(cell,lower.x,lower.z)
	check(hits.any(func(h:Dictionary):return absf(h.position.y-lower.y)<.04),"Actual lower-storey grass sampler missed the terrace")
	var start:=Time.get_ticks_msec()
	while not stream.active.has(cell) and Time.get_ticks_msec()-start<30000:await process_frame
	check(stream.active.has(cell),"Actual lower terrace did not acquire rendered grass")
	var lower_volume_rendered:bool=stream.active.has(cell)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"grass_stream_map_bridge.png")
	await scene.select_spawn(7);await frames(30)
	stream.refresh();start=Time.get_ticks_msec()
	while stream.pending_visible_count()>0 and Time.get_ticks_msec()-start<60000:await process_frame
	var warm_seconds:float=(Time.get_ticks_msec()-start)/1000.0
	var ids:Dictionary={}
	for key:Vector3i in stream.active:ids[key]=stream.active[key].get_instance_id()
	var count_before:int=stream.active.size();var zero_frames:=0;var replaced:=0
	var min_y:float=scene.camper.position.y;var max_y:=min_y;var max_speed:=0.0;var max_ahead:=0.0
	var from:Vector3=scene.camper.position
	var forward_missing_frames:=0
	scene.camper.test_throttle=1
	for i in 240:
		await physics_frame
		if stream.active.is_empty():zero_frames+=1
		for key:Vector3i in ids:
			if stream.active.has(key) and stream.active[key].get_instance_id()!=ids[key]:replaced+=1
		min_y=minf(min_y,scene.camper.position.y);max_y=maxf(max_y,scene.camper.position.y)
		max_speed=maxf(max_speed,scene.camper.drive_speed);max_ahead=maxf(max_ahead,stream.center.distance_to(stream.predicted_center))
		var direction:Vector3=-scene.camper.global_basis.z
		var side:=Vector3(direction.z,0,-direction.x)
		if scene.camper.drive_speed>15:
			for key:Vector3i in stream.required:
				var delta:Vector3=Vector3(key)*24+Vector3.ONE*12-scene.camper.position
				if delta.dot(direction)>0 and delta.dot(direction)<96 and absf(delta.dot(side))<36 and delta.length()<110 and not stream.active.has(key) and not stream.empty.has(key):forward_missing_frames+=1;break
	scene.camper.test_throttle=0;scene.camper.test_braking=true;await frames(30)
	check(count_before>0 and zero_frames==0,"Actual ramp driving cleared the whole grass cache")
	check(replaced==0,"Actual ramp changed resident chunk identities")
	check(max_speed>17,"Actual vehicle did not reach driving speed")
	check(max_ahead>100,"Actual vehicle prediction did not follow real velocity")
	check(forward_missing_frames==0,"Actual route had missing forward volumes at full speed")
	var distance:float=Vector2(scene.camper.position.x-from.x,scene.camper.position.z-from.z).length()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"grass_stream_map_ramp.png")
	var report:Dictionary={"passed":failures.is_empty(),"failures":failures,"actual_map":scene.metadata.source_document,"objects":scene.metadata.objects,"lower_terrace_y":lower.y,"bridge_y":scene.resolved_spawns[1].floor_position.y,"lower_volume_rendered":lower_volume_rendered,"warm_seconds":warm_seconds,"ramp_drive_m":distance,"ramp_height_range":[min_y,max_y],"crossed_old_5m_boundary":floori(min_y/5)!=floori(max_y/5),"maximum_speed_mps":max_speed,"maximum_lookahead_m":max_ahead,"blank_grass_frames":zero_frames,"full_speed_forward_missing_frames":forward_missing_frames,"resident_chunk_replacements":replaced,"stream_metrics":stream.metrics()}
	var file:=FileAccess.open(OUT+"grass_stream_actual_map.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("MAP_1021_STREAM_VERIFY ",JSON.stringify(report));quit(0 if failures.is_empty()else 1)
