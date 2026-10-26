extends RefCounted
## Bounded world-space events. No colliders, floats, or global fluid simulation.
const MAX_EVENTS := 16
const LIFETIME := 5.0
const STEP_AMPLITUDE := 0.020
const LANDING_AMPLITUDE := 0.030
var events: Array[Dictionary] = []
var actor_id := 0
var previous := Vector3.ZERO
var distance_since_step := 0.0
var right_foot := false
var was_grounded := false
var emitted := 0

func reset() -> void:
	events.clear()
	actor_id = 0
	distance_since_step = 0.0
	was_grounded = false

func expire(clock: float) -> void:
	events = events.filter(func(e: Dictionary) -> bool:return clock - float(e.birth) < LIFETIME)

func add_event(position: Vector3, body_id: String, clock: float, amplitude: float = STEP_AMPLITUDE) -> void:
	if events.size() >= MAX_EVENTS:events.pop_front()
	events.append({"xz": Vector2(position.x, position.z), "body": body_id, "birth": clock, "amplitude": amplitude})
	emitted += 1

func tick(actor: CharacterBody3D, clock: float, delta: float, space: PhysicsDirectSpaceState3D) -> void:
	expire(clock)
	if actor == null or not is_instance_valid(actor):return
	var p: Vector3 = actor.global_position
	if actor_id != actor.get_instance_id() or p.distance_to(previous) > 6.0:
		reset();actor_id = actor.get_instance_id();previous = p
		return
	var travel := Vector2(p.x-previous.x,p.z-previous.z).length()
	previous = p
	var grounded := actor.is_on_floor()
	var landed := grounded and not was_grounded
	was_grounded = grounded
	if not grounded or p.y > 0.07 or p.y < -0.90:
		distance_since_step = 0.0
		return
	distance_since_step += minf(travel, 8.0 * delta)
	if not landed and distance_since_step < 0.52:return
	var water_query := PhysicsRayQueryParameters3D.create(Vector3(p.x,0.12,p.z),p+Vector3.DOWN*0.08,4)
	water_query.hit_back_faces = true
	var water: Dictionary = space.intersect_ray(water_query)
	if water.is_empty():distance_since_step = 0.0;return
	var floor_query := PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.12,p+Vector3.DOWN*0.24,32)
	floor_query.exclude = [actor.get_rid()]
	var floor_hit: Dictionary = space.intersect_ray(floor_query)
	if floor_hit.is_empty():return
	distance_since_step = 0.0
	right_foot = not right_foot
	var direction := Vector3(actor.velocity.x,0,actor.velocity.z).normalized()
	var side := Vector3(-direction.z,0,direction.x) * (0.10 if right_foot else -0.10)
	var id: String = water.collider.get_meta("source_id", "")
	var strength := LANDING_AMPLITUDE if landed else STEP_AMPLITUDE
	add_event(p+side,id,clock,strength)

func packed_for(body_id: String) -> PackedVector4Array:
	var packed := PackedVector4Array()
	for e: Dictionary in events:
		if e.body == body_id:packed.append(Vector4(e.xz.x,e.xz.y,e.birth,e.amplitude))
	return packed
