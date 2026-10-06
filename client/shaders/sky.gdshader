shader_type sky;
uniform sampler2D panorama : source_color, filter_linear_mipmap;
void sky() {
    vec2 uv = vec2(atan(EYEDIR.x,EYEDIR.z) / 6.2831853 + 0.5,acos(clamp(EYEDIR.y,-1.0,1.0)) / 3.14159265);
    vec3 photo = texture(panorama,uv).rgb;
    photo = photo / (vec3(1.0) + photo);
    vec3 sky_color = mix(vec3(0.17,0.30,0.49),photo,0.74);
    float horizon = 1.0-smoothstep(0.0,0.32,abs(EYEDIR.y));
    COLOR = mix(sky_color,vec3(0.56,0.70,0.80),horizon*0.48);
}
