shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(0.22, 0.35, 0.51, 1.0);
uniform bool vertical = false;
void vertex() {
    float free_edge = UV.y * UV.y;
    float wave = free_edge * (0.035 * sin(TIME * 2.7 + UV.x * 4.0) + 0.016 * sin(TIME * 5.1 + UV.y * 5.0));
    if (vertical) { VERTEX.z += wave; } else { VERTEX.y += wave; }
    VERTEX.x += free_edge * 0.018 * sin(TIME * 2.2 + UV.y * 4.0);
}
void fragment() {
    ALBEDO = texture(albedo_map, UV * 6.0).rgb * tint.rgb;
    ROUGHNESS = 0.93;
}
