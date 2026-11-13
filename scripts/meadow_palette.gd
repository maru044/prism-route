extends RefCounted
## Original zoning plus bounded lake and height-qualified coastal colours; no root bake.
const LAKE_MASK=preload("res://assets/world/meadow_zone_1030/lake_green_sdf.res")
const SHORE_MASK=preload("res://assets/world/meadow_zone_1030/shore_green_sdf.res")
const COAST_MASK=preload("res://assets/world/meadow_zone_1030/coast_field.res")
const COAST_PARAMETERS := ["coastal_enabled","coastal_field","coastal_bounds","coastal_feather","coastal_grass_dry","coastal_grass_mid","coastal_grass_green","coastal_ground_dry","coastal_ground_green","coastal_far_dry","coastal_far_green"]
const COAST_COLOURS := {
	"coastal_grass_dry":Color("297d9d"),"coastal_grass_mid":Color("4796aa"),"coastal_grass_green":Color("64a8b4"),
	"coastal_ground_dry":Color("2c778e"),"coastal_ground_green":Color("3b91a1"),
	"coastal_far_dry":Color("337f9b"),"coastal_far_green":Color("509fb0"),
	"coastal_tree_shadow":Color("8757b3"),"coastal_tree_mid":Color("b086df"),"coastal_tree_light":Color("d4b1f1"),
}
const COAST_GREEN_CROWN := {
	"coastal_tree_shadow":Color("65a38c"),"coastal_tree_mid":Color("78ceb5"),"coastal_tree_light":Color("9be7ca"),
}
static var coast_image: Image
const ZONE := {
	"biome_noise_scale":0.00135,"biome_warp_distance":210.,
	"biome_transition_half_width":135.,"biome_center_x":20.,
	"biome_lowland_enabled":true,"biome_lowland_fade":Vector2(40.,60.),
	"biome_lowland_green":0.94,"biome_local_feather":80.,
	"biome_shore_enabled":true,
}
const BIOME_PARAMETERS := ["biome_noise_texture","biome_noise_scale","biome_warp_distance","biome_transition_half_width","biome_center_x","biome_lowland_enabled","biome_lowland_fade","biome_lowland_green","biome_local_sdf","biome_local_bounds","biome_local_feather","biome_shore_enabled","biome_shore_sdf","biome_shore_bounds"]+COAST_PARAMETERS
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
	apply_coastal(material)

static func apply_ground(material: ShaderMaterial) -> void:
	for parameter: String in GROUND:material.set_shader_parameter(parameter,GROUND[parameter])
	for parameter: String in FAR_GROUND:material.set_shader_parameter(parameter,FAR_GROUND[parameter])
	material.set_shader_parameter("use_far_meadow_color",true)
	material.set_shader_parameter("meadow_color_fade",Vector2(48.0,128.0))
	apply_coastal(material)

static func apply_coastal(material: ShaderMaterial) -> void:
	var origin: Vector2=COAST_MASK.get_meta("world_origin")
	var extent: Vector2=COAST_MASK.get_meta("world_extent")
	material.set_shader_parameter("coastal_enabled",true)
	material.set_shader_parameter("coastal_field",COAST_MASK)
	material.set_shader_parameter("coastal_bounds",Vector4(origin.x,origin.y,extent.x,extent.y))
	material.set_shader_parameter("coastal_feather",3.)
	for key: String in COAST_COLOURS:material.set_shader_parameter(key,COAST_COLOURS[key])

static func coastal_weight(point: Vector3) -> float:
	if coast_image==null:coast_image=COAST_MASK.get_image()
	var origin: Vector2=COAST_MASK.get_meta("world_origin");var extent: Vector2=COAST_MASK.get_meta("world_extent")
	var uv:=(Vector2(point.x,point.z)-origin)/extent
	if uv.x<0 or uv.y<0 or uv.x>1 or uv.y>1:return 0.
	var pixel:=uv*Vector2(coast_image.get_size())-Vector2.ONE*.5
	var base:=Vector2i(floori(pixel.x),floori(pixel.y));var fraction:=pixel-Vector2(base)
	var a:=coast_image.get_pixel(clampi(base.x,0,coast_image.get_width()-1),clampi(base.y,0,coast_image.get_height()-1))
	var b:=coast_image.get_pixel(clampi(base.x+1,0,coast_image.get_width()-1),clampi(base.y,0,coast_image.get_height()-1))
	var c:=coast_image.get_pixel(clampi(base.x,0,coast_image.get_width()-1),clampi(base.y+1,0,coast_image.get_height()-1))
	var d:=coast_image.get_pixel(clampi(base.x+1,0,coast_image.get_width()-1),clampi(base.y+1,0,coast_image.get_height()-1))
	var sample:=a.lerp(b,fraction.x).lerp(c.lerp(d,fraction.x),fraction.y)
	return smoothstep(0.,3.,sample.r)*(1.-smoothstep(.2,.6,absf(point.y-sample.g)))
