shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform sampler2D ground_field : filter_linear, repeat_disable;
uniform vec4 ground_bounds;
uniform sampler2D sand_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_macro : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 dry_color : source_color = vec4(.90,.835,.735,1.);
uniform vec4 wet_color : source_color = vec4(.73,.685,.60,1.);
uniform float dry_roughness=.92;
uniform float wet_roughness=.30;
uniform float detail_strength=.10;
uniform float macro_strength=.12;
uniform float beach_width=18.;
uniform sampler2D biome_noise_texture : repeat_enable, filter_linear;
uniform float biome_noise_scale=.00135;
uniform float biome_warp_distance=210.;
uniform float biome_transition_half_width=135.;
uniform float biome_center_x=20.;
#include "res://shaders/environment/meadow_zone.gdshaderinc"
uniform vec4 ground_dry : source_color=vec4(.69,.63,.39,1.);
uniform vec4 ground_green : source_color=vec4(.44,.58,.29,1.);
uniform vec4 far_ground_dry : source_color=vec4(.97,.79,.42,1.);
uniform vec4 far_ground_green : source_color=vec4(.41,.69,.25,1.);
uniform vec2 meadow_color_fade=vec2(48.,128.);
varying vec3 world_position;
void vertex() {world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment() {
	vec4 field=texture(ground_field,(world_position.xz-ground_bounds.xy)/ground_bounds.zw);
	float meadow_mix=smoothstep(beach_width-2.,beach_width+2.,field.b);
	float noise_value=texture(biome_noise_texture,world_position.xz*biome_noise_scale+vec2(.137,.411)).r;
	float transition=meadow_green_weight(world_position,noise_value,0.);
	vec3 meadow=mix(ground_dry.rgb,ground_green.rgb,transition);
	float far_mix=smoothstep(meadow_color_fade.x,meadow_color_fade.y,distance(CAMERA_POSITION_WORLD,world_position));
	meadow=mix(meadow,mix(far_ground_dry.rgb,far_ground_green.rgb,transition),far_mix);
	float fine=sin(world_position.x*2.1+sin(world_position.z*1.9))*sin(world_position.z*2.7);
	meadow*=.985+fine*.015;
	vec2 detail_uv=world_position.xz/2.;
	float grain=clamp(dot(texture(sand_detail,detail_uv).rgb,vec3(.2126,.7152,.0722))/.1213,.7,1.3);
	float macro=clamp(1.+(dot(texture(sand_macro,world_position.xz/30.).rgb,vec3(.2126,.7152,.0722))/.2438-1.)*1.25,.65,1.35);
	float wet=1.-smoothstep(.9,5.5,field.b);
	vec3 sand=mix(dry_color.rgb,wet_color.rgb,wet)*mix(1.,grain,detail_strength)*mix(1.,macro,macro_strength);
	ALBEDO=mix(sand,meadow,meadow_mix);
	ROUGHNESS=mix(mix(dry_roughness,wet_roughness,wet)+(texture(sand_roughness,detail_uv).r-.5)*.04,.95,meadow_mix);
	SPECULAR=mix(.35,.08,meadow_mix);METALLIC=0.;
}
