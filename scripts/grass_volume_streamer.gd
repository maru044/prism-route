extends Node3D
## Stable per-volume cache. Sphere selection and predictive corridor share the
## same retention rule; sampling is sliced instead of blocking on 5,200 rays.
const CELL := 24.0
const LOAD_RADIUS := 144.0
const AHEAD_RADIUS := 156.0
const RETAIN_RADIUS := 216.0
const AHEAD_RETAIN_RADIUS := 228.0
const REFRESH_SECONDS := 0.12
const LOOKAHEAD_SECONDS := 5.0
const MAX_AHEAD_METERS := 144.0
const SAMPLE_BATCH := 32
const BASE_BUDGET_USEC := 5000
const DRIVING_BUDGET_USEC := 9000

var vegetation
var world_scene
var columns: Dictionary = {}
var active: Dictionary = {}
var empty: Dictionary = {}
var required: Dictionary = {}
var queue: Array[Vector3i] = []
var work: Dictionary = {}
var center := Vector3.ZERO
var predicted_center := Vector3.ZERO
var prediction_velocity := Vector3.ZERO
var refresh_clock := 0.0
var last_position := Vector3.ZERO
var have_position := false
var last_build_usec := 0
var total_built := 0
var total_unloaded := 0
var query := PhysicsRayQueryParameters3D.new()
var water_query := PhysicsRayQueryParameters3D.new()
var exposure_query := PhysicsRayQueryParameters3D.new()
var max_water_y := -INF
var space: PhysicsDirectSpaceState3D

func initialize(owner_vegetation,owner_world) -> void:
	vegetation=owner_vegetation;world_scene=owner_world
	space=get_world_3d().direct_space_state
	# Sample only plantable geometry; the expensive perforated structure meshes
	# are relevant only to a short clearance ray immediately above a grass root.
	query.collision_mask=16;query.hit_back_faces=true
	water_query.collision_mask=4;water_query.hit_back_faces=true
	exposure_query.collision_mask=1;exposure_query.hit_back_faces=true
	for row:Dictionary in world_scene.metadata.get("object_records",[]):
		if row.kind=="Water":max_water_y=maxf(max_water_y,float(row.bounds[1][2]))
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world_scene.ASSETS+"grass_cells.json"))
	assert(is_equal_approx(float(data.cell_size_m),CELL))
	if world_scene.metadata.has("mesh_sha256"):
		assert(data.source_mesh_sha256==world_scene.metadata.mesh_sha256,"Rebuild grass_cells.json after changing the map")
	for row: Array in data.cells:
		register_cell(Vector3i(row[0],row[1],row[2]))

func register_cell(cell: Vector3i) -> void:
	var column:=Vector2i(cell.x,cell.z)
	if not columns.has(column):columns[column]=[]
	(columns[column] as Array).append(cell)

func _distance_squared(cell: Vector3i,point: Vector3) -> float:
	var minimum:=Vector3(cell)*CELL
	return point.distance_squared_to(point.clamp(minimum,minimum+Vector3.ONE*CELL))

func refresh() -> void:
	if not is_instance_valid(vegetation.target):return
	center=vegetation.target.global_position
	var speed:=prediction_velocity.length()
	var offset:=Vector3.ZERO
	if speed>0.8:
		offset=prediction_velocity.normalized()*clampf(speed*LOOKAHEAD_SECONDS+CELL,48,MAX_AHEAD_METERS)
	predicted_center=center+offset
	var required_now: Dictionary={}
	var low: Vector3=center.min(predicted_center)-Vector3.ONE*AHEAD_RADIUS
	var high: Vector3=center.max(predicted_center)+Vector3.ONE*AHEAD_RADIUS
	for x in range(floori(low.x/CELL),floori(high.x/CELL)+1):
		for z in range(floori(low.z/CELL),floori(high.z/CELL)+1):
			for cell:Vector3i in columns.get(Vector2i(x,z),[]):
				var nearby:=_distance_squared(cell,center)<=LOAD_RADIUS*LOAD_RADIUS
				var ahead:=_distance_squared(cell,predicted_center)<=AHEAD_RADIUS*AHEAD_RADIUS
				if nearby or ahead:required_now[cell]=true
	required=required_now
	queue.clear()
	for cell:Vector3i in required:
		if not active.has(cell) and not empty.has(cell) and (work.is_empty() or cell!=work.cell):queue.append(cell)
	queue.sort_custom(func(a:Vector3i,b:Vector3i):return priority(a)<priority(b))
	# Leaving a 5 m height band never invalidates data. Retain both the current
	# sphere and the forward sphere, with hysteresis beyond their load radii.
	var remove: Array[Vector3i]=[]
	for cell:Vector3i in active:
		if required.has(cell):continue
		if _distance_squared(cell,center)>RETAIN_RADIUS*RETAIN_RADIUS and _distance_squared(cell,predicted_center)>AHEAD_RETAIN_RADIUS*AHEAD_RETAIN_RADIUS:remove.append(cell)
	for cell:Vector3i in remove:
		var chunk: Node3D=active[cell]
		vegetation._remove_chunk_nodes_from_tracking(chunk)
		chunk.queue_free();active.erase(cell);total_unloaded+=1
	if not work.is_empty() and not required.has(work.cell):work.clear()

func priority(cell: Vector3i) -> float:
	var delta:=Vector3(cell)*CELL+Vector3.ONE*CELL*.5-center
	var distance:=sqrt(_distance_squared(cell,center))
	if distance<48:return distance
	var speed:=prediction_velocity.length()
	if speed>.8 and delta.dot(prediction_velocity.normalized())>0:
		var time_until_visible:=maxf(0,distance-110)/speed
		return 1000+time_until_visible*50+distance
	if distance<128:return 3000+distance
	return 4000+sqrt(_distance_squared(cell,predicted_center))

func tick(delta: float) -> void:
	var target: Node3D=vegetation.target
	if not is_instance_valid(target):return
	var actual_velocity:=Vector3.ZERO
	if target is CharacterBody3D:actual_velocity=(target as CharacterBody3D).get_real_velocity()
	elif have_position and delta>0:actual_velocity=(target.global_position-last_position)/delta
	if have_position and target.global_position.distance_to(last_position)>CELL*3:
		# A teleport moves the request volume; existing chunks expire normally.
		actual_velocity=Vector3.ZERO;prediction_velocity=Vector3.ZERO
	prediction_velocity=prediction_velocity.lerp(actual_velocity,1-exp(-delta*8))
	last_position=target.global_position;have_position=true
	refresh_clock+=delta
	if refresh_clock>=REFRESH_SECONDS:
		refresh_clock=0;refresh()
	var start:=Time.get_ticks_usec()
	var budget:=DRIVING_BUDGET_USEC if prediction_velocity.length()>6 else BASE_BUDGET_USEC
	while Time.get_ticks_usec()-start<budget:
		if work.is_empty():
			if queue.is_empty():break
			var cell:Vector3i=queue.pop_front()
			if active.has(cell) or empty.has(cell) or not required.has(cell):continue
			_begin(cell)
		for sample in SAMPLE_BATCH:
			_sample()
			if int(work.samples)>=vegetation.GRASS_SAMPLES_PER_CHUNK:break
		if int(work.samples)>=vegetation.GRASS_SAMPLES_PER_CHUNK:_commit()
	last_build_usec=Time.get_ticks_usec()-start

func _begin(cell: Vector3i) -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=abs(cell.x*73856093 ^ cell.y*83492791 ^ cell.z*19349663 ^ 0x4A31)
	work={"cell":cell,"samples":0,"rng":rng,"near":[],"near_data":[],"far":[],"far_data":[]}

func sample_surfaces(cell: Vector3i,x: float,z: float) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var upper: float=(cell.y+1)*CELL+1.6
	var lower: float=cell.y*CELL-.002
	var water: float=-INF
	if lower<max_water_y+.15:
		water_query.from=Vector3(x,max_water_y+1,z);water_query.to=Vector3(x,lower,z)
		var water_hit:=space.intersect_ray(water_query)
		if not water_hit.is_empty():water=water_hit.position.y
	for step in 18:
		query.from=Vector3(x,upper,z);query.to=Vector3(x,lower,z)
		var hit:=space.intersect_ray(query)
		if hit.is_empty():break
		var p:Vector3=hit.position
		if floori((p.y+.001)/CELL)==cell.y and (hit.normal as Vector3).y>.72:
			var blocked:=p.y<=water+.15
			if not blocked:
				exposure_query.from=p+Vector3.UP*1.55;exposure_query.to=p+Vector3.UP*.03
				blocked=not space.intersect_ray(exposure_query).is_empty()
			if not blocked and not world_scene.architectural_band(p,.55):result.append(hit)
		upper=p.y-.01
		if upper<=lower:break
	return result

func _sample() -> void:
	var rng: RandomNumberGenerator=work.rng
	var cell:Vector3i=work.cell;var origin:=Vector3(cell)*CELL
	var x:=rng.randf_range(0,CELL);var z:=rng.randf_range(0,CELL)
	var surfaces:=sample_surfaces(cell,origin.x+x,origin.z+z)
	for hit:Dictionary in surfaces:
		var p:Vector3=hit.position;var normal:Vector3=hit.normal
		if rng.randf()>vegetation._grass_coverage(p,normal):continue
		for blade in vegetation.GRASS_BLADES_PER_SAMPLE:
			var offset:=Vector2.ZERO
			if blade>0:offset=Vector2(rng.randf_range(-.34,.34),rng.randf_range(-.34,.34))
			var y_offset:=-(normal.x*offset.x+normal.z*offset.y)/normal.y
			var yaw:=rng.randf_range(0,TAU);var width:=rng.randf_range(.88,1.28);var height:=rng.randf_range(.90,1.16)
			var transform:=Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3(width,height,width)),Vector3(x+offset.x,p.y-origin.y+y_offset+.025,z+offset.y))
			var biome:=rng.randf();var value:=rng.randf();var threshold:=rng.randf()
			if threshold<vegetation.GRASS_FAR_SURVIVOR_FRACTION:
				transform.basis=transform.basis.scaled(Vector3(1.32,1.04,1.32))
				(work.far as Array).append(transform);(work.far_data as Array).append(Color(biome,value,threshold/vegetation.GRASS_FAR_SURVIVOR_FRACTION,1))
			else:
				(work.near as Array).append(transform);(work.near_data as Array).append(Color(biome,value,(threshold-vegetation.GRASS_FAR_SURVIVOR_FRACTION)/(1-vegetation.GRASS_FAR_SURVIVOR_FRACTION),0))
	work.samples+=1

func _commit() -> void:
	var cell:Vector3i=work.cell
	if (work.near as Array).is_empty() and (work.far as Array).is_empty():empty[cell]=true;work.clear();return
	var chunk:=Node3D.new();chunk.name="GrassVolume_%d_%d_%d"%[cell.x,cell.y,cell.z];chunk.position=Vector3(cell)*CELL
	add_child(chunk)
	for group:String in ["near","far"]:
		if (work[group] as Array).is_empty():continue
		var transforms: Array[Transform3D]=[];transforms.assign(work[group])
		var custom: Array[Color]=[];custom.assign(work[group+"_data"])
		var end:float=vegetation.GRASS_NEAR_FADE_END if group=="near" else vegetation.GRASS_FAR_FADE_END
		var node:MultiMeshInstance3D=vegetation._make_multimesh_node("Grass_"+group,vegetation.grass_mesh,transforms,vegetation.grass_material,0,end+CELL*1.5,custom)
		node.set_meta("grass_population",group);node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.extra_cull_margin=1.5
		chunk.add_child(node)
		if group=="near":vegetation.grass_lod0_nodes.append(node)
		else:vegetation.grass_lod1_nodes.append(node)
	vegetation._apply_lod_state_to_chunk(chunk)
	active[cell]=chunk;total_built+=1;work.clear()

func pending_visible_count() -> int:
	var count:=0
	for cell:Vector3i in required:
		if _distance_squared(cell,center)>110*110:continue
		if not active.has(cell) and not empty.has(cell):count+=1
	return count

func metrics() -> Dictionary:
	return {"active":active.size(),"queued":queue.size(),"building":not work.is_empty(),"pending_visible":pending_visible_count(),"built":total_built,"unloaded":total_unloaded,"last_build_ms":last_build_usec/1000.0,"lookahead_m":center.distance_to(predicted_center),"speed_mps":prediction_velocity.length()}
