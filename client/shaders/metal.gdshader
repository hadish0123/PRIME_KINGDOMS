shader_type spatial;
render_mode diffuse_burley;

uniform vec3 color : source_color = vec3(0.24, 0.27, 0.29);
uniform float gilded = 0.0;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
    float pixel_fade = 1.0 - clamp(length(fwidth(UV)) * 720.0, 0.0, 1.0);
    float grain = mix(0.5, hash21(floor(UV * 900.0)), pixel_fade);
    float brushing = sin(UV.y * 1150.0 + sin(UV.x * 37.0) * 2.0) * 0.5 + 0.5;
    float scratches = smoothstep(0.985, 1.0, hash21(floor(UV * vec2(118.0, 780.0))));
    float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);

    float tone = 0.91 + grain * 0.085 + brushing * 0.022 * pixel_fade;
    tone += scratches * 0.05 * pixel_fade;
    tone += fresnel * mix(0.08, 0.13, gilded);

    ALBEDO = color * tone;
    METALLIC = mix(0.82, 0.93, gilded);
    ROUGHNESS = mix(0.31, 0.24, gilded) + grain * 0.055 + scratches * 0.035;
    SPECULAR = mix(0.58, 0.72, gilded);
}
