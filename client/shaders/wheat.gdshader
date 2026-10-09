shader_type spatial;
render_mode cull_disabled, diffuse_burley;
void vertex() {
    vec3 world = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    VERTEX.x += sin(TIME*1.5+world.x*0.21+world.z*0.36)*VERTEX.y*VERTEX.y*0.055;
}
void fragment() {
    ALBEDO = mix(vec3(0.37,0.39,0.12),vec3(0.77,0.59,0.23),smoothstep(0.2,0.8,UV.y));
    ROUGHNESS = 0.94;
    BACKLIGHT = vec3(0.10,0.08,0.025);
}
