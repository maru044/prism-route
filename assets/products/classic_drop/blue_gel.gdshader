shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

// Quiet, translucent gel. Soft density islands drift through the core.
uniform vec3 clear_blue : source_color = vec3(0.74, 0.87, 0.93);
uniform vec3 dense_blue : source_color = vec3(0.32, 0.60, 0.76);
uniform float flow_speed : hint_range(0.0, 2.0) = 0.24;
uniform float clear_opacity : hint_range(0.0, 1.0) = 0.24;
uniform float dense_opacity : hint_range(0.0, 1.0) = 0.70;

varying vec3 model_position;

float soft_blob(vec3 point, vec3 center, vec3 scale) {
	vec3 delta = (point - center) * scale;
	return exp(-dot(delta, delta) * 1.65);
}

float bubble_ring(vec2 point, vec2 center, float radius) {
	float distance_to_center = length(point - center);
	float outer = 1.0 - smoothstep(radius - 0.014, radius + 0.009, distance_to_center);
	float inner = 1.0 - smoothstep(radius - 0.027, radius - 0.012, distance_to_center);
	return clamp(outer - inner, 0.0, 1.0);
}

void vertex() {
	model_position = VERTEX;
}

void fragment() {
	float time = TIME * flow_speed;
	vec3 point = model_position;
	point.x += 0.075 * sin(point.y * 3.6 + time * 1.4);
	point.z += 0.055 * sin(point.y * 4.2 - time * 1.1);
	float lower = soft_blob(point, vec3(-0.13 + 0.08 * sin(time), 1.10 + 0.12 * sin(time * 0.7), 0.24), vec3(2.9, 2.9, 0.9));
	float middle = soft_blob(point, vec3(0.13 + 0.07 * sin(time * 0.6), 1.70 + 0.15 * sin(time * 0.8 + 1.4), 0.24), vec3(3.3, 3.1, 0.9));
	float upper = soft_blob(point, vec3(-0.10 + 0.06 * sin(time * 1.1), 2.14 + 0.08 * sin(time * 0.9 + 2.0), 0.20), vec3(4.3, 4.0, 0.9));
	float ribbon_center = -0.035 + 0.17 * sin(point.y * 3.3 - time * 1.1);
	float ribbon = exp(-pow((point.x - ribbon_center) / 0.20, 2.0))
		* smoothstep(0.87, 1.17, point.y) * (1.0 - smoothstep(1.86, 2.22, point.y));
	float density = clamp(max(max(lower, middle), upper) * 0.86 + ribbon * 0.24
		+ 0.06 * sin(point.y * 8.0 - time * 2.2 + sin(point.x * 7.0)), 0.0, 1.0);
	float rich = smoothstep(0.28, 0.90, density);

	float front = smoothstep(-0.05, 0.22, model_position.z);
	vec2 surface = model_position.xy;
	float bubbles = bubble_ring(surface, vec2(-0.14, 1.12 + 0.03 * sin(time)), 0.043)
		+ bubble_ring(surface, vec2(0.18, 1.41 + 0.04 * sin(time * 0.7)), 0.052)
		+ bubble_ring(surface, vec2(-0.26, 1.55 + 0.02 * sin(time * 1.3)), 0.027)
		+ bubble_ring(surface, vec2(0.03, 1.80 + 0.03 * sin(time * 0.8)), 0.038);

	float edge = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	float clear_weight = (1.0 - rich) * (1.0 - rich);
	ALBEDO = mix(clear_blue, dense_blue, rich * 0.88) * (1.0 - edge * 0.16);
	ALBEDO -= vec3(0.06) * clear_weight;
	ALBEDO = mix(ALBEDO, vec3(0.75, 0.88, 0.92), clamp(bubbles * front * 0.24, 0.0, 0.24));
	ALPHA = mix(clear_opacity, dense_opacity, rich) + bubbles * front * 0.09;
}
