shader_type spatial;
render_mode diffuse_burley;
uniform vec2 village_center;
uniform sampler2D grass_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_rough : filter_linear_mipmap;
uniform sampler2D mud_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D mud_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D mud_rough : filter_linear_mipmap;
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
    vec2 tile = UV * 0.25;
    vec3 grass = texture(grass_map, tile).rgb * mix(vec3(0.72,0.75,0.61), vec3(0.93,0.92,0.79), macro);
    float settlement = 1.0 - smoothstep(43.0, 76.0, distance(UV, village_center));
    vec3 earth = texture(mud_map, tile).rgb;
    float blend = settlement * 0.65;
    ALBEDO = mix(grass, earth, blend);
    NORMAL_MAP = mix(texture(grass_normal, tile).rgb, texture(mud_normal, tile).rgb, blend);
    NORMAL_MAP_DEPTH = 0.65;
    ROUGHNESS = mix(texture(grass_rough, tile).r, texture(mud_rough, tile).r, blend);
}
