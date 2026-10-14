shader_type spatial;
render_mode diffuse_burley, cull_back;

uniform sampler2D base_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D micro_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 warm_white : source_color = vec4(0.91, 0.895, 0.865, 1.0);
uniform float detail_strength : hint_range(0.0, 1.0) = 0.20;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.14;
uniform float texture_meters = 1.6;
uniform vec4 arch_shadow_tint : source_color = vec4(0.737, 0.663, 0.604, 1.0);
uniform float arch_shadow_fill : hint_range(0.0, 0.5) = 0.18;
uniform float arch_direct_gain : hint_range(0.0, 2.0) = 0.72;
uniform float arch_ramp_start = -0.15;
uniform float arch_ramp_end = 0.45;
uniform float surface_roughness : hint_range(0.08, 1.0) = 0.30;
uniform float gloss_strength : hint_range(0.0, 2.0) = 1.0;
uniform float coat_strength : hint_range(0.0, 1.0) = 0.30;
uniform float coat_roughness : hint_range(0.08, 1.0) = 0.18;
uniform float reflection_energy : hint_range(0.0, 2.0) = 0.45;
uniform float sky_yaw = 1.2217305;
uniform sampler2D reflection_panorama : source_color, filter_linear_mipmap, repeat_enable;
// Only the selected sun contributes the NPR bounce floor, even with more suns.
uniform vec3 main_light_direction = vec3(0.0, 1.0, 0.0);
varying vec3 main_view_direction;
varying vec3 world_position;
varying vec3 world_normal;

vec3 read_base(vec2 uv) {
    // Mirrored sampling makes the generated albedo continuous at tile edges.
    return texture(base_texture, abs(fract(uv * 0.5) * 2.0 - 1.0)).rgb;
}

void vertex() {
    main_view_direction = mat3(VIEW_MATRIX) * main_light_direction;
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    vec3 n = normalize(world_normal);
    vec3 weights = pow(abs(n), vec3(8.0));
    weights /= max(dot(weights, vec3(1.0)), 0.0001);
    vec3 p = world_position / texture_meters;
    vec3 detail = read_base(p.zy) * weights.x + read_base(p.xz) * weights.y + read_base(p.xy) * weights.z;
    // Fine texture only; broad white color belongs to the fabricated surface.
    ALBEDO = warm_white.rgb * mix(vec3(1.0), clamp(detail / vec3(0.85), vec3(0.75), vec3(1.12)), detail_strength);
    ROUGHNESS = texture(roughness_texture, p.zy).r * weights.x
        + texture(roughness_texture, p.xz).r * weights.y
        + texture(roughness_texture, p.xy).r * weights.z;
    ROUGHNESS = clamp(surface_roughness + (ROUGHNESS - 0.73) * 0.35, 0.08, 1.0);
    CLEARCOAT = coat_strength * gloss_strength;
    CLEARCOAT_ROUGHNESS = coat_roughness;
    METALLIC = 0.0;
    SPECULAR = 0.5 * gloss_strength;
    vec2 nx = texture(micro_normal, p.zy).rg * 2.0 - 1.0;
    vec2 ny = texture(micro_normal, p.xz).rg * 2.0 - 1.0;
    vec2 nz = texture(micro_normal, p.xy).rg * 2.0 - 1.0;
    vec3 bump = vec3(0.0, nx.y, nx.x) * weights.x
        + vec3(ny.x, 0.0, ny.y) * weights.y
        + vec3(nz.x, nz.y, 0.0) * weights.z;
    bump -= n * dot(n, bump);
    NORMAL = normalize(mat3(VIEW_MATRIX) * normalize(n + bump * normal_strength));
    // Material-local sky IBL. Keep world ambient/sky reflection settings and
    // all other materials unchanged. This is sky reflection, not local GI/SSR.
    vec3 reflected = normalize(mat3(INV_VIEW_MATRIX) * reflect(-VIEW, NORMAL));
    float longitude = atan(reflected.z, reflected.x) - sky_yaw;
    vec2 sky_uv = vec2(fract(longitude / TAU + 0.5), acos(clamp(reflected.y, -1.0, 1.0)) / PI);
    vec3 sky_sample = textureLod(reflection_panorama, sky_uv, ROUGHNESS * 7.0).rgb;
    float sky_value = dot(sky_sample, vec3(0.2126, 0.7152, 0.0722));
    // Most of the blue is neutralized to retain a fabricated warm-white finish.
    vec3 neutral_sky = mix(sky_sample, vec3(sky_value), 0.85);
    RADIANCE = vec4(neutral_sky * reflection_energy * gloss_strength, 1.0);
}

// Isotropic dielectric GGX with correlated Smith visibility. This is explicit:
// custom light() replaces the engine's direct specular as well as its diffuse.
float dielectric_ggx(float nl, float nv, float nh, float vh, float roughness) {
    float a2 = pow(max(roughness, 0.08), 4.0);
    float d = nh * nh * (a2 - 1.0) + 1.0;
    float distribution = a2 / max(PI * d * d, 0.000001);
    float gv = nl * sqrt(nv * nv * (1.0 - a2) + a2);
    float gl = nv * sqrt(nl * nl * (1.0 - a2) + a2);
    float visibility = 0.5 / max(gv + gl, 0.00001);
    float fresnel = 0.04 + 0.96 * pow(1.0 - vh, 5.0);
    return distribution * visibility * fresnel * nl;
}

void light() {
    float ndotl = dot(NORMAL, LIGHT);
    if (LIGHT_IS_DIRECTIONAL && dot(LIGHT, normalize(main_view_direction)) > 0.9999) {
        float facing = smoothstep(arch_ramp_start, arch_ramp_end, ndotl);
        float lit = facing * clamp(ATTENUATION, 0.0, 1.0);
        vec3 shade = arch_shadow_tint.rgb * arch_shadow_fill;
        DIFFUSE_LIGHT += mix(shade, vec3(arch_direct_gain), lit) * LIGHT_COLOR / PI;
    } else {
        DIFFUSE_LIGHT += max(ndotl, 0.0) * ATTENUATION * LIGHT_COLOR / PI;
    }
    float nl = max(ndotl, 0.0);
    float nv = max(dot(NORMAL, VIEW), 0.0001);
    vec3 h = normalize(LIGHT + VIEW);
    float nh = max(dot(NORMAL, h), 0.0);
    float vh = max(dot(VIEW, h), 0.0);
    float spec = dielectric_ggx(nl, nv, nh, vh, ROUGHNESS);
    spec += coat_strength * dielectric_ggx(nl, nv, nh, vh, coat_roughness);
    SPECULAR_LIGHT += vec3(spec * gloss_strength * SPECULAR_AMOUNT) * ATTENUATION * LIGHT_COLOR / PI;
}
