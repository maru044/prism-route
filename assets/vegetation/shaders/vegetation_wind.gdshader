shader_type spatial;
render_mode cull_back, depth_prepass_alpha, diffuse_burley, alpha_to_coverage;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 color_tint : source_color = vec4(1.0);
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.42;
uniform float alpha_antialiasing_edge : hint_range(0.0, 1.0) = 0.24;
uniform vec2 atlas_grid = vec2(1.0, 1.0);
uniform float card_edge_fade : hint_range(0.0, 0.25) = 0.0;
uniform vec2 wind_direction = vec2(0.8, 0.35);
uniform float wind_strength : hint_range(0.0, 1.0) = 0.12;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.25;
uniform float wind_scale : hint_range(0.01, 5.0) = 0.65;
uniform float light_wrap : hint_range(0.0, 1.0) = 0.25;

varying float wind_weight;

void vertex() {
	wind_weight = COLOR.r;
	vec3 world_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = dot(world_origin.xz, wind_direction) * wind_scale;
	float primary = sin(TIME * wind_speed + phase);
	float detail = sin(TIME * wind_speed * 1.73 + phase * 2.31) * 0.35;
	float sway = (primary + detail) * wind_strength * wind_weight;
	VERTEX.xz += vec2(wind_direction.x, wind_direction.y) * sway;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV) * color_tint;
	float edge_mask = 1.0;
	if (card_edge_fade > 0.0) {
		vec2 atlas_uv = fract(UV * atlas_grid);
		float edge_distance = min(
			min(atlas_uv.x, 1.0 - atlas_uv.x),
			min(atlas_uv.y, 1.0 - atlas_uv.y)
		);
		edge_mask = smoothstep(0.0, card_edge_fade, edge_distance);
	}
	float cutout_alpha = tex.a * edge_mask;
	// Preserve the volume normals authored on the mesh. Flipping a normal from
	// FRONT_FACING would restore the original card-plane lighting artifact.
	NORMAL = normalize(NORMAL);
	ALBEDO = tex.rgb;
	ALPHA = cutout_alpha;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	ALPHA_ANTIALIASING_EDGE = min(alpha_antialiasing_edge, alpha_cutoff - 0.001);
	ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(albedo_texture, 0));
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
}

void light() {
	// A restrained wrapped diffuse keeps foliage cards from collapsing into
	// black strips at grazing light angles. ATTENUATION retains real shadows.
	float wrapped_ndotl = clamp(
		(dot(NORMAL, LIGHT) + light_wrap) / (1.0 + light_wrap),
		0.0,
		1.0
	);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * wrapped_ndotl;
}
