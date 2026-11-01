shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, shadows_disabled;

uniform vec4 glass_tint : source_color = vec4(0.525, 0.706, 0.725, 1.0);
uniform float base_opacity : hint_range(0.0, 1.0) = 0.35;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.17;
uniform float glass_ior : hint_range(1.0, 2.0) = 1.46;

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float f0 = pow((glass_ior - 1.0) / (glass_ior + 1.0), 2.0);
	float fresnel = f0 + (1.0 - f0) * pow(1.0 - facing, 5.0);
	ALBEDO = glass_tint.rgb;
	ROUGHNESS = surface_roughness;
	METALLIC = 0.0;
	SPECULAR = clamp(f0 / 0.08, 0.0, 1.0);
	ALPHA = clamp(base_opacity * 0.55 + fresnel * 0.65, 0.0, 0.85);
}
