extends SceneTree
## Inspect actual runtime meshes and time collision cooking without vegetation.
const OUT := "res://assets/world/current_map_validation/review/"
func _initialize() -> void:call_deferred("run")
func inspect_meshes(model: Node) -> Dictionary:
	var rows: Array=[]
	for node: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var mesh: ArrayMesh=node.mesh
		var surfaces: Array=[]
		for s in mesh.get_surface_count():
			var data:=RenderingServer.mesh_get_surface(mesh.get_rid(),s)
			var lods: Array=[]
			for lod in data.get("lods",[]):
				lods.append({"keys":lod.keys(),"edge_length":lod.get("edge_length",0),"index_bytes":lod.get("index_data",PackedByteArray()).size()})
			surfaces.append({"vertices":mesh.surface_get_array_len(s),"indices":mesh.surface_get_array_index_len(s),"format":mesh.surface_get_format(s),"lods":lods,"data_keys":data.keys()})
		rows.append({"name":str(node.name),"surfaces":surfaces,"shadow_mesh":mesh.shadow_mesh!=null,"aabb_size":[mesh.get_aabb().size.x,mesh.get_aabb().size.y,mesh.get_aabb().size.z]})
	return {"mesh_nodes":rows.size(),"rows":rows}
func run() -> void:
	var t:=Time.get_ticks_usec()
	var doc:=GLTFDocument.new();var state:=GLTFState.new()
	assert(doc.append_from_file(ProjectSettings.globalize_path("res://assets/world/current_map_validation/current_region.glb"),state)==OK)
	var model:=doc.generate_scene(state)
	var load_ms:=(Time.get_ticks_usec()-t)/1000.0
	var runtime:=inspect_meshes(model)
	var meta: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/current_map_validation/metadata.json"))
	var byid: Dictionary={}
	for row: Dictionary in meta.object_records:byid[row.id]=row
	var cooking: Array=[];var total_faces:=0;var create_total_ms:=0.0
	t=Time.get_ticks_usec()
	for node: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var id:=str(node.name).get_slice("_",1);var row: Dictionary=byid[id]
		if not row.get("collision",true) and row.kind!="Water":continue
		var begin:=Time.get_ticks_usec()
		var shape:=node.mesh.create_trimesh_shape();shape.backface_collision=true
		var create_ms:=(Time.get_ticks_usec()-begin)/1000.0;create_total_ms+=create_ms
		var faces:=shape.get_faces().size()/3
		total_faces+=faces
		cooking.append({"id":id,"triangles":faces,"create_shape_ms":create_ms})
	var cook_ms:=(Time.get_ticks_usec()-t)/1000.0
	model.free()
	t=Time.get_ticks_usec()
	var imported: PackedScene=load("res://assets/world/current_map_validation/current_region.glb")
	var imported_model:=imported.instantiate()
	var editor_import:=inspect_meshes(imported_model)
	var imported_ms:=(Time.get_ticks_usec()-t)/1000.0
	imported_model.free()
	var report: Dictionary={"engine":Engine.get_version_info(),"runtime_direct_gltf":runtime,"editor_imported_resource":editor_import,"runtime_load_generate_ms":load_ms,"imported_resource_load_instantiate_ms":imported_ms,"collision_shapes":cooking.size(),"collision_triangles":total_faces,"collision_shape_creation_ms":create_total_ms,"collision_shape_extraction_and_verification_ms":cook_ms,"collision_rows":cooking,"occlusion_setting":ProjectSettings.get_setting("rendering/occlusion_culling/use_occlusion_culling",false),"limits":"Single headless inspection run, not a cold-load benchmark. Does not include full physics-server registration, GPU upload or end-user frame times. Creation time excludes verification get_faces copies."}
	var file:=FileAccess.open(OUT+"mesh_audit_runtime.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("MESH_RUNTIME_AUDIT_DONE runtime_meshes=",runtime.mesh_nodes," collision_triangles=",total_faces," cooking_ms=",cook_ms)
	quit()
