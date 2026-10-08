shader_type spatial;
render_mode cull_disabled;

uniform vec4 grass_color : source_color = vec4(0.39, 0.47, 0.29, 1.0);
uniform vec4 cliff_color : source_color = vec4(0.47, 0.46, 0.40, 1.0);

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	float slope = 1.0 - abs(normalize(world_normal).y);
	float variation = sin(world_position.x * 0.019 + sin(world_position.z * 0.012))
		* sin(world_position.z * 0.023) * 0.006;
	vec3 grass = grass_color.rgb + variation;
	vec3 cliff = cliff_color.rgb;
	ALBEDO = mix(grass, cliff, smoothstep(0.20, 0.55, slope));
	ROUGHNESS = 0.94;
	SPECULAR = 0.10;
}
