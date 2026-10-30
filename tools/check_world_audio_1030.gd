extends Node
var world
var failures: Array[String] = []
var report: Dictionary = {}
var capture := AudioEffectCapture.new()
var peak := 0.0
var sample_count := 0
var nonzero_count := 0

func check(value: bool, message: String) -> void:
	if not value:failures.append(message); push_error(message)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
		if capture.get_frames_available() > 0:
			var buffer := capture.get_buffer(capture.get_frames_available())
			for value: Vector2 in buffer:
				peak = maxf(peak,maxf(absf(value.x),absf(value.y)))
				if value.length_squared() > .00000001:nonzero_count += 1
			sample_count += buffer.size()

func run() -> void:
	get_tree().create_timer(110).timeout.connect(func():push_error("World audio test timed out");get_tree().quit(1))
	var audio = world.world_audio
	AudioServer.set_bus_mute(0,true)
	AudioServer.add_bus_effect(AudioServer.get_bus_index("PR_World"),capture)
	check(world == get_tree().current_scene,"Audio test is not running in the real F5 world")
	check(audio.ready_audio and audio.shore_segments.size() > 10 and audio.tree_grid.size() > 10,"Missing location data")
	check(audio.listener.is_current(),"Explicit actor listener not current")
	check(audio.GULLS.size()+audio.BIRDS.size()+audio.STEPS.size()+3 == 17,"Unexpected audio clip slot count")
	await frames(20)
	report.cave = audio.sample_context(world.character.global_position+Vector3.UP*1.6)
	check(float(report.cave.cover) > .5,"Initial cave not acoustically covered")
	var open_point := Vector3(0,500,0)
	report.far = audio.sample_context(open_point)
	check(float(report.far.coast) < .01 and float(report.far.forest) < .01,"High distant listener still hears ground ambience")
	var forest_point := Vector3.ZERO
	for bucket: Array in audio.tree_grid.values():
		var p: Vector3 = bucket[0]+Vector3.UP*1.6
		var ctx: Dictionary = audio.sample_context(p)
		if float(ctx.forest) > .9 and float(ctx.cover) < .1:forest_point=p;break
	check(forest_point != Vector3.ZERO,"No outdoor forest audio location found")
	world.set_free(true);world.camera.global_position=forest_point
	world.grass_wind.set_mode(0);world.grass_wind.blend=0
	await frames(25);var calm: float=audio.leaf_target
	world.grass_wind.set_mode(1);world.grass_wind.blend=1
	await frames(100);var strong: float=audio.leaf_target
	report.forest={"position":forest_point,"context":audio.context.duplicate(),"calm_target":calm,"strong_target":strong}
	check(strong > calm*10 and strong > .25,"Strong wind leaves not substantially audible")
	check(audio.leaves.voices[audio.leaves.active].playing,"Strong wind stream not playing")
	var old_voice: int=audio.leaves.active
	var end: float=audio.LEAVES.get_length()-1.6
	audio.leaves.voices[old_voice].seek(end);audio.leaves.age=end
	await frames(115)
	check(audio.leaves.active != old_voice and audio.leaves.voices[audio.leaves.active].playing,"Ambient loop crossfade failed")
	world.grass_wind.set_mode(0);world.grass_wind.blend=0
	audio.bird_due=0;await frames(2)
	check(audio.bird_count > 0 and audio.bird.playing,"Woodland bird playback failed")
	# Use a real sea boundary for the gull, independent of authored spawn placement.
	for segment: Dictionary in audio.shore_segments:
		if float(segment.weight) < .9:continue
		var p: Vector3=(segment.a+segment.b)*.5+Vector3.UP*2
		if p.length() > 4000:continue
		var ctx: Dictionary=audio.sample_context(p)
		if float(ctx.coast)>.9 and float(ctx.cover)<.1:
			world.camera.global_position=p;break
	await frames(25);audio.gull_due=0;await frames(2)
	report.shore=audio.context.duplicate()
	check(audio.wave_target > .25 and audio.gull_count > 0,"Shore waves or gull playback failed")
	# All three user-facing sliders must route to independent buses.
	audio.settings.ambience=0;audio.settings.actions=.44;audio.apply_volumes()
	check(is_zero_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("PR_Ambience"))) and is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("PR_Actions")),.44),"Environment/actions volumes not independent")
	audio.settings.ambience=.85;audio.settings.actions=.85;audio.apply_volumes()
	# Wading must follow the real existing ripple events, then stop while stationary.
	await world._water_review_view(3);await frames(30)
	var emitted: int=world.water_manager.interaction.emitted
	var sounds: int=audio.water_step_count
	world.character.test_move=Vector2(1,0);await frames(160)
	world.character.test_move=Vector2.ZERO;await frames(20)
	var walked: int=audio.water_step_count-sounds
	var ripple_count: int=world.water_manager.interaction.emitted-emitted
	var stopped: int=audio.water_step_count;await frames(65)
	report.wading={"sounds":walked,"ripples":ripple_count,"position":world.character.global_position}
	check(walked>=3 and walked==ripple_count,"Wading sounds do not match actual water contacts")
	check(audio.water_step_count==stopped,"Stationary actor keeps making water footsteps")
	world.set_free(true)
	world.water_manager.interaction.add_event(world.character.global_position,"test",world.water_manager.clock)
	await frames(2);check(audio.water_step_count==stopped,"Free camera emits actor water sounds")
	world.set_free(false);await world.select_spawn(0);await frames(20)
	check(audio.water_step_count==stopped,"Dry land generates water footsteps")
	await world.set_character_mode(false);await frames(15)
	check(not world.character_mode,"Vehicle test could not enter camper")
	var starts: int=audio.startup_count
	world.camper.test_throttle=1;await frames(25)
	check(audio.startup_count==starts+1,"First drive did not start engine sound")
	world.camper.test_throttle=0;world.camper.test_braking=true;await frames(30)
	world.camper.test_braking=false;world.camper.test_throttle=1;await frames(20)
	check(audio.startup_count==starts+1,"Stop/re-accelerate repeats engine startup")
	world.set_free(true);await frames(3);world.set_free(false);await frames(5)
	check(audio.startup_count==starts+1,"Free camera rearms engine startup")
	world.camper.test_throttle=0;world.camper.test_braking=true;await frames(15)
	await world.set_character_mode(true);await frames(5)
	await world.set_character_mode(false);await frames(5)
	world.camper.test_braking=false;world.camper.test_throttle=1;await frames(15)
	check(audio.startup_count==starts+2,"New vehicle session did not rearm startup")
	report.vehicle_startups=audio.startup_count-starts
	check(audio.listener.global_position.distance_to(world.active_actor().global_position+Vector3.UP*1.6)<.3,"Listener detached from active actor")
	audio.settings.master=.37;audio.apply_volumes()
	check(is_equal_approx(AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("PR_World")),.37),"Master volume control failed")
	audio.settings.enabled=false;audio.apply_volumes();await frames(5)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("PR_World")),"Audio mute failed")
	check(not audio.startup.playing and not audio.leaves.voices[0].playing and not audio.leaves.voices[1].playing,"Mute leaves streams playing")
	audio.settings.enabled=true;audio.apply_volumes()
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("PR_World")),"Audio unmute failed")
	check(sample_count>0 and nonzero_count>1000 and peak<1 and peak>.005,"Actual mixed audio is silent or clipped")
	report.mix={"frames":sample_count,"audible_frames":nonzero_count,"peak":peak,"mix_rate":AudioServer.get_mix_rate()}
	var before: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/world_audio_1030_before/hashes.json"))
	var unchanged: Dictionary={}
	for path: String in before:
		unchanged[path]=FileAccess.get_sha256("res://"+path)==before[path]
		check(unchanged[path],"Audio changed protected world asset: "+path)
	report.unchanged=unchanged;report.passed=failures.is_empty();report.failures=failures
	FileAccess.open("res://.current_map_build/world_audio_1030_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("WORLD_AUDIO_VERIFIED ",JSON.stringify(report));get_tree().quit(0 if failures.is_empty() else 1)
