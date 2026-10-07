shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
void fragment() {
    vec3 skin = texture(albedo_map,UV).rgb;
    float beard = COLOR.r;
    ALBEDO = mix(skin*vec3(0.98,0.95,0.91),skin*vec3(0.34,0.29,0.25),beard*0.70);
    NORMAL_MAP = texture(normal_map,UV).rgb;
    NORMAL_MAP_DEPTH = 0.11;
    ROUGHNESS = mix(0.53,0.75,beard);
    SPECULAR = 0.32;
}
