shader_type spatial;
render_mode diffuse_burley, cull_back;
uniform sampler2D base_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D micro_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D seam_mask : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D foliage_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 warm_white : source_color=vec4(.91,.895,.865,1.);
uniform float detail_strength=.20;
uniform float normal_strength=.14;
uniform float texture_meters=1.6;
// Opt-in only for the reversible V6 trial; all legacy materials default unchanged.
uniform float macro_strength=0.0;
uniform float macro_meters=8.0;
uniform float weather_strength=0.0;
uniform float weather_top_y=6.3;
float macro_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float macro_noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(macro_hash(i),macro_hash(i+vec2(1.,0.)),f.x),mix(macro_hash(i+vec2(0.,1.)),macro_hash(i+vec2(1.,1.)),f.x),f.y);}
uniform bool joints_enabled=true;
uniform bool plants_enabled=true;
uniform float joint_strength : hint_range(0.,1.)=.48;
uniform float joint_width : hint_range(.003,.03)=.010;
uniform vec2 panel_meters=vec2(3.,2.5);
uniform float seam_repeat_meters=2.2;
uniform vec4 joint_color : source_color=vec4(.38,.37,.33,1.);
uniform vec3 mapping_origin=vec3(0.);
uniform vec3 mapping_right=vec3(1.,0.,0.);
uniform vec3 mapping_up=vec3(0.,1.,0.);
uniform vec3 mapping_forward=vec3(0.,0.,1.);
uniform float plant_strength : hint_range(0.,1.)=1.;
// Shape comes only from alpha. The project's palette paints every leaf.
uniform vec4 plant_color : source_color=vec4(.4,.733333,.415686,1.);
uniform float leaf_alpha_cutoff : hint_range(0.,1.)=.42;
// Rectangles use generated building coordinates (u minimum, v minimum, width, height).
uniform vec4 plant_rects[4];
uniform bool diagnostic_background=false;
// Runtime-only trial distribution. Default false preserves the isolated art lab.
uniform bool procedural_plants=false;
uniform float plant_density : hint_range(0.,1.)=.72;
uniform float plant_seed=17.;
uniform vec2 plant_tile_meters=vec2(14.,12.);
uniform vec2 plant_cluster_meters=vec2(7.,7.);
uniform float plant_overlap : hint_range(0.,1.)=.65;
uniform float plant_loose_leaves : hint_range(0.,1.)=1.;
uniform float plant_draw_distance=300.;
uniform vec3 plant_region_min=vec3(-100000.);
uniform vec3 plant_region_max=vec3(100000.);
varying vec3 world_position;
varying vec3 world_normal;
vec3 read_base(vec2 p){return texture(base_texture,abs(fract(p*.5)*2.-1.)).rgb;}
float mirror_coordinate(float p){return abs(fract(p*.5)*2.-1.);}
float seam_line(float distance_to_line,float along_line,float coordinate_width){
    // Derivatives of the wrapped distance spike at the middle of every panel.
    // Take the footprint from the continuous coordinate, before mod().
    float aa=max(coordinate_width,.0002);
    float core=1.-smoothstep(joint_width*.5,joint_width*.5+aa,abs(distance_to_line));
    vec2 generated_uv=vec2(.5+distance_to_line/.65,mirror_coordinate(along_line/seam_repeat_meters));
    float band=1.-smoothstep(.28,.325,abs(distance_to_line));
    float wear=texture(seam_mask,clamp(generated_uv,vec2(0.),vec2(1.))).r*band;
    return max(core*.62,wear);
}
vec4 atlas_leaf(vec2 local,int cell) {
    float inside=step(0.,local.x)*step(local.x,1.)*step(0.,local.y)*step(local.y,1.);
    local.y=1.-local.y;
    vec2 quadrant=vec2(float(cell%2),float(cell/2));
    vec2 half_pixel=.5/vec2(textureSize(foliage_atlas,0));
    vec2 atlas_uv=(quadrant+clamp(local,vec2(0.),vec2(1.)))*.5;
    atlas_uv=clamp(atlas_uv,quadrant*.5+half_pixel,(quadrant+vec2(1.))*.5-half_pixel);
    float alpha=texture(foliage_atlas,atlas_uv).a;
    alpha=smoothstep(leaf_alpha_cutoff-.06,leaf_alpha_cutoff+.06,alpha)*inside*plant_strength;
    return vec4(plant_color.rgb,alpha);
}
vec4 plant_sample(vec2 surface_coordinate,int cell) {
    vec4 rect=plant_rects[cell];
    if(rect.z<=0.||rect.w<=0.)return vec4(0.);
    float size=max(rect.z,rect.w);
    return atlas_leaf((surface_coordinate-(rect.xy+rect.zw*.5))/size+vec2(.5),cell);
}
float patch_hash(vec2 cell) {
    return fract(sin(dot(cell+vec2(plant_seed*.37,plant_seed*.71),vec2(127.1,311.7)))*43758.5453);
}
vec2 rotate_leaf(vec2 p,float angle) {
    float c=cos(angle);float s=sin(angle);
    return vec2(c*p.x-s*p.y,s*p.x+c*p.y);
}
vec4 merge_leaves(vec4 underneath,vec4 above) {
    float alpha=underneath.a+above.a*(1.-underneath.a);
    vec3 premultiplied=above.rgb*above.a+underneath.rgb*underneath.a*(1.-above.a);
    return vec4(premultiplied/max(alpha,.00001),alpha);
}
vec4 cluster_stamp(vec2 coordinate,vec2 anchor,vec2 key,float size) {
    if(length(coordinate-anchor)>size*.708)return vec4(0.);
    vec2 local=rotate_leaf((coordinate-anchor)/size,(patch_hash(key+vec2(28.1,8.7))-.5)*2.4);
    if(patch_hash(key+vec2(12.2,33.7))>.5)local.x=-local.x;
    int cell=int(floor(patch_hash(key+vec2(7.3,2.7))*4.));
    vec4 leaf=atlas_leaf(local+vec2(.5),cell);
    leaf.rgb*=mix(.91,1.07,patch_hash(key+vec2(5.7,52.1)));
    return leaf;
}
vec4 loose_leaf(vec2 coordinate,vec2 anchor,vec2 key,float scale,vec2 footprint) {
    // Two intersecting discs form one pointed, flat-painted blade. No stem.
    vec2 local=rotate_leaf((coordinate-anchor)/scale,patch_hash(key+vec2(9.1,18.4))*6.2831853);
    if(abs(local.x)>.51||abs(local.y)>1.)return vec4(0.);
    float edge=max(length(local-vec2(.72,0.)),length(local+vec2(.72,0.)))-1.22;
    float aa=max(max(footprint.x,footprint.y)*.5,.0001)/scale;
    float alpha=(1.-smoothstep(-aa,aa,edge))*plant_strength;
    return vec4(plant_color.rgb*mix(.86,1.12,patch_hash(key+vec2(21.7,6.3))),alpha);
}
vec4 procedural_leaf(vec2 coordinate,vec2 footprint) {
    if(plant_density<=0.||plant_strength<=0.)return vec4(0.);
    vec2 tile_size=max(plant_tile_meters,vec2(.1));
    // A square stamp always preserves the atlas proportions, regardless of cell.
    float base_size=min(min(plant_cluster_meters.x,plant_cluster_meters.y),min(tile_size.x,tile_size.y)*.85);
    vec2 tile=floor(coordinate/tile_size);
    vec4 result=vec4(0.);
    // Include neighbouring cells so rotations, offsets and overlaps never clip
    // to the invisible distribution grid. The radius bound fits this 3x3 search.
    for(int y=-1;y<=1;y++) {
        for(int x=-1;x<=1;x++) {
            vec2 key=tile+vec2(float(x),float(y));
            float local_density=mix(.62,1.,patch_hash(floor(key/3.)+vec2(31.5,14.9)));
            if(patch_hash(key)>plant_density*local_density)continue;
            vec2 jitter=vec2(patch_hash(key+vec2(1.7,9.2)),patch_hash(key+vec2(16.3,4.8)));
            vec2 anchor=(key+vec2(.15)+jitter*.7)*tile_size;
            vec2 delta=coordinate-anchor;
            if(dot(delta,delta)>base_size*base_size*1.3689)continue;
            float size=base_size*mix(.65,1.18,patch_hash(key+vec2(19.7,41.3)));
            result=merge_leaves(result,cluster_stamp(coordinate,anchor,key,size));
            if(patch_hash(key+vec2(51.3,20.1))<plant_overlap) {
                vec2 offset=vec2(patch_hash(key+vec2(41.2,53.8)),patch_hash(key+vec2(6.8,43.7)))-vec2(.5);
                result=merge_leaves(result,cluster_stamp(coordinate,anchor+offset*base_size*.65,key+vec2(72.1,16.9),size*.83));
            }
            for(int blade=0;blade<8;blade++) {
                vec2 blade_key=key+vec2(float(blade)*13.17+108.3,37.7);
                if(patch_hash(blade_key+vec2(3.1,11.7))>plant_loose_leaves)continue;
                vec2 offset=vec2(patch_hash(blade_key),patch_hash(blade_key+vec2(42.3,8.9)))-vec2(.5);
                vec2 position=anchor+offset*base_size*1.04;
                float scale=base_size*mix(.025,.05,patch_hash(blade_key+vec2(4.9,31.1)));
                result=merge_leaves(result,loose_leaf(coordinate,position,blade_key,scale,footprint));
            }
        }
    }
    return result;
}
void vertex() {world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment() {
    vec3 n=normalize(world_normal);
    vec3 weights=pow(abs(n),vec3(8.));weights/=max(dot(weights,vec3(1.)),.0001);
    vec3 p=world_position/texture_meters;
    vec3 base=read_base(p.zy)*weights.x+read_base(p.xz)*weights.y+read_base(p.xy)*weights.z;
    ALBEDO=warm_white.rgb*mix(vec3(1.),clamp(base/vec3(.85),vec3(.75),vec3(1.12)),detail_strength);
    ROUGHNESS=texture(roughness_texture,p.zy).r*weights.x+texture(roughness_texture,p.xz).r*weights.y+texture(roughness_texture,p.xy).r*weights.z;
    METALLIC=0.;SPECULAR=.28;
    vec2 nx=texture(micro_normal,p.zy).rg*2.-1.;vec2 ny=texture(micro_normal,p.xz).rg*2.-1.;vec2 nz=texture(micro_normal,p.xy).rg*2.-1.;
    vec3 bump=vec3(0.,nx.y,nx.x)*weights.x+vec3(ny.x,0.,ny.y)*weights.y+vec3(nz.x,nz.y,0.)*weights.z;
    bump-=n*dot(n,bump);
    NORMAL=normalize(mat3(VIEW_MATRIX)*normalize(n+bump*normal_strength));
    vec3 relative=world_position-mapping_origin;
    vec3 local_position=vec3(dot(relative,mapping_right),dot(relative,mapping_up),dot(relative,mapping_forward));
    vec3 local_normal=vec3(dot(n,mapping_right),dot(n,mapping_up),dot(n,mapping_forward));
    // Dominant-axis projection preserves directional joints/leaf shapes at corners.
    vec2 surface_coordinate=abs(local_normal.z)>=abs(local_normal.x)?local_position.xy:local_position.zy;
    if(abs(local_normal.y)>.7)surface_coordinate=local_position.xz;
    vec2 footprint=fwidth(surface_coordinate);
    float broad=macro_noise(surface_coordinate/max(macro_meters,.1));
    ALBEDO*=1.+(broad-.5)*macro_strength;
    float below=max(0.,weather_top_y-world_position.y);
    float runoff=smoothstep(.67,.86,macro_noise(vec2(surface_coordinate.x*.7,0.)))*exp(-below/1.2)*step(world_position.y,weather_top_y);
    ALBEDO=mix(ALBEDO,ALBEDO*vec3(.86,.81,.71),runoff*weather_strength*step(abs(local_normal.y),.45));
    if(diagnostic_background)ALBEDO=mix(vec3(.028,.045,.065),vec3(.94,.93,.87),step(0.,surface_coordinate.x));
    if(joints_enabled){
        vec2 nearest=mod(surface_coordinate+panel_meters*.5,panel_meters)-panel_meters*.5;
        float seam=max(seam_line(nearest.x,surface_coordinate.y,footprint.x),seam_line(nearest.y,surface_coordinate.x,footprint.y));
        ALBEDO=mix(ALBEDO,joint_color.rgb,seam*joint_strength);
    }
    if(plants_enabled&&abs(local_normal.y)<.45) {
        vec4 foliage=vec4(0.);
        if(procedural_plants) {
            bool region=world_position.x>=plant_region_min.x&&world_position.y>=plant_region_min.y&&world_position.z>=plant_region_min.z&&world_position.x<=plant_region_max.x&&world_position.y<=plant_region_max.y&&world_position.z<=plant_region_max.z;
            float fade=1.-smoothstep(plant_draw_distance*.8,plant_draw_distance,distance(world_position,CAMERA_POSITION_WORLD));
            if(region&&fade>0.) {
                foliage=procedural_leaf(surface_coordinate,footprint);
                foliage.a*=fade;
            }
        } else {
            for(int i=0;i<4;i++) {
                vec4 next=plant_sample(surface_coordinate,i);
                foliage.rgb=next.rgb;
                foliage.a=1.-(1.-foliage.a)*(1.-next.a);
            }
        }
        ALBEDO=mix(ALBEDO,foliage.rgb,foliage.a);
        ROUGHNESS=mix(ROUGHNESS,.9,foliage.a);
        NORMAL=normalize(mix(NORMAL,normalize(mat3(VIEW_MATRIX)*n),foliage.a));
    }
}
