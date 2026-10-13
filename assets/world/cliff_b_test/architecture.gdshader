shader_type spatial;
render_mode diffuse_burley, cull_back;

uniform sampler2D base_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D micro_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 warm_white : source_color = vec4(0.91, 0.895, 0.865, 1.0);
uniform float detail_strength : hint_range(0.0, 1.0) = 0.20;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.14;
uniform float texture_meters = 1.6;
varying vec3 world_position;
varying vec3 world_normal;

vec3 read_base(vec2 uv) {
    // Mirrored sampling makes the generated albedo continuous at tile edges.
    return texture(base_texture, abs(fract(uv * 0.5) * 2.0 - 1.0)).rgb;
}

void vertex() {
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
    METALLIC = 0.0;
    SPECULAR = 0.28;
    vec2 nx = texture(micro_normal, p.zy).rg * 2.0 - 1.0;
    vec2 ny = texture(micro_normal, p.xz).rg * 2.0 - 1.0;
    vec2 nz = texture(micro_normal, p.xy).rg * 2.0 - 1.0;
    vec3 bump = vec3(0.0, nx.y, nx.x) * weights.x
        + vec3(ny.x, 0.0, ny.y) * weights.y
        + vec3(nz.x, nz.y, 0.0) * weights.z;
    bump -= n * dot(n, bump);
    NORMAL = normalize(mat3(VIEW_MATRIX) * normalize(n + bump * normal_strength));
}
