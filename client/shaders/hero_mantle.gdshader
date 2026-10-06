shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec3 tint : source_color = vec3(0.26, 0.32, 0.40);
void fragment() {
    vec3 original = texture(albedo_map, UV).rgb;
    float value = dot(original, vec3(0.2126, 0.7152, 0.0722));
    ALBEDO = tint * mix(0.45, 1.25, sqrt(value));
    NORMAL_MAP = texture(normal_map, UV).rgb;
    NORMAL_MAP_DEPTH = 0.55;
    ROUGHNESS = 0.88;
}
