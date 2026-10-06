shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D soil_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_rough : filter_linear_mipmap;
uniform sampler2D stone_map : source_color, filter_linear_mipmap_anisotropic;
varying vec2 world_uv;
varying vec2 patch;
uniform vec2 half_size = vec2(4.0,56.0);
uniform bool round_patch = false;
void vertex() {
    world_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * 0.30;
    patch = VERTEX.xz / half_size;
}
void fragment() {
    float distance_edge = round_patch ? length(patch) : max(abs(patch.x),abs(patch.y));
    float erosion = sin(world_uv.x * 2.7) * sin(world_uv.y * 3.2) * 0.026;
    ALPHA = 1.0-smoothstep(0.88+erosion,1.0+erosion,distance_edge);
    ALPHA_SCISSOR_THRESHOLD = 0.45;
    ALBEDO = mix(texture(soil_map, world_uv).rgb, texture(stone_map, world_uv).rgb, 0.20) * vec3(0.76,0.72,0.61);
    NORMAL_MAP = texture(soil_normal, world_uv).rgb;
    NORMAL_MAP_DEPTH = 0.7;
    ROUGHNESS = texture(soil_rough, world_uv).r;
}
