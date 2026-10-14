// B variant: synchronized neutral-gray road palette.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley;

uniform sampler2D road_projection : filter_linear, repeat_disable;
uniform vec2 road_origin_xz;
uniform vec2 road_extent_xz;
uniform float ground_road_height_tolerance = 2.0;
uniform vec4 road_color : source_color = vec4(0.42, 0.43, 0.42, 1.0);
#include "res://assets/world/cliff_b_test/road_lighting.gdshaderinc"

varying vec3 world_position;

void vertex() {
    road_main_view_direction = mat3(VIEW_MATRIX) * main_light_direction;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    road_surface_mask = 1.0;
	vec2 uv = (world_position.xz - road_origin_xz) / road_extent_xz;
	vec4 data = textureLod(road_projection, clamp(uv, vec2(0.0), vec2(1.0)), 0.0);
	float terrain_y = data.b / max(data.a, 0.00001);
	// Ground-level roads are drawn once by the terrain material. Bridges and
	// unsupported stretches remain the original road mesh at their CAD height.
	if (data.a > 0.1 && abs(world_position.y - terrain_y) < ground_road_height_tolerance) {
		discard;
	}
	ALBEDO = road_color.rgb;
	ROUGHNESS = 0.94;
	SPECULAR = 0.12;
}
