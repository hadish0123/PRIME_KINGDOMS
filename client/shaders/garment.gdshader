shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec3 tint : source_color = vec3(0.055,0.062,0.073);

float weave(vec2 uv) {
    return 0.5+0.5*sin(uv.x*760.0)*sin(uv.y*690.0);
}

void fragment() {
    vec3 original = texture(albedo_map,UV).rgb;
    float value = dot(original,vec3(0.2126,0.7152,0.0722));
    float fibers = weave(UV);
    ALBEDO = tint*mix(0.42,1.20,sqrt(value))*mix(0.94,1.05,fibers);
    NORMAL_MAP = texture(normal_map,UV).rgb;
    NORMAL_MAP_DEPTH = 0.64;
    ROUGHNESS = mix(0.80,0.91,fibers);
    SPECULAR = 0.26;
}
