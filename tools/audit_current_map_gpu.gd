extends SceneTree
## Temporary A/B only. No saved scene or mesh is modified.
const OUT := "res://assets/world/current_map_validation/review/"
var scene
func _initialize() -> void:call_deferred("run")
func measure() -> Dictionary:
	for i in 35:await process_frame
	var gpu: Array[float]=[];var primitives: Array[float]=[];var draws: Array[float]=[]
	for i in 90:
		await process_frame
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	gpu.sort();primitives.sort();draws.sort()
	return {"gpu_median_ms":gpu[45],"gpu_p95_ms":gpu[85],"engine_primitives_median":primitives[45],"draw_calls_median":draws[45],"vram_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0}
func run() -> void:
	root.size=Vector2i(1600,900)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	scene=load("res://scenes/map_1021.tscn").instantiate();scene.automation_enabled=true;scene.vegetation_bake_only=true
	root.add_child(scene)
	while not scene.test_ready:await process_frame
	scene.set_process(false);scene.set_physics_process(false)
	scene.character.set_physics_process(false);scene.camper.set_physics_process(false)
	scene.character.visible=false;scene.camper.visible=false
	for layer: CanvasLayer in scene.find_children("*","CanvasLayer",true,false):layer.visible=false
	var imported: Node=load("res://assets/world/current_map_validation/current_region.glb").instantiate()
	var imported_meshes: Dictionary={};var original_meshes: Dictionary={}
	for n: MeshInstance3D in imported.find_children("*","MeshInstance3D",true,false):imported_meshes[str(n.name).get_slice("_",1)]=n.mesh
	var model_nodes: Array=scene.model.find_children("*","MeshInstance3D",true,false)
	for n: MeshInstance3D in model_nodes:original_meshes[n]=n.mesh
	var views: Array=[
		{"name":"overview","eye":Vector3(1750,2300,2650),"target":Vector3(0,20,0)},
		{"name":"west_gallery","eye":Vector3(-870,42,1160),"target":Vector3(-890,38,1125)},
		{"name":"north_hill","eye":Vector3(270,24,-8),"target":Vector3(100,12,-220)}]
	var results: Array=[]
	for view: Dictionary in views:
		scene.camera.make_current();scene.camera.global_position=view.eye;scene.camera.look_at(view.target)
		for mode: String in ["runtime_raw","editor_import_lod","runtime_raw_repeat"]:
			for n: MeshInstance3D in model_nodes:n.mesh=imported_meshes[str(n.name).get_slice("_",1)] if mode=="editor_import_lod" else original_meshes[n]
			var result: Dictionary=await measure();result.merge({"view":view.name,"mode":mode});results.append(result)
			print("MESH_GPU ",JSON.stringify(result))
			if mode=="runtime_raw" and view.name=="west_gallery":
				await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"mesh_audit_gallery.png")
			if mode=="runtime_raw" and view.name=="overview":
				await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"mesh_audit_overview.png")
			if mode=="editor_import_lod" and view.name=="overview":
				await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"mesh_audit_overview_lod.png")
	# Isolate the same two overlapping surfaces with diagnostic colors.
	for n: MeshInstance3D in model_nodes:
		var id:=str(n.name).get_slice("_",1)
		n.visible=id in ["d01b8d98-9f3d-46e7-8737-7b60ad7a5657","de6391b1-e6fa-48bf-978c-b261e0d6d4b4"]
		if n.visible:
			var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
			mat.albedo_color=Color("ec6c48") if id.begins_with("d01") else Color("428bea");n.material_override=mat
	scene.camera.global_position=Vector3(-1120,330,300);scene.camera.look_at(Vector3(-1100,23,100))
	for i in 10:await process_frame
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"mesh_audit_overlap_diagnostic.png")
	imported.free()
	var file:=FileAccess.open(OUT+"mesh_audit_gpu.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"resolution":"1600x900","vegetation":false,"variants":results,"note":"Same source geometry and materials; imported mesh resources temporarily substituted on existing nodes. Imported LOD may change silhouettes and requires visual acceptance; this audit does not apply that change. Timings exclude startup. Repeat raw bounds drift."},"  "));file.close();quit()
