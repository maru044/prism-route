extends SceneTree
const BUFFER := preload("res://scripts/grass_instance_buffer.gd")
const STORE := preload("res://scripts/grass_baked_store.gd")
const STREAM := preload("res://scripts/grass_volume_streamer.gd")
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func run() -> void:
	root.size=Vector2i(640,480)
	var world:=Node3D.new();root.add_child(world)
	var camera:=Camera3D.new();camera.position=Vector3(0,15,28);world.add_child(camera);camera.look_at(Vector3.ZERO)
	var mesh:=BoxMesh.new();mesh.size=Vector3(.6,1.1,.4)
	var material:=ShaderMaterial.new();var shader:=Shader.new()
	shader.code="shader_type spatial; render_mode unshaded; varying vec4 tint; void vertex(){tint=INSTANCE_CUSTOM;} void fragment(){ALBEDO=tint.rgb;}"
	material.shader=shader
	var rng:=RandomNumberGenerator.new();rng.seed=131021
	var transforms: Array[Transform3D]=[];var custom: Array[Color]=[]
	for i in 20800:
		transforms.append(Transform3D(Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3(rng.randf_range(.8,1.4),rng.randf_range(.9,1.16),rng.randf_range(.8,1.4))),Vector3(rng.randf_range(-12,12),rng.randf_range(0,2),rng.randf_range(-12,12))))
		custom.append(Color(rng.randf(),rng.randf(),rng.randf(),rng.randf()))
	var start:=Time.get_ticks_usec();var packed:=BUFFER.pack(transforms,custom);var pack_us:=Time.get_ticks_usec()-start
	var bounds:=BUFFER.bounds(packed,mesh.get_aabb())
	start=Time.get_ticks_usec()
	var legacy:=MultiMesh.new();legacy.transform_format=MultiMesh.TRANSFORM_3D;legacy.use_custom_data=true;legacy.mesh=mesh;legacy.instance_count=transforms.size()
	for i in transforms.size():legacy.set_instance_transform(i,transforms[i]);legacy.set_instance_custom_data(i,custom[i])
	var legacy_us:=Time.get_ticks_usec()-start
	var old_node:=MultiMeshInstance3D.new();old_node.multimesh=legacy;old_node.material_override=material;world.add_child(old_node)
	await process_frame;await RenderingServer.frame_post_draw
	var before:=root.get_texture().get_image()
	start=Time.get_ticks_usec()
	var node:=BUFFER.make_node("Bulk",mesh,material,packed,0,bounds);var bulk_us:=Time.get_ticks_usec()-start
	world.add_child(node);old_node.visible=false
	await process_frame;await RenderingServer.frame_post_draw
	var after:=root.get_texture().get_image()
	var max_error:=0.0
	for i in transforms.size():
		var got:=node.multimesh.get_instance_transform(i);var expected:=legacy.get_instance_transform(i)
		max_error=maxf(max_error,got.origin.distance_to(expected.origin))
		for axis in 3:max_error=maxf(max_error,got.basis[axis].distance_to(expected.basis[axis]))
		check(node.multimesh.get_instance_custom_data(i).is_equal_approx(legacy.get_instance_custom_data(i)),"Custom data layout mismatch")
	check(max_error<.00001,"Bulk matrix layout mismatch")
	var pixels_equal:=before.get_data()==after.get_data()
	check(pixels_equal,"Bulk versus setters changed rendered pixels")
	var vegetation=load("res://scripts/map_1021_vegetation.gd").new()
	world.add_child(vegetation);vegetation.grass_mesh=mesh;vegetation.grass_material=material
	var staged:=STREAM.new();world.add_child(staged);staged.vegetation=vegetation
	staged.required[Vector3i.ZERO]=true
	staged.ready_cells[Vector3i.ZERO]={"near":packed,"far":PackedFloat32Array(),"bounds":[[bounds.position.x,bounds.position.y,bounds.position.z,bounds.size.x,bounds.size.y,bounds.size.z],[0,0,0,0,0,0]]}
	var slices:=0
	while not staged.active.has(Vector3i.ZERO) and slices<30:
		staged._commit_ready();slices+=1
		if not staged.staging.is_empty():check(not staged.staging.chunk.visible,"Partial grass cell became visible")
		await process_frame
	check(staged.active.has(Vector3i.ZERO),"Staged cell never completed")
	check(staged.active[Vector3i.ZERO].get_child_count()==2,"Large grass population was not split into bounded uploads")
	node.visible=false
	await process_frame;await RenderingServer.frame_post_draw
	var staged_pixels_equal:=before.get_data()==root.get_texture().get_image().get_data()
	check(staged_pixels_equal,"Staged uploads changed rendered pixels")
	var stream:=STREAM.new();world.add_child(stream);stream._update_frustum()
	check(stream._in_view(Vector3i(0,0,-1)),"Frustum rejects a forward cell")
	check(not stream._in_view(Vector3i(0,0,5)),"Frustum accepts a cell behind the camera")
	stream.center=Vector3.ZERO;stream.camera_position=camera.position;stream.prediction_velocity=Vector3(18,0,0)
	var visible_cell:=Vector3i(0,0,-2);var predicted_cell:=Vector3i(6,0,0)
	check(stream._score(visible_cell)<stream._score(predicted_cell),"Predicted cells outrank visible near grass")
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"instances":transforms.size(),"max_transform_error":max_error,"pixels_equal":pixels_equal,"staged_pixels_equal":staged_pixels_equal,"staged_frames":slices,"pack_ms":pack_us/1000.0,"legacy_upload_ms":legacy_us/1000.0,"bulk_upload_ms":bulk_us/1000.0,"custom_aabb":str(bounds)}
	var file:=FileAccess.open("res://assets/world/current_map_validation/review/issue13_buffer_parity.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("ISSUE13_BUFFER_VERIFY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
