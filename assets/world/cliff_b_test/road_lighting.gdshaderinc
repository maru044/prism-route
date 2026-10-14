// Shared only by B's mesh-road and projected-road shaders.
uniform vec3 main_light_direction = vec3(0.0, 1.0, 0.0);
uniform vec4 road_shadow_tint : source_color = vec4(0.80, 0.78, 0.73, 1.0);
uniform float road_shadow_fill : hint_range(0.0, 0.8) = 0.55;
varying vec3 road_main_view_direction;
varying float road_surface_mask;

vec3 road_diffuse(float ndotl, float attenuation, vec3 light_color, bool is_main_sun) {
    if (is_main_sun) {
        float lit = smoothstep(-0.15, 0.45, ndotl) * clamp(attenuation, 0.0, 1.0);
        return mix(road_shadow_tint.rgb * road_shadow_fill, vec3(0.85), lit) * light_color / PI;
    }
    return max(ndotl, 0.0) * attenuation * light_color / PI;
}

// Burley diffuse for non-road terrain. World grass retains the established
// physical response; the road mask alone selects the stylized bounce floor.
float ground_burley(float nl, float nv, float lh, float roughness) {
    float fd90 = 0.5 + 2.0 * roughness * lh * lh;
    return (1.0 + (fd90 - 1.0) * pow(1.0 - nl, 5.0))
        * (1.0 + (fd90 - 1.0) * pow(1.0 - nv, 5.0)) * nl;
}

float ground_specular(float nl, float nv, float nh, float vh, float roughness) {
    float a2 = pow(max(roughness, 0.08), 4.0);
    float d = nh * nh * (a2 - 1.0) + 1.0;
    float distribution = a2 / max(PI * d * d, 0.000001);
    float gv = nl * sqrt(nv * nv * (1.0 - a2) + a2);
    float gl = nv * sqrt(nl * nl * (1.0 - a2) + a2);
    float visibility = 0.5 / max(gv + gl, 0.00001);
    float fresnel = 0.0096 + 0.9904 * pow(1.0 - vh, 5.0);
    return distribution * visibility * fresnel * nl;
}

void light() {
    float ndotl = dot(NORMAL, LIGHT);
    float nl = max(ndotl, 0.0);
    float nv = max(dot(NORMAL, VIEW), 0.0001);
    vec3 h = normalize(LIGHT + VIEW);
    float lh = max(dot(LIGHT, h), 0.0);
    bool is_main_sun = LIGHT_IS_DIRECTIONAL && dot(LIGHT, normalize(road_main_view_direction)) > 0.9999;
    vec3 physical = vec3(ground_burley(nl, nv, lh, ROUGHNESS)) * ATTENUATION * LIGHT_COLOR / PI;
    DIFFUSE_LIGHT += mix(physical, road_diffuse(ndotl, ATTENUATION, LIGHT_COLOR, is_main_sun), road_surface_mask);
    float spec = ground_specular(nl, nv, max(dot(NORMAL, h), 0.0), max(dot(VIEW, h), 0.0), ROUGHNESS);
    SPECULAR_LIGHT += vec3(spec * SPECULAR_AMOUNT) * ATTENUATION * LIGHT_COLOR / PI;
}
