shader_type spatial;
render_mode diffuse_burley, cull_back;
uniform vec4 base_color : source_color = vec4(0.8);
uniform sampler2D micro_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float base_roughness = 0.8;
uniform float metallic_amount = 0.0;
uniform float specular_amount = 0.4;
uniform float normal_strength = 0.04;
uniform float roughness_variation = 0.08;
uniform float clearcoat_amount = 0.0;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    vec3 n = normalize(world_normal);
    vec3 w = pow(abs(n), vec3(8.0));
    w /= max(dot(w, vec3(1.0)), 0.0001);
    vec3 p = world_position / 2.2;
    float grain = texture(roughness_texture,p.zy).r*w.x + texture(roughness_texture,p.xz).r*w.y + texture(roughness_texture,p.xy).r*w.z;
    ALBEDO = base_color.rgb;
    ROUGHNESS = clamp(base_roughness+(grain-0.5)*roughness_variation,0.03,1.0);
    METALLIC = metallic_amount;
    SPECULAR = specular_amount;
    CLEARCOAT = clearcoat_amount;
    CLEARCOAT_ROUGHNESS = 0.3;
    vec2 nx=texture(micro_normal,p.zy).rg*2.0-1.0;
    vec2 ny=texture(micro_normal,p.xz).rg*2.0-1.0;
    vec2 nz=texture(micro_normal,p.xy).rg*2.0-1.0;
    vec3 bump=vec3(0.0,nx.y,nx.x)*w.x+vec3(ny.x,0.0,ny.y)*w.y+vec3(nz.x,nz.y,0.0)*w.z;
    bump-=n*dot(n,bump);
    NORMAL=normalize(mat3(VIEW_MATRIX)*normalize(n+bump*normal_strength));
}
