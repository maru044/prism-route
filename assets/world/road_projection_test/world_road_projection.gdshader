shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D grass_texture : source_color, repeat_enable, filter_linear;
uniform sampler2D road_texture : source_color, repeat_enable, filter_linear;
// Linear data, not sRGB: coverage and coverage-weighted height.
uniform sampler2D road_projection : repeat_disable, filter_linear_mipmap;
uniform vec2 mask_origin_xz;
uniform vec2 mask_extent_xz;
uniform float tile_meters = 4.0;
uniform float height_tolerance = 4.0;
uniform bool projection_enabled = true;
uniform bool height_and_slope_guard = true;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec2 uv = (world_position.xz - mask_origin_xz) / mask_extent_xz;
	vec2 data = texture(road_projection, clamp(uv, vec2(0.0), vec2(1.0))).rg;
	float bounds = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	float coverage = smoothstep(0.0, 1.0, data.r) * bounds;
	if (height_and_slope_guard) {
		float road_y = data.g / max(data.r, 0.00001);
		float gap = abs(world_position.y - road_y);
		coverage *= 1.0 - smoothstep(height_tolerance * 0.75, height_tolerance, gap);
		coverage *= smoothstep(0.25, 0.55, abs(normalize(world_normal).y));
	}
	vec2 world_uv = world_position.xz / tile_meters;
	vec3 grass = texture(grass_texture, world_uv).rgb;
	vec3 road = texture(road_texture, world_uv).rgb;
	ALBEDO = mix(grass, road, projection_enabled ? coverage : 0.0);
	ROUGHNESS = 0.95;
	SPECULAR = 0.08;
}
