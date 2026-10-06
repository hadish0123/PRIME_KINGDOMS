shader_type spatial;
render_mode diffuse_burley;
float grain(vec2 p) {return fract(sin(dot(floor(p),vec2(127.1,311.7)))*43758.5453);}
void fragment() {
    float fade = 1.0-smoothstep(0.1,0.6,length(fwidth(UV))*320.0);
    float n = mix(0.5,grain(UV*320.0),fade);
    float seam = 1.0-smoothstep(0.005,0.035,min(UV.x,1.0-UV.x));
    ALBEDO = vec3(0.085,0.037,0.017)*mix(0.8,1.30,n)+seam*vec3(0.03,0.02,0.01);
    NORMAL_MAP = vec3(0.5+0.07*fade*sin(UV.y*900.0),0.5+(n-0.5)*0.16,1.0);
    NORMAL_MAP_DEPTH = 0.4;
    ROUGHNESS = 0.67+n*0.18;
}
