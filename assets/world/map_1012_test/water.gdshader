shader_type spatial;
render_mode cull_disabled;

uniform vec4 water_color : source_color = vec4(0.22, 0.60, 0.65, 1.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float ripple = sin(world_position.x * 0.15 + world_position.z * 0.21 + TIME * 0.7)
		* sin(world_position.z * 0.11 - world_position.x * 0.08 + TIME * 0.3);
	float footprint = max(length(dFdx(world_position.xz)), length(dFdy(world_position.xz)));
	float ripple_visibility = 1.0 - smoothstep(0.5, 4.0, footprint);
	ALBEDO = water_color.rgb * (0.985 + ripple * 0.022 * ripple_visibility);
	ROUGHNESS = 0.32;
	SPECULAR = 0.42;
	METALLIC = 0.02;
}
