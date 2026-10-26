// Prism Route C0: own implementation, no game-specific masks or SDF required.
// Base color is applied exactly once by Godot's ALBEDO composition.
uniform sampler2D base_texture : source_color, hint_default_white;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 uv_transform = vec4(1.0, 1.0, 0.0, 0.0);
uniform int region = 3; // face, skin, hair, body, eye, accessory, overlay
uniform int tone_bands = 2;
uniform float edge_softness = 0.08;
uniform float face_softness = 0.45;
uniform float diffuse_gain = 0.85;
uniform float hair_highlight = 0.12;
uniform float eye_highlight = 0.12;
uniform vec3 shadow_multiplier = vec3(0.62, 0.56, 0.70);
uniform vec3 skin_shadow_multiplier = vec3(0.82, 0.68, 0.72);
uniform vec3 head_forward = vec3(0.0, 0.0, 1.0);
uniform float alpha_cutoff = 0.0;
uniform float source_roughness = 0.5;
varying vec3 strand_direction;

void vertex() {
	UV = UV * uv_transform.xy + uv_transform.zw;
	// Tangent-based approximation; no claim of authored strand-flow data.
	strand_direction = mat3(MODELVIEW_MATRIX) * TANGENT;
}

void fragment() {
	vec4 sample_color = texture(base_texture, UV) * base_color;
	if (sample_color.a < alpha_cutoff) { discard; }
	ALBEDO = sample_color.rgb;
	ROUGHNESS = region == 5 ? max(0.3, source_roughness) : 1.0;
	SPECULAR = region == 5 ? 0.25 : 0.0;
	METALLIC = 0.0;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
#ifdef SOURCE_ALPHA_BLEND
	ALPHA = sample_color.a;
#endif
}

void light() {
	vec3 n = normalize(NORMAL);
	if (region == 0) {
		vec3 facing = normalize(mat3(VIEW_MATRIX) * head_forward);
		// A face fallback, not Face SDF: soften geometry-dependent nasal shadows.
		n = normalize(mix(n, facing, clamp(face_softness, 0.0, 0.95)));
	}
	float nl = dot(n, LIGHT);
	float width = max(edge_softness, 0.01);
	float lit_band = smoothstep(-width, width, nl);
	vec3 shade = (region == 0 || region == 1) ? skin_shadow_multiplier : shadow_multiplier;
	vec3 tone = mix(shade, vec3(1.0), lit_band);
	if (tone_bands == 3) {
		float high_band = smoothstep(0.52 - width, 0.52 + width, nl);
		tone = mix(shade * 0.86, mix(shade, vec3(1.0), 0.6), lit_band);
		tone = mix(tone, vec3(1.0), high_band);
	}
	// Additional lights use a Lambert lobe: no illuminated back side or thresholded range.
	if (!LIGHT_IS_DIRECTIONAL) { tone *= max(nl, 0.0); }
	// Real occluders remove direct lighting. Sky/ambient provide the shadow floor.
	DIFFUSE_LIGHT += diffuse_gain * tone * ATTENUATION * LIGHT_COLOR / PI;
	vec3 half_vector = normalize(LIGHT + VIEW + vec3(0.00001));
	float specular_lobe = 0.0;
	if (region == 2 && hair_highlight > 0.0) {
		vec3 tangent = strand_direction / max(length(strand_direction), 0.0001);
		float tangent_half = dot(tangent, half_vector);
		float band = pow(max(0.0, 1.0 - tangent_half * tangent_half), 48.0);
		specular_lobe = band * pow(max(dot(n, half_vector), 0.0), 8.0) * hair_highlight;
	} else if (region == 4) {
		specular_lobe = pow(max(dot(n, half_vector), 0.0), 96.0) * eye_highlight;
	} else if (region == 5) {
		specular_lobe = pow(max(dot(n, half_vector), 0.0), 32.0) * 0.18;
	}
	SPECULAR_LIGHT += specular_lobe * max(nl, 0.0) * ATTENUATION * LIGHT_COLOR / PI;
}
