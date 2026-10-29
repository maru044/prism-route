// World-aligned projection coordinates remain continuous across skinned surfaces.
uniform sampler2D source_texture : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform vec4 source_tint : source_color = vec4(1.0);
uniform vec4 source_uv = vec4(1.0, 1.0, 0.0, 0.0);
uniform bool use_source_alpha = false;
uniform float source_cutoff = 0.0;
uniform float surface_opacity = 1.0;
uniform float face_protection : hint_range(0.0, 1.0) = 0.0;
uniform vec4 projection_color : source_color = vec4(0.18, 0.82, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.42;
uniform float emission_strength : hint_range(0.0, 4.0) = 1.05;
uniform float texture_detail : hint_range(0.0, 1.0) = 0.72;
uniform float rim_strength : hint_range(0.0, 3.0) = 1.25;
uniform float scan_strength : hint_range(0.0, 1.0) = 0.23;
uniform float scan_density : hint_range(8.0, 180.0) = 78.0;
uniform float scan_speed : hint_range(0.0, 3.0) = 0.45;
uniform float glitch_strength : hint_range(0.0, 1.0) = 0.12;
uniform float effect_time = 0.0;
uniform float emitter_height = 0.0;
uniform float signal_strength : hint_range(0.0, 1.0) = 1.0;
// Shared by every surface: the plane travels from the model's crown to its feet.
uniform float materialization_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec2 projection_bounds = vec2(0.0, 1.8);
uniform float print_edge_width : hint_range(0.005, 0.1) = 0.025;
varying float projection_height;

float signal_hash(float x) {
	return fract(sin(x * 127.1 + 31.7) * 43758.5453);
}

void vertex() {
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	projection_height = world_position.y - emitter_height;
	// Match the base surface exactly: no displaced light shell or depth disagreement.
}

void fragment() {
	if (materialization_progress >= 1.0) { discard; }
	vec4 source = texture(source_texture, UV * source_uv.xy + source_uv.zw) * source_tint;
	if (source.a < source_cutoff) { discard; }
	float mask_alpha = use_source_alpha ? source.a : 1.0;
	vec3 n = normalize(NORMAL);
	if (!FRONT_FACING) { n = -n; }
	float rim = pow(1.0 - clamp(abs(dot(n, normalize(VIEW))), 0.0, 1.0), 2.2);
	float line_position = projection_height * scan_density - effect_time * scan_speed;
	float line_distance = abs(fract(line_position) - 0.5);
	float aa = max(fwidth(line_position), 0.02);
	float line = 1.0 - smoothstep(0.10, 0.10 + aa, line_distance);
	float sweep_distance = abs(fract(projection_height * 0.38 - effect_time * 0.12) - 0.5);
	float sweep = 1.0 - smoothstep(0.015, 0.055, sweep_distance);
	float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float detail = mix(0.70, 0.23 + luminance * 0.77, texture_detail);
	float pulse = 0.98 + sin(effect_time * 1.8) * 0.02;
	float slice = floor(projection_height * 42.0);
	float dropout = step(0.994, signal_hash(slice + floor(effect_time * 8.0) * 13.7));
	float effect_weight = 1.0 - face_protection * 0.78;
	float stability = 1.0 - dropout * glitch_strength * 0.5 * effect_weight;
	float plane_height = mix(projection_bounds.y + print_edge_width * 2.0, projection_bounds.x - print_edge_width * 2.0, materialization_progress);
	float hologram_mask = 1.0 - smoothstep(plane_height - print_edge_width, plane_height + print_edge_width, projection_height);
	float print_edge = 1.0 - smoothstep(print_edge_width * 0.2, print_edge_width, abs(projection_height - plane_height));
	if (materialization_progress <= 0.0) { hologram_mask = 1.0; print_edge = 0.0; }
	vec3 body = projection_color.rgb * (0.55 + 0.45 * detail);
	ALBEDO = body * 0.72;
	vec3 rim_tint = mix(projection_color.rgb, vec3(0.72, 0.96, 1.0), 0.65);
	EMISSION = (body * (0.25 + line * scan_strength * effect_weight + sweep * scan_strength * effect_weight * 0.65) + rim_tint * rim * rim_strength * 0.65) * emission_strength * pulse;
	EMISSION = EMISSION * hologram_mask + rim_tint * print_edge * 2.0;
	// This is a light/color layer over an opaque MToon base, not a transparent character.
	float color_layer = opacity * (0.4 + 0.6 * luminance) * (1.0 - face_protection * 0.45);
	float light_alpha = clamp(color_layer + rim * 0.26 + line * scan_strength * effect_weight * 0.35 + sweep * scan_strength * effect_weight * 0.25, 0.0, 0.85);
	ALPHA = clamp(light_alpha * hologram_mask + print_edge * 0.85, 0.0, 1.0) * mask_alpha * surface_opacity * stability * signal_strength;
}
