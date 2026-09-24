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
// Flowering and autumn trees reuse the same alpha silhouette but replace the
// green atlas RGB with a controlled three-tone species palette. The shadow
// color is the ambient/base response; direct sun adds the middle/light tones.
instance uniform float use_species_palette = 0.0;
// 0 = A0 paint-bucket baseline, 1 = A1 nested four-role ramp,
// 2 = A2 continuous three-family blend with a tiny macro boundary warp,
// 3 = A3 same blend with compressed palettes and restrained direct light.
// One packed stage value keeps the shader within Godot's 16 instance-uniform limit.
instance uniform float species_palette_stage = 0.0;
instance uniform vec4 species_deep_color : source_color = vec4(0.32, 0.16, 0.24, 1.0);
instance uniform vec4 species_shadow_color : source_color = vec4(0.42, 0.25, 0.30, 1.0);
instance uniform vec4 species_mid_color : source_color = vec4(0.78, 0.48, 0.56, 1.0);
instance uniform vec4 species_light_color : source_color = vec4(1.0, 0.76, 0.80, 1.0);
instance uniform vec4 species_accent_color : source_color = vec4(0.92, 0.62, 0.66, 1.0);
instance uniform float species_accent_amount : hint_range(0.0, 0.35) = 0.0;
instance uniform float species_seed : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D species_noise_texture : repeat_enable, filter_linear_mipmap;
uniform float species_noise_scale : hint_range(0.005, 0.2) = 0.052;
uniform float species_texture_detail : hint_range(0.0, 0.25) = 0.08;
uniform float species_light_ramp_start : hint_range(-1.0, 1.0) = -0.05;
uniform float species_light_ramp_end : hint_range(-1.0, 1.0) = 0.62;
uniform float species_shadow_band_start : hint_range(-1.0, 1.0) = -0.38;
uniform float species_shadow_band_end : hint_range(-1.0, 1.0) = -0.02;
uniform float species_mid_band_start : hint_range(-1.0, 1.0) = -0.10;
uniform float species_mid_band_end : hint_range(-1.0, 1.0) = 0.30;
uniform float species_sun_band_start : hint_range(-1.0, 1.0) = 0.16;
uniform float species_sun_band_end : hint_range(-1.0, 1.0) = 0.58;
uniform float species_direct_strength : hint_range(0.0, 1.5) = 0.72;
uniform float species_art_direct_strength : hint_range(0.0, 1.5) = 0.95;
uniform float species_light_warp_scale : hint_range(0.001, 0.1) = 0.018;
uniform float species_light_warp_amount : hint_range(0.0, 0.15) = 0.055;
instance uniform float use_tree_palette_anchor = 0.0;
instance uniform vec3 tree_palette_anchor_world = vec3(0.0);
instance uniform float use_tree_canopy_normal = 0.0;
instance uniform vec3 tree_canopy_center_world = vec3(0.0);
instance uniform vec3 tree_canopy_radii = vec3(1.0);
instance uniform float tree_local_normal_weight : hint_range(0.0, 1.0) = 0.34;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.42;
uniform float alpha_antialiasing_edge : hint_range(0.0, 1.0) = 0.24;
uniform vec2 atlas_grid = vec2(1.0, 1.0);
uniform float card_edge_fade : hint_range(0.0, 0.25) = 0.0;
uniform bool use_view_angle_fade = false;
uniform float view_angle_fade_start : hint_range(0.0, 0.5) = 0.020;
uniform float view_angle_fade_end : hint_range(0.0, 0.5) = 0.140;
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
varying vec3 card_plane_normal_view;
varying vec3 global_canopy_normal_view;
varying float species_accent_mix;
varying float species_light_warp;

vec3 decode_octahedral(vec2 encoded) {
	vec2 f = encoded * 2.0 - 1.0;
	vec3 normal = vec3(f.x, f.y, 1.0 - abs(f.x) - abs(f.y));
	if (normal.z < 0.0) {
		normal.xy = (1.0 - abs(f.yx)) * sign(f.xy);
	}
	return normalize(normal);
}

float cubic_bezier_01(float value, float control_1, float control_2) {
	float t = clamp(value, 0.0, 1.0);
	float inverse_t = 1.0 - t;
	return 3.0 * inverse_t * inverse_t * t * control_1
		+ 3.0 * inverse_t * t * t * control_2
		+ t * t * t;
}

void vertex() {
	wind_weight = clamp(COLOR.r, 0.0, 1.0);
	vec3 card_plane_normal_model = decode_octahedral(COLOR.gb);
	card_plane_normal_view = normalize(
		MODELVIEW_NORMAL_MATRIX * card_plane_normal_model
	);
	temporal_wind_strength = 1.0;
	vec3 world_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 palette_origin = mix(
		world_origin,
		tree_palette_anchor_world,
		clamp(use_tree_palette_anchor, 0.0, 1.0)
	);
	global_canopy_normal_view = vec3(0.0, 0.0, 1.0);
	if (use_tree_canopy_normal > 0.5) {
		vec3 safe_radii = max(tree_canopy_radii, vec3(0.001));
		vec3 canopy_delta = world_vertex - tree_canopy_center_world;
		vec3 canopy_normal_world = normalize(canopy_delta / (safe_radii * safe_radii));
		global_canopy_normal_view = normalize(mat3(VIEW_MATRIX) * canopy_normal_world);
	}
	species_accent_mix = 0.0;
	species_light_warp = 0.0;
	if (use_species_palette > 0.5 && species_palette_stage > 1.5) {
		vec2 warp_offset = vec2(
			species_seed * 2.71 + 0.193,
			species_seed * -1.87 + 0.577
		);
		float warp_xz = textureLod(
			species_noise_texture,
			world_vertex.xz * species_light_warp_scale + warp_offset,
			0.0
		).r;
		float warp_xy = textureLod(
			species_noise_texture,
			world_vertex.xy * species_light_warp_scale * 0.79 + warp_offset.yx,
			0.0
		).r;
		float macro_value = warp_xz * 0.58 + warp_xy * 0.42;
		species_light_warp = (macro_value * 2.0 - 1.0)
			* species_light_warp_amount;
	}
	if (
		use_species_palette > 0.5
		&& species_palette_stage < 0.5
		&& species_accent_amount > 0.0
	) {
		vec2 seed_offset = vec2(
			species_seed * 3.17 + 0.137,
			species_seed * -2.43 + 0.619
		);
		float horizontal_noise = textureLod(
			species_noise_texture,
			world_vertex.xz * species_noise_scale + seed_offset,
			0.0
		).r;
		float vertical_noise = textureLod(
			species_noise_texture,
			world_vertex.xy * species_noise_scale * 0.83 + seed_offset.yx,
			0.0
		).r;
		float broad_noise = horizontal_noise * 0.62 + vertical_noise * 0.38;
		species_accent_mix = smoothstep(0.48, 0.78, broad_noise)
			* species_accent_amount;
	}
	palette_tint = vec3(1.0);
	if (use_biome_palette) {
		float noise_value = textureLod(
			biome_noise_texture,
			palette_origin.xz * biome_noise_scale + vec2(0.137, 0.411),
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
			palette_origin.x - biome_center_x + (noise_value * 2.0 - 1.0)
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
	float view_mask = 1.0;
	if (use_view_angle_fade) {
		float facing = abs(dot(
			normalize(card_plane_normal_view),
			normalize(VIEW)
		));
		view_mask = smoothstep(
			view_angle_fade_start,
			view_angle_fade_end,
			facing
		);
	}
	float cutout_alpha = tex.a * edge_mask * view_mask;
	// Preserve the volume normals authored on the mesh. Flipping a normal from
	// FRONT_FACING would restore the original card-plane lighting artifact.
	vec3 lighting_normal = normalize(NORMAL);
	if (use_tree_canopy_normal > 0.5) {
		lighting_normal = normalize(mix(
			global_canopy_normal_view,
			lighting_normal,
			clamp(tree_local_normal_weight, 0.0, 1.0)
		));
	}
	NORMAL = lighting_normal;
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
	if (use_species_palette > 0.5) {
		// Retain only a trace of atlas luminance. Its green RGB must not tint a
		// pink or orange species into mud, and the texture must not paint shadow.
		float atlas_value = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		float atlas_detail = mix(
			1.0,
			mix(0.94, 1.04, clamp(atlas_value, 0.0, 1.0)),
			species_texture_detail
		);
		if (species_palette_stage > 1.5) {
			// In A2, deep is intentionally dormant until a real interior-volume
			// mask is tested in phase B. Environment light starts from shadow.
			vec3 environment_family = species_shadow_color.rgb;
			if (species_palette_stage > 2.5) {
				// Low-contrast stylization keeps indirect light inside the same
				// family instead of allowing the crown underside to become a
				// separate dark/purple object.
				environment_family = mix(
					species_shadow_color.rgb,
					species_mid_color.rgb,
					0.42
				);
			}
			ALBEDO = environment_family * atlas_detail;
		} else if (species_palette_stage > 0.5) {
			// A1 starts from the deliberate deep family under environment light.
			// The directional light adds shadow/mid/sun target colors below.
			ALBEDO = mix(
				species_shadow_color.rgb,
				species_deep_color.rgb,
				0.28
			) * atlas_detail;
		} else {
			vec3 accent_shadow = species_accent_color.rgb * 0.62;
			ALBEDO = mix(
				species_shadow_color.rgb,
				accent_shadow,
				species_accent_mix
			) * atlas_detail;
		}
	} else {
		ALBEDO = tex.rgb * palette_tint * variant_tint.rgb
			* wind_tone * height_tone;
	}
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
	if (
		use_species_palette > 0.5
		&& species_palette_stage > 0.5
		&& LIGHT_IS_DIRECTIONAL
	) {
		float ndotl = dot(NORMAL, LIGHT);
		vec3 direct_palette;
		float artistic_diffuse;
		if (species_palette_stage > 1.5) {
			float light_t = smoothstep(
				-0.30,
				0.80,
				ndotl + species_light_warp
			);
			float shadow_weight = 1.0 - smoothstep(0.10, 0.58, light_t);
			float sun_weight = smoothstep(0.62, 0.92, light_t);
			float mid_weight = max(0.0, 1.0 - shadow_weight - sun_weight);
			direct_palette = species_shadow_color.rgb * shadow_weight
				+ species_mid_color.rgb * mid_weight
				+ species_light_color.rgb * sun_weight;
			artistic_diffuse = smoothstep(
				-0.32,
				0.68,
				ndotl + species_light_warp
			);
		} else {
			float shadow_band = smoothstep(
				species_shadow_band_start,
				species_shadow_band_end,
				ndotl
			);
			float mid_band = smoothstep(
				species_mid_band_start,
				species_mid_band_end,
				ndotl
			);
			float sun_band = smoothstep(
				species_sun_band_start,
				species_sun_band_end,
				ndotl
			);
			direct_palette = mix(
				species_deep_color.rgb,
				species_shadow_color.rgb,
				shadow_band
			);
			direct_palette = mix(direct_palette, species_mid_color.rgb, mid_band);
			direct_palette = mix(direct_palette, species_light_color.rgb, sun_band);
			artistic_diffuse = smoothstep(
				species_shadow_band_start,
				species_sun_band_end,
				ndotl
			);
		}
		float palette_direct_strength = species_art_direct_strength;
		if (species_palette_stage > 2.5) {
			// A3 keeps the hue response but stops the sun family from reading as
			// a second, almost-white paint layer over the crown.
			palette_direct_strength *= 0.42;
		}
		DIFFUSE_LIGHT += direct_palette * LIGHT_COLOR * ATTENUATION
			* artistic_diffuse * palette_direct_strength;
	} else if (use_species_palette > 0.5) {
		float palette_ramp = smoothstep(
			species_light_ramp_start,
			species_light_ramp_end,
			dot(NORMAL, LIGHT)
		);
		vec3 middle_color = mix(
			species_mid_color.rgb,
			species_accent_color.rgb * 0.88,
			species_accent_mix
		);
		vec3 light_color = mix(
			species_light_color.rgb,
			species_accent_color.rgb * 1.08,
			species_accent_mix
		);
		vec3 direct_palette = mix(middle_color, light_color, palette_ramp);
		DIFFUSE_LIGHT += direct_palette * LIGHT_COLOR * ATTENUATION
			* wrapped_ndotl * species_direct_strength;
	} else {
		DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * wrapped_ndotl;
	}
}
