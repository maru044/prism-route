shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

// Scene buffers are linear HDR. Reflection viewport is also linear HDR;
// exposure and ACES are applied only by the final, main viewport.
uniform sampler2D screen_color : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D screen_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D sky_panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D planar_color : filter_linear, repeat_disable;
uniform mat4 reflection_vp;
uniform bool planar_enabled = false;
uniform float reflection_mix = 0.0;
uniform vec2 reflection_texel = vec2(0.001);
uniform float sky_yaw = 1.473;
uniform vec4 shallow_color : source_color = vec4(0.24, 0.69, 0.65, 1.0);
uniform vec4 deep_color : source_color = vec4(0.075, 0.36, 0.46, 1.0);
uniform float absorption = 0.65;
uniform bool see_bottom = true;
uniform float exposure_to_wind = 0.5;
uniform float water_clock = 0.0;
uniform float wind_strength = 0.0;
uniform vec2 wind_direction = vec2(0.916, 0.401);
uniform float surface_detail = 1.0;
uniform int event_count = 0;
// x/z position, birth time, height amplitude. Per-water-body filtering is CPU side.
uniform vec4 ripple_events[16];
varying vec3 world_position;

void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 wave_gradient(vec2 p, float t) {
    vec2 d = normalize(wind_direction);
    vec2 side = vec2(-d.y, d.x);
    float wind = wind_strength * exposure_to_wind;
    float patch = 0.72 + 0.28 * sin(dot(p, d) * 0.075 - t * 0.38 + sin(dot(p, side) * 0.12));
    vec2 gradient = d * cos(dot(p, d) * 2.3 - t * 2.1) * 0.028;
    vec2 cross_dir = normalize(d + side * 0.48);
    gradient += cross_dir * cos(dot(p, cross_dir) * 5.1 - t * 3.7 + 1.4) * 0.017;
    gradient += normalize(d - side * 0.30) * cos(dot(p, d - side * 0.30) * 0.67 - t * 0.85) * 0.015;
    return gradient * (0.018 + wind * patch * 2.2) * surface_detail;
}

vec2 interaction_gradient(vec2 p, float footprint) {
    vec2 gradient = vec2(0.0);
    for (int i = 0; i < 16; i++) {
        if (i >= event_count) { break; }
        vec4 e = ripple_events[i];
        vec2 delta = p - e.xy;
        float r = length(delta);
        float age = water_clock - e.z;
        if (age < 0.0 || age > 5.0 || r > 6.6) { continue; }
        float s = r - age * 1.10;
        if (abs(s) > 1.10) { continue; }
        float width = 0.30 + age * 0.055;
        float inv_w2 = 1.0 / (width * width);
        float envelope = exp(-s * s * inv_w2 - age * 0.85);
        float derivative = e.w * envelope * (cos(s * 14.0) * 14.0 - sin(s * 14.0) * 2.0 * s * inv_w2);
        gradient += delta / max(r, 0.02) * derivative;
    }
    return gradient * (1.0 - smoothstep(0.04, 0.22, footprint));
}

vec3 reflected_sky(vec3 direction) {
    // Same orientation and equirectangular convention as Godot's sky.glsl.
    float c = cos(sky_yaw);
    float s = sin(sky_yaw);
    vec3 local_direction = vec3(c * direction.x - s * direction.z, direction.y, s * direction.x + c * direction.z);
    vec2 uv = vec2(fract(atan(local_direction.x, -local_direction.z) / TAU), acos(clamp(local_direction.y, -1.0, 1.0)) / PI);
    uv.y = clamp(uv.y, 0.0006, 0.9994);
    vec3 color = texture(sky_panorama, uv).rgb;
    float edge = min(uv.x, 1.0 - uv.x);
    if (edge < 0.015) {
        vec3 joined = (texture(sky_panorama, vec2(0.015, uv.y)).rgb + texture(sky_panorama, vec2(0.985, uv.y)).rgb) * 0.5;
        color = mix(joined, color, smoothstep(0.0, 0.015, edge));
    }
    float pole = min(uv.y, 1.0 - uv.y);
    if (pole < 0.20) {
        vec3 pole_color = texture(sky_panorama, vec2(0.5, uv.y < 0.5 ? 0.0006 : 0.9994)).rgb;
        color = mix(pole_color, color, smoothstep(0.0, 0.20, pole));
    }
    return color;
}

void fragment() {
    float footprint = max(length(dFdx(world_position.xz)), length(dFdy(world_position.xz)));
    vec2 gradient = wave_gradient(world_position.xz, water_clock);
    gradient *= 1.0 - smoothstep(0.16, 1.5, footprint);
    gradient += interaction_gradient(world_position.xz, footprint);
    vec2 screen_right = normalize(INV_VIEW_MATRIX[0].xz + vec2(0.000001));
    vec2 screen_forward = -INV_VIEW_MATRIX[2].xz;
    if (length(screen_forward) < 0.01) { screen_forward = -INV_VIEW_MATRIX[1].xz; }
    screen_forward = normalize(screen_forward);
    vec2 screen_gradient = vec2(dot(gradient, screen_right), dot(gradient, screen_forward));
    vec3 n = normalize(vec3(-gradient.x, 1.0, -gradient.y));
    vec3 to_eye = normalize(CAMERA_POSITION_WORLD - world_position);
    vec3 reflection_direction = reflect(-to_eye, n);
    vec3 reflection = reflected_sky(reflection_direction);

    if (planar_enabled && reflection_mix > 0.001) {
        vec4 projected = reflection_vp * vec4(world_position, 1.0);
        vec2 uv = projected.xy / max(projected.w, 0.0001) * 0.5 + 0.5;
        uv.y = 1.0 - uv.y;
        // Angle-dependent displacement stays bounded near the horizon.
        uv += screen_gradient * vec2(0.10, 0.065);
        float edge = min(min(uv.x, uv.y), min(1.0 - uv.x, 1.0 - uv.y));
        float valid = smoothstep(0.0, 0.025, edge) * step(0.0, projected.w);
        vec3 captured = texture(planar_color, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
        float blur = wind_strength * exposure_to_wind * 1.7;
        if (blur > 0.01) {
            vec2 tap = reflection_texel * blur;
            captured = (captured * 4.0
                + texture(planar_color, clamp(uv + vec2(tap.x, 0.0), vec2(0.001), vec2(0.999))).rgb
                + texture(planar_color, clamp(uv - vec2(tap.x, 0.0), vec2(0.001), vec2(0.999))).rgb
                + texture(planar_color, clamp(uv + vec2(0.0, tap.y), vec2(0.001), vec2(0.999))).rgb
                + texture(planar_color, clamp(uv - vec2(0.0, tap.y), vec2(0.001), vec2(0.999))).rgb) / 8.0;
        }
        reflection = mix(reflection, captured, valid * reflection_mix);
    }

    vec3 transmission = deep_color.rgb;
    float shore_coverage = 1.0;
    if (see_bottom) {
        float z = texture(screen_depth, SCREEN_UV).r;
        vec4 below = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
        below.xyz /= below.w;
        vec3 below_world = (INV_VIEW_MATRIX * vec4(below.xyz, 1.0)).xyz;
        float vertical_depth = max(world_position.y - below_world.y, 0.0);
        float path_length = length(below.xyz - VERTEX);
        bool valid_bottom = z > 0.000001 && below_world.y < world_position.y - 0.002;
        if (valid_bottom) {
            // Reject displaced samples hitting foreground geometry (halos at banks).
            vec2 refract_uv = clamp(SCREEN_UV + screen_gradient * 0.055 * min(vertical_depth * 2.0, 1.0), vec2(0.001), vec2(0.999));
            float rz = texture(screen_depth, refract_uv).r;
            vec4 rp = INV_PROJECTION_MATRIX * vec4(refract_uv * 2.0 - 1.0, rz, 1.0);
            vec3 rw = (INV_VIEW_MATRIX * vec4(rp.xyz / rp.w, 1.0)).xyz;
            if (rw.y >= world_position.y) { refract_uv = SCREEN_UV; }
            vec3 bottom = texture(screen_color, refract_uv).rgb;
            vec3 extinction = vec3(1.15, 0.48, 0.34) * absorption;
            vec3 transmittance = exp(-extinction * min(path_length, 30.0));
            vec3 scattering = mix(shallow_color.rgb, deep_color.rgb, smoothstep(0.4, 5.0, vertical_depth));
            transmission = bottom * transmittance + scattering * (vec3(1.0) - transmittance);
            shore_coverage = smoothstep(0.002, 0.035, vertical_depth);
        } else if (z > 0.000001 && below_world.y >= world_position.y - 0.002) {
            // MSAA depth samples on a bank can belong to the dry side. Preserve
            // the background here instead of drawing a thin cyan outline.
            shore_coverage = 0.0;
        }
    }
    float facing = clamp(dot(n, to_eye), 0.0, 1.0);
    float fresnel = 0.035 + 0.965 * pow(1.0 - facing, 5.0);
    // A small artistic floor keeps the painted sky readable without hiding the bed.
    fresnel = max(fresnel, 0.075);
    ALBEDO = mix(transmission, reflection, fresnel);
    // A single restrained directional glint, not glittering noise over the whole sea.
    vec3 sun_direction = normalize(vec3(0.47, 0.74, 0.47));
    float glint = pow(max(dot(reflection_direction, sun_direction), 0.0), mix(1600.0, 220.0, wind_strength));
    ALBEDO += vec3(1.0, 0.94, 0.82) * glint * 0.20;
    if (shore_coverage < 1.0) {
        ALBEDO = mix(texture(screen_color, SCREEN_UV).rgb, ALBEDO, shore_coverage);
    }
}
