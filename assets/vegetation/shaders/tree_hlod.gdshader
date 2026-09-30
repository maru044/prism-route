shader_type spatial;
render_mode cull_back, depth_prepass_alpha, diffuse_burley, alpha_to_coverage;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform bool use_painted_foliage = false;
uniform sampler2D painted_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float painted_luma_reference = 0.20;
uniform float painted_detail_strength = 0.65;
uniform vec4 color_tint : source_color = vec4(1.0);
uniform vec4 variant_tint : source_color = vec4(1.0);
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.45;
uniform float alpha_antialiasing_edge : hint_range(0.0, 1.0) = 0.24;
uniform vec2 atlas_grid = vec2(1.0);
uniform float card_edge_fade : hint_range(0.0, 0.25) = 0.0;
uniform bool use_view_angle_fade = false;
uniform float view_angle_fade_start = 0.02;
uniform float view_angle_fade_end = 0.14;

uniform bool use_y_billboard = false;
uniform bool use_spherical_billboard = false;
uniform bool use_billboard_pivot_data = false;
uniform bool use_directional_impostor = false;
uniform float directional_impostor_views = 8.0;
uniform bool use_impostor_canopy_normal = false;
uniform bool use_tree_local_canopy_normal = false;
uniform vec3 tree_canopy_center_local = vec3(0.0);
uniform vec3 tree_canopy_radii_local = vec3(1.0);
uniform float tree_local_normal_weight : hint_range(0.0, 1.0) = 0.34;
uniform vec4 tree_lod_fade = vec4(-100000.0, -99999.0, 99999.0, 100000.0);
uniform sampler2D lod_dither_texture : repeat_enable, filter_nearest;

uniform vec2 wind_direction = vec2(0.8, 0.35);
uniform float wind_strength = 0.05;
uniform float wind_speed = 0.72;
uniform float wind_scale = 0.65;
uniform float light_wrap = 0.34;

// World-aligned colour transition used by the accepted vegetation test.
// These stay material uniforms so MultiMesh batches do not consume Godot's
// limited per-instance shader-variable buffer.
uniform bool use_biome_palette = false;
uniform sampler2D biome_noise_texture : repeat_enable, filter_linear;
uniform vec4 palette_dry : source_color = vec4(1.0);
uniform vec4 palette_green : source_color = vec4(1.0);
uniform float biome_noise_scale = 0.014;
uniform float biome_warp_distance = 4.0;
uniform float biome_transition_half_width = 5.0;
uniform float biome_center_x = 0.0;

uniform float use_species_palette = 0.0;
uniform float species_palette_stage = 3.0;
uniform vec4 species_deep_color : source_color = vec4(0.32, 0.16, 0.24, 1.0);
uniform vec4 species_shadow_color : source_color = vec4(0.42, 0.25, 0.30, 1.0);
uniform vec4 species_mid_color : source_color = vec4(0.78, 0.48, 0.56, 1.0);
uniform vec4 species_light_color : source_color = vec4(1.0, 0.76, 0.80, 1.0);
uniform vec4 species_accent_color : source_color = vec4(0.92, 0.62, 0.66, 1.0);
uniform float species_accent_amount = 0.0;
uniform float species_seed = 0.0;
uniform sampler2D species_noise_texture : repeat_enable, filter_linear_mipmap;
uniform float species_texture_detail = 0.06;
uniform float species_art_direct_strength = 0.95;
uniform float species_light_warp_scale = 0.018;
uniform float species_light_warp_amount = 0.045;

varying vec3 card_plane_normal_view;
varying vec3 canopy_normal_view;
varying float tree_lod_visibility;
varying float directional_impostor_frame;
varying float species_light_warp;
varying vec3 palette_tint;
varying float painted_light_detail;

vec3 decode_octahedral(vec2 encoded) {
	vec2 f = encoded * 2.0 - 1.0;
	vec3 normal = vec3(f.x, f.y, 1.0 - abs(f.x) - abs(f.y));
	if (normal.z < 0.0) {
		normal.xy = (1.0 - abs(f.yx)) * sign(f.xy);
	}
	return normalize(normal);
}

void vertex() {
	vec3 authored_vertex = VERTEX;
	vec3 world_origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	directional_impostor_frame = 0.0;
	if (use_directional_impostor) {
		vec3 to_camera = normalize(CAMERA_POSITION_WORLD - world_origin);
		float local_x = dot(to_camera, normalize(MODEL_MATRIX[0].xyz));
		float local_z = dot(to_camera, normalize(MODEL_MATRIX[2].xyz));
		float views = max(1.0, directional_impostor_views);
		directional_impostor_frame = mod(
			floor(atan(local_x, local_z) / TAU * views + 0.5), views
		);
	}
	if (use_y_billboard || use_spherical_billboard) {
		vec3 pivot_model = vec3(0.0);
		if (use_billboard_pivot_data) {
			// UV2 stores the Blender X/Y group centre.  glTF maps Blender Y
			// to negative Godot Z; vertical Y stays authored on each vertex.
			pivot_model = vec3(UV2.x, 0.0, -UV2.y);
			VERTEX -= pivot_model;
		}
		vec3 pivot_world = (MODEL_MATRIX * vec4(pivot_model, 1.0)).xyz;
		vec3 world_up = normalize(MODEL_MATRIX[1].xyz);
		vec3 camera_back = normalize(MAIN_CAM_INV_VIEW_MATRIX[2].xyz);
		vec3 right;
		vec3 billboard_up;
		vec3 back;
		if (use_spherical_billboard) {
			right = normalize(MAIN_CAM_INV_VIEW_MATRIX[0].xyz);
			billboard_up = normalize(MAIN_CAM_INV_VIEW_MATRIX[1].xyz);
			back = camera_back;
		} else {
			right = normalize(cross(world_up, camera_back));
			billboard_up = world_up;
			back = normalize(cross(right, world_up));
		}
		mat4 billboard_model = mat4(
			vec4(right * length(MODEL_MATRIX[0].xyz), 0.0),
			vec4(billboard_up * length(MODEL_MATRIX[1].xyz), 0.0),
			vec4(back * length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(pivot_world, 1.0)
		);
		MODELVIEW_MATRIX = VIEW_MATRIX * billboard_model;
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}

	card_plane_normal_view = normalize(
		MODELVIEW_NORMAL_MATRIX * decode_octahedral(COLOR.gb)
	);
	canopy_normal_view = vec3(0.0, 0.0, 1.0);
	if (use_tree_local_canopy_normal) {
		vec3 radii = max(tree_canopy_radii_local, vec3(0.001));
		vec3 local_normal = normalize(
			(authored_vertex - tree_canopy_center_local) / (radii * radii)
		);
		canopy_normal_view = normalize(MODELVIEW_NORMAL_MATRIX * local_normal);
	}

	float camera_distance = distance(world_origin, CAMERA_POSITION_WORLD);
	tree_lod_visibility = smoothstep(
		tree_lod_fade.x, tree_lod_fade.y, camera_distance
	) * (1.0 - smoothstep(
		tree_lod_fade.z, tree_lod_fade.w, camera_distance
	));

	float wind_weight = clamp(COLOR.r, 0.0, 1.0);
	vec2 direction = normalize(wind_direction);
	float phase = dot(world_origin.xz, direction) * wind_scale;
	float sway = (
		sin(TIME * wind_speed + phase)
		+ sin(TIME * wind_speed * 1.73 + phase * 2.31) * 0.35
	) * wind_strength * wind_weight;
	VERTEX.xz += direction * sway;

	vec3 authored_world_vertex = (
		MODEL_MATRIX * vec4(authored_vertex, 1.0)
	).xyz;
	palette_tint = vec3(1.0);
	if (use_biome_palette) {
		float biome_noise = textureLod(
			biome_noise_texture,
			world_origin.xz * biome_noise_scale + vec2(0.137, 0.411),
			0.0
		).r;
		float transition = smoothstep(
			-biome_transition_half_width,
			biome_transition_half_width,
			world_origin.x - biome_center_x + (biome_noise * 2.0 - 1.0)
				* biome_warp_distance
		);
		palette_tint = mix(palette_dry.rgb, palette_green.rgb, transition);
	}

	species_light_warp = 0.0;
	if (use_species_palette > 0.5) {
		vec2 warp_offset = vec2(
			species_seed * 2.71 + 0.193,
			species_seed * -1.87 + 0.577
		);
		float warp_xz = textureLod(
			species_noise_texture,
			authored_world_vertex.xz * species_light_warp_scale + warp_offset,
			0.0
		).r;
		float warp_xy = textureLod(
			species_noise_texture,
			authored_world_vertex.xy * species_light_warp_scale * 0.79
				+ warp_offset.yx,
			0.0
		).r;
		float macro_value = warp_xz * 0.58 + warp_xy * 0.42;
		species_light_warp = (macro_value * 2.0 - 1.0) * species_light_warp_amount;
	}
}

void fragment() {
	vec2 local_uv = UV;
	vec2 sample_uv = UV;
	if (use_directional_impostor) {
		float frame_x = mod(directional_impostor_frame, atlas_grid.x);
		float frame_y = floor(directional_impostor_frame / atlas_grid.x);
		sample_uv = (local_uv + vec2(frame_x, frame_y)) / atlas_grid;
	}
	vec4 tex = texture(albedo_texture, sample_uv) * color_tint;
	float painted_detail = 1.0;
	if (use_painted_foliage) {
		vec4 painted = texture(painted_texture, sample_uv);
		float value = dot(painted.rgb, vec3(0.299, 0.587, 0.114));
		painted_detail = mix(1.0, clamp(value / max(painted_luma_reference, 0.001), 0.65, 1.30), painted_detail_strength);
		tex.a = painted.a * color_tint.a;
	}
	float edge_mask = 1.0;
	if (card_edge_fade > 0.0) {
		vec2 cell_uv = local_uv;
		if (!use_directional_impostor) {
			cell_uv = fract(UV * atlas_grid);
		}
		float edge_distance = min(
			min(cell_uv.x, 1.0 - cell_uv.x),
			min(cell_uv.y, 1.0 - cell_uv.y)
		);
		edge_mask = smoothstep(0.0, card_edge_fade, edge_distance);
	}
	float view_mask = 1.0;
	if (use_view_angle_fade) {
		float facing = abs(dot(normalize(card_plane_normal_view), normalize(VIEW)));
		view_mask = smoothstep(view_angle_fade_start, view_angle_fade_end, facing);
	}
	// Leaf cutout and LOD coverage are deliberately independent. Multiplying
	// tex.a by the continuous LOD weight before a fixed alpha scissor collapses
	// a nominal 30 m transition into an almost-hard switch. Adjacent tiers share
	// this screen-space threshold tile and complementary visibility weights, so
	// each screen pixel is assigned to one representation throughout the fade.
	if (tree_lod_visibility < 0.9999) {
		vec2 noise_size = vec2(textureSize(lod_dither_texture, 0));
		vec2 noise_pixel = mod(floor(FRAGCOORD.xy), noise_size);
		float lod_threshold = textureLod(
			lod_dither_texture,
			(noise_pixel + vec2(0.5)) / noise_size,
			0.0
		).r;
		if (lod_threshold >= tree_lod_visibility) {
			discard;
		}
	}
	vec3 lighting_normal = normalize(NORMAL);
	if (use_tree_local_canopy_normal) {
		lighting_normal = normalize(mix(
			canopy_normal_view, lighting_normal, tree_local_normal_weight
		));
	}
	if (use_impostor_canopy_normal) {
		vec2 normal_uv = local_uv;
		if (!use_directional_impostor) {
			normal_uv = fract(UV * atlas_grid);
		}
		vec2 sphere_xy = (normal_uv * 2.0 - 1.0) * vec2(0.82, 0.94);
		float sphere_z = sqrt(max(0.08, 1.0 - dot(sphere_xy, sphere_xy)));
		lighting_normal = normalize(vec3(sphere_xy.x, -sphere_xy.y, sphere_z));
	}
	NORMAL = lighting_normal;

	if (use_species_palette > 0.5) {
		float value = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		float detail = mix(
			1.0,
			mix(0.94, 1.04, clamp(value, 0.0, 1.0)),
			species_texture_detail
		);
		ALBEDO = mix(species_shadow_color.rgb, species_mid_color.rgb, 0.42) * detail;
	} else {
		ALBEDO = tex.rgb * palette_tint * variant_tint.rgb;
	}
	ALBEDO *= painted_detail;
	painted_light_detail = painted_detail;
	ALPHA = tex.a * edge_mask * view_mask;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	ALPHA_ANTIALIASING_EDGE = min(alpha_antialiasing_edge, alpha_cutoff - 0.001);
	ALPHA_TEXTURE_COORDINATE = sample_uv * vec2(textureSize(albedo_texture, 0));
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
}

void light() {
	float wrapped = clamp(
		(dot(NORMAL, LIGHT) + light_wrap) / (1.0 + light_wrap), 0.0, 1.0
	);
	if (use_species_palette > 0.5 && LIGHT_IS_DIRECTIONAL) {
		float ndotl = dot(NORMAL, LIGHT);
		float light_t = smoothstep(-0.30, 0.80, ndotl + species_light_warp);
		float shadow_weight = 1.0 - smoothstep(0.10, 0.58, light_t);
		float sun_weight = smoothstep(0.62, 0.92, light_t);
		float mid_weight = max(0.0, 1.0 - shadow_weight - sun_weight);
		vec3 palette = species_shadow_color.rgb * shadow_weight
			+ species_mid_color.rgb * mid_weight
			+ species_light_color.rgb * sun_weight;
		float artistic_diffuse = smoothstep(
			-0.32,
			0.68,
			ndotl + species_light_warp
		);
		DIFFUSE_LIGHT += palette * painted_light_detail * LIGHT_COLOR * ATTENUATION
			* artistic_diffuse * species_art_direct_strength * 0.42;
	} else {
		DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * wrapped;
	}
}
