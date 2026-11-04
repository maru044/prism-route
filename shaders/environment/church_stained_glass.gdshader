shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 glass_tint : source_color = vec4(0.42, 0.72, 0.79, 1.0);
uniform float base_opacity : hint_range(0.0, 1.0) = 0.24;
varying vec3 glass_world;

void vertex() {
	glass_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// World-plane coordinates also work with the original UV-less Rhino panes.
	float across = dot(glass_world.xz, normalize(vec2(0.4104, -0.9119)));
	vec2 panes = vec2((across + glass_world.y * 0.34) / 1.25, glass_world.y / 1.75);
	vec2 cell = floor(panes);
	vec2 edge = min(fract(panes), 1.0 - fract(panes));
	float line = 1.0 - smoothstep(0.008, 0.008 + max(fwidth(panes.x), fwidth(panes.y)), min(edge.x, edge.y));
	float variation = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 azure = mix(glass_tint.rgb, vec3(0.64, 0.84, 0.85), variation);
	vec3 tint = mix(azure, vec3(0.86, 0.68, 0.36), step(0.82, variation));
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float fresnel = 0.04 + 0.96 * pow(1.0 - facing, 5.0);
	ALBEDO = mix(tint, vec3(0.12, 0.14, 0.13), line);
	METALLIC = line * 0.45;
	ROUGHNESS = mix(0.17 + variation * 0.08, 0.65, line);
	SPECULAR = 0.5;
	ALPHA = mix(clamp(base_opacity + fresnel * 0.4, 0.0, 0.68), 0.86, line);
}
