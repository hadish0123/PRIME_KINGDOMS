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
    float macro = noise(UV * 0.033);
    float fine = noise(UV * 0.24);
    vec2 tile = UV * 0.17;
    vec3 grass = mix(texture(grass_map,tile).rgb,texture(grass_map,vec2(-tile.y,tile.x)*0.73+vec2(0.29,0.57)).rgb,0.48);
    // Rich meadow greens keep the settlement from reading as one flat olive field.
    grass *= mix(vec3(0.48,0.68,0.31),vec3(0.74,0.86,0.49),macro);
    vec2 village_local = UV - village_center;
    float settlement = 1.0 - smoothstep(40.0, 74.0, length(village_local));
    vec3 earth = texture(mud_map, tile).rgb;
    float patch = smoothstep(0.52,0.82,fine*0.42+macro*0.58);
    // Two authored village paths match the clear corridors used by Nature.
    float north_road = 1.0 - smoothstep(2.5,5.0,abs(village_local.x));
    north_road *= 1.0 - smoothstep(58.0,72.0,abs(village_local.y));
    float market_road = 1.0 - smoothstep(2.6,4.6,abs(village_local.y-8.0));
    market_road *= 1.0 - smoothstep(40.0,50.0,abs(village_local.x));
    float road = max(north_road,market_road) * settlement;
    float blend = max(settlement*(0.035+patch*0.12),patch*0.18);
    blend = max(blend,road*0.58);
    ALBEDO = mix(grass, earth, blend);
    NORMAL_MAP = mix(texture(grass_normal, tile).rgb, texture(mud_normal, tile).rgb, blend);
    NORMAL_MAP_DEPTH = 0.55;
    ROUGHNESS = mix(texture(grass_rough, tile).r, texture(mud_rough, tile).r, blend);
    float cliff = smoothstep(0.10,0.39,1.0-terrain_normal.y);
    ALBEDO = mix(ALBEDO,texture(rock_map,UV*0.19).rgb * vec3(0.67,0.68,0.65),cliff);
    NORMAL_MAP = mix(NORMAL_MAP,texture(rock_normal,UV*0.19).rgb,cliff);
    float snow = smoothstep(550.0,720.0,terrain_world.y+global_origin.y) * smoothstep(0.48,0.86,terrain_normal.y);
    snow *= smoothstep(0.20,0.65,noise(UV*0.035));
    ALBEDO = mix(ALBEDO,vec3(0.80,0.86,0.90),snow);
    ROUGHNESS = mix(ROUGHNESS,0.96,snow);
}
