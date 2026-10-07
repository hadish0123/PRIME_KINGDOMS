shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec3 tint : source_color = vec3(0.26, 0.32, 0.40);
uniform bool empire_enabled = false;
uniform vec4 empire_primary : source_color = vec4(0.5,0.1,0.1,1.0);
uniform vec4 empire_secondary : source_color = vec4(0.8,0.65,0.3,1.0);
uniform sampler2D emblem_mask : filter_linear_mipmap;
void fragment() {
    vec3 original = texture(albedo_map, UV).rgb;
    float value = dot(original, vec3(0.2126, 0.7152, 0.0722));
    ALBEDO = tint * mix(0.45, 1.25, sqrt(value));
    NORMAL_MAP = texture(normal_map, UV).rgb;
    NORMAL_MAP_DEPTH = 0.55;
    ROUGHNESS = 0.88;
    if (empire_enabled) {
        float grain = 0.84 + 0.08*sin(UV.x*1700.0)*sin(UV.y*1350.0);
        ALBEDO = empire_primary.rgb * grain;
        vec2 emblem_uv = (UV-vec2(0.5,0.42))*vec2(2.2,2.4)+vec2(0.5);
        float inside = step(0.0,emblem_uv.x)*step(emblem_uv.x,1.0)*step(0.0,emblem_uv.y)*step(emblem_uv.y,1.0);
        float mask = texture(emblem_mask,clamp(emblem_uv,vec2(0.0),vec2(1.0))).a*inside;
        float trim = 1.0-smoothstep(0.01,0.025,min(UV.x,1.0-UV.x));
        ALBEDO = mix(ALBEDO,empire_secondary.rgb,max(mask,trim));
    }
}
