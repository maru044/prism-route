extends SceneTree
const OUT := "res://.vegetation_art_build/trunk_comparison/"
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func frames(n: int) -> void:
	for i in n:await process_frame
func check(ok: bool, message: String) -> void:
	if not ok:failures.append(message);push_error(message)
func shot(name: String) -> void:
	await frames(5);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size=Vector2i(1600,900);Engine.max_fps=60
	var scene: Node3D=load("res://scenes/vegetation_grove_test.tscn").instantiate();root.add_child(scene)
	await frames(20)
	var comparison=scene.trunk_comparison
	if comparison==null or comparison.records.is_empty():check(false,"No comparison tree found");quit(1);return
	comparison.select_species(0)
	check(comparison.menu.selected==2 and comparison.selected_variant==2,"Connected comparison is not selected")
	var camera: Camera3D=scene.get_node("OrbitCamera");camera.set_process(false)
	comparison.focus_trunk()
	scene.grass_wind_demo.running=false
	scene.grass_wind_demo.panel.visible=false;scene.get_node("Instructions").hide()
	var tree: Node3D=comparison.records[0].tree
	var leaves: Array[MeshInstance3D]=[];var leaf_meshes: Array[Mesh]=[]
	for node: MeshInstance3D in tree.find_children("*","MeshInstance3D",true,false):
		if "foliage" in str(node.name).to_lower():leaves.append(node);leaf_meshes.append(node.mesh)
	comparison.menu.item_selected.emit(0)
	check(comparison.records[0].node.mesh==comparison.records[0].original,"Original mesh cannot be restored")
	await shot("original_in_grove")
	comparison.menu.item_selected.emit(1)
	check(comparison.records[0].node.mesh==comparison.candidate_mesh,"Candidate menu cannot select the new mesh")
	for i in leaves.size():check(leaves[i].mesh==leaf_meshes[i],"Comparison altered accepted foliage")
	await shot("candidate_in_grove")
	comparison.menu.item_selected.emit(2)
	check(comparison.records[0].node.mesh==comparison.connected_mesh,"Connected comparison cannot be selected")
	await shot("connected_v2_in_grove")
	comparison.focus_whole_tree()
	await shot("connected_v2_whole_tree")
	# An explicitly labelled inspection view exposes the thin wood behind foliage.
	comparison.wood_toggle.button_pressed=true
	for leaf in leaves:check(not leaf.visible,"Wood inspection does not hide the target canopy")
	for row: Dictionary in comparison.records:
		check(row.node.material_override==row.material,"Comparison changed trunk material")
	comparison.focus_trunk()
	for variant in [0,1,2]:
		comparison.set_variant(variant)
		await shot(["original_wood_only","candidate_wood_only","connected_v2_wood_only"][variant])
	camera.global_position=tree.global_position+Vector3(-10.0,4.0,-4.0)
	camera.look_at(tree.to_global(Vector3(0.0,4.0,0.0)))
	await shot("connected_v2_wood_side")
	camera.global_position=tree.to_global(Vector3(0.0,2.25,4.0))
	camera.look_at(tree.to_global(Vector3(0.15,2.25,0.0)))
	await shot("connected_v2_fork_close")
	comparison.wood_toggle.button_pressed=false
	for leaf in leaves:check(leaf.visible,"Cannot restore inspected canopy")
	for i in leaves.size():check(leaves[i].mesh==leaf_meshes[i],"Connected comparison altered accepted foliage")
	comparison.focus_trunk()
	var build: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"connected_v2_build.json"))
	check(build.main_radii_unchanged,"Main trunk was thickened")
	check(build.connected_components==1 and build.nonmanifold_edges==0,"Fork is not one closed connected surface")
	check(build.self_intersections==0 and build.degenerate_triangles==0,"Fork contains invalid triangles")
	var report: Dictionary={"passed":failures.is_empty(),"failures":failures,"changed_trees":comparison.records.size(),"foliage_meshes_unchanged":leaves.size(),"wood_triangles":build.triangles,"main_radii_unchanged":build.main_radii_unchanged,"connected_components":build.connected_components,"self_intersections":build.self_intersections,"nonmanifold_edges":build.nonmanifold_edges}
	FileAccess.open(OUT+"connected_v2_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TRUNK_COMPARISON_VERIFY ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
