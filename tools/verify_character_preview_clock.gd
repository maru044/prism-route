extends SceneTree
## Measure ordinary playback against wall time, deliberately without --fixed-fps.
var review
var rows: Array=[]
var failures: Array[String]=[]
func _initialize() -> void:Engine.max_fps=60;call_deferred("run")
func frames(n: int) -> void:
	for i in n:await process_frame
func run() -> void:
	review=load("res://scenes/character_roster_review.tscn").instantiate();root.add_child(review)
	while not review.ready_for_review:await process_frame
	for config in [[0,2,1.],[1,2,1.],[2,2,1.],[1,1,.75]]:
		review.playing=false;review.motion_select.select(config[0]);review.select_motion(config[0])
		review.speed_select.select(config[1]);review.speed_select.item_selected.emit(config[1])
		await frames(3);review.time=0.;review.actor.seek(0.);review.playing=true
		var started:=Time.get_ticks_usec();var last: float=review.time;var advanced:=0.;var samples:=0
		while Time.get_ticks_usec()-started<2000000:
			await process_frame
			var step: float=review.time-last
			if step< -review.actor.duration*.5:step+=review.actor.duration
			advanced+=step;last=review.time;samples+=1
		var elapsed:=float(Time.get_ticks_usec()-started)/1000000.
		var ratio:=advanced/elapsed
		var row: Dictionary={"clip":review.clips[config[0]].id,"selected_speed":config[2],"wall_seconds":elapsed,"animation_seconds":advanced,"measured_speed":ratio,"samples":samples,"source_loop_seconds":review.actor.duration,"actor_auto_play":review.actor.auto_play,"engine_time_scale":Engine.time_scale}
		if absf(ratio-float(config[2]))>.04 or review.actor.auto_play:failures.append("Clock differs from selected speed: "+str(row))
		rows.append(row);review.playing=false;print("PREVIEW_CLOCK ",JSON.stringify(row))
	var paused: float=review.time;await frames(20)
	if absf(review.time-paused)>.00001:failures.append("Pause advanced the animation")
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"measurements":rows,"pause_preserved":absf(review.time-paused)<.00001}
	FileAccess.open("res://docs/character_batch_1104/playback_clock.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	quit(0 if failures.is_empty() else 1)
