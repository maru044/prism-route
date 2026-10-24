extends SceneTree
## Exact current Godot/Jolt sampler and RNG, for a pilot or full-map shards.
## Does not load trees or alter CAD; publishes data through the merge validator.
const STREAM := preload("res://scripts/grass_volume_streamer.gd")
const VEG := preload("res://scripts/map_1021_vegetation.gd")
const STORE := preload("res://scripts/grass_baked_store.gd")
const DEST := "res://assets/world/current_map_validation/grass_bake/"
var scene
var stream
var manifest_path:=DEST+"manifest.json"

func _initialize() -> void:call_deferred("run")
func run() -> void:
	scene=load("res://scenes/map_1021.tscn").instantiate()
	scene.automation_enabled=true;scene.vegetation_bake_only=true;root.add_child(scene)
	while not scene.test_ready:await process_frame
	var vegetation:=VEG.new();vegetation.world_scene=scene;scene.add_child(vegetation)
	vegetation.target=scene.camera;vegetation.biome_noise_texture=scene._noise();vegetation._load_meshes_and_materials()
	stream=STREAM.new();vegetation.add_child(stream);stream.initialize(vegetation,scene)
	stream.use_baked=false
	stream.collect_detailed_timings=true
	stream.capture_roots=true
	var signature:=STORE.signature(scene)
	var args:=OS.get_cmdline_user_args();var full: bool="--full" in args
	var shard_count:=1;var shard_index:=0
	for arg in args:
		if arg.begins_with("--shards="):shard_count=maxi(1,int(arg.get_slice("=",1)))
		if arg.begins_with("--shard="):shard_index=int(arg.get_slice("=",1))
	assert(shard_index>=0 and shard_index<shard_count)
	if shard_count>1:manifest_path=DEST+"manifest_part_%d.json"%shard_index
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	var manifest: Dictionary={"version":2,"signature":signature,"scope":"issue13 pilot: 360m camera corridor plus representative roofs/terraces; online fallback elsewhere","cells":{}}
	if FileAccess.file_exists(DEST+"manifest.json"):
		var previous=JSON.parse_string(FileAccess.get_file_as_string(DEST+"manifest.json"))
		if previous is Dictionary and previous.get("signature","")==signature:manifest=previous
	if FileAccess.file_exists(manifest_path):
		var previous=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if previous is Dictionary and previous.get("signature","")==signature:manifest=previous
	if full:manifest.scope="full-map generation shard"
	manifest["shard_index"]=shard_index;manifest["shard_count"]=shard_count
	var origin: Vector3=scene.resolved_spawns[7].floor_position+Vector3.UP*4
	var direction:=Vector3(.7,0,-1).normalized()
	var points: Array[Vector3]=[]
	for distance in range(0,553,24):points.append(origin+direction*distance)
	var candidates: Array[Vector3i]=[]
	for column: Array in stream.columns.values():
		for cell: Vector3i in column:
			var include:=full
			for point in points:
				if stream._distance_squared(cell,point)<=168*168:include=true;break
			# Small extra patches cover an actual roof and lower bridge terrace.
			for point in [scene.resolved_spawns[0].floor_position,Vector3(-203.37573,39.5049438,1182.29857)]:
				if stream._distance_squared(cell,point)<=36*36:include=true
			if include:candidates.append(cell)
	candidates.sort()
	var global_candidates:=candidates.size()
	if shard_count>1:
		var subset: Array[Vector3i]=[]
		for i in candidates.size():
			if i%shard_count==shard_index:subset.append(candidates[i])
		candidates=subset
	var started:=Time.get_ticks_msec();var count:=0;var bytes_total:=0;var raw_total:=0;var instance_total:=0
	print("GRASS_BAKE_START candidates=",candidates.size())
	for cell in candidates:
		var id:=STORE.key(cell)
		if manifest.cells.has(id) and FileAccess.file_exists(DEST+id+".grass"):
			count+=1;continue
		stream._begin(cell)
		for i in vegetation.GRASS_SAMPLES_PER_CHUNK:stream._sample()
		var data: Dictionary=stream.payload()
		var roots:=PackedFloat64Array(stream.work.roots);var states:=PackedInt64Array(stream.work.root_states)
		var seed_value: int=stream.work.rng.seed
		var reconstructed:=STREAM.BUFFER.from_roots(roots,states,.2,vegetation.grass_mesh.get_aabb(),seed_value)
		if reconstructed.near.to_byte_array()!=data.near.to_byte_array() or reconstructed.far.to_byte_array()!=data.far.to_byte_array():
			push_error("Baked data parity failed at "+id+" roots="+str(states.size())+" near="+str(data.near.size()/16));quit(1);return
		stream.work={}
		var raw: PackedByteArray=roots.to_byte_array();raw.append_array(states.to_byte_array())
		var compressed:=PackedByteArray() if raw.is_empty() else raw.compress(FileAccess.COMPRESSION_ZSTD)
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
		if not compressed.is_empty():hash.update(compressed)
		var file:=FileAccess.open(DEST+id+".grass",FileAccess.WRITE);file.store_buffer(compressed);file.close()
		var instances: int=(data.near.size()+data.far.size())/16
		manifest.cells[id]={"instances":instances,"near_count":data.near.size()/16,"far_count":data.far.size()/16,"root_count":states.size(),"seed":seed_value,"raw_bytes":raw.size(),"compressed_bytes":compressed.size(),"sha256":hash.finish().hex_encode(),"bounds":data.bounds}
		count+=1;bytes_total+=compressed.size();raw_total+=raw.size();instance_total+=instances
		if count%25==0:
			print("GRASS_BAKE_PROGRESS ",count,"/",candidates.size()," seconds=",(Time.get_ticks_msec()-started)/1000.0)
			save_manifest(manifest)
		await process_frame
	save_manifest(manifest)
	var report: Dictionary={"candidate_cells":candidates.size(),"global_candidates":global_candidates,"scope":"full" if full else "pilot","shard_index":shard_index,"shard_count":shard_count,"seconds":(Time.get_ticks_msec()-started)/1000.0,"new_compressed_bytes":bytes_total,"new_raw_bytes":raw_total,"new_instances":instance_total,"signature":signature,"profile":stream.profile_totals}
	var report_name: String="issue13_bake_full_part_%d.json"%shard_index if full else "issue13_bake.json"
	if full and bytes_total==0:report_name="issue13_bake_full_part_%d_resume.json"%shard_index
	var report_file:=FileAccess.open("res://assets/world/current_map_validation/review/"+report_name,FileAccess.WRITE)
	report_file.store_string(JSON.stringify(report,"  "));report_file.close()
	print("GRASS_BAKE_DONE ",JSON.stringify(report));quit()

func save_manifest(data: Dictionary) -> void:
	var file:=FileAccess.open(manifest_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data));file.close()
