shader_type spatial;
render_mode cull_front, unshaded;
uniform sampler2D base_texture : source_color, hint_default_white;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 uv_transform = vec4(1.0, 1.0, 0.0, 0.0);
uniform vec4 outline_color : source_color = vec4(0.17, 0.13, 0.24, 1.0);
uniform float outline_pixels = 0.85;
uniform float outline_cutoff = 0.5;

void vertex() {
	UV = UV * uv_transform.xy + uv_transform.zw;
	vec3 position_view = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 normal_view = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec4 clip_position = PROJECTION_MATRIX * vec4(position_view, 1.0);
	vec2 projected = (PROJECTION_MATRIX * vec4(normal_view, 0.0)).xy;
	float normal_length = length(projected);
	float distance_fade = 1.0 - smoothstep(5.0, 12.0, length(position_view));
	float pixels = outline_pixels * distance_fade * smoothstep(0.03, 0.30, normal_length);
	vec2 offset = projected / max(normal_length, 0.0001) * pixels * 2.0 / VIEWPORT_SIZE;
	if (!IN_SHADOW_PASS) { clip_position.xy += offset * clip_position.w; }
	POSITION = clip_position;
}

void fragment() {
	if (texture(base_texture, UV).a * base_color.a < outline_cutoff) { discard; }
	ALBEDO = outline_color.rgb;
}
