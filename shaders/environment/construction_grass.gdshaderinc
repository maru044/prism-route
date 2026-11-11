// Runtime presentation cut, independent of immutable root bake/signature.
uniform bool construction_grass_enabled=false;
uniform sampler2D construction_mask_a : filter_nearest, repeat_disable;
uniform sampler2D construction_mask_b : filter_nearest, repeat_disable;
uniform mat4 construction_inverse_a;
uniform mat4 construction_inverse_b;
bool construction_grass_cut(vec3 root) {
    if (!construction_grass_enabled) { return false; }
    vec3 a=(construction_inverse_a*vec4(root,1.0)).xyz;
    vec3 b=(construction_inverse_b*vec4(root,1.0)).xyz;
    if (abs(a.y)<0.65 && all(greaterThanEqual(a.xz,vec2(0.0))) && all(lessThan(a.xz,vec2(60.0)))) {
        if (textureLod(construction_mask_a,a.xz/60.0,0.0).r>0.5) { return true; }
    }
    if (abs(b.y)<0.65 && all(greaterThanEqual(b.xz,vec2(0.0))) && all(lessThan(b.xz,vec2(60.0)))) {
        if (textureLod(construction_mask_b,b.xz/60.0,0.0).r>0.5) { return true; }
    }
    return false;
}
