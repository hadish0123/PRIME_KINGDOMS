shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
void fragment() {
    vec3 skin = texture(albedo_map,UV).rgb;
    float beard = COLOR.r;
    ALBEDO = mix(skin*vec3(0.91,0.86,0.79),skin*vec3(0.32,0.25,0.21),beard*0.75);
    NORMAL_MAP = texture(normal_map,UV).rgb;
    NORMAL_MAP_DEPTH = 0.18;
    ROUGHNESS = mix(0.59,0.83,beard);
    SPECULAR = 0.26;
}
