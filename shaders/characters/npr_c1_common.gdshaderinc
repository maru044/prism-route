// Own C1 implementation. Face threshold SDF is authored for the actual Ganyu UV.
// Direct lighting keeps Godot's real shadow attenuation; no baked sun/emission.
uniform sampler2D base_texture : source_color, hint_default_white;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 uv_transform = vec4(1.0, 1.0, 0.0, 0.0);
uniform sampler2D face_sdf : filter_linear, repeat_disable;
uniform sampler2D body_material_mask : filter_linear_mipmap, repeat_disable;
uniform bool has_body_mask = false;
uniform bool sdf_enabled = true;
uniform float sdf_softness = 0.035;
uniform int region = 3;
uniform int tone_bands = 2;
uniform float ambient_weight = 0.62;
uniform float c1_diffuse_gain = 0.82;
uniform vec3 c1_shadow_multiplier = vec3(0.50, 0.46, 0.64);
uniform vec3 c1_skin_shadow_multiplier = vec3(0.71, 0.48, 0.55);
uniform float c1_hair_highlight = 0.22;
uniform float eye_highlight = 0.12;
uniform vec3 head_forward = vec3(0.0, 0.0, 1.0);
uniform vec3 head_right = vec3(1.0, 0.0, 0.0);
uniform vec3 head_up = vec3(0.0, 1.0, 0.0);
uniform float alpha_cutoff = 0.0;
varying vec3 strand_direction;
varying vec2 material_selection;
varying vec3 forward_view;
varying vec3 right_view;
varying vec3 up_view;

void vertex() {
	UV = UV * uv_transform.xy + uv_transform.zw;
	strand_direction = mat3(MODELVIEW_MATRIX) * TANGENT;
	forward_view = mat3(VIEW_MATRIX) * head_forward;
	right_view = mat3(VIEW_MATRIX) * head_right;
	up_view = mat3(VIEW_MATRIX) * head_up;
}

void fragment() {
	vec4 base = texture(base_texture, UV) * base_color;
	if (base.a < alpha_cutoff) { discard; }
	ALBEDO = base.rgb;
	material_selection = has_body_mask ? texture(body_material_mask, UV).rg : vec2(0.0);
	// AO controls the real environment contribution, not a replacement ambient color.
	// Keep direct light unaffected so occluder tests remain independent.
	AO = ambient_weight * mix(1.0, 0.86, material_selection.g);
	AO_LIGHT_AFFECT = 0.0;
	ROUGHNESS = mix(1.0, 0.38, material_selection.r);
	SPECULAR = 0.20 * material_selection.r;
	METALLIC = 0.0;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
#ifdef SOURCE_ALPHA_BLEND
	ALPHA = base.a;
#endif
}

float face_lighting(vec3 light_direction, vec3 forward_axis, vec3 right_axis, vec3 up_axis, vec2 uv) {
	vec2 planar = vec2(dot(light_direction, right_axis), dot(light_direction, forward_axis));
	float planar_length = length(planar);
	// Head-relative axes follow roll/pitch too. No world-X sign or zero normalize.
	float frontal = planar.y / max(planar_length, 0.0001);
	float phase = 0.5 - 0.5 * frontal;
	phase = mix(dot(light_direction, up_axis) >= 0.0 ? 0.1 : 0.9, phase, smoothstep(0.0, 0.05, planar_length));
	vec2 fields = texture(face_sdf, uv).rg;
	float sdf_value = planar.x >= 0.0 ? fields.r : fields.g;
	return smoothstep(phase - sdf_softness, phase + sdf_softness, sdf_value);
}

void light() {
	vec3 n = normalize(NORMAL);
	float nl = dot(n, LIGHT);
	float width = max(0.025, fwidth(nl) * 1.2);
	float lit_band = smoothstep(0.10 - width, 0.10 + width, nl);
	bool skin = region == 0 || region == 1;
	if (region == 0 && LIGHT_IS_DIRECTIONAL && sdf_enabled) {
		lit_band = face_lighting(LIGHT, forward_view, right_view, up_view, UV);
	}
	vec3 shade = skin ? c1_skin_shadow_multiplier : c1_shadow_multiplier;
	if (region == 2) { shade = vec3(0.48, 0.49, 0.72); }
	vec3 tone = mix(shade, vec3(1.0), lit_band);
	if (tone_bands == 3 && !skin) {
		float upper = smoothstep(0.58 - width, 0.58 + width, nl);
		tone = mix(shade, mix(shade, vec3(1.0), 0.60), lit_band);
		tone = mix(tone, vec3(1.0), upper);
	}
	if (!LIGHT_IS_DIRECTIONAL) { tone *= max(nl, 0.0); }
	float gain = c1_diffuse_gain * mix(1.0, 0.90, material_selection.g);
	DIFFUSE_LIGHT += gain * tone * ATTENUATION * LIGHT_COLOR / PI;
	vec3 half_vector = normalize(LIGHT + VIEW + vec3(0.00001));
	float specular_lobe = 0.0;
	vec3 specular_tint = vec3(1.0);
	if (region == 2) {
		vec3 tangent = strand_direction / max(length(strand_direction), 0.0001);
		float th = dot(tangent, half_vector);
		float ribbon = pow(max(0.0, 1.0 - th * th), 26.0);
		specular_lobe = smoothstep(0.40, 0.85, ribbon) * pow(max(dot(n, half_vector), 0.0), 10.0) * c1_hair_highlight;
		specular_tint = vec3(0.75, 0.85, 1.0);
	} else if (region == 4) {
		specular_lobe = pow(max(dot(n, half_vector), 0.0), 96.0) * eye_highlight;
	} else {
		float gold = max(material_selection.r, region == 5 ? 0.65 : 0.0);
		specular_lobe = smoothstep(0.35, 0.80, pow(max(dot(n, half_vector), 0.0), 32.0)) * gold * 0.48;
		specular_tint = vec3(1.0, 0.80, 0.45);
	}
	SPECULAR_LIGHT += specular_tint * specular_lobe * max(nl, 0.0) * ATTENUATION * LIGHT_COLOR / PI;
}
