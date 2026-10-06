shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D soil_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D soil_rough : filter_linear_mipmap;
uniform sampler2D stone_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D height_map : filter_linear_mipmap_anisotropic;
varying vec2 world_uv;
varying vec2 patch;
uniform vec2 half_size = vec2(4.0,56.0);
uniform bool round_patch = false;
void vertex() {
    world_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * 0.72;
    patch = VERTEX.xz / half_size;
}
void fragment() {
    float distance_edge = round_patch ? length(patch) : max(abs(patch.x),abs(patch.y));
    float erosion = sin(world_uv.x * 2.7) * sin(world_uv.y * 3.2) * 0.026;
    ALPHA = 1.0-smoothstep(0.88+erosion,1.0+erosion,distance_edge);
    ALPHA_SCISSOR_THRESHOLD = 0.45;
    vec3 view_tangent = vec3(dot(VIEW,TANGENT),dot(VIEW,BINORMAL),dot(VIEW,NORMAL));
    float nearby = 1.0-smoothstep(5.0,14.0,length(VERTEX));
    vec2 uv = world_uv;
    vec2 step_uv = view_tangent.xy/max(view_tangent.z,0.35)*0.018*nearby/8.0;
    float layer = 0.0;
    for (int i=0;i<8;i++) {
        if (layer < 1.0-texture(height_map,uv).r) {uv-=step_uv;layer+=0.125;}
    }
    float elevation = texture(height_map,uv).r;
    float damp_patch = sin(world_uv.x*0.31+sin(world_uv.y*0.19))*sin(world_uv.y*0.38);
    float wet = smoothstep(0.10,0.62,damp_patch) * (1.0-smoothstep(0.43,0.69,elevation));
    float dirt = smoothstep(0.72,0.99,distance_edge)*0.60;
    vec3 stone = texture(stone_map,uv).rgb;
    ALBEDO = mix(stone,texture(soil_map,world_uv*0.31).rgb,dirt)*mix(0.88,0.64,wet);
    NORMAL_MAP = mix(texture(soil_normal,uv).rgb,vec3(0.5,0.5,1.0),wet*0.70);
    NORMAL_MAP_DEPTH = 0.95;
    ROUGHNESS = mix(texture(soil_rough,uv).r,0.13,wet);
    METALLIC = 0.0;
    SPECULAR = 0.5;
    AO = mix(0.65,1.0,elevation);
}
