// World-space capsule footprints shared by every streamed grass chunk.
// Disabled by default: the same wind shader is also used by other vegetation.
uniform bool use_grass_interaction = false;
uniform int grass_push_count = 0;
uniform vec4 grass_push_starts[16]; // xyz: capsule start, w: core radius (m)
uniform vec4 grass_push_ends[16];   // xyz: capsule end, w: bend strength
uniform vec3 grass_push_bounds_min = vec3(0.0);
uniform vec3 grass_push_bounds_max = vec3(0.0);
uniform float grass_push_margin = 0.65;
uniform float grass_push_vertical_range = 1.15;
uniform float grass_push_max_angle = 1.256637; // 72 degrees

vec3 grass_interaction_offset(vec3 root_world, vec3 vertex_world, float root_weight) {
	if (!use_grass_interaction || grass_push_count == 0 || root_weight <= 0.0) {
		return vec3(0.0);
	}
	// Most of the island bypasses the footprint loop altogether.
	if (any(lessThan(root_world, grass_push_bounds_min))
		|| any(greaterThan(root_world, grass_push_bounds_max))) {
		return vec3(0.0);
	}
	float strongest = 0.0;
	vec2 push_direction = vec2(0.0);
	for (int i = 0; i < grass_push_count; i++) {
		vec4 start = grass_push_starts[i];
		vec4 end = grass_push_ends[i];
		vec2 segment = end.xz - start.xz;
		float along = clamp(dot(root_world.xz - start.xz, segment)
			/ max(dot(segment, segment), 0.0001), 0.0, 1.0);
		vec3 nearest = mix(start.xyz, end.xyz, along);
		vec2 away = root_world.xz - nearest.xz;
		float distance_to_body = length(away);
		float falloff = 1.0 - smoothstep(start.w * 0.25,
			start.w + grass_push_margin, distance_to_body);
		// Prevent an actor on a different storey, or high in a jump, pressing grass.
		float vertical = 1.0 - smoothstep(grass_push_vertical_range * 0.5,
			grass_push_vertical_range, abs(root_world.y - nearest.y));
		float influence = falloff * vertical * end.w;
		if (influence > strongest) {
			strongest = influence;
			// An exact centreline still has a stable outward direction.
			vec2 fallback = dot(segment, segment) > 0.0001
				? normalize(vec2(-segment.y, segment.x)) : vec2(1.0, 0.0);
			push_direction = distance_to_body > 0.001 ? away / distance_to_body : fallback;
		}
	}
	float angle = grass_push_max_angle * clamp(strongest, 0.0, 1.0);
	float height = max(vertex_world.y - root_world.y, 0.0);
	// COLOR.r is the authored root-to-tip weight; the base never moves.
	float bend = smoothstep(0.0, 1.0, root_weight);
	vec2 horizontal = push_direction * height * sin(angle) * bend;
	return vec3(horizontal.x, -height * (1.0 - cos(angle)) * bend, horizontal.y);
}
