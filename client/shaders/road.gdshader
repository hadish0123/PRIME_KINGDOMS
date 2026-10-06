shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D soil_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_rough : filter_linear_mipmap;
uniform sampler2D stone_map : source_color, filter_linear_mipmap_anisotropic;
varying vec2 world_uv;
void vertex() { world_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * 0.30; }
void fragment() {
    ALBEDO = mix(texture(soil_map, world_uv).rgb, texture(stone_map, world_uv).rgb, 0.38) * vec3(0.91,0.86,0.75);
    NORMAL_MAP = texture(soil_normal, world_uv).rgb;
    NORMAL_MAP_DEPTH = 0.7;
    ROUGHNESS = texture(soil_rough, world_uv).r;
}
