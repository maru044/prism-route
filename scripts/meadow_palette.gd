extends RefCounted
## Accepted grass colours. Presentation only; baked roots and biome zoning stay unchanged.
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

static func apply_ground(material: ShaderMaterial) -> void:
	for parameter: String in GROUND:material.set_shader_parameter(parameter,GROUND[parameter])
	for parameter: String in FAR_GROUND:material.set_shader_parameter(parameter,FAR_GROUND[parameter])
	material.set_shader_parameter("use_far_meadow_color",true)
	material.set_shader_parameter("meadow_color_fade",Vector2(48.0,128.0))
