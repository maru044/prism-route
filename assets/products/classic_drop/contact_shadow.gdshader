shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

void fragment() {
	float radius = length((UV - vec2(0.5)) * vec2(1.0, 1.5));
	float falloff = pow(clamp(1.0 - radius * 2.0, 0.0, 1.0), 2.0);
	ALBEDO = vec3(0.13, 0.18, 0.24);
	ALPHA = falloff * 0.16;
}
