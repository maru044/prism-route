shader_type spatial;
render_mode diffuse_burley, cull_back;

// Feature-local variation; the world's shared architecture shader stays intact.
uniform sampler2D base_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D micro_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D aged_concrete : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 warm_white : source_color = vec4(0.9,0.875,0.81,1.0);
uniform float wear_strength = 0.65;
uniform float material_role = 0.0; // 0 roof, 1 wall, 2 stone/cut concrete
uniform float normal_strength = 0.18;
uniform float texture_meters = 1.6;
varying vec3 world_position;
varying vec3 world_normal;

float hash21(vec2 p) {
    return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
float noise2(vec2 p) {
    vec2 i=floor(p),f=fract(p);
    f=f*f*(3.0-2.0*f);
    return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),
               mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
vec2 mirrored(vec2 uv) { return abs(fract(uv*0.5)*2.0-1.0); }
vec3 age(vec2 uv) { return texture(aged_concrete,mirrored(uv)).rgb; }

void vertex() {
    world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}

void fragment() {
    vec3 n=normalize(world_normal);
    vec3 weights=pow(abs(n),vec3(8.0));
    weights/=max(dot(weights,vec3(1.0)),0.0001);
    vec3 p=world_position/texture_meters;
    vec3 fine=texture(base_texture,mirrored(p.zy)).rgb*weights.x
             +texture(base_texture,mirrored(p.xz)).rgb*weights.y
             +texture(base_texture,mirrored(p.xy)).rgb*weights.z;
    // Painted medium-scale erosion plus broad rain/mineral variation.
    vec3 a=world_position/5.2;
    vec3 worn=age(a.zy)*weights.x+age(a.xz)*weights.y+age(a.xy)*weights.z;
    vec3 paint=clamp(worn/vec3(0.87,0.85,0.80),vec3(0.62),vec3(1.08));
    float vertical=1.0-smoothstep(0.25,0.75,abs(n.y));
    float broad=noise2(world_position.xz*0.19+vec2(world_position.y*.08));
    float streak=smoothstep(.52,.84,noise2(vec2((world_position.x+world_position.z)*1.4,world_position.y*.12)));
    float base_band=(1.0-smoothstep(.18,1.05,world_position.y))*vertical;
    float rain=streak*vertical*smoothstep(1.1,3.6,world_position.y)*0.10;
    vec3 color=warm_white.rgb*mix(vec3(1.0),paint,wear_strength);
    color*=mix(vec3(1.0),clamp(fine/vec3(.85),vec3(.80),vec3(1.10)),.22);
    color*=1.0-wear_strength*(broad*.055+rain);
    color=mix(color,color*vec3(.76,.79,.72),base_band*wear_strength*.48);
    // Coarse cut surfaces stay distinct from painted walls at viewing distance.
    float cut=step(1.5,material_role);
    ALBEDO=color*(1.0-cut*broad*.09);
    float rough=texture(roughness_texture,p.zy).r*weights.x
               +texture(roughness_texture,p.xz).r*weights.y
               +texture(roughness_texture,p.xy).r*weights.z;
    ROUGHNESS=clamp(mix(rough,.94,.45+cut*.20),.68,1.0);
    METALLIC=0.0;
    SPECULAR=.22;
    vec2 nx=texture(micro_normal,p.zy).rg*2.0-1.0;
    vec2 ny=texture(micro_normal,p.xz).rg*2.0-1.0;
    vec2 nz=texture(micro_normal,p.xy).rg*2.0-1.0;
    vec3 bump=vec3(0,nx.y,nx.x)*weights.x+vec3(ny.x,0,ny.y)*weights.y+vec3(nz.x,nz.y,0)*weights.z;
    bump-=n*dot(n,bump);
    NORMAL=normalize(mat3(VIEW_MATRIX)*normalize(n+bump*normal_strength*(1.0+cut*.6)));
}
