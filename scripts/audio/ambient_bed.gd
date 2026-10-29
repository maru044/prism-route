extends Node
## Two overlapping voices avoid a hard cut at the end of long field recordings.
var voices: Array[AudioStreamPlayer] = []
var active := 0
var age := 0.0
var crossfade := 0.0
var gain := 0.0
var crossfading := false
var rng := RandomNumberGenerator.new()

func initialize(stream: AudioStream, bus: StringName) -> void:
	rng.randomize()
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.stream = stream; player.bus = bus
		player.volume_db = -80; add_child(player); voices.append(player)

func advance(delta: float, target: float) -> void:
	gain = move_toward(gain, target, delta * .32)
	if gain < .0001 and target < .0001:
		for player in voices:player.stop()
		crossfading = false
		return
	var duration := voices[active].stream.get_length()
	if not voices[active].playing:
		age = rng.randf_range(0, maxf(0, duration - 5))
		voices[active].play(age)
	# Follow the mixer clock rather than accumulated physics time during frame stalls.
	age = voices[active].get_playback_position()
	if not crossfading and age >= duration - 1.5:
		voices[1-active].play(); crossfade = 0; crossfading = true
	if crossfading:
		crossfade = minf(1, crossfade + delta / 1.5)
		voices[active].volume_linear = gain * sqrt(1-crossfade)
		voices[1-active].volume_linear = gain * sqrt(crossfade)
		if crossfade >= 1:
			voices[active].stop(); active = 1-active; age = 1.5; crossfading = false
	else:voices[active].volume_linear = gain

func silence() -> void:
	gain = 0; crossfading = false
	for player in voices:player.stop()
