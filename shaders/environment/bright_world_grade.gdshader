shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D world_color : hint_screen_texture, repeat_disable, filter_nearest;
uniform float exposure_lift : hint_range(0.0, 0.55, 0.01) = 0.40;
uniform float high_end : hint_range(0.75, 1.0, 0.01) = 0.96;
uniform float contrast : hint_range(0.8, 1.2, 0.01) = 1.02;
uniform float saturation : hint_range(0.0, 1.4, 0.01) = 1.09;
uniform float warm_light : hint_range(0.0, 0.08, 0.001) = 0.021;
uniform float display_gamma : hint_range(0.70, 1.40, 0.01) = 1.00;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	vec3 source = texture(world_color, SCREEN_UV).rgb;
	float brightness = dot(source, LUMA);

	// Lift the low and middle values. The lift and its slope both fall to zero at the shoulder.
	float position = clamp(brightness / high_end, 0.0, 1.0);
	float lift = high_end * exposure_lift * sin(PI * position) * (1.0 - position);
	float graded = brightness + lift;
	graded = clamp(graded + (contrast - 1.0) * (graded - 0.5) * sin(PI * graded), 0.0, 1.0);
	if (display_gamma != 1.0) {
		graded = pow(graded, 1.0 / display_gamma);
	}

	float light = smoothstep(0.52, 0.85, brightness) * (1.0 - smoothstep(0.91, 1.0, brightness));
	vec3 white_balance = vec3(1.0, 0.0, -0.9) * (warm_light * light);
	white_balance -= vec3(dot(white_balance, LUMA));

	vec3 chroma = (source - vec3(brightness)) * saturation + white_balance;
	// Keep the graded luminance and hue when a saturated color approaches the display limit.
	float positive = max(max(chroma.r, chroma.g), chroma.b);
	float negative = -min(min(chroma.r, chroma.g), chroma.b);
	float headroom = min((1.0 - graded) / max(positive, 0.0001), graded / max(negative, 0.0001));
	COLOR = vec4(clamp(vec3(graded) + chroma * min(1.0, headroom), vec3(0.0), vec3(1.0)), 1.0);
}
