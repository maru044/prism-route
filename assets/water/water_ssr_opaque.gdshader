shader_type spatial;
render_mode cull_back;
// Deliberately separate: no screen/depth sampling or ALPHA, so native SSR
// can be tested without silently switching this material to transparency.
uniform vec4 deep_color : source_color = vec4(0.075, 0.36, 0.46, 1.0);
void fragment() {
    ALBEDO = deep_color.rgb * 0.10;
    METALLIC = 0.0;
    SPECULAR = 0.5;
    ROUGHNESS = 0.025;
}
