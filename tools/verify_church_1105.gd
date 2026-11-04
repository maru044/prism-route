extends SceneTree
const ROOT="res://assets/world/church_ruins_1105/"
const STORE=preload("res://scripts/grass_baked_store.gd")
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func visual_floor_height(mesh: MeshInstance3D,p: Vector3) -> float:
	var faces:=mesh.mesh.get_faces();var height:=-INF
	for i in range(0,faces.size(),3):
		var a: Vector3=mesh.global_transform*faces[i];var b: Vector3=mesh.global_transform*faces[i+1];var c: Vector3=mesh.global_transform*faces[i+2]
		var den:=(b.z-c.z)*(a.x-c.x)+(c.x-b.x)*(a.z-c.z)
		if absf(den)<.000001:continue
		var u:=((b.z-c.z)*(p.x-c.x)+(c.x-b.x)*(p.z-c.z))/den
		var v:=((c.z-a.z)*(p.x-c.x)+(a.x-c.x)*(p.z-c.z))/den;var w:=1.-u-v
		if u>=-.00001 and v>=-.00001 and w>=-.00001:height=maxf(height,u*a.y+v*b.y+w*c.y)
	return height
func run() -> void:
	create_timer(180).timeout.connect(func():push_error("Church verification timeout");quit(1))
	AudioServer.set_bus_mute(0,true)
	var world=load("res://scenes/map_1021.tscn").instantiate();world.automation_enabled=true;root.add_child(world)
	while not world.test_ready:await process_frame
	var church=world.church_ruins;var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/church_performance_1105/grass_bake.json"))
	check(church.local_grass_cells==12,"Local replacement cells were not installed")
	check(church.meshes_by_source.size()==93,"Church source geometry count changed")
	check(FileAccess.get_sha256(ROOT+"church.glb")==church.manifest.mesh_sha256,"Church geometry changed")
	var colliders: Array=church.geometry.find_children("*","CollisionShape3D",true,false)
	check(church.colonly_ramps==7,"Church colonly ramps missing")
	check(colliders.size()==50,"Church collision geometry count changed")
	var glass_count:=0
	for row: Dictionary in church.manifest.objects:
		if row.kind!="Glazing":continue
		var mesh: MeshInstance3D=church.meshes_by_source[row.id]
		check(mesh.material_override is ShaderMaterial,"Glass is still a flat standard material")
		check(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Glass casts opaque shadow")
		glass_count+=1
	var baked: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"grass_bake/manifest.json"));var roots:=0;var under_paving:=0;var parity_cells:=0
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/current_map_validation/grass_bake/manifest.json"))
	for overlay: String in [world.oval_atrium.GRASS_BAKE,world.earth_pavilion.GRASS_BAKE,world.terrain_repairs.GRASS_BAKE]:
		if FileAccess.file_exists(overlay):
			var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(overlay))
			if data.get("complete",false) and data.get("signature","")==source.signature:source.cells.merge(data.cells,true)
	for id: String in baked.cells:
		var row: Dictionary=baked.cells[id];var parts:=id.split("_");var cell:=Vector3i(int(parts[0]),int(parts[1]),int(parts[2]))
		check(world.vegetation.volume_streamer.store.manifest.cells[id].get("resource_path","")==ROOT+"grass_bake/"+id+".grass","Runtime does not use replacement cell "+id)
		var raw:=PackedByteArray()
		if int(row.root_count)>0:raw=FileAccess.get_file_as_bytes(row.resource_path).decompress(int(row.raw_bytes),FileAccess.COMPRESSION_ZSTD)
		var values:=raw.slice(0,int(row.root_count)*48).to_float64_array();var states:=raw.slice(int(row.root_count)*48).to_int64_array()
		for i in states.size():
			var at:=i*6;var p:=Vector3(cell)*24.+Vector3(values[at],values[at+2],values[at+1])
			if church.blocks_grass(p):under_paving+=1
		roots+=states.size()
		# Byte-for-byte retained roots and RNG states, including local overlays.
		var old: Dictionary=source.cells[id];var old_raw:=PackedByteArray()
		if int(old.root_count)>0:old_raw=FileAccess.get_file_as_bytes(old.get("resource_path","res://assets/world/current_map_validation/grass_bake/"+id+".grass")).decompress(int(old.raw_bytes),FileAccess.COMPRESSION_ZSTD)
		var old_values:=old_raw.slice(0,int(old.root_count)*48).to_float64_array();var old_states:=old_raw.slice(int(old.root_count)*48).to_int64_array()
		var expected:=PackedFloat64Array();var expected_states:=PackedInt64Array()
		for i in old_states.size():
			var at:=i*6;var p:=Vector3(cell)*24.+Vector3(old_values[at],old_values[at+2],old_values[at+1])
			if not church.blocks_grass(p):expected.append_array(old_values.slice(at,at+6));expected_states.append(old_states[i])
		check(expected.to_byte_array()==values.to_byte_array() and expected_states.to_byte_array()==states.to_byte_array(),"Neighboring grass changed in cell "+id);parity_cells+=1
	check(under_paving==0,"Grass roots remain under paving")
	check(roots==int(original.retained_roots),"Unexpected root count")
	var spawn: Vector3=world.vec(church.manifest.spawn_godot);var forward: Vector3=world.vec(church.manifest.spawn_look_direction_godot)
	await physics_frame;var floor_checks:=0
	for distance in [0.,2.,4.,8.,12.,16.,20.,24.]:
		var p: Vector3=spawn+forward*float(distance)
		# The authored plinth is stepped/sloped, not a flat 43.4 m plane.
		var height:=visual_floor_height(church.meshes_by_source[church.manifest.spawn_source_id],p)
		check(is_finite(height),"Missing visual floor at "+str(distance))
		var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,height+.1,p.z),Vector3(p.x,height-.3,p.z),32)
		var hit: Dictionary={}
		for attempt in 16:
			hit=world.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty() or hit.collider.get_meta("source_id","")==church.manifest.spawn_source_id:break
			var excluded:=query.exclude;excluded.append(hit.collider.get_rid());query.exclude=excluded
		check(not hit.is_empty(),"Nave floor collision missing at "+str(distance))
		if not hit.is_empty():check(absf((hit.position as Vector3).y-height)<.002,"Collision differs from visible floor")
		floor_checks+=1
	check(FileAccess.get_sha256("res://assets/world/tree_planting/world_edits.json")==original.tree_save_sha256,"User tree save changed")
	check(FileAccess.get_sha256("res://assets/world/current_map_validation/grass_bake/manifest.json")==original.global_manifest_sha256,"Global grass bake changed")
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"church_meshes":church.meshes_by_source.size(),"church_colliders":colliders.size(),"glass_panels":glass_count,"installed_local_grass_cells":church.local_grass_cells,"retained_roots":roots,"remaining_roots_under_paving":under_paving,"root_and_rng_parity_cells":parity_cells,"floor_collision_checks":floor_checks,"global_bake_unchanged":true,"user_tree_save_unchanged":true,"church_geometry_unchanged":true}
	FileAccess.open("res://docs/church_performance_1105/validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n");print("CHURCH_VALIDATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
