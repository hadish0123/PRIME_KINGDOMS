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
        vec3 down_in_mesh = normalize(transpose(mat3(MODEL_MATRIX)) * vec3(0.0, -1.0, 0.0));
        VERTEX += (down_in_mesh - vec3(0.0, -1.0, 0.0)) * free_edge * 0.52;
    }

    float broad_wave = 0.036 * sin(TIME * 2.2 + UV.x * 5.1);
    float detail_wave = 0.014 * sin(TIME * 4.7 + UV.y * 7.3 + UV.x * 2.0);
    float wave = free_edge * (broad_wave + detail_wave);
    if (vertical) {
        VERTEX.z += wave;
    } else {
        VERTEX.y += wave;
    }
    VERTEX.x += free_edge * 0.020 * sin(TIME * 1.9 + UV.y * 4.8);
}

void fragment() {
    vec3 linen = texture(albedo_map, UV * 6.5).rgb;
    float warp = sin(UV.x * 720.0) * 0.5 + 0.5;
    float weft = sin(UV.y * 690.0) * 0.5 + 0.5;
    float weave = (warp * weft - 0.25) * 0.09;

    ALBEDO = linen * tint.rgb * (0.92 + weave);

    if (royal) {
        vec2 crest_uv = vec2((UV.x - 0.5) * 2.05 + 0.5, (UV.y - 0.50) * 1.60 + 0.5);
        vec4 crest = texture(heraldry, clamp(crest_uv, vec2(0.0), vec2(1.0)));
        float inside = step(0.0, crest_uv.x) * step(crest_uv.x, 1.0) * step(0.0, crest_uv.y) * step(crest_uv.y, 1.0);

        vec3 embroidered_gold = vec3(0.56, 0.35, 0.075) * (0.90 + weave * 2.0);
        ALBEDO = mix(ALBEDO, embroidered_gold, crest.a * inside * 0.96);

        float edge_distance = min(min(UV.x, 1.0 - UV.x), 1.0 - UV.y);
        float outer_border = 1.0 - smoothstep(0.018, 0.032, edge_distance);
        float inner_border = smoothstep(0.036, 0.050, edge_distance) * (1.0 - smoothstep(0.058, 0.072, edge_distance));
        ALBEDO = mix(ALBEDO, vec3(0.50, 0.30, 0.065), max(outer_border, inner_border) * 0.92);
    }

    ROUGHNESS = 0.84 + (1.0 - weave) * 0.05;
    SPECULAR = 0.28;
}
