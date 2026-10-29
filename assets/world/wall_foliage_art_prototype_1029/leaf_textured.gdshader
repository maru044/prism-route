shader_type spatial;
render_mode diffuse_burley, cull_disabled, depth_draw_opaque, alpha_to_coverage;
uniform sampler2D leaf_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool texture_color_enabled=true;
uniform bool parallax_enabled=true;
uniform bool orthographic_view=true;
uniform float parallax_depth_m : hint_range(0.,.2)=.10;
uniform float fold_height : hint_range(0.,.2)=.08;
uniform vec3 wall_right_world=vec3(1.,0.,0.);
uniform vec3 wall_normal_world=vec3(0.,0.,1.);
uniform vec4 deep_color : source_color=vec4(.219608,.556863,.235294,1.);
uniform vec4 mid_color : source_color=vec4(.4,.733333,.415686,1.);
uniform vec4 light_color : source_color=vec4(.505882,.780392,.517647,1.);
varying flat float atlas_cell;
varying flat float leaf_tone;

void vertex() {
    atlas_cell=INSTANCE_CUSTOM.r;
    leaf_tone=INSTANCE_CUSTOM.b;
    // A few millimetres of ridge, not a uniformly flat card. The quad is split
    // along its middle so both painted planes also have a shallow geometric fold.
    VERTEX.z+=(1.-abs(UV.x*2.-1.))*fold_height;
    NORMAL=normalize(vec3(UV.x<.5?-.10:.10,0.,1.));
    if(parallax_enabled) {
        vec3 center=(MODEL_MATRIX*vec4(0.,0.,0.,1.)).xyz;
        // MAIN_CAM keeps view-dependent displacement consistent in shadow passes.
        vec3 to_eye=orthographic_view?normalize(MAIN_CAM_INV_VIEW_MATRIX[2].xyz):normalize(MAIN_CAM_INV_VIEW_MATRIX[3].xyz-center);
        float slope=clamp(dot(to_eye,wall_right_world)/max(abs(dot(to_eye,wall_normal_world)),.45),-.8,.8);
        float offset=-slope*parallax_depth_m*INSTANCE_CUSTOM.g;
        // Convert WORLD wall-right motion to each rotated/scaled leaf's local
        // coordinates. Every vertex gets the same shift, preserving its shape.
        VERTEX+=inverse(mat3(MODEL_MATRIX))*(wall_right_world*offset);
    }
}

void fragment() {
    int cell=int(atlas_cell+.5);
    vec2 quadrant=vec2(float(cell%2),float(cell/2));
    vec2 half_pixel=.5/vec2(textureSize(leaf_atlas,0));
    vec2 atlas_uv=clamp((quadrant+UV)*.5,quadrant*.5+half_pixel,(quadrant+vec2(1.))*.5-half_pixel);
    vec4 paint=texture(leaf_atlas,atlas_uv);
    vec3 flat_color=leaf_tone<.5?deep_color.rgb:(leaf_tone<1.5?mid_color.rgb:light_color.rgb);
    ALBEDO=texture_color_enabled?paint.rgb*mix(.94,1.06,leaf_tone*.5):flat_color;
    ALPHA=paint.a;
    ALPHA_SCISSOR_THRESHOLD=.50;
    ALPHA_ANTIALIASING_EDGE=.35;
    ALPHA_TEXTURE_COORDINATE=atlas_uv*vec2(textureSize(leaf_atlas,0));
    ROUGHNESS=.95;SPECULAR=.10;
}
