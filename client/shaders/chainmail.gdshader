shader_type spatial;
render_mode diffuse_burley;
void fragment() {
    vec2 p = UV*vec2(180,240);
    p.x += mod(floor(p.y),2.0)*0.5;
    vec2 f = fract(p)-0.5;
    float d = length(f*vec2(1.0,1.45));
    float ring = smoothstep(0.30,0.34,d)*(1.0-smoothstep(0.40,0.44,d));
    float fade = 1.0-smoothstep(0.25,0.9,length(fwidth(p)));
    ring = mix(0.24,ring,fade);
    ALBEDO = mix(vec3(0.023,0.026,0.028),vec3(0.29,0.30,0.30),ring);
    METALLIC = 0.80;
    ROUGHNESS = 0.48;
    NORMAL_MAP = vec3(0.5+f.x*ring*0.4*fade,0.5+f.y*ring*0.4*fade,1.0);
    NORMAL_MAP_DEPTH = 0.6;
}
