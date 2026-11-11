shader_type canvas_item;
render_mode unshaded;

uniform vec4 upper_color : source_color = vec4(0.34, 0.18, 0.61, 1.0);
uniform vec4 lower_color : source_color = vec4(0.07, 0.52, 0.60, 1.0);
uniform vec4 motif_color : source_color = vec4(0.78, 0.70, 0.95, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.78;
varying vec4 canvas_tint;

void vertex() {
	canvas_tint = COLOR;
}

float contour(vec2 p, vec2 center, vec2 radius, float width) {
	float distance_to_curve = abs(length((p - center) / radius) - 1.0) * min(radius.x, radius.y);
	return 1.0 - smoothstep(width * 0.34, width * 0.50 + 0.0014, distance_to_curve);
}

void fragment() {
	vec2 uv = UV;
	// Leave the stage clear, even where the view behind the fade is very bright.
	float around_stage = length((uv - vec2(0.5, 0.51)) / vec2(0.35, 0.63));
	float sides = smoothstep(0.97, 1.49, around_stage);
	float ceiling = (1.0 - smoothstep(0.0, 0.23, uv.y)) * 0.70;
	float ground = smoothstep(0.81, 1.0, uv.y) * 0.62;
	float border = max(sides, max(ceiling, ground));

	COLOR = vec4(0.0);
	if (border > 0.0) {
		float tide = smoothstep(0.16, 0.84, uv.y);
		vec4 wash = mix(upper_color, lower_color, tide);
		wash.rgb *= mix(1.10, 0.86, smoothstep(0.50, 1.0, border));

		// Sweeping ribbons and finer parallel lines are drawn directly from curves.
		vec2 sweep = vec2(uv.x + 0.18 * uv.y, uv.y);
		float ribbon = max(
			contour(sweep, vec2(-0.115, 0.12), vec2(0.33, 0.54), 0.040),
			contour(sweep, vec2(1.185, 0.72), vec2(0.27, 0.64), 0.035)
		);
		float linework = max(
			contour(sweep, vec2(-0.085, 0.12), vec2(0.32, 0.57), 0.005),
			contour(sweep, vec2(1.170, 0.68), vec2(0.31, 0.62), 0.004)
		);
		linework = max(linework, contour(uv, vec2(1.09, -0.20), vec2(0.31, 0.41), 0.006));
		linework = max(linework, contour(uv, vec2(0.01, 1.10), vec2(0.29, 0.30), 0.005));

		vec2 dots_uv = uv * vec2(218.0, 123.0);
		dots_uv.x += 0.5 * mod(floor(dots_uv.y), 2.0);
		float dots = 1.0 - smoothstep(0.08, 0.25, length(fract(dots_uv) - 0.5));
		float ornament = (ribbon * 0.15 + linework * 0.30 + dots * 0.06) * motif_color.a;
		wash.rgb = mix(wash.rgb, motif_color.rgb, ornament * smoothstep(0.05, 0.72, border));

		COLOR = vec4(wash.rgb, border * strength * wash.a) * canvas_tint;
	}
}
