extends Node3D

const Surfaces = preload("res://scripts/visual_materials.gd")
const Architecture = preload("res://scripts/architecture.gd")
const GRASS_TILE = 24.0
const GROVE_TILE = 80.0
var terrain: Node3D
var quality = 1
var grass: Dictionary = {}
var groves: Dictionary = {}
var pending_grass: Array[Vector2i] = []
var pending_groves: Array[Vector2i] = []
var grass_center = Vector2i(99999, 99999)
var grove_center = Vector2i(99999, 99999)
static var blade_mesh: ArrayMesh
static var leaf_mesh: QuadMesh
static var grass_material: ShaderMaterial
static var leaf_material: ShaderMaterial
static var tree_mesh: ArrayMesh

func _ready() -> void:
	if not grass_material:
		grass_material = ShaderMaterial.new()
		grass_material.shader = load("res://shaders/foliage.gdshader")
		leaf_material = ShaderMaterial.new()
		leaf_material.shader = grass_material.shader
		leaf_material.set_shader_parameter("leaves", true)
		leaf_material.set_shader_parameter("wind_strength", 0.025)
		leaf_material.set_shader_parameter("base_color", Vector3(0.22, 0.30, 0.10))
		leaf_mesh = QuadMesh.new()
		leaf_mesh.size = Vector2(0.95, 0.95)
		blade_mesh = make_blades()
		var trunk = Architecture.new()
		trunk.begin()
		trunk.cylinder(0.27, 5.5, Vector3(0, 2.75, 0), "wood")
		trunk.cylinder(0.16, 2.7, Vector3(0.1, 6.25, 0), "wood", Vector3(0.12, 0.05, 0.08))
		for i in range(9):
			var a = i * TAU / 9.0
			trunk.beam(Vector3(0, 3.5 + i * 0.23, 0), Vector3(sin(a) * 2.1, 5.9 + i * 0.19, cos(a) * 2.1), 0.10 - i * 0.005)
		tree_mesh = trunk.batches.wood.commit()
		trunk.free()

func set_quality(value: int) -> void:
	if value == quality: return
	quality = clampi(value, 0, 2)
	reset()

func reset() -> void:
	for node in grass.values(): node.queue_free()
	for node in groves.values(): node.queue_free()
	grass.clear()
	groves.clear()
	pending_grass.clear()
	pending_groves.clear()
	grass_center = Vector2i(99999, 99999)
	grove_center = Vector2i(99999, 99999)

func clear_at(p: Vector2, for_tree: bool) -> bool:
	for village in terrain.villages:
		var home = Vector2(float(village.position.x) - terrain.origin.x, float(village.position.z) - terrain.origin.z)
		var local = p - home
		if for_tree and local.length() < 72.0: return false
		if not for_tree and local.length() < 65.0:
			if absf(local.x) < 5.1 or (absf(local.x) < 47.0 and absf(local.y - 8.0) < 4.2): return false
			for building in [Vector2(0, -27), Vector2(-25, -23), Vector2(25, -26), Vector2(-26, 6), Vector2(28, 14), Vector2(-27, 32), Vector2(31, 34)]:
				if absf(local.x - building.x) < 8.0 and absf(local.y - building.y) < 7.0: return false
	return true

func stream_at(viewer: Vector3) -> void:
	var next = Vector2i(floori((viewer.x + terrain.origin.x) / GRASS_TILE), floori((viewer.z + terrain.origin.z) / GRASS_TILE))
	var radius = quality + 2
	if next != grass_center:
		grass_center = next
		pending_grass.clear()
		for key in grass.keys():
			if maxi(absi(key.x - next.x), absi(key.y - next.y)) > radius:
				grass[key].queue_free()
				grass.erase(key)
		for z in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var key = next + Vector2i(x, z)
				if not grass.has(key): pending_grass.append(key)
		pending_grass.sort_custom(func(a, b): return a.distance_squared_to(next) < b.distance_squared_to(next))
	var grove = Vector2i(floori((viewer.x + terrain.origin.x) / GROVE_TILE), floori((viewer.z + terrain.origin.z) / GROVE_TILE))
	var grove_radius = quality + 1
	if grove != grove_center:
		grove_center = grove
		pending_groves.clear()
		for key in groves.keys():
			if maxi(absi(key.x - grove.x), absi(key.y - grove.y)) > grove_radius:
				groves[key].queue_free()
				groves.erase(key)
		for z in range(-grove_radius, grove_radius + 1):
			for x in range(-grove_radius, grove_radius + 1):
				var key = grove + Vector2i(x, z)
				if not groves.has(key): pending_groves.append(key)
		pending_groves.sort_custom(func(a, b): return a.distance_squared_to(grove) < b.distance_squared_to(grove))
	for i in range(2):
		if not pending_grass.is_empty(): build_grass(pending_grass.pop_front())
	if not pending_groves.is_empty(): build_grove(pending_groves.pop_front())

static func make_blades() -> ArrayMesh:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle in [0.0, PI / 3.0, PI * 2.0 / 3.0]:
		var basis = Basis(Vector3.UP, angle)
		for segment in range(3):
			for pair in [[0, 0], [0, 1], [1, 0], [0, 1], [1, 1], [1, 0]]:
				var y = float(segment + pair[0]) / 3.0
				var width = sin((y * 0.85 + 0.15) * PI) * 0.018
				surface.set_normal(basis * Vector3(0, 0.25, 1).normalized())
				surface.set_uv(Vector2(pair[1], y))
				surface.add_vertex(basis * Vector3((float(pair[1]) - 0.5) * width * 2.0, y * 0.30, y * y * 0.045))
	return surface.commit()

func seeded(key: Vector2i, salt: int) -> RandomNumberGenerator:
	var rng = RandomNumberGenerator.new()
	# Only presentation scenery uses this seed. Server-owned terrain and homes stay unchanged.
	rng.seed = (key.x * 73856093) ^ (key.y * 19349663) ^ terrain.seed_value ^ salt
	return rng

func build_grass(key: Vector2i) -> void:
	var rng = seeded(key, 1931)
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var corner = Vector2(key.x, key.y) * GRASS_TILE - Vector2(terrain.origin.x, terrain.origin.z)
	var base = Vector3(corner.x, terrain.height_at(corner.x + 12, corner.y + 12), corner.y)
	for i in range([256, 640, 960][quality]):
		var p = corner + Vector2(rng.randf_range(0, GRASS_TILE), rng.randf_range(0, GRASS_TILE))
		if not clear_at(p, false): continue
		var basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.65, 1.4))
		transforms.append(Transform3D(basis, Vector3(p.x, terrain.height_at(p.x, p.y), p.y) - base))
		colors.append(Color(rng.randf(), 0, 0, 0))
	var mesh = MultiMesh.new()
	mesh.transform_format = MultiMesh.TRANSFORM_3D
	mesh.use_custom_data = true
	mesh.mesh = blade_mesh
	mesh.instance_count = transforms.size()
	for i in range(transforms.size()):
		mesh.set_instance_transform(i, transforms[i])
		mesh.set_instance_custom_data(i, colors[i])
	var visual = MultiMeshInstance3D.new()
	visual.multimesh = mesh
	visual.material_override = grass_material
	visual.position = base
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.visibility_range_end = [55.0, 85.0, 110.0][quality]
	add_child(visual)
	grass[key] = visual

func build_grove(key: Vector2i) -> void:
	var rng = seeded(key, 8312)
	var node = Node3D.new()
	add_child(node)
	groves[key] = node
	var corner = Vector2(key.x, key.y) * GROVE_TILE - Vector2(terrain.origin.x, terrain.origin.z)
	for i in range(3):
		var p = corner + Vector2(rng.randf_range(8, 72), rng.randf_range(8, 72))
		if not clear_at(p, true): continue
		var tree = Node3D.new()
		node.add_child(tree)
		tree.position = Vector3(p.x, terrain.height_at(p.x, p.y), p.y)
		tree.rotation.y = rng.randf() * TAU
		tree.scale = Vector3.ONE * rng.randf_range(0.85, 1.45)
		var trunk = MeshInstance3D.new()
		trunk.mesh = tree_mesh
		trunk.material_override = Surfaces.pbr("bark_brown_02", Color(0.78, 0.76, 0.69), 0.9)
		trunk.visibility_range_end = 290.0
		tree.add_child(trunk)
		var leaves_mesh = MultiMesh.new()
		leaves_mesh.transform_format = MultiMesh.TRANSFORM_3D
		leaves_mesh.use_custom_data = true
		leaves_mesh.mesh = leaf_mesh
		leaves_mesh.instance_count = [150, 240, 360][quality]
		for leaf in range(leaves_mesh.instance_count):
			var direction = Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
			var at = Vector3(0, 6.5, 0) + direction * rng.randf_range(0.4, 2.7)
			var basis = Basis.from_euler(Vector3(rng.randf() * PI, rng.randf() * TAU, rng.randf() * TAU))
			leaves_mesh.set_instance_transform(leaf, Transform3D(basis, at))
			leaves_mesh.set_instance_custom_data(leaf, Color(rng.randf(), 0, 0, 0))
		var canopy = MultiMeshInstance3D.new()
		canopy.multimesh = leaves_mesh
		canopy.material_override = leaf_material
		canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if quality == 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		canopy.visibility_range_end = 260.0
		tree.add_child(canopy)
		var body = StaticBody3D.new()
		var collider = CollisionShape3D.new()
		var shape = CylinderShape3D.new()
		shape.radius = 0.28
		shape.height = 5.5
		collider.shape = shape
		collider.position.y = 2.75
		body.add_child(collider)
		tree.add_child(body)
