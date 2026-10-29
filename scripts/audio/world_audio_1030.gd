extends Node3D
## Environmental beds use shoreline distance, tree proximity and roof cover.
## Foley follows existing gameplay events; no additional character physics.
const BED := preload("res://scripts/audio/ambient_bed.gd")
const WAVES := preload("res://assets/audio/world_1030/sea_waves.ogg")
const LEAVES := preload("res://assets/audio/world_1030/wind_leaves.ogg")
const GULLS := [preload("res://assets/audio/world_1030/gull_01.wav"),preload("res://assets/audio/world_1030/gull_02.wav"),preload("res://assets/audio/world_1030/gull_03.wav"),preload("res://assets/audio/world_1030/gull_04.wav")]
const BIRDS := [preload("res://assets/audio/world_1030/bird_01.wav"),preload("res://assets/audio/world_1030/bird_02.wav")]
const STEPS := [preload("res://assets/audio/world_1030/water_step_01.wav"),preload("res://assets/audio/world_1030/water_step_02.wav"),preload("res://assets/audio/world_1030/water_step_03.wav"),preload("res://assets/audio/world_1030/water_step_04.wav"),preload("res://assets/audio/world_1030/water_step_05.wav"),preload("res://assets/audio/world_1030/water_step_06.wav")]
const STARTUP := preload("res://assets/audio/world_1030/vehicle_start.wav")
const TREE_CELL := 32.0
var world
var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/world_1030/settings.json"))
var listener: AudioListener3D
var waves
var leaves
var gull: AudioStreamPlayer3D
var bird: AudioStreamPlayer3D
var startup: AudioStreamPlayer3D
var steps: Array[AudioStreamPlayer3D] = []
var step_voice := 0
var last_step := -1
var tree_grid: Dictionary = {}
var shore_segments: Array[Dictionary] = []
var context: Dictionary = {"coast":0.0,"forest":0.0,"cover":0.0,"underwater":false}
var wave_target := 0.0
var leaf_target := 0.0
var elapsed := 0.0
var sample_due := 0.0
var gull_due := 5.0
var bird_due := 3.0
var last_character_mode := true
var startup_armed := true
var water_step_count := 0
var startup_count := 0
var gull_count := 0
var bird_count := 0
var rng := RandomNumberGenerator.new()
var popup: PopupPanel
var lowpass := AudioEffectLowPassFilter.new()
var ready_audio := false

func initialize(scene: Node3D) -> void:
	world = scene; rng.randomize()
	_bus("PR_World", "Master"); _bus("PR_Ambience", "PR_World"); _bus("PR_Actions", "PR_World")
	AudioServer.add_bus_effect(AudioServer.get_bus_index("PR_Ambience"),lowpass)
	lowpass.cutoff_hz = 20500
	var limiter := AudioEffectLimiter.new(); limiter.ceiling_db = -1.5
	AudioServer.add_bus_effect(AudioServer.get_bus_index("PR_World"),limiter)
	listener = AudioListener3D.new(); add_child(listener); listener.make_current()
	waves = BED.new(); add_child(waves); waves.initialize(WAVES,"PR_Ambience")
	leaves = BED.new(); add_child(leaves); leaves.initialize(LEAVES,"PR_Ambience")
	gull = _voice("PR_Ambience",60); bird = _voice("PR_Ambience",35)
	startup = _voice("PR_Actions",30)
	for i in 6:steps.append(_voice("PR_Actions",15))
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(world.ASSETS+"tree_layout.json"))
	for row: Array in rows:
		var p := Vector3(row[0],row[1],row[2])
		if world.initial_ruin.planting_mask.blocks(p,3):continue
		var cell := _tree_cell(p)
		if not tree_grid.has(cell):tree_grid[cell] = []
		tree_grid[cell].append(p)
	for body: Dictionary in world.water_manager.bodies:_extract_shores(body)
	world.water_manager.interaction.step_emitted.connect(_water_step)
	last_character_mode = world.character_mode
	ready_audio = true; apply_volumes()
	print("WORLD_AUDIO_READY shoreline_segments=%d tree_cells=%d"%[shore_segments.size(),tree_grid.size()])

func _bus(label: StringName, send: StringName) -> void:
	if AudioServer.get_bus_index(label) >= 0:return
	AudioServer.add_bus(); var index := AudioServer.bus_count-1
	AudioServer.set_bus_name(index,label); AudioServer.set_bus_send(index,send)

func _voice(bus: StringName, distance: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.bus = bus; player.unit_size = 6; player.max_distance = distance
	player.max_db = 0; player.attenuation_filter_cutoff_hz = 12000
	add_child(player); return player

func _tree_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x/TREE_CELL),floori(p.z/TREE_CELL))

func _extract_shores(body: Dictionary) -> void:
	var mesh: MeshInstance3D = body.mesh
	var points := PackedVector3Array(); var ids: Dictionary = {}; var edges: Dictionary = {}
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var remap := PackedInt32Array()
		for vertex in vertices:
			var p := (mesh.global_transform*vertex).snapped(Vector3.ONE*.02)
			if not ids.has(p):ids[p] = points.size(); points.append(p)
			remap.append(ids[p])
		if indices.is_empty():
			for i in vertices.size():indices.append(i)
		for i in range(0,indices.size(),3):
			for side in 3:
				var a := remap[indices[i+side]]; var b := remap[indices[i+(side+1)%3]]
				if a == b:continue
				var edge := Vector2i(mini(a,b),maxi(a,b))
				edges[edge] = int(edges.get(edge,0))+1
	var lagoon: bool = str(body.profile).begins_with("lagoon")
	for edge: Vector2i in edges:
		if edges[edge] == 1:
			shore_segments.append({"a":points[edge.x],"b":points[edge.y],"weight":.3 if lagoon else 1.0})

func sample_context(p: Vector3) -> Dictionary:
	var coast := 0.0
	for segment: Dictionary in shore_segments:
		var a: Vector3 = segment.a; var ab: Vector3 = segment.b-a
		var nearest := a+ab*clampf((p-a).dot(ab)/maxf(ab.length_squared(),.0001),0,1)
		var influence := 1-smoothstep(12,float(settings.shore_fade_m),p.distance_to(nearest))
		coast = maxf(coast,influence*float(segment.weight))
	var cell := _tree_cell(p); var forest := 0.0
	for x in range(-2,3):
		for z in range(-2,3):
			for tree: Vector3 in tree_grid.get(cell+Vector2i(x,z),[]):
				if absf(tree.y-(p.y-1.6)) > 18:continue
				var distance := Vector2(tree.x-p.x,tree.z-p.z).length()
				forest += (1-smoothstep(5,float(settings.forest_radius_m),distance))*.22
	forest = clampf(forest,0,1)
	var space := get_world_3d().direct_space_state; var cover := 0.0
	for offset: Vector3 in [Vector3.ZERO,Vector3(3,0,0),Vector3(-3,0,0),Vector3(0,0,3),Vector3(0,0,-3)]:
		var q := PhysicsRayQueryParameters3D.create(p+offset,p+offset+Vector3.UP*65,32)
		q.hit_back_faces = true
		if not space.intersect_ray(q).is_empty():cover += .2
	var underwater := false
	if p.y < -.1:
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x,.2,p.z),p,4)
		q.hit_back_faces = true; underwater = not space.intersect_ray(q).is_empty()
	return {"coast":coast,"forest":forest,"cover":cover,"underwater":underwater}

func _physics_process(delta: float) -> void:
	if not ready_audio:return
	elapsed += delta
	var p: Vector3 = world.camera.global_position if world.free_mode else world.active_actor().global_position+Vector3.UP*1.6
	listener.global_position = p
	var view: Camera3D = world.camera if world.free_mode else world.active_camera()
	listener.global_basis = view.global_basis
	sample_due -= delta
	if sample_due <= 0:context = sample_context(p); sample_due = .25
	var outdoors := lerpf(1,.16,float(context.cover))
	var wind: float = clampf(world.grass_wind.blend,0,1)
	wave_target = float(settings.waves_gain)*float(context.coast)*outdoors
	leaf_target = float(settings.leaves_gain)*float(context.forest)*lerpf(.045,1,wind)*outdoors
	if bool(context.underwater):wave_target *= .4; leaf_target *= .2
	lowpass.cutoff_hz = lerpf(lowpass.cutoff_hz,900.0 if bool(context.underwater) else 20500.0,minf(1,delta*3))
	if bool(settings.enabled):
		waves.advance(delta,wave_target); leaves.advance(delta,leaf_target)
	else:
		waves.silence(); leaves.silence()
	if world.character_mode != last_character_mode:
		startup_armed = true; last_character_mode = world.character_mode
		if world.character_mode:startup.stop()
	if not world.character_mode and not world.free_mode and startup_armed and absf(world.camper.drive_speed) > .15:
		startup_armed = false
		if bool(settings.enabled):
			startup.global_position = world.camper.global_position+Vector3.UP*.8
			startup.stream = STARTUP; startup.volume_db = float(settings.startup_db); startup.play(); startup_count += 1
	if not world.character_mode and startup.playing:startup.global_position = world.camper.global_position+Vector3.UP*.8
	if world.free_mode:
		for voice in steps:voice.stop()
		startup.stop()
	gull_due -= delta; bird_due -= delta
	if gull_due <= 0:
		gull_due = rng.randf_range(9,20)
		if _calls_allowed() and float(context.coast) > .18 and rng.randf() < float(context.coast):
			_call(gull,GULLS,p,float(settings.gull_db),12); gull_count += 1
	if bird_due <= 0:
		bird_due = rng.randf_range(7,16)
		if _calls_allowed() and float(context.forest) > .2 and rng.randf() < float(context.forest)*(1-.65*wind):
			_call(bird,BIRDS,p,float(settings.bird_db),7); bird_count += 1

func _calls_allowed() -> bool:
	return bool(settings.enabled) and float(context.cover) < .6 and not bool(context.underwater)

func _call(player: AudioStreamPlayer3D, clips: Array, p: Vector3, db: float, radius: float) -> void:
	var angle := rng.randf()*TAU
	player.global_position = p+Vector3(cos(angle)*radius,rng.randf_range(2,5),sin(angle)*radius)
	player.stream = clips[rng.randi_range(0,clips.size()-1)]
	player.pitch_scale = rng.randf_range(.95,1.05); player.volume_db = db; player.play()

func _water_step(event: Dictionary) -> void:
	if not ready_audio or not bool(settings.enabled) or not world.character_mode or world.free_mode:return
	var voice := steps[step_voice]; step_voice = (step_voice+1)%steps.size()
	var clip := rng.randi_range(0,STEPS.size()-2)
	if clip >= last_step:clip += 1
	last_step = clip
	voice.stream = STEPS[clip]; voice.global_position = Vector3(event.xz.x,0,event.xz.y)
	voice.pitch_scale = rng.randf_range(.94,1.06)
	voice.volume_db = float(settings.step_db)+(2 if float(event.amplitude) > .025 else 0)
	voice.play(); water_step_count += 1

func apply_volumes() -> void:
	if not ready_audio:return
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("PR_World"),float(settings.master))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("PR_World"),not bool(settings.enabled))
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("PR_Ambience"),float(settings.ambience))
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("PR_Actions"),float(settings.actions))
	if not bool(settings.enabled):
		waves.silence(); leaves.silence(); gull.stop(); bird.stop(); startup.stop()
		for voice in steps:voice.stop()

func add_controls(box: VBoxContainer) -> void:
	var button := Button.new(); button.text = "声音 · 音量设置"; button.focus_mode = Control.FOCUS_NONE; box.add_child(button)
	popup = PopupPanel.new(); add_child(popup)
	var margin := MarginContainer.new(); popup.add_child(margin)
	for side in ["left","top","right","bottom"]:margin.add_theme_constant_override("margin_"+side,16)
	var list := VBoxContainer.new(); list.custom_minimum_size.x = 300; margin.add_child(list)
	var enabled := CheckBox.new(); enabled.text = "开启游戏声音"; enabled.button_pressed = bool(settings.enabled); list.add_child(enabled)
	enabled.toggled.connect(func(value: bool):settings.enabled = value; apply_volumes())
	for row: Array in [["master","总音量"],["ambience","环境 · 海浪 / 鸟鸣 / 风声"],["actions","动作 · 涉水 / 车辆启动"]]:
		var label := Label.new(); label.text = str(row[1]); list.add_child(label)
		var slider := HSlider.new(); slider.min_value = 0; slider.max_value = 1; slider.step = .01; slider.value = float(settings[row[0]]); list.add_child(slider)
		slider.value_changed.connect(func(value: float):settings[row[0]] = value; apply_volumes())
	button.pressed.connect(func():popup.popup(Rect2i(Vector2i(button.global_position+Vector2(button.size.x+12,0)),Vector2i(340,240))))

func hide_settings() -> void:
	if popup != null:popup.hide()
