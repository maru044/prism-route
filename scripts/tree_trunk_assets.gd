extends RefCounted
## Approved wood meshes shared by world instancing and runtime tree authoring.
## Crowns, palettes, planting transforms and grass generation remain independent.
const SCENES := {
	"small":preload("res://assets/vegetation/models/tree_small_trunk_connected_comparison_v2.glb"),
	"broad":preload("res://assets/vegetation/models/tree_broad_trunk_connected_comparison_v2.glb"),
	"upright":preload("res://assets/vegetation/models/tree_upright_trunk_connected_comparison_v2.glb"),
	"birch":preload("res://assets/vegetation/models/tree_birch_trunk_connected_comparison_v2.glb"),
	"cypress":preload("res://assets/vegetation/models/tree_cypress_trunk_connected_comparison_v2.glb"),
}
const SOURCE_SPECIES := {
	"res://assets/vegetation/models/tree_small_broad_canopy.glb":"small",
	"res://assets/vegetation/models/tree_medium_broad_clustered_canopy.glb":"broad",
	"res://assets/vegetation/models/tree_medium_upright_asymmetric_canopy.glb":"upright",
	"res://assets/vegetation/models/tree_medium_birch_upright_canopy.glb":"birch",
	"res://assets/vegetation/models/tree_medium_columnar_cypress.glb":"cypress",
}
static var meshes: Dictionary = {}

static func mesh_for(species: String) -> Mesh:
	if not SCENES.has(species):return null
	if not meshes.has(species):
		var root: Node3D = SCENES[species].instantiate()
		var nodes := root.find_children("*","MeshInstance3D",true,false)
		assert(nodes.size()==1,"Approved trunk must contain exactly one wood mesh")
		var wood: MeshInstance3D = nodes[0]
		assert(wood.transform.is_equal_approx(Transform3D.IDENTITY),"Approved wood must use tree-local coordinates")
		meshes[species] = wood.mesh
		root.free()
	return meshes[species]

static func apply_streamer(renderer: Node) -> void:
	for pair: Array in [["small","tree_near"],["broad","tree_large_broad"],["upright","tree_large_upright"]]:
		var wood := mesh_for(pair[0])
		renderer.set(pair[1]+"_trunk_mesh",wood)
		renderer.set(pair[1]+"_lod1_trunk_mesh",wood)
	# The renderer keeps one trunk pass through the near/medium range. Far LOD
	# renders only the unchanged crown impostor, so it needs no duplicate wood.

static func apply_visual(tree: Node3D) -> void:
	var species: String = SOURCE_SPECIES.get(tree.scene_file_path,"")
	if species.is_empty():return # Future/custom species keep their own geometry.
	for node: MeshInstance3D in tree.find_children("*","MeshInstance3D",true,false):
		if "trunk" in str(node.name).to_lower():node.mesh=mesh_for(species)
