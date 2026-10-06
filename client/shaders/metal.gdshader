shader_type spatial;
render_mode diffuse_burley;
uniform vec3 color : source_color = vec3(0.24,0.27,0.29);
uniform float gilded = 0.0;
float grain(vec2 p) { return fract(sin(dot(floor(p),vec2(127.1,311.7))) * 43758.5453); }
void fragment() {
    float attenuation = 1.0-clamp(length(fwidth(UV))*780.0,0.0,1.0);
    float n = mix(0.5,grain(UV * 780.0),attenuation);
    float polish = sin(UV.x * 420.0) * 0.012 * attenuation;
    ALBEDO = color * (0.93+n*0.08+polish);
    METALLIC = mix(0.68,0.88,gilded);
    ROUGHNESS = mix(0.35,0.32,gilded) + n * 0.045;
}
