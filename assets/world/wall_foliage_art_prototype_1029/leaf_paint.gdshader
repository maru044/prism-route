shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 deep_color : source_color=vec4(.219608,.556863,.235294,1.);
uniform vec4 mid_color : source_color=vec4(.4,.733333,.415686,1.);
uniform vec4 light_color : source_color=vec4(.505882,.780392,.517647,1.);
varying flat float leaf_tone;
void vertex() {leaf_tone=INSTANCE_CUSTOM.r;}
void fragment() {
    ALBEDO=leaf_tone<.5?deep_color.rgb:(leaf_tone<1.5?mid_color.rgb:light_color.rgb);
    ROUGHNESS=1.;
}
