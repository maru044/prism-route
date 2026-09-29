shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 deep_blue : source_color = vec3(0.003, 0.04, 0.22);
uniform vec3 bright_blue : source_color = vec3(0.015, 0.48, 0.84);
uniform float flow_speed : hint_range(0.0, 2.0) = 0.22;

varying vec3 model_position;

float bubble_ring(vec2 point, vec2 center, float radius) {
	float distance_to_center = length(point - center);
	float outer = 1.0 - smoothstep(radius - 0.012, radius + 0.008, distance_to_center);
	float inner = 1.0 - smoothstep(radius - 0.035, radius - 0.018, distance_to_center);
	return clamp(outer - inner, 0.0, 1.0);
}

void vertex() {
	model_position = VERTEX;
}

void fragment() {
	float moving = sin(model_position.y * 8.0 - TIME * flow_speed * 5.0
		+ sin(model_position.x * 13.0 + TIME * 0.4) * 0.65);
	float detail = sin(model_position.y * 20.0 + model_position.z * 9.0 + TIME * 0.3);
	float blend_factor = clamp(0.48 + 0.22 * moving + 0.08 * detail, 0.0, 1.0);
	float front = smoothstep(-0.05, 0.22, model_position.z);
	vec2 surface = model_position.xy;
	float bubbles = bubble_ring(surface, vec2(-0.14, 1.12), 0.043)
		+ bubble_ring(surface, vec2(0.18, 1.41), 0.052)
		+ bubble_ring(surface, vec2(-0.26, 1.55), 0.027)
		+ bubble_ring(surface, vec2(0.03, 1.80), 0.038)
		+ bubble_ring(surface, vec2(0.12, 2.08), 0.021);
	ALBEDO = mix(mix(deep_blue, bright_blue, blend_factor), vec3(0.58, 0.90, 1.0), clamp(bubbles * front, 0.0, 0.8));
	METALLIC = 0.06;
	ROUGHNESS = 0.1;
	SPECULAR = 0.75;
	EMISSION = bright_blue * (0.025 + 0.02 * moving) + vec3(0.08, 0.23, 0.29) * bubbles * front;
}
