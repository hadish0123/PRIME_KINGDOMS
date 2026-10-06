shader_type spatial;
render_mode diffuse_burley;
uniform vec3 dark : source_color = vec3(0.11,0.058,0.026);
uniform vec3 highlight : source_color = vec3(0.25,0.15,0.065);
void vertex() {
    float loose = pow(UV.y,3.0);
    VERTEX.x += loose*sin(TIME*1.8+floor(UV.x*0.5)*2.4)*0.0014;
    VERTEX.z += loose*sin(TIME*2.1+floor(UV.x*0.5))*0.0008;
}
void fragment() {
    float clump = floor(UV.x*0.5);
    float variation = fract(sin(clump*127.1+4.7)*43758.5453);
    float fade = 1.0-smoothstep(0.15,0.6,length(fwidth(UV))*220.0);
    float fibers = sin(fract(UV.x)*330.0+sin(UV.y*31.0+clump)*0.7);
    ALBEDO = mix(dark,highlight,0.16+variation*0.28)*(0.93+fibers*0.075*fade);
    ROUGHNESS = 0.69+variation*0.09;
    SPECULAR = 0.24;
    NORMAL_MAP = vec3(0.5+fibers*0.045*fade,0.5,1.0);
    NORMAL_MAP_DEPTH = 0.32;
}
