extends RefCounted
## A bounded recent path: shared uniforms, no per-blade CPU updates or collisions.

const MAX_SOURCES := 16
const RECOVERY_SECONDS := 1.6
const SAMPLE_SECONDS := 0.075
const SAMPLE_DISTANCE := 0.40
const TELEPORT_DISTANCE := 12.0
# Walking parts the grass gently; the camper retains its full flattening footprint.
const CHARACTER_RADIUS := 0.45
const CHARACTER_STRENGTH := 0.50
const CHARACTER_MARGIN := 0.35
const VEHICLE_MARGIN := 0.65
var actor: Node3D
var vehicle := false
var history: Array[Dictionary] = []
var sample_clock := 0.0
var last_sample := Vector3.ZERO
var previous_position := Vector3.ZERO
var have_position := false
var enabled := true

func set_actor(body: Node3D, is_vehicle: bool) -> void:
	if actor == body and vehicle == is_vehicle:
		return
	actor = body
	vehicle = is_vehicle
	reset()

func reset() -> void:
	history.clear()
	sample_clock = 0.0
	have_position = false

func footprint() -> Dictionary:
	var point := actor.global_position
	var axis := actor.global_basis.z
	axis.y = 0.0
	axis = axis.normalized()
	var half_segment := 1.75 if vehicle else 0.0
	return {"start": point - axis * half_segment, "end": point + axis * half_segment,
		"radius": 1.30 if vehicle else CHARACTER_RADIUS,
		"strength": 1.0 if vehicle else CHARACTER_STRENGTH, "age": 0.0}

func update(delta: float, material: ShaderMaterial) -> void:
	if not enabled or not is_instance_valid(actor) or not actor.visible:
		reset()
		material.set_shader_parameter("use_grass_interaction", false)
		material.set_shader_parameter("grass_push_count", 0)
		return
	var position := actor.global_position
	if have_position and position.distance_to(previous_position) > TELEPORT_DISTANCE:
		reset()
	previous_position = position
	for item in history:
		item.age += delta
	history = history.filter(func(item: Dictionary): return item.age < RECOVERY_SECONDS)
	sample_clock += delta
	var current := footprint()
	if not have_position or (sample_clock >= SAMPLE_SECONDS and position.distance_to(last_sample) >= SAMPLE_DISTANCE):
		history.push_front(current.duplicate())
		if history.size() >= MAX_SOURCES:
			history.resize(MAX_SOURCES - 1)
		last_sample = position
		sample_clock = 0.0
		have_position = true
	var sources: Array[Dictionary] = [current]
	sources.append_array(history)
	var starts := PackedVector4Array()
	var ends := PackedVector4Array()
	starts.resize(MAX_SOURCES)
	ends.resize(MAX_SOURCES)
	var bounds_min := Vector3(INF, INF, INF)
	var bounds_max := Vector3(-INF, -INF, -INF)
	var margin := VEHICLE_MARGIN if vehicle else CHARACTER_MARGIN
	for i in sources.size():
		var source := sources[i]
		var start: Vector3 = source.start
		var end: Vector3 = source.end
		var strength := float(source.strength) * (1.0 - smoothstep(0.0, RECOVERY_SECONDS, float(source.age)))
		starts[i] = Vector4(start.x, start.y, start.z, source.radius)
		ends[i] = Vector4(end.x, end.y, end.z, strength)
		var padding := Vector3(float(source.radius) + margin, 1.15, float(source.radius) + margin)
		bounds_min = bounds_min.min(start.min(end) - padding)
		bounds_max = bounds_max.max(start.max(end) + padding)
	material.set_shader_parameter("use_grass_interaction", true)
	material.set_shader_parameter("grass_push_count", sources.size())
	material.set_shader_parameter("grass_push_starts", starts)
	material.set_shader_parameter("grass_push_ends", ends)
	material.set_shader_parameter("grass_push_margin", margin)
	material.set_shader_parameter("grass_push_bounds_min", bounds_min)
	material.set_shader_parameter("grass_push_bounds_max", bounds_max)
