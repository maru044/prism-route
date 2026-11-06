extends SceneTree
## Fixed-camera material A/B in the actual main world; no scene or bake writes.
const OUT="res://docs/beach_slope_1107/"
var world
var sand_meshes: Array[MeshInstance3D]=[]
var measurements: Array=[]
func _initialize() -> void:call_deferred("run")
func settle(seconds: float) -> void:
	var start:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<seconds*1000.:await process_frame
func capture(label: String,material: Material) -> void:
	for mesh in sand_meshes:mesh.material_override=material
	await settle(1.)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
	var gpu:=0.;var cpu:=0.;var frames:=0
	var start:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<1000:
		await process_frame
		gpu+=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		cpu+=RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		frames+=1
	measurements.append({"view":label,"gpu_ms":gpu/frames,"render_cpu_ms":cpu/frames,"samples":frames})
	print("SAND_MATERIAL_CAPTURE ",label)
func run() -> void:
	create_timer(150).timeout.connect(func():push_error("Sand material review timeout");quit(1))
	AudioServer.set_bus_mute(0,true);Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	world=load("res://scenes/main.tscn").instantiate();world.automation_enabled=true;root.add_child(world)
	while not world.test_ready:await process_frame
	world.set_free(true)
	for layer: CanvasLayer in world.review_ui_layers:layer.visible=false
	for mesh: MeshInstance3D in world.model.find_children("*","MeshInstance3D",true,false):
		if str(mesh.name).begins_with("Sand_"):sand_meshes.append(mesh)
	assert(sand_meshes.size()==4)
	var after: ShaderMaterial=load("res://assets/environment/beach_sand/beach_sand.tres")
	var before:=ShaderMaterial.new();var shader:=Shader.new()
	shader.code=FileAccess.get_file_as_string(OUT+"material_before.gdshader.txt")
	assert(not shader.code.is_empty());before.shader=shader
	for key: String in ["sand_detail","sand_normal","sand_roughness","sand_macro","shore_distance","shore_origin","shore_extent"]:
		before.set_shader_parameter(key,after.get_shader_parameter(key))
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/beach_slope_1107/manifest.json"))
	var a: Array=manifest.report.profiles[3].xyz[0]
	var b: Array=manifest.report.profiles[3].xyz[-1]
	var p:=Vector3(float(a[0])-1450.,0.,1150.-float(a[1]))
	var direction:=(Vector3(float(b[0])-1450.,0.,1150.-float(b[1]))-p).normalized()
	world.character.set_spawn(p-direction*6.+Vector3.UP*.08,atan2(-direction.x,-direction.z))
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	var views: Array=[
		{"name":"shore","eye":p-direction*9.+Vector3.UP*2.2,"target":p+direction*36.+Vector3.UP*.15},
		{"name":"wet","eye":p-direction*2.8+Vector3.UP*.8,"target":p+direction*5.5},
		{"name":"overview","eye":p-direction*20.+Vector3.UP*12.,"target":p+direction*14.}]
	for view: Dictionary in views:
		world.camera.global_position=view.eye;world.camera.look_at(view.target)
		await settle(2.)
		await capture("material_before_"+str(view.name),before)
		await capture("material_after_"+str(view.name),after)
	var report: Dictionary={"entry":"scenes/main.tscn","sand_meshes":sand_meshes.size(),
		"adapter":RenderingServer.get_video_adapter_name(),"resolution":[root.size.x,root.size.y],
		"measurements":measurements,"note":"Sequential material A/B; brief local samples, not a whole-world performance benchmark."}
	FileAccess.open(OUT+"material_review.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("SAND_MATERIAL_REVIEW_DONE")
	quit()
