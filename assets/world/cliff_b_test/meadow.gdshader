shader_type spatial;
render_mode diffuse_burley, cull_back;
uniform vec4 green : source_color = vec4(0.42, 0.51, 0.29, 1.0);
uniform vec4 straw : source_color = vec4(0.60, 0.57, 0.35, 1.0);
varying vec3 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float field = sin(world_position.x * 0.018 + sin(world_position.z * 0.021) * 1.4) * 0.55
        + sin(world_position.z * 0.027 - world_position.x * 0.006) * 0.45;
    float grain = sin(world_position.x * 1.67 + sin(world_position.z * 1.93))
        * sin(world_position.z * 1.39);
    ALBEDO = mix(green.rgb, straw.rgb, smoothstep(0.1, 0.75, field) * 0.48) * (0.99 + grain * 0.018);
    ROUGHNESS = 0.96;
    SPECULAR = 0.08;
}
