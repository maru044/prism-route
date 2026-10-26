extends Node
## Local height-band moisture history. No extra mesh, pass or UV wetness texture.
const SAMPLE_COUNT := 24
const MIN_HEIGHT := -0.15
const MAX_HEIGHT := 2.15
const WET_SECONDS := 0.25
const DRY_SECONDS := 14.0
const QUERY_INTERVAL := 1.0 / 15.0
const TELEPORT_DISTANCE := 6.0
const OFFSETS := [Vector2.ZERO, Vector2(.18,0), Vector2(-.18,0), Vector2(0,.18), Vector2(0,-.18)]
var actor: Node3D
var materials: Array[ShaderMaterial] = []
var levels := PackedFloat32Array()
var water_level := -10000.0
var contact := false
var coverage := 0.0
var water_id := ""
var previous_position := Vector3.ZERO
var query_clock := QUERY_INTERVAL
var enabled := true

func bind(body: Node3D, visual: Node3D) -> void:
	actor = body
	materials.clear()
	for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null: continue
		for i in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(i) as ShaderMaterial
			if material != null and material.shader.resource_path.get_file().begins_with("wet_mtoon"):
				materials.append(material)
	reset()

func _ready() -> void:
	# Keep drying while the actor is hidden by the camper switch, but obey pause.
	process_mode = Node.PROCESS_MODE_PAUSABLE

func reset() -> void:
	levels.resize(SAMPLE_COUNT)
	levels.fill(0.0)
	contact = false; coverage = 0.0; water_level = -10000.0; water_id = ""
	query_clock = QUERY_INTERVAL
	if is_instance_valid(actor): previous_position = actor.global_position
	_sync()

func _physics_process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not is_instance_valid(actor): return
	if actor.global_position.distance_to(previous_position) > TELEPORT_DISTANCE: reset()
	previous_position = actor.global_position
	query_clock += delta
	if query_clock >= QUERY_INTERVAL:
		query_clock = 0.0
		_query_water()
	for i in SAMPLE_COUNT:
		var height := lerpf(MIN_HEIGHT, MAX_HEIGHT, float(i)/(SAMPLE_COUNT-1))
		var submerged := contact and actor.global_position.y + height <= water_level
		levels[i] = move_toward(levels[i], coverage if submerged and enabled else 0.0, delta/(WET_SECONDS if submerged and enabled else DRY_SECONDS))
	_sync()

func _query_water() -> void:
	contact = false; coverage = 0.0; water_level = -10000.0; water_id = ""
	if not enabled or not actor.is_inside_tree(): return
	var space := actor.get_world_3d().direct_space_state
	var hits := 0
	for offset: Vector2 in OFFSETS:
		var p := actor.global_position + Vector3(offset.x,0,offset.y)
		var query := PhysicsRayQueryParameters3D.create(p+Vector3.UP*4.0,p-Vector3.UP*4.0,4)
		query.hit_back_faces = true
		var hit := space.intersect_ray(query)
		if hit.is_empty(): continue
		hits += 1
		if hit.position.y > water_level:
			water_level = hit.position.y
			water_id = hit.collider.get_meta("source_id","")
	contact = hits > 0 and water_level >= actor.global_position.y + MIN_HEIGHT
	coverage = float(hits)/OFFSETS.size()

func _sync() -> void:
	if not is_instance_valid(actor): return
	for material in materials:
		material.set_shader_parameter("wet_levels",levels)
		material.set_shader_parameter("wet_root_height",actor.global_position.y)
		material.set_shader_parameter("wet_water_level",water_level)
		material.set_shader_parameter("wet_contact",contact and enabled)

func metrics() -> Dictionary:
	var maximum := 0.0
	for value in levels: maximum = maxf(maximum,value)
	return {"contact":contact,"coverage":coverage,"water_level":water_level,"water_id":water_id,"max_wetness":maximum,"levels":Array(levels),"materials":materials.size()}
