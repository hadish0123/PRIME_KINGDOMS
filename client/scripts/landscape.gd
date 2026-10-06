extends RefCounted

# Art-space relief is separate from the stable version-1 save coordinates.
# Conversion preserves height above the surface (including jumps and rooftops).
# It never changes world IDs, village elevations, server terrain or saved data.
static func relief(x: float, z: float, seed_number: int, settlements: Array) -> float:
	var distance = INF
	for village in settlements:
		var p: Dictionary = village.position
		distance = minf(distance, Vector2(x - float(p.x), z - float(p.z)).length())
	if distance < 150.0: return 0.0
	var envelope = smoothstep(150.0, 1800.0, distance)
	var wide = noise(x / 2400.0, z / 2400.0, seed_number + 911)
	var ridge = 1.0 - absf(2.0 * noise(x / 1150.0, z / 1150.0, seed_number + 301) - 1.0)
	var detail = 1.0 - absf(2.0 * noise(x / 290.0, z / 290.0, seed_number + 713) - 1.0)
	return envelope * (pow(ridge, 7.0) * lerpf(180.0, 680.0, wide) + pow(detail, 3.0) * 26.0)

static func noise(x: float, z: float, seed_number: int) -> float:
	var ix = floori(x)
	var iz = floori(z)
	var fx = x - floor(x)
	var fz = z - floor(z)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	return lerpf(lerpf(hash_value(ix, iz, seed_number), hash_value(ix + 1, iz, seed_number), fx), lerpf(hash_value(ix, iz + 1, seed_number), hash_value(ix + 1, iz + 1, seed_number), fx), fz)

static func hash_value(x: int, z: int, seed_number: int) -> float:
	var n: int = ((x * 374761393) & 0xffffffff) ^ ((z * 668265263) & 0xffffffff) ^ (seed_number & 0xffffffff)
	n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
	return float((n ^ (n >> 16)) & 0xffffffff) / 4294967295.0
