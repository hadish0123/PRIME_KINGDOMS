shader_type spatial;
varying vec2 world_xz;
void vertex() {
    world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
    vec2 p = world_xz * 3.0;
    float grain = hash(floor(p));
    float stone = smoothstep(0.09, 0.16, length(fract(p) - vec2(0.5))) * 0.045;
    ALBEDO = mix(vec3(0.19, 0.145, 0.09), vec3(0.32, 0.25, 0.16), grain) - stone;
    ROUGHNESS = 0.97;
}
