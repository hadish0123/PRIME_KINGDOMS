extends Node3D

const Nature = preload("res://scripts/nature.gd")
const CHUNK_SIZE = 160.0
const RADIUS = 6
var view_radius = 5
var seed_value: int = 1
var origin: Vector3 = Vector3.ZERO
var world_size: float = 65536.0
var villages: Array = []
var chunks: Dictionary = {}
var pending: Array[Vector2i] = []
var center = Vector2i(100000, 100000)
var material: ShaderMaterial
var nature: Node3D

func set_radius(value: int) -> void:
	var next = clampi(value, 4, RADIUS)
	if next == view_radius: return
	view_radius = next
	center = Vector2i(100000, 100000)

static func hash_value(x: int, z: int, seed_number: int) -> float:
	var n: int = ((x * 374761393) & 0xffffffff) ^ ((z * 668265263) & 0xffffffff) ^ (seed_number & 0xffffffff)
	n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
	return float((n ^ (n >> 16)) & 0xffffffff) / 4294967295.0

static func smooth_noise(x: float, z: float, seed_number: int) -> float:
	var ix = int(floor(x))
	var iz = int(floor(z))
	var fx = x - floor(x)
	var fz = z - floor(z)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	return lerpf(lerpf(hash_value(ix, iz, seed_number), hash_value(ix + 1, iz, seed_number), fx), lerpf(hash_value(ix, iz + 1, seed_number), hash_value(ix + 1, iz + 1, seed_number), fx), fz)

static func raw_height(x: float, z: float, seed_number: int) -> float:
	return 12.0 + smooth_noise(x / 1400.0, z / 1400.0, seed_number) * 44.0 + smooth_noise(x / 360.0, z / 360.0, seed_number + 71) * 13.0 + smooth_noise(x / 110.0, z / 110.0, seed_number + 137) * 3.0

func height_at(x: float, z: float) -> float:
	var wx = x + origin.x
	var wz = z + origin.z
	var y = raw_height(wx, wz, seed_value)
	for village in villages:
		var p: Dictionary = village.position
		var distance = Vector2(wx - float(p.x), wz - float(p.z)).length()
		if distance < 125.0:
			y = lerpf(float(p.y), y, smoothstep(78.0, 125.0, distance))
	return y - origin.y

func configure(world: Dictionary, base: Vector3, settlements: Array) -> void:
	seed_value = int(world.seed)
	world_size = float(world.sizeM)
	origin = base
	villages = settlements
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/ground.gdshader")
	for role in ["grass", "mud"]:
		var asset_name = "grass_ground" if role == "grass" else "brown_mud"
		for map_name in ["map", "normal", "rough"]:
			var suffix = "diff" if map_name == "map" else map_name
			material.set_shader_parameter(role + "_" + map_name, load("res://assets/textures/%s_%s.jpg" % [asset_name, suffix]))
	material.set_shader_parameter("village_center", Vector2(float(villages[0].position.x) - origin.x, float(villages[0].position.z) - origin.z))
	nature = Nature.new()
	nature.terrain = self
	add_child(nature)

func update_villages(settlements: Array) -> void:
	var changed: Array = []
	for old in villages:
		if not settlements.any(func(v): return v.id == old.id and v.position == old.position): changed.append(old)
	for new_village in settlements:
		if not villages.any(func(v): return v.id == new_village.id and v.position == new_village.position): changed.append(new_village)
	if changed.is_empty(): return
	villages = settlements
	if nature: nature.reset()
	for key in chunks.keys():
		var tile = Rect2(Vector2(key.x * CHUNK_SIZE, key.y * CHUNK_SIZE), Vector2.ONE * CHUNK_SIZE).grow(125.0)
		if changed.any(func(v): return tile.has_point(Vector2(float(v.position.x) - origin.x, float(v.position.z) - origin.z))):
			chunks[key].queue_free()
			chunks.erase(key)
			if key not in pending: pending.append(key)
	pending.sort_custom(func(a, b): return a.distance_squared_to(center) < b.distance_squared_to(center))

func stream_at(position_value: Vector3) -> void:
	if nature: nature.stream_at(position_value)
	var next = Vector2i(int(floor(position_value.x / CHUNK_SIZE)), int(floor(position_value.z / CHUNK_SIZE)))
	if center.x != 100000:
		# Keep tiny physics corrections near a tile edge from rebuilding both LOD rings.
		var previous_center = Vector2((center.x + 0.5) * CHUNK_SIZE, (center.y + 0.5) * CHUNK_SIZE)
		if absf(position_value.x - previous_center.x) < CHUNK_SIZE * 0.65: next.x = center.x
		if absf(position_value.z - previous_center.y) < CHUNK_SIZE * 0.65: next.y = center.y
	if next != center:
		center = next
		pending.clear()
		for key in chunks.keys():
			var distance = maxi(absi(key.x - center.x), absi(key.y - center.y))
			if distance > view_radius or bool(chunks[key].get_meta("near")) != (distance <= 2):
				chunks[key].queue_free()
				chunks.erase(key)
		for dz in range(-view_radius, view_radius + 1):
			for dx in range(-view_radius, view_radius + 1):
				var key = center + Vector2i(dx, dz)
				if not chunks.has(key): pending.append(key)
		pending.sort_custom(func(a, b): return a.distance_squared_to(center) < b.distance_squared_to(center))
	# A small number of chunks per frame prevents a full-world allocation.
	for count in range(2):
		if not pending.is_empty(): build_chunk(pending.pop_front())

func build_chunk(key: Vector2i) -> void:
	var distance = maxi(absi(key.x - center.x), absi(key.y - center.y))
	var divisions = 20 if distance <= 2 else 5
	var node = Node3D.new()
	node.name = "Terrain_%s_%s" % [key.x, key.y]
	node.set_meta("near", distance <= 2)
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step = CHUNK_SIZE / divisions
	var corner = Vector2(key.x * CHUNK_SIZE, key.y * CHUNK_SIZE)
	for z in range(divisions + 1):
		for x in range(divisions + 1):
			var px = corner.x + x * step
			var pz = corner.y + z * step
			var normal = Vector3(height_at(px - 1.0, pz) - height_at(px + 1.0, pz), 2.0, height_at(px, pz - 1.0) - height_at(px, pz + 1.0)).normalized()
			surface.set_normal(normal)
			surface.set_uv(Vector2(px, pz))
			surface.add_vertex(Vector3(x * step, height_at(px, pz), z * step))
	for z in range(divisions):
		for x in range(divisions):
			var a = z * (divisions + 1) + x
			for index in [a, a + 1, a + divisions + 1, a + 1, a + divisions + 2, a + divisions + 1]:
				surface.add_index(index)
	surface.generate_tangents()
	var mesh = surface.commit()
	var visual = MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	if distance > 2: visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(visual)
	if distance <= 2:
		var body = StaticBody3D.new()
		var collision = CollisionShape3D.new()
		collision.shape = mesh.create_trimesh_shape()
		body.add_child(collision)
		node.add_child(body)
	add_child(node)
	node.position = Vector3(corner.x, 0.0, corner.y)
	chunks[key] = node

func ensure_spawn(position_value: Vector3) -> void:
	stream_at(position_value)
	# Immediate colliders at the spawn; the remaining world streams progressively.
	var local_center = center
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key = local_center + Vector2i(dx, dz)
			if not chunks.has(key):
				pending.erase(key)
				build_chunk(key)
