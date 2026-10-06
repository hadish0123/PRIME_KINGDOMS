shader_type spatial;
render_mode diffuse_burley;
uniform vec2 village_center;
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
    float b = fract(sin(dot(i + vec2(1,0), vec2(127.1, 311.7))) * 43758.5453);
    float c = fract(sin(dot(i + vec2(0,1), vec2(127.1, 311.7))) * 43758.5453);
    float d = fract(sin(dot(i + vec2(1,1), vec2(127.1, 311.7))) * 43758.5453);
    return mix(mix(a,b,f.x), mix(c,d,f.x), f.y);
}
void fragment() {
    float macro = noise(UV * 0.023);
    float micro = noise(UV * 3.0) * 0.07;
    vec3 grass = mix(vec3(0.18,0.26,0.13), vec3(0.36,0.40,0.20), macro) + micro;
    float settlement = 1.0 - smoothstep(43.0, 76.0, distance(UV, village_center));
    vec3 earth = mix(vec3(0.34,0.28,0.19), vec3(0.48,0.41,0.29), noise(UV * 0.5));
    ALBEDO = mix(grass, earth, settlement * 0.55);
    ROUGHNESS = 0.95;
}
