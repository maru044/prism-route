@tool
extends SceneTree

const BUFFER := preload("res://scripts/grass_instance_buffer.gd")
const STREAMER := preload("res://scripts/grass_volume_streamer.gd")
const WIND_WORLD := preload("res://scripts/grass_wind_world.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("TEST: Starting grass buffer and streamer defense tests~")

	# Test 1: Normal pack
	var transforms: Array = [Transform3D.IDENTITY, Transform3D(Basis(), Vector3(1, 2, 3))]
	var colors: Array = [Color.WHITE, Color.RED]
	var buf: PackedFloat32Array = BUFFER.pack(transforms, colors)
	assert(buf.size() == 32, "Normal pack size should be 32")
	assert(buf[0] == 1.0 and buf[19] == 1.0 and buf[27] == 3.0, "Pack values should match")
	print("PASS: Normal pack succeeded~")

	# Test 2: Mismatched size or empty pack
	var empty_buf: PackedFloat32Array = BUFFER.pack([], [])
	assert(empty_buf.is_empty(), "Empty pack should return empty array")
	var mismatched_buf: PackedFloat32Array = BUFFER.pack([Transform3D.IDENTITY], [])
	assert(mismatched_buf.is_empty(), "Mismatched pack should return empty array safely")
	print("PASS: Empty and mismatched pack defense succeeded~")

	# Test 3: make_node with empty and valid buffers
	var mesh := BoxMesh.new()
	var mat := StandardMaterial3D.new()
	var empty_node: MultiMeshInstance3D = BUFFER.make_node("empty_grass", mesh, mat, empty_buf, 50.0, AABB())
	assert(empty_node.multimesh != null, "Empty node should have multimesh")
	assert(empty_node.multimesh.instance_count == 0, "Empty node should have 0 instance count")
	empty_node.free()

	var valid_node: MultiMeshInstance3D = BUFFER.make_node("valid_grass", mesh, mat, buf, 50.0, AABB())
	assert(valid_node.multimesh != null, "Valid node should have multimesh")
	assert(valid_node.multimesh.instance_count == 2, "Valid node should have 2 instances")
	valid_node.free()
	print("PASS: make_node empty and valid checks passed~")

	# Test 4: make_display_multimesh in streamer
	var streamer := STREAMER.new()
	var empty_mm: MultiMesh = streamer.make_display_multimesh(mesh, empty_buf, AABB(), false)
	assert(empty_mm.instance_count == 0, "Streamer empty MM should have 0 instances")

	var valid_mm: MultiMesh = streamer.make_display_multimesh(mesh, buf, AABB(), true)
	assert(valid_mm.instance_count == 2, "Streamer valid MM should have 2 instances")
	streamer.free()
	print("PASS: Streamer make_display_multimesh defense passed~")

	# Test 5: grass_wind_world LOD switch without MultiMesh reallocation
	var wind_world := WIND_WORLD.new()
	var test_inst := MultiMeshInstance3D.new()
	test_inst.multimesh = valid_mm
	var box_aabb := AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))
	test_inst.set_meta("wind_bounds", box_aabb)
	test_inst.set_meta("wind_mesh", mesh)
	test_inst.set_meta("wind_lod", 4)
	
	var alt_mesh := SphereMesh.new()
	wind_world.lod_meshes = {1: alt_mesh, 2: alt_mesh, 4: mesh}
	wind_world.optimized = false
	wind_world.reference_mesh = alt_mesh
	wind_world._update_node_lod(test_inst, true)
	assert(test_inst.multimesh.mesh == alt_mesh, "Mesh should switch directly without recreating multimesh")
	assert(test_inst.multimesh == valid_mm, "MultiMesh instance must be preserved to prevent memory leak")
	
	test_inst.free()
	wind_world.free()
	print("PASS: Wind world zero-allocation mesh switch passed~")

	print("ALL GRASS DEFENSE TESTS COMPLETED SUCCESSFULLY!")
	quit(0)
