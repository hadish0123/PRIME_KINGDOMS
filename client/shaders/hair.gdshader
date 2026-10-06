shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 tint : source_color = vec3(0.12,0.075,0.042);
void fragment() {
    vec4 strand = texture(albedo_map,UV);
    float detail = dot(strand.rgb,vec3(0.55,0.30,0.15));
    ALBEDO = tint*(0.55+detail*1.1);
    ALPHA = strand.a;
    ALPHA_SCISSOR_THRESHOLD = 0.18;
    ROUGHNESS = 0.71;
    SPECULAR = 0.28;
}
