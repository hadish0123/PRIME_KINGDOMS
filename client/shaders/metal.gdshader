shader_type spatial;
render_mode diffuse_burley;
uniform vec3 color : source_color = vec3(0.52,0.54,0.57);
uniform float gilded = 0.0;

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
    float pixel = clamp(length(fwidth(UV))*900.0,0.0,1.0);
    float detail = 1.0-pixel;
    float fine = hash12(floor(UV*1250.0));
    float broad = hash12(floor(UV*110.0));
    float brushed = sin(UV.y*980.0 + broad*8.0)*0.010*detail;
    float scratch = smoothstep(0.965,0.995,hash12(floor(UV*430.0+vec2(broad*17.0,0.0))))*0.07*detail;
    float wear = mix(0.985,1.055,fine)*mix(0.97,1.03,broad);
    vec3 base = color*wear + vec3(brushed);
    base += vec3(0.06,0.045,0.015)*scratch*gilded;
    ALBEDO = base;
    METALLIC = mix(0.90,0.97,gilded);
    ROUGHNESS = clamp(mix(0.25,0.20,gilded)+broad*0.055+scratch*0.14,0.16,0.40);
    SPECULAR = mix(0.62,0.78,gilded);
}
