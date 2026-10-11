shader_type spatial;
render_mode cull_disabled;

uniform vec4 sand_color : source_color = vec4(0.82, 0.75, 0.55, 1.0);
uniform sampler2D grain_texture : repeat_enable, filter_linear_mipmap;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float grain = texture(grain_texture, world_position.xz * 0.15).r;
	float broad = sin(world_position.x * 0.024 + sin(world_position.z * 0.019));
	ALBEDO = sand_color.rgb * (0.98 + grain * 0.025 + broad * 0.018);
	ROUGHNESS = 0.96;
	SPECULAR = 0.12;
}
