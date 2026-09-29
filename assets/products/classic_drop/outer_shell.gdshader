shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 glass_tint : source_color = vec3(0.85, 0.95, 1.0);
uniform vec3 edge_tint : source_color = vec3(0.13, 0.24, 0.36);
uniform float face_opacity : hint_range(0.0, 1.0) = 0.018;
uniform float edge_opacity : hint_range(0.0, 1.0) = 0.62;

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.2);
	ALBEDO = mix(glass_tint, edge_tint, fresnel * 0.8);
	METALLIC = 0.0;
	ROUGHNESS = 0.055;
	SPECULAR = 0.65;
	ALPHA = face_opacity + fresnel * edge_opacity;
}
