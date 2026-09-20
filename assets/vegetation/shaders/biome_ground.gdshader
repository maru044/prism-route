shader_type spatial;
render_mode diffuse_burley;

// Match the grass transition in vegetation_wind.gdshader. Both materials use
// the same texture, world coordinates and remapping parameters.
uniform sampler2D biome_noise_texture : repeat_enable, filter_linear;
uniform vec4 ground_dry : source_color = vec4(0.588, 0.541, 0.333, 1.0);
uniform vec4 ground_green : source_color = vec4(0.333, 0.463, 0.302, 1.0);
uniform float biome_noise_scale = 0.014;
uniform float biome_warp_distance = 4.0;
uniform float biome_transition_half_width = 5.0;
uniform float biome_center_x = 0.0;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float noise_value = texture(
		biome_noise_texture,
		world_xz * biome_noise_scale + vec2(0.137, 0.411)
	).r;
	float transition = smoothstep(
		-biome_transition_half_width,
		biome_transition_half_width,
		world_xz.x - biome_center_x
			+ (noise_value * 2.0 - 1.0) * biome_warp_distance
	);
	ALBEDO = mix(ground_dry.rgb, ground_green.rgb, transition);
	ROUGHNESS = 0.98;
	SPECULAR = 0.05;
}
