shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley;
uniform sampler2D meadow : source_color, filter_linear_mipmap_anisotropic;
varying vec2 tile;
varying float variety;
void vertex() {
    float selection = min(floor(INSTANCE_CUSTOM.r * 4.0),3.0);
    tile = vec2(mod(selection,2.0),floor(selection/2.0));
    variety = INSTANCE_CUSTOM.g;
    vec3 p = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    VERTEX.x += sin(TIME*1.8+p.x*0.34+p.z*0.22) * pow(max(VERTEX.y,0.0),2.0) * 0.30;
}
void fragment() {
    vec4 sample_value = texture(meadow,(UV+tile)*0.5);
    ALBEDO = sample_value.rgb * mix(vec3(0.53,0.64,0.32),vec3(0.72,0.74,0.41),variety);
    ALPHA = sample_value.a;
    ALPHA_SCISSOR_THRESHOLD = 0.38;
    ROUGHNESS = 0.96;
    BACKLIGHT = ALBEDO * 0.06;
}
