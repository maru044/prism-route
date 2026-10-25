// Segmented wind shared by the grove and the streamed world.
uniform float gust_mix : hint_range(0.0, 1.0) = 0.0;
uniform float gust_time = -1.0;
uniform float gust_sway_hz : hint_range(1.0, 3.0) = 2.1;
uniform float gust_sway_amplitude : hint_range(0.0, 0.7) = 0.51;
uniform float gust_base_angle = 0.60;
uniform float gust_model_height = 1.15;
// 0: preserved synchronized baseline, 2: accepted body + tip. A was removed.
uniform int gust_motion = 2;
uniform float gust_min_angle = 0.7853982;
uniform float gust_max_angle = 1.4835299;
uniform float gust_event_interval = 4.2;
uniform vec4 gust_stages = vec4(0.22, 0.12, 0.46, 0.20);
uniform float gust_body_hz = 0.85;
uniform float gust_tip_hz = 2.4;
uniform float gust_tip_amplitude = 0.0698132;
uniform float gust_tip_lag = 0.045;
uniform float gust_tip_variation : hint_range(0.0, 1.0) = 0.0;
uniform bool gust_fixed_normal = false;
uniform bool gust_freeze_tone = false;
uniform bool gust_single_card = false;
uniform int gust_debug_view = 0;
// World-only fast path: one shared five-row curve evaluated once per frame.
uniform bool gust_shared_curve = false;
uniform bool gust_distance_lod = false;
uniform vec4 gust_curve_forward;
uniform vec4 gust_curve_up;
uniform vec4 gust_curve_normal_forward;
uniform vec4 gust_curve_normal_up;
// Offline geometry checks can freeze the angle; normal play leaves this disabled.
uniform float gust_angle_override = -100.0;

float gust_current_angle(float clock) {
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

float gust_ease(float x) {
	x = clamp(x, 0.0, 1.0);
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
}

float gust_loaded_angle(float clock, float hz) {
	vec4 stages = max(gust_stages, vec4(0.001));
	stages /= dot(stages, vec4(1.0));
	// Bent under sustained load is the default state. A short, irregular GLOBAL
	// release event occasionally lets the grass rebound, then load returns.
	// The event cadence is independent of the speed of that brief response.
	float interval = max(gust_event_interval, 2.0 / max(hz, 0.1));
	float event = floor(clock / interval);
	// Integer jitter gives the CPU shared curve and GPU reference identical events.
	float seed = float((uint(event) * 1664525u + 1013904223u) & 65535u) / 65535.0;
	float event_start = interval * (0.25 + seed * 0.15);
	float p = (clock - event * interval - event_start) * hz;
	float pressure;
	if (p < 0.0 || p >= 1.0) {
		pressure = 1.0;
	} else if (p < stages.z) {
		pressure = mix(1.0, 0.28, gust_ease(p / stages.z));
	} else if (p < stages.z + stages.w) {
		pressure = mix(0.28, 0.0, gust_ease((p - stages.z) / stages.w));
	} else if (p < stages.z + stages.w + stages.x) {
		pressure = gust_ease((p - stages.z - stages.w) / stages.x);
	} else {
		pressure = 1.0;
	}
	// Global pressure changes, never a spatially travelling front. The lower
	// angle remains under load even at the low point of every fast cycle.
	float load = 0.98 + 0.02 * sin(clock * 0.73);
	return mix(gust_min_angle, max(gust_min_angle, gust_max_angle), pressure * load);
}

float gust_body_angle(float clock) {
	if (gust_angle_override > -10.0) { return gust_angle_override; }
	if (gust_motion == 0) { return gust_current_angle(clock); }
	return gust_loaded_angle(clock, gust_body_hz);
}

float gust_tip_angle(float clock, float u, float variation) {
	float weight = smoothstep(0.35, 1.0, u);
	// Lag is along height ONLY. No per-tuft or world-position time shift.
	float phase = 6.2831853 * gust_tip_hz * (clock - gust_tip_lag * u);
	return gust_tip_amplitude * variation * weight * weight
		* (sin(phase) + 0.15 * sin(phase * 1.7)) / 1.15;
}

vec3 gust_rotate(vec3 value, vec3 axis, float angle) {
	return value * cos(angle) + cross(axis, value) * sin(angle)
		+ axis * dot(axis, value) * (1.0 - cos(angle));
}

float gust_curve_sample(vec4 rows, float u, float root) {
	float row = clamp(u * 4.0, 0.0, 4.0);
	int low = int(floor(row));
	float a = low == 0 ? root : rows[low - 1];
	float b = rows[min(low, 3)];
	return mix(a, b, fract(row));
}

float gust_lod_sample(vec4 rows, float u, float root, float distance_to_camera) {
	float fine = gust_curve_sample(rows, u, root);
	if (!gust_distance_lod) { return fine; }
	float middle = u <= 0.5 ? mix(root, rows.y, u * 2.0)
		: mix(rows.y, rows.w, (u - 0.5) * 2.0);
	float coarse = mix(root, rows.w, u);
	return mix(mix(fine, middle, smoothstep(8.0, 14.0, distance_to_camera)),
		coarse, smoothstep(26.0, 40.0, distance_to_camera));
}

void apply_grass_gust(inout vec3 vertex, inout vec3 normal, mat3 model,
	vec2 origin, vec2 direction, vec2 breeze_offset, float height_weight, float distance_to_camera) {
	if (gust_single_card && abs(vertex.z) > 0.01) { vertex = vec3(0.0); return; }
	float blend = smoothstep(0.0, 1.0, gust_mix);
	vec3 breeze = vertex + vec3(breeze_offset.x, 0.0, breeze_offset.y);
	if (blend <= 0.0) { vertex = breeze; return; }
	float clock = gust_time < 0.0 ? TIME : gust_time;
	float lateral = sin(clock * 0.65) * 0.07;
	vec2 heading = normalize(direction + vec2(-direction.y, direction.x) * lateral);
	// Original spatial breeze fades out during the transition. At full strong
	// wind it must not reintroduce different bending times across the field.
	bool shared = gust_shared_curve && gust_motion == 2 && gust_angle_override <= -10.0;
	float angle = 0.0;
	if (!shared) { angle = gust_body_angle(clock); }
	vec3 up = normalize(model[1]);
	vec3 wind = vec3(heading.x, 0.0, heading.y);
	vec3 forward = normalize(wind - up * dot(up, wind));
	vec3 axis = normalize(cross(up, forward));
	float u = clamp(height_weight, 0.0, 1.0);
	float length_world = gust_model_height * length(model[1]);
	float a = angle * u;
	vec3 center;
	if (shared) {
		center = length_world * (forward * gust_lod_sample(gust_curve_forward, u, 0.0, distance_to_camera)
			+ up * gust_lod_sample(gust_curve_up, u, 0.0, distance_to_camera));
	} else if (gust_motion == 2 && gust_angle_override <= -10.0) {
		// Integrate four unit tangents: each segment has exactly H/4 length.
		// Substituting a height-dependent angle into the circular-arc equation
		// would incorrectly claim constant arc length for a nonuniform curvature.
		vec2 card_axis = abs(normalize(vertex.xz + vec2(0.0001)));
		float seed = fract(sin(dot(origin, vec2(12.9898, 78.233))
			+ dot(card_axis, vec2(17.0, 43.0))) * 43758.5453);
		float variation = mix(1.0, mix(0.75, 1.25, seed), gust_tip_variation);
		center = vec3(0.0);
		for (int segment = 0; segment < 4; segment++) {
			float start = float(segment) * 0.25;
			float piece = clamp(u - start, 0.0, 0.25);
			float middle = start + piece * 0.5;
			float tangent = angle * middle + gust_tip_angle(clock, middle, variation);
			center += length_world * piece * (up * cos(tangent) + forward * sin(tangent));
		}
		a += gust_tip_angle(clock, u, variation);
	} else if (abs(angle) < 0.001) {
		center = up * length_world * u + forward * length_world * angle * u * u * 0.5;
	} else {
		center = length_world / angle * (up * sin(a) + forward * (1.0 - cos(a)));
	}
	vec3 side = model * vec3(vertex.x, 0.0, vertex.z);
	// This mesh is a wide tuft atlas, not one narrow blade. Keep its width frame
	// horizontal: rotating wide cross-card edges would lift corners above the tip.
	vec3 curved;
	if (shared) {
		// World grass has orthogonal yaw/scale transforms: avoid a matrix inverse
		// for every vertex while preserving the exact local coordinates.
		curved = vec3(vertex.x, 0.0, vertex.z) + vec3(
			dot(center, model[0]) / dot(model[0], model[0]),
			dot(center, model[1]) / dot(model[1], model[1]),
			dot(center, model[2]) / dot(model[2], model[2]));
	} else { curved = inverse(model) * (center + side); }
	vertex = mix(breeze, curved, blend);
	// Keep the accepted soft upward lighting, while following the new curvature.
	vec3 soft_normal = normalize(mix(up, gust_rotate(up, axis, a), 0.55));
	if (shared) {
		soft_normal = normalize(up * gust_lod_sample(gust_curve_normal_up, u, 1.0, distance_to_camera)
			+ forward * gust_lod_sample(gust_curve_normal_forward, u, 0.0, distance_to_camera));
	}
	vec3 local_normal = normalize(transpose(model) * soft_normal);
	if (!gust_fixed_normal) { normal = normalize(mix(normal, local_normal, blend)); }
}
