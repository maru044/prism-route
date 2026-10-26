shader_type spatial;
render_mode cull_disabled, shadows_disabled;
uniform vec4 base_color : source_color = vec4(0.91, 0.895, 0.865, 1.0);
uniform sampler2D leaf_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform bool leaf_cutout = false;
uniform float water_level = 0.0;
varying float world_y;
void vertex() { world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y; }
void fragment() {
    // Actual clip in reflection-only geometry: no near-plane approximation.
    if (world_y < water_level + 0.003) { discard; }
    if (leaf_cutout && texture(leaf_texture, UV).a < 0.45) { discard; }
    ALBEDO = base_color.rgb;
    ROUGHNESS = 0.95;
    SPECULAR = 0.0;
}
