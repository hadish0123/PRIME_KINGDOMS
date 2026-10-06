shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D needles : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D mask : filter_linear_mipmap;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap;
varying float variation;
void vertex() {
    vec3 world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    variation = INSTANCE_CUSTOM.r;
    VERTEX.x += sin(TIME * 1.45 + world.x * 0.17 + world.z * 0.11) * UV.y * 0.045;
    VERTEX.z += sin(TIME * 2.1 + world.z * 0.21) * UV.y * 0.026;
}
void fragment() {
    // The source is an atlas; sample the photographed twig, excluding the cones.
    vec2 twig_uv = vec2(mix(0.008,0.234,UV.x),mix(0.008,0.468,UV.y));
    ALBEDO = texture(needles,twig_uv).rgb * mix(vec3(0.64,0.78,0.53),vec3(0.95,1.04,0.78),variation);
    ALPHA = texture(mask,twig_uv).r;
    ALPHA_SCISSOR_THRESHOLD = 0.42;
    NORMAL_MAP = texture(normal_map,twig_uv).rgb;
    NORMAL_MAP_DEPTH = 0.32;
    ROUGHNESS = 0.92;
    BACKLIGHT = vec3(0.17,0.22,0.08);
}
