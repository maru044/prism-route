shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D sand_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_macro : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D shore_distance : filter_linear, repeat_disable;
uniform vec4 dry_color : source_color = vec4(0.90,0.835,0.735,1.0);
uniform vec4 wet_color : source_color = vec4(0.73,0.685,0.60,1.0);
uniform float dry_roughness : hint_range(0.5,1.0) = 0.92;
uniform float wet_roughness : hint_range(0.1,0.7) = 0.30;
uniform float detail_strength : hint_range(0.0,0.5) = 0.10;
uniform float macro_strength : hint_range(0.0,0.5) = 0.12;
uniform float wet_width_m : hint_range(1.5,10.0) = 5.5;
uniform vec2 shore_origin;
uniform vec2 shore_extent;
varying vec3 world_position;

void vertex() {
	world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}

void fragment() {
	vec2 detail_uv=world_position.xz/2.0;
	vec3 photo=texture(sand_detail,detail_uv).rgb;
	// source_color samplers return linear RGB. These means were measured in
	// linear space; the old 0.55/0.5 divisors clamped nearly all detail to 0.7.
	float grain=clamp(dot(photo,vec3(0.2126,0.7152,0.0722))/0.1213,0.7,1.3);
	float macro=clamp(1.0+(dot(texture(sand_macro,world_position.xz/30.0).rgb,vec3(0.2126,0.7152,0.0722))/0.2438-1.0)*1.25,0.65,1.35);
	vec2 shore_uv=(world_position.xz-shore_origin)/shore_extent;
	float distance_m=20.0;
	if(all(greaterThanEqual(shore_uv,vec2(0.0))) && all(lessThanEqual(shore_uv,vec2(1.0)))) {
		distance_m=texture(shore_distance,shore_uv).r*20.0;
	}
	// Reuse the macro sample for a small, stable variation in wet-band width.
	distance_m+=clamp((macro-1.0)*2.5,-0.7,0.7);
	float wet=max(1.0-smoothstep(0.9,wet_width_m,distance_m),1.0-smoothstep(-0.12,-0.025,world_position.y));
	ALBEDO=mix(dry_color.rgb,wet_color.rgb,wet)*mix(1.0,grain,detail_strength)*mix(1.0,macro,macro_strength);
	ROUGHNESS=clamp(mix(dry_roughness,wet_roughness,wet)+(texture(sand_roughness,detail_uv).r-0.5)*mix(0.08,0.025,wet),0.22,0.98);
	METALLIC=0.0;
	vec2 normal_xy=texture(sand_normal,detail_uv).xy*2.0-1.0;
	vec3 axis_x=(VIEW_MATRIX*vec4(1.0,0.0,0.0,0.0)).xyz;
	vec3 axis_z=(VIEW_MATRIX*vec4(0.0,0.0,1.0,0.0)).xyz;
	NORMAL=normalize(NORMAL+(axis_x*normal_xy.x+axis_z*normal_xy.y)*mix(0.13,0.035,wet));
}
