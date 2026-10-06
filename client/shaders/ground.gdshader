shader_type spatial;
render_mode diffuse_burley;
uniform vec2 village_center;
uniform vec3 global_origin;
uniform bool far_surface = false;
uniform sampler2D grass_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_rough : filter_linear_mipmap;
uniform sampler2D mud_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D mud_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D mud_rough : filter_linear_mipmap;
uniform sampler2D rock_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D rock_rough : filter_linear_mipmap;
varying vec3 terrain_world;
varying vec3 terrain_normal;
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
    float b = fract(sin(dot(i + vec2(1,0), vec2(127.1, 311.7))) * 43758.5453);
    float c = fract(sin(dot(i + vec2(0,1), vec2(127.1, 311.7))) * 43758.5453);
    float d = fract(sin(dot(i + vec2(1,1), vec2(127.1, 311.7))) * 43758.5453);
    return mix(mix(a,b,f.x), mix(c,d,f.x), f.y);
}
void vertex() {
    terrain_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    terrain_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
    if (far_surface && distance(terrain_world.xz,CAMERA_POSITION_WORLD.xz) < 590.0) { discard; }
    float macro = noise(UV * 0.023);
    vec2 tile = UV * 0.25;
    vec3 grass = mix(texture(grass_map,tile).rgb * vec3(0.64,0.78,0.46),vec3(0.095,0.13,0.044),0.35) * mix(0.72,1.04,macro);
    float settlement = 1.0 - smoothstep(43.0, 76.0, distance(UV, village_center));
    vec3 earth = texture(mud_map, tile).rgb;
    float blend = settlement * 0.18;
    ALBEDO = mix(grass, earth, blend);
    NORMAL_MAP = mix(texture(grass_normal, tile).rgb, texture(mud_normal, tile).rgb, blend);
    NORMAL_MAP_DEPTH = 0.65;
    ROUGHNESS = mix(texture(grass_rough, tile).r, texture(mud_rough, tile).r, blend);
    float cliff = smoothstep(0.10,0.39,1.0-terrain_normal.y);
    ALBEDO = mix(ALBEDO,texture(rock_map,UV*0.055).rgb * vec3(0.37,0.42,0.46),cliff);
    NORMAL_MAP = mix(NORMAL_MAP,texture(rock_normal,UV*0.055).rgb,cliff);
    float snow = smoothstep(550.0,720.0,terrain_world.y+global_origin.y) * smoothstep(0.48,0.86,terrain_normal.y);
    snow *= smoothstep(0.20,0.65,noise(UV*0.035));
    ALBEDO = mix(ALBEDO,vec3(0.80,0.86,0.90),snow);
    ROUGHNESS = mix(ROUGHNESS,0.96,snow);
}
