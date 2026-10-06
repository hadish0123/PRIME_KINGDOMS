shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform bool leaves = false;
uniform vec3 base_color : source_color = vec3(0.27, 0.34, 0.13);
uniform float wind_strength = 0.08;
varying float variation;
void vertex() {
    vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    variation = INSTANCE_CUSTOM.r;
    float bend = leaves ? 1.0 : VERTEX.y * VERTEX.y;
    VERTEX.x += bend * wind_strength * (sin(TIME * 1.6 + world.x * 0.3 + world.z * 0.2) + 0.35 * sin(TIME * 3.7 + world.z));
    VERTEX.z += bend * wind_strength * 0.45 * sin(TIME * 2.1 + world.x * 0.4);
}
void fragment() {
    if (leaves) {
        vec2 p = fract(UV * 3.0) - vec2(0.5);
        float shape = 1.0 - smoothstep(0.38, 0.48, length(p * vec2(1.35, 1.0)));
        ALPHA = shape;
        ALPHA_SCISSOR_THRESHOLD = 0.5;
    }
    ALBEDO = base_color * mix(0.70, 1.15, variation) * mix(0.70, 1.0, UV.y);
    ROUGHNESS = 0.91;
    BACKLIGHT = vec3(0.18, 0.23, 0.09);
}
