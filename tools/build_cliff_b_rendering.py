"""Build B-only shader variants; original world materials remain the baseline."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets/world/cliff_b_test'

def main():
    architecture = (ASSETS/'architecture.gdshader').read_text(encoding='utf-8')
    architecture = architecture.replace('varying vec3 world_position;', '''uniform vec4 arch_shadow_tint : source_color = vec4(0.737, 0.663, 0.604, 1.0);
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
varying vec3 world_position;''')
    architecture = architecture.replace('void vertex() {', 'void vertex() {\n    main_view_direction = mat3(VIEW_MATRIX) * main_light_direction;')
    architecture = architecture.replace('    NORMAL = normalize(mat3(VIEW_MATRIX) * normalize(n + bump * normal_strength));', '''    NORMAL = normalize(mat3(VIEW_MATRIX) * normalize(n + bump * normal_strength));
    // Material-local sky IBL. Keep world ambient/sky reflection settings and
    // all other materials unchanged. This is sky reflection, not local GI/SSR.
    vec3 reflected = normalize(mat3(INV_VIEW_MATRIX) * reflect(-VIEW, NORMAL));
    float longitude = atan(reflected.z, reflected.x) - sky_yaw;
    vec2 sky_uv = vec2(fract(longitude / TAU + 0.5), acos(clamp(reflected.y, -1.0, 1.0)) / PI);
    vec3 sky_sample = textureLod(reflection_panorama, sky_uv, ROUGHNESS * 7.0).rgb;
    float sky_value = dot(sky_sample, vec3(0.2126, 0.7152, 0.0722));
    // Most of the blue is neutralized to retain a fabricated warm-white finish.
    vec3 neutral_sky = mix(sky_sample, vec3(sky_value), 0.85);
    RADIANCE = vec4(neutral_sky * reflection_energy * gloss_strength, 1.0);''')
    architecture = architecture.replace('    METALLIC = 0.0;', '''    ROUGHNESS = clamp(surface_roughness + (ROUGHNESS - 0.73) * 0.35, 0.08, 1.0);
    CLEARCOAT = coat_strength * gloss_strength;
    CLEARCOAT_ROUGHNESS = coat_roughness;
    METALLIC = 0.0;''').replace('SPECULAR = 0.28;', 'SPECULAR = 0.5 * gloss_strength;')
    architecture += '''
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
'''
    (ASSETS/'architecture_toon.gdshader').write_text(architecture, encoding='utf-8')
    material = (ASSETS/'architecture.tres').read_text(encoding='utf-8').replace('architecture.gdshader','architecture_toon.gdshader')
    material = material.replace('normal_strength = 0.14', 'normal_strength = 0.07')
    material = material.replace('load_steps=5', 'load_steps=6').replace('[resource]', '[ext_resource type="Texture2D" path="res://assets/environment/sky/fresh_cumulus_panorama_v2.png" id="5"]\n\n[resource]')
    material += '\nshader_parameter/reflection_panorama = ExtResource("5")\n'
    (ASSETS/'architecture_toon.tres').write_text(material, encoding='utf-8')
    # Road base-color correction is identical for the projected and mesh paths.
    # Keep the established terrain BRDF so vegetation/ground lighting is stable.
    for source, target in [
        ('assets/world/terrain/shaders/terrain_draft.gdshader', 'terrain.gdshader'),
        ('assets/world/map_1012_test/road.gdshader', 'road.gdshader')]:
        text = (ROOT/source).read_text(encoding='utf-8').replace('vec4(0.23, 0.25, 0.25, 1.0)', 'vec4(0.42, 0.43, 0.42, 1.0)')
        text = text.replace('void vertex() {', 'void vertex() {\n    road_main_view_direction = mat3(VIEW_MATRIX) * main_light_direction;')
        text = text.replace('void fragment() {', 'void fragment() {\n    road_surface_mask = '+('0.0;' if target == 'terrain.gdshader' else '1.0;'))
        if target == 'terrain.gdshader':
            text = text.replace('color = mix(color, road_color.rgb, road_data.r * inside * close * top_surface);', 'road_surface_mask = road_data.r * inside * close * top_surface;\n        color = mix(color, road_color.rgb, road_surface_mask);')
            text = text.replace('ROUGHNESS = 0.93;', 'ROUGHNESS = mix(0.93, 0.94, road_surface_mask);')
        text = text.replace('varying vec3 world_position;', '#include "res://assets/world/cliff_b_test/road_lighting.gdshaderinc"\n\nvarying vec3 world_position;')
        (ASSETS/target).write_text('// B variant: synchronized neutral-gray road palette.\n'+text, encoding='utf-8')
    print('B-only glossy architecture, daylight reflections, road variants generated.')

if __name__ == '__main__':
    main()
