shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, alpha_to_coverage;
uniform sampler2D cluster_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool painted_color=true;
uniform bool parallax_enabled=false;
uniform float parallax_depth_m=.06;
uniform vec4 silhouette_color : source_color=vec4(.4,.733333,.415686,1.);
void vertex() {
    if(parallax_enabled) {
        vec3 to_eye=normalize(MAIN_CAM_INV_VIEW_MATRIX[2].xyz);
        float slope=clamp(to_eye.x/max(abs(to_eye.z),.45),-.8,.8);
        VERTEX+=inverse(mat3(MODEL_MATRIX))*vec3(-slope*parallax_depth_m*INSTANCE_CUSTOM.r,0.,0.);
    }
}
void fragment() {
    vec4 paint=texture(cluster_texture,UV);
    ALBEDO=painted_color?paint.rgb:silhouette_color.rgb;
    ALPHA=paint.a;
    ALPHA_SCISSOR_THRESHOLD=.50;
    ALPHA_ANTIALIASING_EDGE=.35;
    ALPHA_TEXTURE_COORDINATE=UV*vec2(textureSize(cluster_texture,0));
    ROUGHNESS=1.;
}
