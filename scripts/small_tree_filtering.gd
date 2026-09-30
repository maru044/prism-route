class_name SmallTreeFiltering
extends RefCounted
## Accepted small-tree baseline. Historical comparison is archived.
const TEXTURES := [
	preload("res://assets/vegetation/textures/filtered_lod/leaf_coverage.res"),
	preload("res://assets/vegetation/textures/filtered_lod/clump_coverage.res"),
	preload("res://assets/vegetation/textures/filtered_lod/canopy_coverage.res"),
]
const SMOOTHING := [0.62, 0.35, 0.0]

static func apply(material: ShaderMaterial, level: int) -> void:
	material.set_shader_parameter("albedo_texture", TEXTURES[level])
	material.set_shader_parameter("canopy_smoothing_strength", SMOOTHING[level])
	material.set_shader_parameter("canopy_color_uniformity", 0.85 if level < 2 else 0.0)
	material.set_shader_parameter("canopy_base_color", Color(91.0/255.0, 120.0/255.0, 75.0/255.0)
		if level == 0 else Color(106.8/255.0, 131.6/255.0, 94.1/255.0))
	material.set_shader_parameter("tree_canopy_center_local", Vector3(0.011, 3.672, -0.049))
	material.set_shader_parameter("tree_canopy_radii_local", Vector3(3.850, 2.568, 2.883))
