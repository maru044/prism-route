shader_type canvas_item;
render_mode unshaded;

uniform vec2 plate_size = vec2(386.0, 84.0);
uniform vec4 face : source_color;
uniform vec4 tint : source_color;
uniform vec4 light_color : source_color;
uniform float density = 0.7;
uniform float selected = 0.0;
uniform float interaction = 0.0;
uniform float depressed = 0.0;
uniform float unavailable = 0.0;
varying vec4 canvas_tint;

void vertex() {
	canvas_tint = COLOR;
}

void fragment() {
	float sides = smoothstep(0.08, 1.0, abs(UV.x * 2.0 - 1.0));
	float depth = smoothstep(0.0, 1.0, UV.y);
	vec3 body = mix(face.rgb, tint.rgb, 0.10 + 0.80 * depth);
	body = mix(body, face.rgb * 0.64, sides * 0.67);
	float center_light = (0.06 + selected * 0.045 + interaction * 0.17 + depressed * 0.08) * (1.0 - sides * 0.78);
	body = mix(body, light_color.rgb, center_light);

	vec2 p = UV * plate_size;
	float stripe = 0.5 + 0.5 * cos(p.y * 2.03);
	body *= 1.0 - stripe * 0.065;

	// Use the full rectangle. The tint and opacity change inside it.
	float opacity = density * mix(0.76, 1.0, sides) + interaction * 0.10;
	vec2 from_edge = min(p, plate_size - p);
	float border = 1.0 - smoothstep(0.55, 1.35, min(from_edge.x, from_edge.y));
	float border_light = border * max(selected * 0.32, interaction * 0.75);
	body = mix(body, light_color.rgb, border_light);
	opacity = max(opacity, border_light * 0.94);
	COLOR = vec4(body, clamp(opacity, 0.0, 0.96) * mix(1.0, 0.50, unavailable)) * canvas_tint;
}
