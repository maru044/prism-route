class_name SmallTreeFiltering
extends RefCounted
## Filtering derivatives of the accepted textures; no generated painting.
const ORIGINAL := [
	preload("res://assets/vegetation/textures/leaf_clusters_witness_sparse_flat_v11.png"),
	preload("res://assets/vegetation/textures/tree_broad_clump_unlit_4var_v1.png"),
	preload("res://assets/vegetation/textures/tree_small_canopy_unlit_8view_v1.png"),
]
const FILTERED := [
	preload("res://assets/vegetation/textures/filtered_lod/leaf_coverage.res"),
	preload("res://assets/vegetation/textures/filtered_lod/clump_coverage.res"),
	preload("res://assets/vegetation/textures/filtered_lod/canopy_coverage.res"),
]
const SMOOTHING := [0.62, 0.35, 0.0]

static func apply(material: ShaderMaterial, level: int, enabled: bool = true) -> void:
	material.set_shader_parameter("albedo_texture", FILTERED[level] if enabled else ORIGINAL[level])
	material.set_shader_parameter("canopy_smoothing_strength", SMOOTHING[level] if enabled else 0.0)
	material.set_shader_parameter("canopy_color_uniformity", 0.85 if enabled and level < 2 else 0.0)
	material.set_shader_parameter("canopy_base_color", Color(91.0/255.0, 120.0/255.0, 75.0/255.0)
		if level == 0 else Color(106.8/255.0, 131.6/255.0, 94.1/255.0))
	if enabled:
		material.set_shader_parameter("tree_canopy_center_local", Vector3(0.011, 3.672, -0.049))
		material.set_shader_parameter("tree_canopy_radii_local", Vector3(3.850, 2.568, 2.883))
