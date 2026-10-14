// B variant: synchronized neutral-gray road palette.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley;

uniform vec4 sand_color : source_color = vec4(0.68, 0.62, 0.40, 1.0);
uniform vec4 dry_grass_color : source_color = vec4(0.60, 0.55, 0.34, 1.0);
uniform vec4 green_grass_color : source_color = vec4(0.39, 0.47, 0.30, 1.0);
uniform vec4 high_grass_color : source_color = vec4(0.35, 0.44, 0.24, 1.0);
uniform vec4 rock_color : source_color = vec4(0.39, 0.39, 0.35, 1.0);
uniform sampler2D biome_noise_texture : repeat_enable, filter_linear;
uniform float biome_noise_scale = 0.00135;
uniform float biome_warp_distance = 210.0;
uniform float biome_transition_half_width = 135.0;
uniform float biome_center_x = 20.0;
uniform float rock_bias = 0.0;
// CAD exports with separate beaches do not need a sea-height sand heuristic.
uniform bool use_height_sand = true;
// Optional CAD road projection: draw near-ground roads on this surface once.
uniform bool project_roads = false;
uniform sampler2D road_projection : filter_linear, repeat_disable;
uniform vec2 road_origin_xz;
uniform vec2 road_extent_xz;
uniform float ground_road_height_tolerance = 2.0;
uniform vec4 road_color : source_color = vec4(0.42, 0.43, 0.42, 1.0);
// The far proxy preserves the screen-integrated identity of a meadow after
// individual grass cards disappear. It deliberately contains no blade detail.
uniform bool use_far_grass_proxy = true;
uniform vec4 far_dry_grass_color : source_color = vec4(0.80, 0.67, 0.33, 1.0);
uniform vec4 far_green_grass_color : source_color = vec4(0.45, 0.53, 0.28, 1.0);
uniform vec4 far_high_grass_color : source_color = vec4(0.41, 0.50, 0.24, 1.0);
uniform float far_grass_proxy_strength : hint_range(0.0, 1.0) = 0.78;

#include "res://assets/world/cliff_b_test/road_lighting.gdshaderinc"

varying vec3 world_position;
varying vec3 world_normal;

float soft_noise(vec2 position) {
	float first = sin(position.x * 0.021 + sin(position.y * 0.014) * 1.7);
	float second = sin(position.y * 0.031 - position.x * 0.009);
	return first * 0.62 + second * 0.38;
}

void vertex() {
    road_main_view_direction = mat3(VIEW_MATRIX) * main_light_direction;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    road_surface_mask = 0.0;
	float broad_noise = soft_noise(world_position.xz);
	float biome_noise = texture(biome_noise_texture,
		world_position.xz * biome_noise_scale + vec2(0.137, 0.411)).r;
	float biome_mask = smoothstep(-biome_transition_half_width,
		biome_transition_half_width, world_position.x - biome_center_x
		+ (biome_noise * 2.0 - 1.0) * biome_warp_distance);
	float height_mix = smoothstep(22.0, 145.0, world_position.y + broad_noise * 7.0);
	vec3 meadow = mix(dry_grass_color.rgb, green_grass_color.rgb, biome_mask);
	vec3 grass = mix(meadow, high_grass_color.rgb, height_mix * 0.34);
	if (use_far_grass_proxy) {
		vec3 far_meadow = mix(
			far_dry_grass_color.rgb,
			far_green_grass_color.rgb,
			biome_mask
		);
		far_meadow = mix(far_meadow, far_high_grass_color.rgb, height_mix * 0.34);
		// Very low contrast variation retains field scale without pretending to
		// draw distant individual blades or creating a camera-centred ring.
		far_meadow *= 0.988 + broad_noise * 0.012;
		grass = mix(grass, far_meadow, far_grass_proxy_strength);
	}
	float fine_grass = sin(world_position.x * 0.34 + sin(world_position.z * 0.19));
	float wind_field = soft_noise(world_position.xz + vec2(TIME * 24.0, TIME * 8.0));
	float wind_band = smoothstep(0.46, 0.76, wind_field);
	grass *= 0.985 + fine_grass * 0.012 - wind_band * 0.035;
	float sand_mix = 1.0 - smoothstep(1.5, 8.0, world_position.y + broad_noise * 1.8);
	if (!use_height_sand) {
		sand_mix = 0.0;
	}
	// Rhino surfaces may be exported with their normals facing downward. Terrain
	// steepness is orientation-independent, so use the absolute Y component.
	float slope = 1.0 - clamp(abs(world_normal.y), 0.0, 1.0);
	float rock_mix = smoothstep(0.24, 0.58, slope + rock_bias);
	vec3 color = mix(grass, sand_color.rgb, sand_mix);
	color = mix(color, rock_color.rgb, rock_mix);
	color *= 0.97 + broad_noise * 0.025;
	if (project_roads) {
		vec2 uv = (world_position.xz - road_origin_xz) / road_extent_xz;
		float inside = step(0.0, uv.x) * step(uv.x, 1.0)
			* step(0.0, uv.y) * step(uv.y, 1.0);
		vec4 road_data = textureLod(road_projection, clamp(uv, vec2(0.0), vec2(1.0)), 0.0);
		float road_y = road_data.g / max(road_data.r, 0.00001);
		float close = 1.0 - step(ground_road_height_tolerance, abs(world_position.y - road_y));
		float top_surface = smoothstep(0.25, 0.55, abs(world_normal.y));
		road_surface_mask = road_data.r * inside * close * top_surface;
        color = mix(color, road_color.rgb, road_surface_mask);
	}
	ALBEDO = color;
	ROUGHNESS = mix(0.93, 0.94, road_surface_mask);
	SPECULAR = 0.12;
}
