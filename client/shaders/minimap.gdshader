shader_type canvas_item;
void fragment() {
    vec4 scene = texture(TEXTURE,UV);
    float inside = 1.0-smoothstep(0.465,0.475,length(UV-vec2(0.5)));
    COLOR = vec4(scene.rgb,inside);
}
