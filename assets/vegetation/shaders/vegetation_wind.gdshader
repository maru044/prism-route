shader_type spatial;
render_mode cull_back, depth_prepass_alpha, diffuse_burley, alpha_to_coverage;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 color_tint : source_color = vec4(1.0);
// A shared palette can recolor the same texture without painting new species.
// Grass gets a little per-blade overlap from MultiMesh custom data; each tree
// gets a restrained per-instance tint through GeometryInstance3D.
uniform bool use_biome_palette = false;
uniform bool use_multimesh_color_data = false;
uniform sampler2D biome_noise_texture : repeat_enable, filter_linear;
uniform vec4 palette_dry : source_color = vec4(1.0);
uniform vec4 palette_green : source_color = vec4(1.0);
uniform float biome_noise_scale = 0.014;
uniform float biome_warp_distance = 4.0;
uniform float biome_transition_half_width = 5.0;
uniform float biome_center_x = 0.0;
uniform float biome_instance_overlap = 0.0;
instance uniform vec4 variant_tint : source_color = vec4(1.0);
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.42;
uniform float alpha_antialiasing_edge : hint_range(0.0, 1.0) = 0.24;
uniform vec2 atlas_grid = vec2(1.0, 1.0);
uniform float card_edge_fade : hint_range(0.0, 0.25) = 0.0;
uniform vec2 wind_direction = vec2(0.8, 0.35);
uniform float wind_strength : hint_range(0.0, 1.0) = 0.12;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.25;
uniform float wind_scale : hint_range(0.01, 5.0) = 0.65;
uniform bool use_noise_wind = false;
uniform sampler2D wind_noise_texture : repeat_enable, filter_linear;
uniform float wind_noise_world_scale : hint_range(0.001, 0.1) = 0.018;
uniform float wind_noise_scroll_speed : hint_range(0.001, 0.2) = 0.035;
uniform float wind_tone_curve_c1 : hint_range(0.0, 1.0) = 0.92;
uniform float wind_tone_curve_c2 : hint_range(0.0, 1.0) = 1.0;
uniform float wind_detail_scale : hint_range(1.0, 6.0) = 2.65;
uniform float wind_detail_amount : hint_range(0.0, 0.5) = 0.20;
uniform float wind_lateral_amount : hint_range(0.0, 0.5) = 0.14;
uniform float wind_gust_floor : hint_range(0.0, 0.5) = 0.12;
uniform float wind_tone_strength : hint_range(0.0, 0.35) = 0.0;
uniform float wind_variation_speed : hint_range(0.001, 0.1) = 0.018;
uniform float wind_variation_min : hint_range(0.0, 1.0) = 0.45;
uniform float wind_variation_max : hint_range(1.0, 2.0) = 1.15;
uniform float light_wrap : hint_range(0.0, 1.0) = 0.25;
uniform float root_tone : hint_range(0.5, 1.5) = 1.0;
uniform float tip_tone : hint_range(0.5, 1.5) = 1.0;

varying float wind_weight;
varying float wind_wave;
varying float temporal_wind_strength;
varying vec3 palette_tint;

float cubic_bezier_01(float value, float control_1, float control_2) {
	float t = clamp(value, 0.0, 1.0);
	float inverse_t = 1.0 - t;
	return 3.0 * inverse_t * inverse_t * t * control_1
		+ 3.0 * inverse_t * t * t * control_2
		+ t * t * t;
}

void vertex() {
	wind_weight = clamp(COLOR.r, 0.0, 1.0);
	temporal_wind_strength = 1.0;
	vec3 world_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	palette_tint = vec3(1.0);
	if (use_biome_palette) {
		float noise_value = textureLod(
			biome_noise_texture,
			world_origin.xz * biome_noise_scale + vec2(0.137, 0.411),
			0.0
		).r;
		float instance_shift = 0.0;
		float subtle_value = 1.0;
		if (use_multimesh_color_data) {
			instance_shift = (INSTANCE_CUSTOM.r * 2.0 - 1.0)
				* biome_instance_overlap;
			subtle_value = mix(0.96, 1.04, INSTANCE_CUSTOM.g);
		}
		float transition = smoothstep(
			-biome_transition_half_width,
			biome_transition_half_width,
			world_origin.x - biome_center_x + (noise_value * 2.0 - 1.0)
				* biome_warp_distance + instance_shift
		);
		palette_tint = mix(palette_dry.rgb, palette_green.rgb, transition)
			* subtle_value;
	}
	float direction_length = max(length(wind_direction), 0.0001);
	vec2 direction = wind_direction / direction_length;

	if (use_noise_wind) {
		// Sample by the complete instance world position so adjacent MultiMesh
		// chunks share one continuous wind field instead of restarting in squares.
		float wind_time = TIME * wind_speed;
		// A separate, very slow noise trajectory gives the whole meadow calm and
		// gust phases. Two differently oriented samples avoid a simple loop or
		// sine-like pulse while remaining smooth and deterministic.
		float slow_time = TIME * wind_variation_speed;
		float slow_primary = textureLod(
			wind_noise_texture,
			vec2(slow_time + 0.137, 0.319),
			0.0
		).r;
		float slow_secondary = textureLod(
			wind_noise_texture,
			vec2(0.731, -slow_time * 0.61 + 0.547),
			0.0
		).r;
		float slow_gust = smoothstep(
			0.24,
			0.76,
			slow_primary * 0.72 + slow_secondary * 0.28
		);
		temporal_wind_strength = mix(
			wind_variation_min,
			wind_variation_max,
			slow_gust
		);
		vec2 perpendicular = vec2(-direction.y, direction.x);
		vec2 primary_uv = world_origin.xz * wind_noise_world_scale;
		primary_uv -= direction * wind_time * wind_noise_scroll_speed;
		float primary_noise = textureLod(wind_noise_texture, primary_uv, 0.0).r;
		float gust = smoothstep(0.20, 0.80, primary_noise);

		// Rotate and rescale the second lookup to prevent aligned octaves from
		// revealing a grid. Its amplitude stays subordinate to the main gust.
		vec2 detail_position = world_origin.xz * wind_noise_world_scale * wind_detail_scale;
		const float ROTATION_COS = 0.8660254;
		const float ROTATION_SIN = 0.5;
		vec2 rotated_detail = vec2(
			detail_position.x * ROTATION_COS - detail_position.y * ROTATION_SIN,
			detail_position.x * ROTATION_SIN + detail_position.y * ROTATION_COS
		);
		vec2 detail_direction = normalize(direction * 0.94 + perpendicular * 0.34);
		vec2 detail_uv = rotated_detail
			- detail_direction * wind_time * wind_noise_scroll_speed * 1.37
			+ vec2(0.37, 0.61);
		float detail_noise = textureLod(wind_noise_texture, detail_uv, 0.0).r * 2.0 - 1.0;
		float natural_wave = clamp(
			gust * 0.90 + (detail_noise * 0.5 + 0.5) * 0.10,
			0.0,
			1.0
		);
		// Preserve the natural noise contours and spacing. The Bezier response
		// only remaps tonal occupancy, lifting most mid-values toward the light
		// range so the dark portion becomes narrower without becoming striped.
		wind_wave = cubic_bezier_01(
			natural_wave,
			wind_tone_curve_c1,
			wind_tone_curve_c2
		);

		float longitudinal = max(
			0.0,
			mix(wind_gust_floor, 1.0, gust) + detail_noise * wind_detail_amount
		);
		float lateral = detail_noise * wind_lateral_amount;
		vec2 displacement = (
			direction * longitudinal + perpendicular * lateral
		) * wind_strength * wind_weight * temporal_wind_strength;
		VERTEX.xz += displacement;
	} else {
		// Lightweight fallback retained for tree foliage until its wind model is
		// tuned separately from the grass meadow.
		float phase = dot(world_origin.xz, direction) * wind_scale;
		float primary = sin(TIME * wind_speed + phase);
		float detail = sin(TIME * wind_speed * 1.73 + phase * 2.31) * 0.35;
		float sway = (primary + detail) * wind_strength * wind_weight;
		wind_wave = 0.5;
		VERTEX.xz += direction * sway;
	}
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
	// At meadow scale, the moving low-frequency tonal band carries the wind
	// farther than the subpixel silhouette displacement. Keep it achromatic so
	// the grass remains one restrained straw-yellow color family.
	float animated_tone_strength = wind_tone_strength * temporal_wind_strength;
	float wind_tone = mix(
		1.0 - animated_tone_strength,
		1.0 + animated_tone_strength * 0.30,
		wind_wave
	);
	// A restrained height-only value shift separates overlapping blades while
	// preserving the flat, single-hue art direction.
	float height_tone = mix(
		root_tone,
		tip_tone,
		smoothstep(0.0, 1.0, wind_weight)
	);
	ALBEDO = tex.rgb * palette_tint * variant_tint.rgb
		* wind_tone * height_tone;
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
