shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 tint : source_color = vec3(0.66,0.54,0.40);
void fragment() {
    vec4 strand = texture(albedo_map,UV);
    float detail = dot(strand.rgb,vec3(0.55,0.30,0.15));
    ALBEDO = strand.rgb*tint;
    ALPHA = strand.a;
    ALPHA_SCISSOR_THRESHOLD = 0.18;
    float fade = 1.0-smoothstep(0.15,0.65,length(fwidth(UV))*800.0);
    float fiber = sin(UV.x*1800.0+sin(UV.y*19.0)*0.8)*fade;
    NORMAL_MAP = vec3(0.5+fiber*0.045,0.5,1.0);
    NORMAL_MAP_DEPTH = 0.25;
    ROUGHNESS = 0.70+detail*0.12;
    SPECULAR = 0.18;
}
