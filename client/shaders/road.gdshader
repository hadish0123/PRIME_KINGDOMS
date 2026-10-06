shader_type spatial;
varying vec2 world_xz;
void vertex() {
    world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
               mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
    float soil = noise(world_xz * 0.7) * 0.65 + noise(world_xz * 7.0) * 0.35;
    vec2 cell = floor(world_xz * 9.0);
    float seed = hash(cell);
    vec2 pebble_center = vec2(0.2 + 0.6 * seed, 0.2 + 0.6 * hash(cell + 37.0));
    float pebble = (1.0 - smoothstep(0.11, 0.21, distance(fract(world_xz * 9.0), pebble_center))) * step(0.8, seed);
    ALBEDO = mix(vec3(0.20, 0.15, 0.095), vec3(0.32, 0.245, 0.16), soil) + pebble * 0.045;
    ROUGHNESS = 0.97;
}
