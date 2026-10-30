// Original regional field plus the marked lake pocket, not all world lowlands.
uniform bool biome_lowland_enabled = false;
uniform vec2 biome_lowland_fade = vec2(40.0,60.0);
uniform float biome_lowland_green = 0.94;
uniform sampler2D biome_local_sdf : filter_linear, repeat_disable;
uniform vec4 biome_local_bounds = vec4(0.0,0.0,1.0,1.0);
uniform float biome_local_feather = 80.0;
uniform bool biome_shore_enabled = false;
uniform sampler2D biome_shore_sdf : filter_linear, repeat_disable;
uniform vec4 biome_shore_bounds = vec4(0.0,0.0,1.0,1.0);

float meadow_green_weight(vec3 world_root,float noise_value,float instance_shift) {
    float regional=smoothstep(-biome_transition_half_width,biome_transition_half_width,
        world_root.x-biome_center_x+(noise_value*2.0-1.0)*biome_warp_distance+instance_shift);
    if (biome_lowland_enabled) {
        vec2 uv=(world_root.xz-biome_local_bounds.xy)/biome_local_bounds.zw;
        float bounds=step(0.0,uv.x)*step(uv.x,1.0)*step(0.0,uv.y)*step(uv.y,1.0);
        float inside_distance=textureLod(biome_local_sdf,clamp(uv,vec2(0.0),vec2(1.0)),0.0).r;
        // All feathering is INSIDE the authored outline; outside remains exact.
        float local=smoothstep(0.0,biome_local_feather,inside_distance)*bounds;
        if (biome_shore_enabled) {
            vec2 shore_uv=(world_root.xz-biome_shore_bounds.xy)/biome_shore_bounds.zw;
            float shore_bounds=step(0.0,shore_uv.x)*step(shore_uv.x,1.0)*step(0.0,shore_uv.y)*step(shore_uv.y,1.0);
            float shore_distance=textureLod(biome_shore_sdf,clamp(shore_uv,vec2(0.0),vec2(1.0)),0.0).r;
            local=max(local,smoothstep(0.0,biome_local_feather,shore_distance)*shore_bounds);
        }
        float wet=(1.0-smoothstep(biome_lowland_fade.x,biome_lowland_fade.y,world_root.y))*local;
        regional=mix(regional,max(regional,biome_lowland_green),wet);
    }
    return regional;
}
