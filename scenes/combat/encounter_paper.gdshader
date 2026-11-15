shader_type canvas_item;
render_mode unshaded;

uniform vec2 plate_size = vec2(386.0, 84.0);
uniform vec4 face : source_color;
uniform vec4 tint : source_color;
uniform vec4 light_color : source_color;
uniform vec4 pencil : source_color;
uniform float density = 0.7;
uniform float selected = 0.0;
uniform float interaction = 0.0;
uniform float depressed = 0.0;
uniform float unavailable = 0.0;
uniform float sheet = 0.0;

float grain(vec2 coordinate) {
	vec3 p = fract(vec3(coordinate.xyx) * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	vec2 p = UV * plate_size;
	float strength = max(selected * 0.76, interaction * 0.72) + depressed * 0.17;
	float local_wash = smoothstep(0.14, 0.95, abs(UV.x * 2.0 - 1.0));
	float pigment = clamp(0.27 + local_wash * 0.47 + (1.0 - UV.y) * 0.11, 0.0, 1.0);
	vec3 paper = mix(face.rgb, tint.rgb, pigment);
	paper = mix(paper, light_color.rgb, strength * (0.48 + local_wash * 0.28));
	float tooth = grain(floor(p * 0.78));
	float fibers = grain(floor(p * vec2(0.32, 1.1)));
	paper *= 1.0 + (tooth - 0.5) * 0.054 + (fibers - 0.5) * 0.018;

	vec2 curl = vec2(sin(p.y * 0.074) * 1.0, sin(p.x * 0.041) * 0.75) * (1.0 + sheet * 0.65);
	vec2 edge = min(p, plate_size - p) + curl;
	float torn_edge = min(edge.x, edge.y) - (tooth - 0.5) * 1.1;
	float silhouette = smoothstep(0.0, 1.35, torn_edge);
	float pencil_y = abs(edge.y - (4.2 + sheet * 1.8 + sin(p.x * 0.027 + 0.6) * 0.6));
	float rule = (1.0 - smoothstep(0.20, 1.15, pencil_y)) * smoothstep(5.0, 16.0, edge.x);
	float spine = (1.0 - smoothstep(0.50, 1.6, abs(p.x - 5.0))) * smoothstep(3.0, 9.0, edge.y);
	float contour = (1.0 - smoothstep(0.35, 1.45, abs(edge.x - 4.8))) * smoothstep(5.0, 13.0, edge.y);
	float ink = max(max(rule * (0.54 + strength * 0.19), contour * 0.28), spine * selected * 0.78);
	paper = mix(paper, pencil.rgb, ink * (0.70 + tooth * 0.30));
	float opacity = mix(0.90, 0.98, clamp(density + strength * 0.25, 0.0, 1.0));
	COLOR = vec4(paper, silhouette * opacity * mix(1.0, 0.76, unavailable));
}
