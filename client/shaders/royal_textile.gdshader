shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic;
uniform bool cape = false;
void vertex() {
    if (cape) {
        float edge = UV.y*UV.y;
        vec3 gravity = normalize(transpose(mat3(MODEL_MATRIX))*vec3(0,-1,0));
        VERTEX += (gravity-vec3(0,-1,0))*edge*0.50;
        VERTEX.z += edge*(sin(TIME*2.3+UV.x*7.0)*0.022+sin(TIME*4.1+UV.y*8.0)*0.008);
    }
}
uniform bool empire_enabled = false;
uniform vec4 empire_primary : source_color = vec4(0.5,0.1,0.1,1.0);
uniform vec4 empire_secondary : source_color = vec4(0.8,0.65,0.3,1.0);
uniform sampler2D emblem_mask : filter_linear_mipmap;
void fragment() {
    vec3 textile = texture(albedo_map,UV).rgb;
    float gold = smoothstep(0.08,0.3,textile.g-textile.b) * smoothstep(0.12,0.38,textile.r);
    ALBEDO = textile*0.80;
    METALLIC = gold*0.45;
    ROUGHNESS = mix(0.92,0.50,gold);
    float fade = 1.0-smoothstep(0.2,0.6,length(fwidth(UV))*1100.0);
    NORMAL_MAP = vec3(0.5+sin(UV.y*2500.0)*0.07*fade,0.5+sin(UV.x*1900.0)*0.07*fade,1.0);
    NORMAL_MAP_DEPTH = 0.25;
    if (empire_enabled) {
        float grain = 0.84 + 0.08*sin(UV.x*1700.0)*sin(UV.y*1350.0);
        ALBEDO = empire_primary.rgb * grain;
        vec2 emblem_uv = (UV-vec2(0.5,0.42))*vec2(2.2,2.4)+vec2(0.5);
        float inside = step(0.0,emblem_uv.x)*step(emblem_uv.x,1.0)*step(0.0,emblem_uv.y)*step(emblem_uv.y,1.0);
        float mask = texture(emblem_mask,clamp(emblem_uv,vec2(0.0),vec2(1.0))).a*inside;
        float trim = 1.0-smoothstep(0.01,0.025,min(UV.x,1.0-UV.x));
        ALBEDO = mix(ALBEDO,empire_secondary.rgb,max(mask,trim));
    }
}
