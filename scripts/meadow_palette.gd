extends RefCounted
## Original world zoning plus a bounded north-lake override; no root bake.
const LAKE_MASK=preload("res://assets/world/meadow_zone_1030/lake_green_sdf.res")
const SHORE_MASK=preload("res://assets/world/meadow_zone_1030/shore_green_sdf.res")
const ZONE := {
	"biome_noise_scale":0.00135,"biome_warp_distance":210.,
	"biome_transition_half_width":135.,"biome_center_x":20.,
	"biome_lowland_enabled":true,"biome_lowland_fade":Vector2(40.,60.),
	"biome_lowland_green":0.94,"biome_local_feather":80.,
	"biome_shore_enabled":true,
}
const BIOME_PARAMETERS := ["biome_noise_texture","biome_noise_scale","biome_warp_distance","biome_transition_half_width","biome_center_x","biome_lowland_enabled","biome_lowland_fade","biome_lowland_green","biome_local_sdf","biome_local_bounds","biome_local_feather","biome_shore_enabled","biome_shore_sdf","biome_shore_bounds"]
const GRASS := {
	"canopy_color_uniformity":1.0,
	"canopy_base_color":Color.WHITE,
	"palette_dry":Color("ccb472"),
	"palette_green":Color("73a448"),
	"root_tone":0.94,
	"tip_tone":1.035,
	"wind_tone_strength":0.14,
}
const GROUND := {"ground_dry":Color("b1a064"),"ground_green":Color("71944b")}
# Screen-calibrated distant meadow, separate from the darker root layer.
const FAR_GROUND := {"far_ground_dry":Color("f9ca6b"),"far_ground_green":Color("69af3f")}

static func apply_grass(material: ShaderMaterial) -> void:
	for parameter: String in GRASS:material.set_shader_parameter(parameter,GRASS[parameter])
	for parameter: String in ZONE:material.set_shader_parameter(parameter,ZONE[parameter])
	material.set_shader_parameter("biome_local_sdf",LAKE_MASK)
	var origin: Vector2=LAKE_MASK.get_meta("world_origin")
	var extent: Vector2=LAKE_MASK.get_meta("world_extent")
	material.set_shader_parameter("biome_local_bounds",Vector4(origin.x,origin.y,extent.x,extent.y))
	material.set_shader_parameter("biome_shore_sdf",SHORE_MASK)
	var shore_origin: Vector2=SHORE_MASK.get_meta("world_origin")
	var shore_extent: Vector2=SHORE_MASK.get_meta("world_extent")
	material.set_shader_parameter("biome_shore_bounds",Vector4(shore_origin.x,shore_origin.y,shore_extent.x,shore_extent.y))
	material.set_shader_parameter("biome_instance_overlap",35.)

static func apply_ground(material: ShaderMaterial) -> void:
	for parameter: String in GROUND:material.set_shader_parameter(parameter,GROUND[parameter])
	for parameter: String in FAR_GROUND:material.set_shader_parameter(parameter,FAR_GROUND[parameter])
	material.set_shader_parameter("use_far_meadow_color",true)
	material.set_shader_parameter("meadow_color_fade",Vector2(48.0,128.0))
