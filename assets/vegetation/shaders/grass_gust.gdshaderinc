// Opt-in, length-preserving centreline bending. Only the grove demo compiles this.
uniform float gust_mix : hint_range(0.0, 1.0) = 0.0;
uniform float gust_time = -1.0;
uniform float gust_sway_hz : hint_range(1.0, 3.0) = 2.1;
uniform float gust_sway_amplitude : hint_range(0.0, 0.7) = 0.51;
uniform float gust_base_angle = 0.60;
uniform float gust_model_height = 1.15;
// Offline geometry checks can freeze the angle; normal play leaves this disabled.
uniform float gust_angle_override = -100.0;

float gust_angle(float clock) {
	if (gust_angle_override > -10.0) { return gust_angle_override; }
	// One global clock for every tuft: bend and rebound simultaneously, with
	// no travelling wave, spatial noise, or per-instance phase/amplitude variation.
	float phase = 6.2831853 * gust_sway_hz * clock + 0.24 * sin(clock * 1.13);
	// The harmonic makes the bend/rebound timing asymmetric without a pause or
	// angle clamp at either end. Slower modulation changes strength, not cadence.
	float sway = (sin(phase) + 0.20 * sin(2.0 * phase + 0.4)) / 1.12;
	float envelope = 0.88 + 0.12 * sin(clock * 0.73);
	float secondary = 0.045 * sin(phase * 1.19);
	return gust_base_angle + envelope * (gust_sway_amplitude * sway + secondary);
}

vec3 gust_rotate(vec3 value, vec3 axis, float angle) {
	return value * cos(angle) + cross(axis, value) * sin(angle)
		+ axis * dot(axis, value) * (1.0 - cos(angle));
}

void apply_grass_gust(inout vec3 vertex, inout vec3 normal, mat3 model,
	vec2 origin, vec2 direction, vec2 breeze_offset, float height_weight) {
	float blend = smoothstep(0.0, 1.0, gust_mix);
	vec3 breeze = vertex + vec3(breeze_offset.x, 0.0, breeze_offset.y);
	if (blend <= 0.0) { vertex = breeze; return; }
	float clock = gust_time < 0.0 ? TIME : gust_time;
	float lateral = sin(clock * 0.65) * 0.07;
	vec2 heading = normalize(direction + vec2(-direction.y, direction.x) * lateral);
	// Original spatial breeze fades out during the transition. At full strong
	// wind it must not reintroduce different bending times across the field.
	float angle = gust_angle(clock);
	vec3 up = normalize(model[1]);
	vec3 wind = vec3(heading.x, 0.0, heading.y);
	vec3 forward = normalize(wind - up * dot(up, wind));
	vec3 axis = normalize(cross(up, forward));
	float u = clamp(height_weight, 0.0, 1.0);
	float length_world = gust_model_height * length(model[1]);
	float a = angle * u;
	vec3 center;
	if (abs(angle) < 0.001) {
		center = up * length_world * u + forward * length_world * angle * u * u * 0.5;
	} else {
		center = length_world / angle * (up * sin(a) + forward * (1.0 - cos(a)));
	}
	vec3 side = model * vec3(vertex.x, 0.0, vertex.z);
	// This mesh is a wide tuft atlas, not one narrow blade. Keep its width frame
	// horizontal: rotating wide cross-card edges would lift corners above the tip.
	vec3 curved = inverse(model) * (center + side);
	vertex = mix(breeze, curved, blend);
	// Keep the accepted soft upward lighting, while following the new curvature.
	vec3 soft_normal = normalize(mix(up, gust_rotate(up, axis, a), 0.55));
	vec3 local_normal = normalize(transpose(model) * soft_normal);
	normal = normalize(mix(normal, local_normal, blend));
}
