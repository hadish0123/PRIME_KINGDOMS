shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(0.22, 0.35, 0.51, 1.0);
uniform bool vertical = false;
uniform bool royal = false;
uniform sampler2D heraldry : source_color, filter_linear_mipmap;
void vertex() {
    float free_edge = UV.y * UV.y;
    if (vertical && royal) {
        vec3 down_in_mesh = normalize(transpose(mat3(MODEL_MATRIX))*vec3(0.0,-1.0,0.0));
        VERTEX += (down_in_mesh-vec3(0.0,-1.0,0.0))*free_edge*0.50;
    }
    float wave = free_edge * (0.035 * sin(TIME * 2.7 + UV.x * 4.0) + 0.016 * sin(TIME * 5.1 + UV.y * 5.0));
    if (vertical) { VERTEX.z += wave; } else { VERTEX.y += wave; }
    VERTEX.x += free_edge * 0.018 * sin(TIME * 2.2 + UV.y * 4.0);
}
uniform bool empire_enabled = false;
uniform vec4 empire_primary : source_color = vec4(0.5,0.1,0.1,1.0);
uniform vec4 empire_secondary : source_color = vec4(0.8,0.65,0.3,1.0);
uniform sampler2D emblem_mask : filter_linear_mipmap;
void fragment() {
    ALBEDO = texture(albedo_map, UV * 6.0).rgb * tint.rgb;
    if (royal) {
        vec2 crest_uv = vec2((UV.x-0.5)*2.1+0.5,(UV.y-0.55)*1.7+0.5);
        vec4 crest = texture(heraldry,clamp(crest_uv,vec2(0.0),vec2(1.0)));
        float inside = step(0.0,crest_uv.x)*step(crest_uv.x,1.0)*step(0.0,crest_uv.y)*step(crest_uv.y,1.0);
        ALBEDO = mix(ALBEDO,crest.rgb * 0.83,crest.a*inside);
        float border = 1.0-smoothstep(0.022,0.034,min(min(UV.x,1.0-UV.x),1.0-UV.y));
        ALBEDO = mix(ALBEDO,vec3(0.39,0.23,0.055),border);
    }
    ROUGHNESS = 0.93;
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
