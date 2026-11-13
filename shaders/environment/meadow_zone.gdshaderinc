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

// Colour-only field: trimmed 35m platform including verges; road/curb masks stay independent.
// Never used by density, collision, placement or grass-root generation.
uniform bool coastal_enabled = false;
uniform sampler2D coastal_field : filter_linear, repeat_disable;
uniform vec4 coastal_bounds = vec4(0.0,0.0,1.0,1.0);
uniform float coastal_feather = 3.0;
uniform vec4 coastal_grass_dry : source_color = vec4(1.0);
uniform vec4 coastal_grass_mid : source_color = vec4(1.0);
uniform vec4 coastal_grass_green : source_color = vec4(1.0);
uniform vec4 coastal_ground_dry : source_color = vec4(1.0);
uniform vec4 coastal_ground_green : source_color = vec4(1.0);
uniform vec4 coastal_far_dry : source_color = vec4(1.0);
uniform vec4 coastal_far_green : source_color = vec4(1.0);
uniform bool coastal_tree_enabled = false;
uniform vec4 coastal_tree_shadow : source_color = vec4(1.0);
uniform vec4 coastal_tree_mid : source_color = vec4(1.0);
uniform vec4 coastal_tree_light : source_color = vec4(1.0);

float coastal_weight(vec3 root) {
    if (!coastal_enabled) { return 0.0; }
    vec2 uv=(root.xz-coastal_bounds.xy)/coastal_bounds.zw;
    if (any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0)))) { return 0.0; }
    vec2 field=textureLod(coastal_field,uv,0.0).rg;
    return smoothstep(0.0,coastal_feather,field.r)
        *(1.0-smoothstep(0.2,0.6,abs(root.y-field.g)));
}

float coastal_gradient(vec3 root) {
    // Grass roots and the ground share the same slow variation in world metres.
    float noise_value = textureLod(biome_noise_texture, root.xz * 0.004 + vec2(0.67, 0.29), 0.0).r;
    return mix(0.12, 0.88, smoothstep(0.20, 0.80, noise_value));
}

vec3 coastal_grass_colour(vec3 root) {
    float t=coastal_gradient(root);
    vec3 shade_to_base=mix(coastal_grass_dry.rgb,coastal_grass_mid.rgb,smoothstep(0.08,0.48,t));
    return mix(shade_to_base,coastal_grass_green.rgb,smoothstep(0.58,0.95,t));
}

vec3 coastal_ground_colour(vec3 original,vec3 point,float far_mix) {
    float weight = coastal_weight(point);
    if (weight <= 0.0) { return original; }
    float t=coastal_gradient(point);
    vec3 near_colour=mix(coastal_ground_dry.rgb,coastal_ground_green.rgb,t);
    vec3 far_colour=mix(coastal_far_dry.rgb,coastal_far_green.rgb,t);
    return mix(original,mix(near_colour,far_colour,far_mix),weight);
}

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
