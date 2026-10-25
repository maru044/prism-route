extends SceneTree
const OUT := "res://.vegetation_art_build/trunk_comparison/species/"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:await process_frame

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func shot(name: String) -> void:
	await frames(5)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+name+".png")==OK,"Screenshot failed: "+name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1600,900)
	Engine.max_fps = 60
	var scene: Node3D = load("res://scenes/vegetation_grove_test.tscn").instantiate()
	root.add_child(scene)
	await frames(20)
	var comparison = scene.trunk_comparison
	if comparison==null or comparison.records.is_empty():
		check(false,"Tree comparison did not initialize")
		quit(1)
		return
	check(comparison.selected_species==1,"Inspection should start on the newly updated small tree")
	var camera: Camera3D = scene.get_node("OrbitCamera")
	camera.set_process(false)
	scene.grass_wind_demo.running = false
	scene.grass_wind_demo.panel.hide()
	scene.get_node("Instructions").hide()
	var snapshots: Array[Dictionary] = []
	for row: Dictionary in comparison.records:
		for leaf: Dictionary in row.leaves:
			snapshots.append({"node":leaf.node,"mesh":leaf.node.mesh,"material":leaf.node.material_override})
	var results: Array[Dictionary] = []
	for index in comparison.SPECIES.size():
		comparison.species_menu.item_selected.emit(index)
		var info: Dictionary = comparison.SPECIES[index]
		var focused: Dictionary = comparison.focused_record()
		check(not focused.is_empty(),"Missing species: "+info.key)
		if focused.is_empty():continue
		var tree: Node3D = focused.tree
		for row: Dictionary in comparison.records:
			check(row.tree.visible==(row.tree==tree),"Isolation does not follow selected species")
		comparison.wood_toggle.button_pressed = true
		for row: Dictionary in comparison.records:
			for leaf: Dictionary in row.leaves:
				check(leaf.node.visible==(leaf.visible and row.tree!=tree),"Inspection hides a different tree's canopy")
		comparison.menu.item_selected.emit(0)
		for row: Dictionary in comparison.records:
			if row.species==index:check(row.node.mesh==row.original,"Cannot restore original "+info.key)
		await shot(info.key+"_original_wood")
		if index==0:
			comparison.menu.item_selected.emit(1)
			check(focused.node.mesh==comparison.candidate_mesh,"Previous broad-tree comparison missing")
		comparison.menu.item_selected.emit(2)
		var instances := 0
		for row: Dictionary in comparison.records:
			if row.species==index:
				instances += 1
				check(row.node.mesh==comparison.meshes[index],"Connected mesh not assigned to "+str(row.tree.name))
			check(row.node.material_override==row.material,"Wood material changed: "+info.key)
		await shot(info.key+"_connected_wood")
		comparison.wood_toggle.button_pressed = false
		comparison.focus_whole_tree()
		await shot(info.key+"_connected_whole")
		var report_name: String = "connected_v2_build.json" if index==0 else info.key+"_v2_build.json"
		var build: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://.vegetation_art_build/trunk_comparison/"+report_name))
		check(build.main_radii_unchanged,"Main trunk thickened: "+info.key)
		check(build.connected_components==1 and build.nonmanifold_edges==0,"Disconnected/open fork: "+info.key)
		check(build.self_intersections==0 and build.degenerate_triangles==0,"Invalid triangles: "+info.key)
		if info.key=="small":
			check(build.branches.is_empty(),"Small tree should have an unbranched trunk")
		if info.key=="birch":
			check(build.bark_uv,"Birch UV missing from Blender model")
			var uv: PackedVector2Array = comparison.meshes[index].surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
			check(not uv.is_empty(),"Birch UV missing after GLB import")
			check(focused.node.material_override.albedo_texture==scene.BIRCH_BARK_TEXTURE,"Birch bark texture changed")
			comparison.wood_toggle.button_pressed = true
			camera.global_position = tree.to_global(Vector3(0,3.0,4.5))
			camera.look_at(tree.to_global(Vector3(0,3.0,0)))
			await shot("birch_bark_fork_close")
			comparison.wood_toggle.button_pressed = false
		results.append({"species":info.key,"instances":instances,"wood_triangles":build.triangles})
	comparison.isolate_toggle.button_pressed = false
	comparison.wood_toggle.button_pressed = false
	for row: Dictionary in comparison.records:
		check(row.tree.visible==row.tree_visible,"Cannot restore grove tree visibility")
		for leaf: Dictionary in row.leaves:check(leaf.node.visible==leaf.visible,"Cannot restore original canopy visibility")
	for snapshot in snapshots:
		check(snapshot.node.mesh==snapshot.mesh and snapshot.node.material_override==snapshot.material,"Accepted canopy mesh/material was changed")
	comparison.select_species(1)
	comparison.isolate_toggle.button_pressed = true
	comparison.focus_trunk()
	var result := {"passed":failures.is_empty(),"failures":failures,"species":results,
		"tree_instances":comparison.records.size(),"foliage_meshes_unchanged":snapshots.size()}
	FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("TREE_TRUNK_SPECIES_VERIFY ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
