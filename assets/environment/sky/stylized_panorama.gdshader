shader_type sky;

// Keep the accepted HDRI's radiance independent of the painted background.
uniform sampler2D lighting_panorama : source_color, filter_linear, repeat_enable;
uniform sampler2D display_panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform float lighting_energy : hint_range(0.0, 4.0) = 0.48;
uniform float display_energy : hint_range(0.0, 4.0) = 1.0;
uniform float display_yaw : hint_range(-3.141593, 3.141593) = 0.0;

vec3 painted_sky(vec2 coordinates) {
	vec2 uv = vec2(fract(coordinates.x + display_yaw / TAU), clamp(coordinates.y, 0.0006, 0.9994));
	vec3 color = texture(display_panorama, uv).rgb;
	// The generated PNG has small edge color differences. Join only the narrow
	// cloud-free margin, and make the two poles independent of longitude.
	float edge_distance = min(uv.x, 1.0 - uv.x);
	if (edge_distance < 0.015) {
		vec3 joined = (texture(display_panorama, vec2(0.015, uv.y)).rgb
			+ texture(display_panorama, vec2(0.985, uv.y)).rgb) * 0.5;
		color = mix(joined, color, smoothstep(0.0, 0.015, edge_distance));
	}
	float pole_distance = min(uv.y, 1.0 - uv.y);
	if (pole_distance < 0.20) {
		float pole_y = uv.y < 0.5 ? 0.0006 : 0.9994;
		vec3 pole = texture(display_panorama, vec2(0.5, pole_y)).rgb;
		color = mix(pole, color, smoothstep(0.0, 0.20, pole_distance));
	}
	return color * display_energy;
}

void sky() {
	if (AT_CUBEMAP_PASS) {
		COLOR = texture(lighting_panorama, SKY_COORDS).rgb * lighting_energy;
	} else {
		COLOR = painted_sky(SKY_COORDS);
	}
}
