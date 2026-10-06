shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(0.42,0.016,0.028,1.0);
uniform bool vertical = false;
uniform bool royal = false;
uniform sampler2D heraldry : source_color, filter_linear_mipmap;

float weave(vec2 uv) {
    float a = sin(uv.x*980.0)*0.5+0.5;
    float b = sin(uv.y*860.0+1.57)*0.5+0.5;
    return mix(a,b,0.5);
}

void vertex() {
    float free_edge = UV.y*UV.y;
    if (vertical && royal) {
        vec3 down_in_mesh = normalize(transpose(mat3(MODEL_MATRIX))*vec3(0.0,-1.0,0.0));
        VERTEX += (down_in_mesh-vec3(0.0,-1.0,0.0))*free_edge*0.42;
    }
    float wave = free_edge*(0.043*sin(TIME*2.25+UV.x*5.2)+0.018*sin(TIME*4.7+UV.y*7.0));
    if (vertical) { VERTEX.z += wave; } else { VERTEX.y += wave; }
    VERTEX.x += free_edge*0.022*sin(TIME*1.9+UV.y*5.3);
}

void fragment() {
    vec3 linen = texture(albedo_map,UV*7.0).rgb;
    float fibers = weave(UV);
    ALBEDO = linen*tint.rgb*mix(0.90,1.08,fibers);
    if (royal) {
        vec2 crest_uv = vec2((UV.x-0.5)*1.72+0.5,(UV.y-0.50)*1.52+0.5);
        vec4 crest = texture(heraldry,clamp(crest_uv,vec2(0.0),vec2(1.0)));
        float inside = step(0.0,crest_uv.x)*step(crest_uv.x,1.0)*step(0.0,crest_uv.y)*step(crest_uv.y,1.0);
        vec3 gold = vec3(0.67,0.43,0.085)*mix(0.90,1.14,fibers);
        ALBEDO = mix(ALBEDO,gold,crest.a*inside*0.96);
        float d = min(min(UV.x,1.0-UV.x),1.0-UV.y);
        float border = 1.0-smoothstep(0.020,0.040,d);
        ALBEDO = mix(ALBEDO,gold,border);
    }
    ROUGHNESS = mix(0.78,0.92,fibers);
    SPECULAR = 0.30;
}
