shader_type spatial;
render_mode diffuse_burley, cull_disabled;

// Linear RG16F: signed CAD-boundary distance in metres, authored storey height.
uniform sampler2D landscape_mask : filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 mask_origin_xz;
uniform vec2 mask_extent_xz;
uniform int comparison_mode = 0;
uniform float edge_feather_m = 0.06;
uniform float height_tolerance = 6.0;
// Colour zoning follows the live grass material; CAD distance/height stay separate.
uniform bool use_shared_meadow_biome = false;
uniform sampler2D biome_noise_texture : repeat_enable, filter_linear;
uniform float biome_noise_scale = 0.00135;
uniform float biome_warp_distance = 210.0;
uniform float biome_transition_half_width = 135.0;
uniform float biome_center_x = 20.0;
uniform vec4 ground_dry : source_color = vec4(0.588235, 0.541176, 0.333333, 1.0);
uniform vec4 ground_green : source_color = vec4(0.447, 0.475, 0.255, 1.0);
uniform bool use_far_meadow_color = false;
uniform vec4 far_ground_dry : source_color = vec4(0.7, 0.63, 0.4, 1.0);
uniform vec4 far_ground_green : source_color = vec4(0.44, 0.58, 0.29, 1.0);
uniform vec2 meadow_color_fade = vec2(48.0, 128.0);
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    vec2 uv=(world_position.xz-mask_origin_xz)/mask_extent_xz;
    float bounds=step(0.0,uv.x)*step(uv.x,1.0)*step(0.0,uv.y)*step(uv.y,1.0);
    vec2 sample_uv=uv;
    if(comparison_mode==1) { sample_uv=(floor(uv*128.0)+0.5)/128.0; }
    // Explicit base-level bilinear distance sampling plus screen-space analytic
    // AA preserves narrow CAD strokes at distance, without thresholding a bitmap.
    vec2 data=textureLod(landscape_mask,clamp(sample_uv,vec2(0.0),vec2(1.0)),0.0).rg;
    float aa=max(fwidth(data.r)*0.75,edge_feather_m);
    float white=1.0-smoothstep(-aa,aa,data.r);
    if(comparison_mode==1) { white=1.0-step(0.0,data.r); }
    float level=1.0-smoothstep(height_tolerance*0.55,height_tolerance,abs(world_position.y-data.g));
    white*=bounds*level;
    // Orient two-sided CAD faces toward the visible side: roofs plant, soffits stay architectural.
    vec3 visible_normal=normalize(world_normal)*(FRONT_FACING ? 1.0 : -1.0);
    float top=smoothstep(0.30,0.67,visible_normal.y);
    float grass=top*(1.0-white);
    if(comparison_mode==2) { grass=0.0; }
    float broad=sin(world_position.x*0.019+sin(world_position.z*0.024))*0.5
        +sin(world_position.z*0.035-world_position.x*0.009)*0.5;
    float fine=sin(world_position.x*2.1+sin(world_position.z*1.9))*sin(world_position.z*2.7);
    vec3 meadow=mix(vec3(0.12,0.19,0.045),vec3(0.27,0.25,0.095),smoothstep(-0.4,0.8,broad)*0.65);
    if (use_shared_meadow_biome) {
        float noise_value=textureLod(biome_noise_texture,
            world_position.xz*biome_noise_scale+vec2(0.137,0.411),0.0).r;
        float transition=smoothstep(-biome_transition_half_width,biome_transition_half_width,
            world_position.x-biome_center_x+(noise_value*2.0-1.0)*biome_warp_distance);
        meadow=mix(ground_dry.rgb,ground_green.rgb,transition);
        if (use_far_meadow_color) {
            // Match the loss of dense grass (48–76 m) and survivors (76–128 m).
            // Use full 3D distance, including elevated roads and rooftops.
            float far_mix=smoothstep(meadow_color_fade.x,meadow_color_fade.y,
                distance(CAMERA_POSITION_WORLD,world_position));
            meadow=mix(meadow,mix(far_ground_dry.rgb,far_ground_green.rgb,transition),far_mix);
        }
    }
    meadow*=0.985+fine*0.015;
    ALBEDO=mix(vec3(0.92,0.90,0.86),meadow,grass);
    ROUGHNESS=mix(0.28,0.95,grass);
    SPECULAR=mix(0.48,0.08,grass);
    METALLIC=0.0;
    CLEARCOAT=0.12*(1.0-grass);
    CLEARCOAT_ROUGHNESS=0.4;
}
