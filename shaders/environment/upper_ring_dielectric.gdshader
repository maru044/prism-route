shader_type spatial;
render_mode blend_premul_alpha, cull_back, depth_draw_never;
// Preserve full PBR reflection radiance while alpha attenuates transmission.
// Actual-scene blending preserves alpha-to-coverage foliage behind glazing.
uniform sampler2D screen_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec4 transmission_tint : source_color = vec4(0.8,0.95,0.96,1.0);
uniform float ior = 1.5;
uniform float surface_roughness = 0.075;
uniform float density = 1.0;
uniform float nominal_thickness = 0.11;
uniform bool water_surface = false;
uniform float wave_strength = 0.018;
uniform float water_clock = 0.0;
varying vec3 world_position;
void vertex() {
    world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
vec3 view_point(vec2 uv,float depth,mat4 inverse_projection) {
    vec4 p=inverse_projection*vec4(uv*2.0-1.0,depth,1.0);
    return p.xyz/p.w;
}
void fragment() {
    vec3 n=normalize(NORMAL);
    if (water_surface) {
        vec2 p=world_position.xz;
        vec2 gradient=vec2(0.8,0.35)*cos(dot(p,vec2(0.8,0.35))-water_clock*0.65);
        gradient+=vec2(-0.45,1.3)*cos(dot(p,vec2(-0.45,1.3))+water_clock*0.9)*0.45;
        vec3 wn=normalize(vec3(-gradient.x*wave_strength,1.0,-gradient.y*wave_strength));
        n=normalize(mat3(VIEW_MATRIX)*wn);
    }
    NORMAL=n;
    float facing=clamp(abs(dot(n,normalize(VIEW))),0.0,1.0);
    float f0=pow((ior-1.0)/(ior+1.0),2.0);
    float fresnel=f0+(1.0-f0)*pow(1.0-facing,5.0);
    vec2 uv=SCREEN_UV;
    float z=texture(screen_depth,uv).r;
    vec3 behind=view_point(uv,z,INV_PROJECTION_MATRIX);
    float thickness=nominal_thickness;
    if (water_surface && z>0.000001) {
        vec3 below_world=(INV_VIEW_MATRIX*vec4(behind,1.0)).xyz;
        if (below_world.y<world_position.y-0.003) {
            thickness=clamp(world_position.y-below_world.y,0.015,1.5);
        }
    }
    float optical_path=min(thickness/max(facing,0.12),2.0);
    vec3 attenuation=exp(log(max(transmission_tint.rgb,vec3(0.01)))*density*optical_path);
    // Scalar extinction approximates absorption with ordinary alpha blending.
    // A small colored scattering term gives water its stylized tint.
    float transmittance=dot(attenuation,vec3(0.2126,0.7152,0.0722));
    ALBEDO=vec3(0.0);
    METALLIC=0.0;
    // Forward+ uses dielectric F0 = 0.16 * SPECULAR^2.
    SPECULAR=sqrt(f0/0.16);
    ROUGHNESS=surface_roughness;
    EMISSION=transmission_tint.rgb*(1.0-transmittance)*(water_surface?0.20:0.025)*(1.0-fresnel);
    ALPHA=1.0-transmittance*(1.0-fresnel);
    PREMUL_ALPHA_FACTOR=1.0;
}
