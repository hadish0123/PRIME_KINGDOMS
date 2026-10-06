extends RefCounted

# Shared material resources avoid one texture/material allocation per resident or prop.
static var cache: Dictionary = {}

static func pbr(asset: String, tint: Color = Color.WHITE, scale_value: float = 1.0, world: bool = true) -> StandardMaterial3D:
	var key = "%s:%s:%s:%s" % [asset, tint, scale_value, world]
	if cache.has(key): return cache[key]
	var material = StandardMaterial3D.new()
	material.set_meta("source_asset", asset)
	material.albedo_color = tint
	material.albedo_texture = load("res://assets/textures/%s_diff.jpg" % asset)
	material.normal_enabled = true
	material.normal_texture = load("res://assets/textures/%s_normal.jpg" % asset)
	material.normal_scale = 0.65 if world else 0.22
	material.roughness_texture = load("res://assets/textures/%s_rough.jpg" % asset)
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_scale = Vector3.ONE * scale_value
	material.uv1_triplanar = world
	material.uv1_world_triplanar = world
	cache[key] = material
	return material

static func plain(color: Color, roughness: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var key = "%s:%s:%s" % [color, roughness, metal]
	if cache.has(key): return cache[key]
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metal
	cache[key] = material
	return material
