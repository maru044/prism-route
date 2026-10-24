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
const COMMIT_BUDGET_USEC := 1000
const UPLOAD_INSTANCES := 16384
const BUFFER := preload("res://scripts/grass_instance_buffer.gd")
const STORE := preload("res://scripts/grass_baked_store.gd")
var store:=STORE.new()
var use_baked := true
var use_bulk := true
var capture_roots := false
var profiling := true
var collect_detailed_timings := "--grass-profile" in OS.get_cmdline_user_args()
var ready_cells: Dictionary = {}
var staging: Dictionary = {}
var paused: Dictionary = {}
var requested_at: Dictionary = {}
var visible_at: Dictionary = {}
var build_counts: Dictionary = {}
var cell_reports: Array[Dictionary] = []
var profile_totals: Dictionary = {}
var last_phases: Dictionary = {}
var frame_phases: Dictionary = {}
var total_served:=0
var total_cancelled:=0
var total_requested:=0
var total_rebuilt:=0
var last_commit_usec:=0
var max_commit_usec:=0
var queue_refresh_usec:=0
var profile_started_usec:=0
var frustum: Array[Plane] = []
var priority_scores: Dictionary = {}
var camera_position:=Vector3.ZERO
var completed_ages: Array[float] = []
var arrival_times: Array[int] = []
var completion_times: Array[int] = []
var latest_record: Dictionary = {}

var vegetation
var world_scene
var columns: Dictionary = {}
var indexed_cells_count:=0
var render_configured:=false
var active: Dictionary = {}
var empty: Dictionary = {}
var required: Dictionary = {}
var queue: Array[Vector3i] = []
var online_queue: Array[Vector3i] = []
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
	store.mesh_bounds=vegetation.grass_mesh.get_aabb()
	profile_started_usec=Time.get_ticks_usec()
	var args:=OS.get_cmdline_user_args()
	use_baked=not "--grass-no-bake" in args
	use_bulk=not "--grass-legacy-upload" in args
	profiling=not "--grass-no-profile" in args
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
	if use_baked and world_scene.metadata.has("mesh_sha256"):
		store.open(world_scene.ASSETS+"grass_bake",STORE.signature(world_scene))
		if not store.last_error.is_empty():push_warning(store.last_error)

func _exit_tree() -> void:
	store.close()

func _record(key: String,usec: int,for_work: bool=true) -> void:
	if not profiling or not collect_detailed_timings:return
	profile_totals[key]=int(profile_totals.get(key,0))+usec
	frame_phases[key]=int(frame_phases.get(key,0))+usec
	if for_work and not work.is_empty():
		var stats: Dictionary=work.stats
		stats[key]=int(stats.get(key,0))+usec

func _ray(q: PhysicsRayQueryParameters3D,kind: String) -> Dictionary:
	if not profiling or not collect_detailed_timings:return space.intersect_ray(q)
	var start:=Time.get_ticks_usec();var hit:=space.intersect_ray(q)
	_record(kind+"_usec",Time.get_ticks_usec()-start)
	_record(kind+"_count",1)
	return hit

func _update_frustum() -> void:
	var camera:=get_viewport().get_camera_3d()
	frustum=[]
	if camera!=null:frustum=camera.get_frustum();camera_position=camera.global_position

func _in_view(cell: Vector3i) -> bool:
	if frustum.is_empty():return true
	var middle:=Vector3(cell)*CELL+Vector3.ONE*CELL*.5
	for plane: Plane in frustum:
		# Godot's camera planes face outward; project the cell half-extents.
		if plane.distance_to(middle)>plane.normal.abs().dot(Vector3.ONE*CELL*.5):return false
	return true

func register_cell(cell: Vector3i) -> void:
	var column:=Vector2i(cell.x,cell.z)
	if not columns.has(column):columns[column]=[]
	(columns[column] as Array).append(cell)
	indexed_cells_count+=1

func _distance_squared(cell: Vector3i,point: Vector3) -> float:
	var minimum:=Vector3(cell)*CELL
	return point.distance_squared_to(point.clamp(minimum,minimum+Vector3.ONE*CELL))

func refresh() -> void:
	if not is_instance_valid(vegetation.target):return
	var refresh_start:=Time.get_ticks_usec()
	_update_frustum()
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
		if store.is_empty(cell):empty[cell]=true
		if active.has(cell) or empty.has(cell):continue
		if not requested_at.has(cell):
			requested_at[cell]=Time.get_ticks_usec();arrival_times.append(Time.get_ticks_usec());total_requested+=1
			latest_record.erase(cell)
		if _in_view(cell) and _distance_squared(cell,camera_position)<=128*128 and not visible_at.has(cell):visible_at[cell]=Time.get_ticks_usec()
		if not ready_cells.has(cell) and (work.is_empty() or cell!=work.cell) and (staging.is_empty() or staging.cell!=cell):queue.append(cell)
	priority_scores.clear()
	for cell: Vector3i in queue:priority_scores[cell]=_score(cell)
	for cell: Vector3i in ready_cells:priority_scores[cell]=_score(cell)
	queue.sort_custom(func(a:Vector3i,b:Vector3i):return priority(a)<priority(b))
	online_queue.clear()
	for cell: Vector3i in queue:
		if not use_baked or not store.contains(cell):online_queue.append(cell)
	# Leaving a 5 m height band never invalidates data. Retain both the current
	# sphere and the forward sphere, with hysteresis beyond their load radii.
	var remove: Array[Vector3i]=[]
	for cell:Vector3i in active:
		if required.has(cell):continue
		if _distance_squared(cell,center)>RETAIN_RADIUS*RETAIN_RADIUS and _distance_squared(cell,predicted_center)>AHEAD_RETAIN_RADIUS*AHEAD_RETAIN_RADIUS:remove.append(cell)
	for cell:Vector3i in remove:
		var unload_start:=Time.get_ticks_usec()
		var chunk: Node3D=active[cell]
		vegetation._remove_chunk_nodes_from_tracking(chunk)
		chunk.queue_free();active.erase(cell);total_unloaded+=1
		_record("unload_usec",Time.get_ticks_usec()-unload_start,false)
	if not work.is_empty() and not required.has(work.cell):
		paused[work.cell]=work;work={}
		if paused.size()>8:
			var dropped: Vector3i=paused.keys()[0]
			var cancelled: Dictionary=paused[dropped].stats.duplicate()
			cancelled["cell"]=str(dropped);cancelled["cancelled"]=true;cancelled["samples"]=paused[dropped].samples
			if cell_reports.size()<4096:cell_reports.append(cancelled)
			paused.erase(dropped);total_cancelled+=1
	for cell:Vector3i in ready_cells.keys():
		if not required.has(cell):ready_cells.erase(cell)
	# Age only the current request, not a previous visit to the same cell.
	for cell:Vector3i in requested_at.keys():
		if not required.has(cell):requested_at.erase(cell);visible_at.erase(cell)
	queue_refresh_usec=Time.get_ticks_usec()-refresh_start
	_record("refresh_usec",queue_refresh_usec,false)

func priority(cell: Vector3i) -> float:
	return float(priority_scores.get(cell,10000.0))

func _score(cell: Vector3i) -> float:
	var delta:=Vector3(cell)*CELL+Vector3.ONE*CELL*.5-center
	var distance:=sqrt(_distance_squared(cell,center))
	var age: float=(Time.get_ticks_usec()-int(requested_at.get(cell,Time.get_ticks_usec())))/1000000.0
	var camera_distance:=sqrt(_distance_squared(cell,camera_position))
	if distance<24:return distance
	if _in_view(cell) and camera_distance<=76:return 100+camera_distance-minf(age*2,60)
	if _in_view(cell) and camera_distance<=128:return 400+camera_distance-minf(age*3,250)
	if distance<76:return 800+distance-minf(age*4,500)
	var speed:=prediction_velocity.length()
	if speed>.8 and delta.dot(prediction_velocity.normalized())>0:
		var time_until_visible:=maxf(0,distance-110)/speed
		return 1200+time_until_visible*50+distance-minf(age*8,900)
	return 2000+distance-minf(age*12,1800)

func tick(delta: float) -> void:
	var tick_start:=Time.get_ticks_usec()
	if not render_configured:
		vegetation.grass_material.set_shader_parameter("skip_invisible_grass",not "--grass-legacy-vertices" in OS.get_cmdline_user_args())
		render_configured=true
	frame_phases={}
	last_commit_usec=0
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
	var poll_start:=Time.get_ticks_usec();store.poll()
	_record("poll_usec",Time.get_ticks_usec()-poll_start,false)
	# A queued upload holds at most one cell's buffers; background completions
	# live in the bounded CPU cache. Never synchronously load a file here.
	var checked:=0
	for cell: Vector3i in queue:
		if ready_cells.size()>=2:break
		if active.has(cell) or empty.has(cell):continue
		if not staging.is_empty() and staging.cell==cell:continue
		checked+=1
		var cached: Dictionary=store.get_data(cell)
		if not cached.is_empty():ready_cells[cell]=cached
		elif use_baked and store.contains(cell):store.request(cell)
		if checked>=16 and store.jobs.size()>=STORE.MAX_JOBS:break
	_commit_ready()
	var budget:=DRIVING_BUDGET_USEC if prediction_velocity.length()>6 else BASE_BUDGET_USEC
	# Refresh, polling and upload consume the same main-thread time allowance.
	while Time.get_ticks_usec()-tick_start<budget:
		if work.is_empty():
			if online_queue.is_empty():break
			var cell:Vector3i=online_queue.pop_front()
			if active.has(cell) or empty.has(cell) or ready_cells.has(cell) or not required.has(cell):continue
			if not staging.is_empty() and staging.cell==cell:continue
			if store.jobs.has(STORE.key(cell)):continue
			if use_baked and store.contains(cell):continue
			_begin(cell)
		if int(work.samples)>=vegetation.GRASS_SAMPLES_PER_CHUNK:_finish();break
		for sample in SAMPLE_BATCH:
			_sample()
			if int(work.samples)>=vegetation.GRASS_SAMPLES_PER_CHUNK:break
		if int(work.samples)>=vegetation.GRASS_SAMPLES_PER_CHUNK:
			_finish();break
	last_build_usec=Time.get_ticks_usec()-tick_start
	last_phases=frame_phases

func _begin(cell: Vector3i) -> void:
	if paused.has(cell):work=paused[cell];paused.erase(cell);return
	var rng:=RandomNumberGenerator.new()
	rng.seed=abs(cell.x*73856093 ^ cell.y*83492791 ^ cell.z*19349663 ^ 0x4A31)
	work={"cell":cell,"samples":0,"rng":rng,"near":[],"near_data":[],"far":[],"far_data":[],"roots":[],"root_states":[],"stats":{},"started_usec":Time.get_ticks_usec()}
	build_counts[cell]=int(build_counts.get(cell,0))+1
	if build_counts[cell]>1:total_rebuilt+=1

func sample_surfaces(cell: Vector3i,x: float,z: float) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var upper: float=(cell.y+1)*CELL+1.6
	var lower: float=cell.y*CELL-.002
	var water: float=-INF
	if lower<max_water_y+.15:
		water_query.from=Vector3(x,max_water_y+1,z);water_query.to=Vector3(x,lower,z)
		var water_hit:=_ray(water_query,"water_ray")
		if not water_hit.is_empty():water=water_hit.position.y
	for step in 18:
		query.from=Vector3(x,upper,z);query.to=Vector3(x,lower,z)
		var hit:=_ray(query,"terrain_ray")
		if hit.is_empty():break
		var p:Vector3=hit.position
		if floori((p.y+.001)/CELL)==cell.y and (hit.normal as Vector3).y>.72:
			var blocked:=p.y<=water+.15
			if not blocked:
				# Thin architectural paving can sit only 1–3cm above the plantable
				# host. Stop 5mm above the root so those decks also block planting.
				exposure_query.from=p+Vector3.UP*1.55;exposure_query.to=p+Vector3.UP*.005
				blocked=not _ray(exposure_query,"clearance_ray").is_empty()
			if not blocked:
				var mask_start:=Time.get_ticks_usec()
				var band: bool=world_scene.architectural_band(p,.55)
				_record("mask_usec",Time.get_ticks_usec()-mask_start)
				if not band:result.append(hit);_record("surface_hits",1)
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
		var coverage_start:=Time.get_ticks_usec()
		var coverage: float=vegetation.grass_coverage_unmasked(p,normal)
		_record("coverage_usec",Time.get_ticks_usec()-coverage_start)
		if rng.randf()>coverage:continue
		var math_start:=Time.get_ticks_usec()
		if capture_roots:
			(work.roots as Array).append_array([x,z,p.y-origin.y,normal.x,normal.y,normal.z])
			(work.root_states as Array).append(rng.state)
		BUFFER.append_blades(rng,x,z,p.y-origin.y,normal,work.near,work.far,work.near_data,work.far_data,vegetation.GRASS_FAR_SURVIVOR_FRACTION)
		_record("math_usec",Time.get_ticks_usec()-math_start)
	work.samples+=1
	_record("samples",1)

func payload() -> Dictionary:
	var start:=Time.get_ticks_usec()
	var result: Dictionary={"near":BUFFER.pack(work.near,work.near_data),"far":BUFFER.pack(work.far,work.far_data),"bounds":[],"bytes":0}
	for group: String in ["near","far"]:
		var b:=BUFFER.bounds(result[group],vegetation.grass_mesh.get_aabb())
		result.bounds.append([b.position.x,b.position.y,b.position.z,b.size.x,b.size.y,b.size.z])
		result.bytes+=(result[group] as PackedFloat32Array).size()*4
	_record("pack_usec",Time.get_ticks_usec()-start)
	return result

func _finish() -> void:
	var cell: Vector3i=work.cell
	var record: Dictionary=work.stats.duplicate()
	record["cell"]=str(cell);record["near"]=work.near.size();record["far"]=work.far.size()
	record["enqueue_usec"]=requested_at.get(cell,0);record["first_visible_usec"]=visible_at.get(cell,0)
	record["sampling_ready_usec"]=Time.get_ticks_usec();record["rebuild_count"]=build_counts.get(cell,1)-1
	latest_record[cell]=record
	record["sample_wall_ms"]=(Time.get_ticks_usec()-int(work.started_usec))/1000.0
	if cell_reports.size()<4096:cell_reports.append(record)
	if work.near.is_empty() and work.far.is_empty():
		empty[cell]=true;_served(cell)
	else:store.pack_async(cell,work,vegetation.grass_mesh.get_aabb())
	work={}

func _served(cell: Vector3i) -> void:
	total_served+=1
	completion_times.append(Time.get_ticks_usec())
	if latest_record.has(cell):latest_record[cell]["gpu_ready_usec"]=Time.get_ticks_usec()
	if requested_at.has(cell):
		completed_ages.append((Time.get_ticks_usec()-int(requested_at[cell]))/1000000.0)
		if completed_ages.size()>4096:completed_ages.pop_front()
	requested_at.erase(cell);visible_at.erase(cell)

func _commit_ready() -> void:
	var cells:=ready_cells.keys()
	cells.sort_custom(func(a:Vector3i,b:Vector3i):return priority(a)<priority(b))
	var start:=Time.get_ticks_usec()
	if not staging.is_empty() and not required.has(staging.cell):
		(staging.chunk as Node3D).queue_free();staging={}
	while Time.get_ticks_usec()-start<COMMIT_BUDGET_USEC:
		if staging.is_empty():
			if cells.is_empty():break
			var cell: Vector3i=cells.pop_front()
			if not required.has(cell) or active.has(cell) or empty.has(cell):ready_cells.erase(cell);continue
			var chunk:=Node3D.new();chunk.name="GrassVolume_%d_%d_%d"%[cell.x,cell.y,cell.z]
			chunk.position=Vector3(cell)*CELL;chunk.visible=false;add_child(chunk)
			staging={"cell":cell,"chunk":chunk,"data":ready_cells[cell],"group":0,"offset":0,"commit_usec":0,"upload_usec":0}
			ready_cells.erase(cell)
		_upload_piece()
	last_commit_usec=Time.get_ticks_usec()-start
	max_commit_usec=maxi(max_commit_usec,last_commit_usec)

func _upload_piece() -> void:
	var commit_start:=Time.get_ticks_usec()
	var cell: Vector3i=staging.cell;var data: Dictionary=staging.data;var chunk: Node3D=staging.chunk
	if staging.group<2:
		var group: String="near" if staging.group==0 else "far"
		var source: PackedFloat32Array=data[group]
		var offset: int=staging.offset
		if offset>=source.size()/16:staging.group+=1;staging.offset=0;return
		var buffer:=source.slice(offset*16,mini(source.size(),(offset+UPLOAD_INSTANCES)*16))
		var b: Array=data.bounds[staging.group]
		var end:float=vegetation.GRASS_NEAR_FADE_END if group=="near" else vegetation.GRASS_FAR_FADE_END
		var upload_start:=Time.get_ticks_usec()
		var node: MultiMeshInstance3D
		if use_bulk:
			node=BUFFER.make_node("Grass_"+group,vegetation.grass_mesh,vegetation.grass_material,buffer,end+CELL*1.5,AABB(Vector3(b[0],b[1],b[2]),Vector3(b[3],b[4],b[5])))
		else:
			var transforms: Array[Transform3D]=[];var custom: Array[Color]=[]
			for at in range(0,buffer.size(),16):
				transforms.append(Transform3D(Basis(Vector3(buffer[at],buffer[at+4],buffer[at+8]),Vector3(buffer[at+1],buffer[at+5],buffer[at+9]),Vector3(buffer[at+2],buffer[at+6],buffer[at+10])),Vector3(buffer[at+3],buffer[at+7],buffer[at+11])))
				custom.append(Color(buffer[at+12],buffer[at+13],buffer[at+14],buffer[at+15]))
			node=vegetation._make_multimesh_node("Grass_"+group,vegetation.grass_mesh,transforms,vegetation.grass_material,0,end+CELL*1.5,custom)
		var upload_time:=Time.get_ticks_usec()-upload_start
		staging.upload_usec+=upload_time;_record("upload_usec",upload_time,false)
		node.set_meta("grass_population",group);node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.extra_cull_margin=1.5
		chunk.add_child(node)
		staging.offset+=buffer.size()/16
		var piece_time:=Time.get_ticks_usec()-commit_start
		staging.commit_usec+=piece_time;_record("commit_usec",piece_time,false)
		return
	# Activate a complete cell atomically, never an unfinished population.
	for node: MultiMeshInstance3D in chunk.get_children():
		if node.get_meta("grass_population")=="near":vegetation.grass_lod0_nodes.append(node)
		else:vegetation.grass_lod1_nodes.append(node)
	vegetation._apply_lod_state_to_chunk(chunk);chunk.visible=true
	if not latest_record.has(cell):
		var record: Dictionary={"cell":str(cell),"enqueue_usec":requested_at.get(cell,0),"first_visible_usec":visible_at.get(cell,0),"source":"baked_or_cpu_cache"}
		latest_record[cell]=record
		if cell_reports.size()<4096:cell_reports.append(record)
	latest_record[cell]["commit_usec"]=staging.commit_usec;latest_record[cell]["upload_usec"]=staging.upload_usec
	active[cell]=chunk;total_built+=1;_served(cell)
	staging={}

func pending_visible_count() -> int:
	var count:=0
	for cell:Vector3i in required:
		if _distance_squared(cell,center)>110*110:continue
		if not active.has(cell) and not empty.has(cell):count+=1
	return count

func metrics() -> Dictionary:
	var seconds:=maxf((Time.get_ticks_usec()-profile_started_usec)/1000000.0,.001)
	var cutoff:=Time.get_ticks_usec()-5000000
	while not arrival_times.is_empty() and arrival_times[0]<cutoff:arrival_times.pop_front()
	while not completion_times.is_empty() and completion_times[0]<cutoff:completion_times.pop_front()
	var oldest:=0.0;var ages: Array[float]=[]
	for cell: Vector3i in requested_at:
		var age: float=(Time.get_ticks_usec()-int(requested_at[cell]))/1000000.0;ages.append(age)
		if visible_at.has(cell) and _in_view(cell) and _distance_squared(cell,camera_position)<=128*128:oldest=maxf(oldest,(Time.get_ticks_usec()-int(visible_at[cell]))/1000000.0)
	ages.sort()
	return {"active":active.size(),"queued":queue.size(),"building":not work.is_empty(),"pending_visible":pending_visible_count(),"built":total_built,"unloaded":total_unloaded,"last_build_ms":last_build_usec/1000.0,"lookahead_m":center.distance_to(predicted_center),"speed_mps":prediction_velocity.length(),"commit_ms":last_commit_usec/1000.0,"max_commit_ms":max_commit_usec/1000.0,"incoming_per_s":arrival_times.size()/minf(seconds,5),"completed_per_s":completion_times.size()/minf(seconds,5),"oldest_visible_s":oldest,"queue_p95_s":0.0 if ages.is_empty() else ages[maxi(0,ceili(ages.size()*.95)-1)],"ready_cells":ready_cells.size(),"cancelled":total_cancelled,"rebuilt":total_rebuilt,"cache":store.metrics(),"visible":visible_missing(),"phases":last_phases,"indexed_cells":indexed_cells_count}

func visible_missing() -> Dictionary:
	var result: Dictionary={"0_48":0,"48_76":0,"76_110":0,"110_128":0}
	for cell: Vector3i in required:
		if active.has(cell) or empty.has(cell) or not _in_view(cell):continue
		var d:=sqrt(_distance_squared(cell,camera_position))
		if d>128:continue
		var band: String="0_48" if d<48 else ("48_76" if d<76 else ("76_110" if d<110 else "110_128"))
		result[band]+=1
	return result

func profile_report() -> Dictionary:
	return {"totals":profile_totals,"cells":cell_reports,"current":metrics(),"detailed_timing_enabled":profiling and collect_detailed_timings,"note":"Counts are candidate cells until sampled or baked empty. Optional profiling has overhead. Upload is bounded to 16,384 instances per call; only complete cells become visible."}
