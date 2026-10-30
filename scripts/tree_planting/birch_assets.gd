extends RefCounted
## One source of birch meshes/materials for editor handles and world batches.
const NEAR=preload("res://assets/vegetation/models/tree_medium_birch_upright_canopy.glb")
const MIDDLE=preload("res://assets/vegetation/models/tree_medium_birch_upright_canopy_lod1.glb")
const FAR=preload("res://assets/vegetation/models/tree_medium_birch_upright_canopy_lod2_impostor.glb")
const LEAF=preload("res://assets/vegetation/textures/leaf_clusters_birch_sparse_flat_v1.png")
const CLUMP=preload("res://assets/vegetation/textures/tree_birch_clump_unlit_4var_v1.png")
const IMPOSTOR=preload("res://assets/vegetation/textures/tree_birch_canopy_unlit_8view_v1.png")
const BARK=preload("res://assets/vegetation/textures/bark_birch_flat_v1.png")
const GREEN_VALUES={
	"use_species_palette":1.0,"species_palette_stage":3.0,
	"species_deep_color":Color("7c8966"),"species_shadow_color":Color("8c9e76"),
	"species_mid_color":Color("a8b98b"),"species_light_color":Color("c0cda4"),
	"species_accent_color":Color("a8b98b"),"species_accent_amount":0.0,"species_seed":0.34,
}
var leaves: Array[Mesh]=[]
var materials: Array[ShaderMaterial]=[]
var wood: Mesh
var bark: StandardMaterial3D

func initialize(renderer: Node) -> void:
	wood=preload("res://scripts/tree_trunk_assets.gd").mesh_for("birch")
	for scene: PackedScene in [NEAR,MIDDLE,FAR]:leaves.append(renderer._extract_tree_meshes(scene)[1])
	var center:=Vector3(0,7.05,0);var radii:=Vector3(3.15,4.75,3.05)
	var near_material: ShaderMaterial=renderer._make_tree_lod0_material(center,radii)
	near_material.set_shader_parameter("albedo_texture",LEAF)
	near_material.set_shader_parameter("wind_strength",0.082)
	near_material.set_shader_parameter("wind_speed",0.58)
	near_material.set_shader_parameter("alpha_cutoff",0.48)
	near_material.set_shader_parameter("alpha_antialiasing_edge",0.26)
	materials.append(near_material)
	materials.append(renderer._make_tree_hlod_material(CLUMP,false,center,radii,Vector4(160,200,280,330)))
	materials.append(renderer._make_tree_hlod_material(IMPOSTOR,true,center,radii,Vector4(280,330,5700,renderer.MAP_FAR_TREE_END)))
	for material: ShaderMaterial in materials:
		# Preserve the approved grove palette when the shared world style binds.
		# Other explicitly selected palettes (pink/gold/etc.) still work normally.
		material.set_meta("foliage_green_palette",GREEN_VALUES)
		material.set_shader_parameter("tree_local_normal_weight",0.30)
		# The generic painted atlases depict other crowns. Keep birch's own baked
		# silhouette, including when the global painted-foliage switch is toggled.
		material.set_shader_parameter("use_painted_foliage",false)
		renderer.painted_lod_materials.erase(material)
	bark=StandardMaterial3D.new()
	bark.albedo_texture=BARK;bark.albedo_color=Color("e2ded1");bark.roughness=0.98
	bark.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

func add_level(renderer: Node,parent: Node3D,transforms: Array[Transform3D],palette: int,level: int,margin: float) -> void:
	if leaves.is_empty():initialize(renderer)
	if level<2:
		renderer._add_tree_mesh_pair(parent,"Tree3_LOD%d"%level,wood,leaves[level],transforms,materials[level],
			0.0 if level==0 else maxf(0.,160.-margin),(200. if level==0 else 330.)+margin,level,palette,level==0,330.+margin)
		if level==0:parent.get_node("Tree3_LOD0_Trunks").material_override=bark
	else:
		var node: MultiMeshInstance3D=renderer._make_multimesh_node("Tree3_LOD2_Impostors",leaves[2],transforms,
			renderer._get_tree_palette_material(materials[2],palette),maxf(0.,280.-margin),renderer.MAP_FAR_TREE_END+margin)
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node);renderer.tree_lod2_nodes.append(node)
