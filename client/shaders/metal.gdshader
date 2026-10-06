shader_type spatial;
render_mode diffuse_burley, cull_disabled;
uniform vec3 color : source_color = vec3(0.24,0.27,0.29);
uniform float gilded = 0.0;
float grain(vec2 p) { return fract(sin(dot(floor(p),vec2(127.1,311.7))) * 43758.5453); }
void fragment() {
    float attenuation = 1.0-clamp(length(fwidth(UV))*780.0,0.0,1.0);
    float n = mix(0.5,grain(UV * 780.0),attenuation);
    float polish = sin(UV.x * 420.0) * 0.012 * attenuation;
    float border = 1.0-smoothstep(0.012,0.036,min(UV.y,1.0-UV.y));
    float scroll = sin(UV.x*150.0+sin(UV.y*90.0)*2.5)*sin(UV.y*110.0);
    float etch = smoothstep(0.91,0.99,scroll)*(1.0-border)*0.12;
    ALBEDO = color * (0.90+n*0.12+polish-etch);
    METALLIC = mix(0.90,0.94,gilded);
    ROUGHNESS = mix(0.28,0.25,gilded)+n*0.08+etch;
    NORMAL_MAP = vec3(0.5+polish*2.0,0.5+(n-0.5)*0.045*attenuation,1.0);
    NORMAL_MAP_DEPTH = 0.4;
}
