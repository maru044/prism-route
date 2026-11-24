extends SceneTree

const BUFFER := preload("res://scripts/grass_instance_buffer.gd")
const STORE := preload("res://scripts/grass_baked_store.gd")
const STREAMER := preload("res://scripts/grass_volume_streamer.gd")
const WIND := preload("res://scripts/grass_wind_world.gd")

class MapData extends RefCounted:
	const ASSETS := "res://assets/world/current_map_validation/"
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ASSETS + "metadata.json"))

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	var transforms := [Transform3D.IDENTITY, Transform3D(Basis(), Vector3(1, 2, 3))]
	var colors := [Color.WHITE, Color.RED]
	var buffer := BUFFER.pack(transforms, colors)
	check(buffer.size() == 32 and buffer[0] == 1.0 and buffer[19] == 1.0 and buffer[27] == 3.0, "Valid buffers keep the packed layout")
	check(BUFFER.pack([], []).is_empty(), "Empty population is valid")
	check(BUFFER.pack(transforms, []).is_empty(), "Mismatched input stops packing safely")
	check(BUFFER.pack_populations(transforms, colors, transforms, [], AABB()).is_empty(), "A failed population never returns partial data")

	var source := BoxMesh.new()
	var empty := BUFFER.make_node("Empty", source, null, PackedFloat32Array(), 0.0, AABB())
	var valid := BUFFER.make_node("Valid", source, null, buffer, 0.0, AABB())
	var malformed := BUFFER.make_node("Invalid", source, null, buffer.slice(0, 17), 0.0, AABB())
	check(empty != null and empty.multimesh.instance_count == 0, "Empty buffer does not request instances")
	check(valid != null and valid.multimesh.instance_count == 2, "Valid buffer uploads both instances")
	check(malformed == null, "Partial instance is rejected before upload")
	if malformed != null:
		malformed.free()
	if empty != null:
		empty.free()
	if valid != null:
		valid.free()

	var streamer := STREAMER.new()
	root.add_child(streamer)
	var chunk := Node3D.new()
	streamer.add_child(chunk)
	streamer.staging = {"cell":Vector3i.ZERO, "chunk":chunk,
		"data":{"near":buffer.slice(0, 17), "bounds":[[],[]]}, "group":0, "offset":0}
	streamer._upload_piece()
	check(streamer.staging.is_empty() and streamer.active.is_empty() and chunk.is_queued_for_deletion(),
		"An invalid upload discards the entire staged chunk")
	check(streamer.store.allocation_paused(), "A failed upload backs off immediately")
	streamer.free()

	await verify_store(transforms, colors)
	var mesh := WIND.make_presentation_mesh(source, null, 4, true)
	check(mesh.surface_get_array_index_len(0) == 72, "The shared mesh retains its 24-triangle near geometry")
	if DisplayServer.get_name() != "headless":
		await verify_rendered_lods(mesh, buffer.slice(0, 16))
	print("GRASS_DEFENSE_RESULT ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func verify_store(transforms: Array, colors: Array) -> void:
	var store := STORE.new()
	var source := MapData.new()
	var signature := STORE.signature(source)
	check(store.open(source.ASSETS + "grass_bake", signature), "Current world still opens the existing bake")
	check(STORE.buffer_bake_hash(FileAccess.get_sha256("res://scripts/grass_instance_buffer.gd")) == STORE.LEGACY_BUFFER_SHA256,
		"Exact verified compatibility revision maps to the accepted bake")
	var changed := "a future generation change".sha256_text()
	check(STORE.buffer_bake_hash(changed) == changed, "Future revisions change the bake fingerprint")

	var cell := Vector3i.ZERO
	var other := Vector3i(1,0,0)
	var bounds := AABB(Vector3(-1,-1,-1), Vector3.ONE * 2.0)
	var sample := {"near":transforms,"near_data":colors,"far":[], "far_data":[]}
	var invalid := {"near":transforms,"near_data":[], "far":[], "far_data":[]}
	check(store.pack_async(cell, sample, bounds), "First worker slot accepts work")
	check(store.pack_async(other, invalid, bounds), "Second worker slot accepts work")
	check(not store.pack_async(Vector3i(2,0,0), sample, bounds), "Online conversion respects the shared worker limit")
	# The deliberately mismatched population follows the same retry path as a failed pack.
	store.manifest.cells[STORE.key(other)] = {"instances":8}
	var deadline := Time.get_ticks_msec() + 2000
	while not store.jobs.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
		store.poll()
	check(store.jobs.is_empty() and not store.get_data(cell).is_empty(), "Worker completion publishes a valid chunk")
	check(store.get_data(other).is_empty() and store.contains(other) and store.allocation_paused(),
		"A failed conversion neither publishes partial data nor invalidates the bake")
	check(not store.pack_async(other, sample, bounds), "No new worker allocates during the cooldown")
	store.close()

func verify_rendered_lods(mesh: ArrayMesh, buffer: PackedFloat32Array) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920,1080)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.fov = 60.0
	viewport.add_child(camera)
	camera.make_current()
	var matte := StandardMaterial3D.new()
	matte.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	matte.cull_mode = BaseMaterial3D.CULL_DISABLED
	var grass := BUFFER.make_node("Grass",mesh,matte,buffer,0.0,
		AABB(Vector3(-1,-1,-1), Vector3.ONE * 2.0))
	check(grass != null, "Rendering buffer allocation succeeds")
	if grass == null:
		viewport.free()
		return
	viewport.add_child(grass)
	var multi_rid := grass.multimesh.get_rid()
	var buffer_rid := RenderingServer.multimesh_get_buffer_rd_rid(multi_rid)
	check(buffer_rid.is_valid(), "Forward+ returns a real storage buffer")
	var triangles: Array[int] = []
	for distance: float in [10.0, 31.0, 60.0, 10.0]:
		camera.position = Vector3(0,0,distance)
		for frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		triangles.append(viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))
		check(grass.multimesh.get_rid() == multi_rid and RenderingServer.multimesh_get_buffer_rd_rid(multi_rid) == buffer_rid,
			"Camera movement keeps the original MultiMesh and storage buffer")
	check(triangles == [24,12,6,24], "Forward+ selects all three index LODs and returns to full detail")
	print("GRASS_NATIVE_LODS ", JSON.stringify(triangles))
	viewport.free()
