extends SceneTree
## Exercise the formal loader, full-detail collisions and rendered LODs.
const OUT := "res://assets/world/current_map_validation/review/"
var scene
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+name+".png")==OK,"Capture failed")
func measure() -> Dictionary:
	for i in 20:await process_frame
	var values: Array[float]=[]
	for i in 60:
		await process_frame
		values.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
	values.sort()
	return {"gpu_median_ms":values[30],"gpu_p95_ms":values[56],"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
func run() -> void:
	root.size=Vector2i(1600,900);RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	scene=load("res://scenes/map_1021.tscn").instantiate();scene.automation_enabled=true;scene.vegetation_bake_only=true;root.add_child(scene)
	while not scene.test_ready:await process_frame
	scene.set_process(false);scene.character.set_physics_process(false);scene.camper.set_physics_process(false)
	scene.character.visible=false;scene.camper.visible=false
	for layer: CanvasLayer in scene.find_children("*","CanvasLayer",true,false):layer.visible=false
	var byid: Dictionary={}
	for row: Dictionary in scene.metadata.object_records:byid[row.id]=row
	var nodes: Array=scene.model.find_children("*","MeshInstance3D",true,false)
	var lod_objects:=0;var lod_levels:=0;var shadow_meshes:=0;var collision_shapes:=0;var collision_triangles:=0
	var doc:=GLTFDocument.new();var state:=GLTFState.new()
	assert(doc.append_from_file(ProjectSettings.globalize_path(scene.ASSETS+"current_region.glb"),state)==OK)
	var raw:=doc.generate_scene(state);var raw_byid: Dictionary={}
	for n: MeshInstance3D in raw.find_children("*","MeshInstance3D",true,false):raw_byid[str(n.name).get_slice("_",1)]=n
	var different_face_layouts: Array=[]
	for n: MeshInstance3D in nodes:
		var id:=str(n.name).get_slice("_",1);var row: Dictionary=byid[id];var lods:=0
		check(n.mesh.surface_get_array_index_len(0)==int(row.index_count),"Base triangle count mismatch: "+id)
		for s in n.mesh.get_surface_count():lods+=(RenderingServer.mesh_get_surface(n.mesh.get_rid(),s).get("lods",[]) as Array).size()
		if lods>0:lod_objects+=1
		lod_levels+=lods
		if n.mesh.shadow_mesh!=null:shadow_meshes+=1
		if n.mesh.get_faces().to_byte_array()!=(raw_byid[id] as MeshInstance3D).mesh.get_faces().to_byte_array():different_face_layouts.append(id)
		for collider: CollisionShape3D in n.find_children("*","CollisionShape3D",true,false):
			collision_shapes+=1
			check(collider.shape is ConcavePolygonShape3D and collider.shape.backface_collision,"Collision strategy changed")
			var count: int=collider.shape.get_faces().size()/3;collision_triangles+=count
			check(count==int(row.index_count)/3,"Collision uses reduced LOD geometry: "+id)
	check(nodes.size()==199 and lod_objects>100 and shadow_meshes==199,"Imported LOD/shadow resources missing")
	# The importer reorders triangles for vertex-cache locality. Compare their
	# oriented geometric multiset, not serialized face order (Python audit).
	var parity: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"mesh_repair_imported_faces.json"))
	check(parity.get("passed",false) and parity.get("mesh_sha256","")==scene.metadata.mesh_sha256,"Imported base geometry parity failed or stale")
	raw.free()
	var views: Array=[
		{"name":"overview","eye":Vector3(-160,1800,2100),"target":Vector3(-250,15,400)},
		{"name":"bridge","eye":Vector3(-180,105,1350),"target":Vector3(-100,55,1200)},
		{"name":"gallery","eye":Vector3(-870,42,1160),"target":Vector3(-890,38,1125)},
		{"name":"double_bridge","eye":Vector3(-100,100,630),"target":Vector3(-250,45,650)}]
	var measurements: Array=[]
	var threshold:=root.mesh_lod_threshold
	for view: Dictionary in views:
		scene.camera.make_current();scene.camera.global_position=view.eye;scene.camera.look_at(view.target)
		for enabled: bool in [false,true]:
			root.mesh_lod_threshold=threshold if enabled else 0.0
			var row: Dictionary=await measure();row.merge({"view":view.name,"lod_enabled":enabled});measurements.append(row)
			await capture("mesh_repaired_%s_%s"%[view.name,"lod" if enabled else "full"])
			print("MESH_REPAIR_VIEW ",JSON.stringify(row))
	root.mesh_lod_threshold=0.0
	for n: MeshInstance3D in nodes:
		var id:=str(n.name).get_slice("_",1)
		n.visible=id in ["d01b8d98-9f3d-46e7-8737-7b60ad7a5657","de6391b1-e6fa-48bf-978c-b261e0d6d4b4"]
		if n.visible:
			var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
			mat.albedo_color=Color("ec6c48") if id.begins_with("d01") else Color("428bea");n.material_override=mat
	scene.camera.global_position=Vector3(-1120,330,300);scene.camera.look_at(Vector3(-1100,23,100))
	for i in 10:await process_frame
	await capture("mesh_repaired_overlap_diagnostic")
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"objects":nodes.size(),"lod_objects":lod_objects,"lod_levels":lod_levels,"shadow_meshes":shadow_meshes,"collision_shapes":collision_shapes,"collision_triangles":collision_triangles,"base_geometry_identical_to_direct_gltf":parity.get("passed",false),"reordered_face_layouts":different_face_layouts.size(),"measurements":measurements,"resolution":"1600x900","vegetation":false,"note":"Formal production scene loader, full-detail collision unchanged; LOD on/off changes rendering only. GPU figures exclude vegetation and startup."}
	var file:=FileAccess.open(OUT+"mesh_repair_runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close();print("MESH_REPAIR_TEST ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
