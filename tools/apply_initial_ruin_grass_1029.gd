extends SceneTree
## Only removes newly occluded roots; retains every surviving root/RNG state byte.
const STORE=preload("res://scripts/grass_baked_store.gd")
const BUFFER=preload("res://scripts/grass_instance_buffer.gd")
const MASK=preload("res://scripts/world/initial_ruin_mask.gd")
const BASE="res://assets/world/current_map_validation/"
const BACKUP="res://.current_map_build/initial_ruin_1029_before/grass_bake/"
const OUT="res://docs/initial_ruin_1029/"
class SignatureWorld:
	extends RefCounted
	const ASSETS="res://assets/world/current_map_validation/"
	var metadata: Dictionary
var failures: Array[String]=[]

func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func digest(bytes: PackedByteArray) -> String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():hash.update(bytes)
	return hash.finish().hex_encode()
func put_json(path: String,value) -> void:
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(value,"  "))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT);DirAccess.make_dir_recursive_absolute(BACKUP)
	var context:=SignatureWorld.new();context.metadata=JSON.parse_string(FileAccess.get_file_as_string(BASE+"metadata.json"))
	var expected:=STORE.signature(context)
	var current: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BASE+"grass_bake/manifest.json"))
	if current.signature==expected:
		print("INITIAL_RUIN_GRASS_ALREADY_CURRENT ",expected);quit();return
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BACKUP+"manifest.json"))
	check(original.signature=="fbff5b4111f4a5b47d716476007ed1d2e00e83d3bf54219c60618738ab6daf9a","Unexpected source bake; cannot prove unchanged terrain")
	var old_metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://.current_map_build/initial_ruin_1029_before/metadata.json"))
	check(old_metadata.mesh_sha256==context.metadata.mesh_sha256,"Base terrain mesh changed")
	if not failures.is_empty():quit(1);return
	var model: Node3D=load("res://assets/vegetation/models/grass_star_3card_v6.glb").instantiate()
	var mesh: Mesh=(model.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D).mesh
	var mesh_bounds:=mesh.get_aabb();model.free()
	var mask=MASK.new();var manifest: Dictionary=original.duplicate(true)
	var updates: Array[Dictionary]=[];var changed: Array[Dictionary]=[]
	var scanned:=0;var preserved:=0;var removed_roots:=0;var checked_files:=0
	for id: String in original.cells:
		var row: Dictionary=original.cells[id];var filename:=BASE+"grass_bake/"+id+".grass"
		var bytes:=FileAccess.get_file_as_bytes(filename)
		if digest(bytes)!=row.sha256 and FileAccess.file_exists(BACKUP+id+".grass"):bytes=FileAccess.get_file_as_bytes(BACKUP+id+".grass")
		check(digest(bytes)==row.sha256,"Source grass file is corrupt: "+id);checked_files+=1
		if not failures.is_empty():quit(1);return
		var parts:=id.split("_");var cell:=Vector3i(int(parts[0]),int(parts[1]),int(parts[2]));var origin:=Vector3(cell)*24.
		var rect:=Rect2(Vector2(origin.x,origin.z),Vector2(24,24))
		if not rect.intersects(mask.bounds.grow(.55)) or int(row.root_count)==0:
			preserved+=1;continue
		scanned+=1
		var raw:=bytes.decompress(int(row.raw_bytes),FileAccess.COMPRESSION_ZSTD)
		check(raw.size()==int(row.root_count)*56,"Bad grass root buffer: "+id)
		if not failures.is_empty():quit(1);return
		var at_states:=int(row.root_count)*48
		var roots:=raw.slice(0,at_states).to_float64_array();var states:=raw.slice(at_states).to_int64_array()
		var kept:=PackedFloat64Array();var kept_states:=PackedInt64Array()
		for i in states.size():
			var a:=i*6;var point:=origin+Vector3(roots[a],roots[a+2],roots[a+1])
			if mask.blocks(point,.55):continue
			kept.append_array(roots.slice(a,a+6));kept_states.append(states[i])
		var removed:=states.size()-kept_states.size()
		if removed==0:preserved+=1;continue
		var data:=BUFFER.from_roots(kept,kept_states,.20,mesh_bounds,int(row.seed))
		var new_raw:=kept.to_byte_array();new_raw.append_array(kept_states.to_byte_array())
		var compressed:=PackedByteArray() if new_raw.is_empty() else new_raw.compress(FileAccess.COMPRESSION_ZSTD)
		var replacement: Dictionary={"instances":kept_states.size()*4,"root_count":kept_states.size(),"near_count":data.near.size()/16,"far_count":data.far.size()/16,"seed":row.seed,"raw_bytes":new_raw.size(),"compressed_bytes":compressed.size(),"sha256":digest(compressed),"bounds":data.bounds}
		manifest.cells[id]=replacement
		updates.append({"id":id,"bytes":compressed,"before":bytes})
		changed.append({"cell":id,"removed_roots":removed,"before_sha256":row.sha256,"after_sha256":replacement.sha256})
		removed_roots+=removed
		if scanned%20==0:print("INITIAL_RUIN_GRASS_SCAN ",scanned," changed=",changed.size())
		await process_frame
	for update: Dictionary in updates:
		var backup_path: String=BACKUP+str(update.id)+".grass"
		if not FileAccess.file_exists(backup_path):FileAccess.open(backup_path,FileAccess.WRITE).store_buffer(update.before)
		FileAccess.open(BASE+"grass_bake/"+update.id+".grass",FileAccess.WRITE).store_buffer(update.bytes)
	manifest.signature=expected;manifest["static_feature_patch"]="initial_ruin_1029"
	put_json(BASE+"grass_bake/manifest.json",manifest)
	var instances:=0;var compressed_bytes:=0;var raw_bytes:=0;var empty:=0
	for row: Dictionary in manifest.cells.values():
		instances+=int(row.instances);compressed_bytes+=int(row.compressed_bytes);raw_bytes+=int(row.raw_bytes)
		empty+=int(int(row.instances)==0)
	var trees: Array=JSON.parse_string(FileAccess.get_file_as_string(BASE+"tree_layout.json"));var hidden: Array=[]
	for i in trees.size():
		var row: Array=trees[i]
		if mask.blocks(Vector3(row[0],row[1],row[2]),3.):hidden.append({"index":i,"position":row.slice(0,3)})
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"signature":expected,"previous_signature":original.signature,"checked_source_files":checked_files,"affected_candidates":scanned,"changed_cells":changed,"unchanged_files":preserved,"removed_roots":removed_roots,"removed_blades":removed_roots*4,"instances":instances,"cells":manifest.cells.size(),"compressed_bytes":compressed_bytes,"source_layout_trees":trees.size(),"excluded_trees":hidden,"visible_trees":trees.size()-hidden.size(),"base_mesh_unchanged":true,"surviving_root_states_preserved":true}
	put_json(OUT+"vegetation_patch.json",report)
	put_json(BASE+"review/issue13_full_bake.json",{"complete":true,"cells":manifest.cells.size(),"empty":empty,"instances":instances,"compressed_bytes":compressed_bytes,"raw_root_bytes":raw_bytes,"expanded_matrix_bytes":instances*64,"signature":expected,"static_feature_patch":"initial_ruin_1029"})
	print("INITIAL_RUIN_GRASS_RESULT ",JSON.stringify({"passed":report.passed,"changed_cells":changed.size(),"preserved_files":preserved,"removed_blades":removed_roots*4,"visible_trees":trees.size()-hidden.size(),"signature":expected}));quit(0 if failures.is_empty() else 1)
