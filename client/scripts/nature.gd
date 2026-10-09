extends Node3D

const Surfaces = preload("res://scripts/visual_materials.gd")
const Architecture = preload("res://scripts/architecture.gd")
const GRASS_TILE = 24.0
const GROVE_TILE = 80.0
var terrain: Node3D
var settlement_sites: Array = []
var quality = 1
var grass: Dictionary = {}
var groves: Dictionary = {}
var pending_grass: Array[Vector2i] = []
var pending_groves: Array[Vector2i] = []
var grass_center = Vector2i(99999, 99999)
var grove_center = Vector2i(99999, 99999)
static var blade_mesh: ArrayMesh
static var leaf_mesh: QuadMesh
static var rock_scenes: Array[PackedScene] = []
static var grass_material: ShaderMaterial
static var leaf_material: ShaderMaterial
static var tree_mesh: ArrayMesh

func _ready() -> void:
	if not grass_material:
		grass_material = ShaderMaterial.new()
		grass_material.shader = load("res://shaders/foliage.gdshader")
		grass_material.set_shader_parameter("meadow",load("res://assets/textures/meadow_alpha.png"))
		leaf_material = ShaderMaterial.new()
		leaf_material.shader = load("res://shaders/pine.gdshader")
		leaf_material.set_shader_parameter("needles", load("res://assets/textures/pine_twig_diff.jpg"))
		leaf_material.set_shader_parameter("mask", load("res://assets/textures/pine_twig_alpha.jpg"))
		leaf_material.set_shader_parameter("normal_map", load("res://assets/textures/pine_twig_normal.jpg"))
		leaf_mesh = QuadMesh.new()
		leaf_mesh.size = Vector2(1.05, 1.95)
		blade_mesh = make_blades()
		var trunk = Architecture.new()
		trunk.begin()
		for level in range(8):
			trunk.cylinder(lerpf(0.30,0.045,level / 7.0), 1.25, Vector3(0,0.62+level*1.18,0), "wood")
		for tier in range(7):
			var y = 2.9 + tier * 0.87
			for branch in range(7):
				var a = branch * TAU / 7.0 + tier * 0.72
				var radius = 3.5 - tier * 0.43
				var middle = Vector3(sin(a)*radius*0.55,y-0.12,cos(a)*radius*0.55)
				var tip = Vector3(sin(a)*radius,y+0.36,cos(a)*radius)
				trunk.beam(Vector3(0,y,0),middle,0.06-tier*0.006)
				trunk.beam(middle,tip,0.028-tier*0.002)
		tree_mesh = trunk.batches.wood.commit()
		trunk.free()
		for i in range(7): rock_scenes.append(load("res://assets/nature/rock-%d.glb" % i))

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
		# Keep the settlement readable without creating the old 72 m empty desert.
		# Trees/rocks may form a natural ring close to the village edge, but never
		# invade the civic core or authored building footprints.
		if for_tree and local.length() < 38.0: return false
		if local.length() < 76.0:
			for building in settlement_sites:
				if absf(local.x-building.x)<7.0 and absf(local.y-building.z)<7.0: return false
		if not for_tree and local.length() < 65.0:
			if absf(local.x) < 5.1 or (absf(local.x) < 47.0 and absf(local.y - 8.0) < 4.2): return false
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
	for angle in [0.0, PI * 0.5]:
		var basis = Basis(Vector3.UP, angle)
		for segment in range(1):
			for pair in [[0, 0], [0, 1], [1, 0], [0, 1], [1, 1], [1, 0]]:
				var y = float(segment + pair[0])
				surface.set_normal(basis * Vector3(0, 0.78, 0.62).normalized())
				surface.set_uv(Vector2(pair[1], 1.0-y))
				surface.add_vertex(basis * Vector3((float(pair[1]) - 0.5) * 0.26, y * 0.26-0.01, y * y * 0.018))
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
	for i in range([280, 440, 620][quality]):
		var p = corner + Vector2(rng.randf_range(0, GRASS_TILE), rng.randf_range(0, GRASS_TILE))
		if not clear_at(p, false): continue
		var basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.65, 1.4))
		transforms.append(Transform3D(basis, Vector3(p.x, terrain.height_at(p.x, p.y), p.y) - base))
		colors.append(Color(rng.randf(), rng.randf(), 0, 0))
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
	node.position = Vector3(corner.x,0,corner.y)
	var trees: Array[Transform3D] = []
	var needles: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in range([4,8,12][quality]):
		var p = corner + Vector2(rng.randf_range(4,76),rng.randf_range(4,76))
		if not clear_at(p,true): continue
		var at = Vector3(p.x-corner.x,terrain.height_at(p.x,p.y),p.y-corner.y)
		var scale_value = rng.randf_range(1.1,1.9)
		var tree_transform = Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_value),at)
		trees.append(tree_transform)
		for leaf in range([90,144,196][quality]):
			var tier = leaf % 7
			var a = rng.randf() * TAU
			var radius = rng.randf_range(0.18,3.25-tier*0.42)
			var local = Vector3(sin(a)*radius,3.0+tier*0.86+rng.randf_range(-0.24,0.30),cos(a)*radius)
			var basis = Basis.from_euler(Vector3(rng.randf_range(-0.70,0.70),a+PI*0.5,rng.randf_range(-0.22,0.22)))
			basis = basis.scaled(Vector3.ONE * lerpf(1.0,0.48,tier/6.0))
			needles.append(tree_transform * Transform3D(basis,local))
			colors.append(Color(rng.randf(),0,0,0))
		var body = StaticBody3D.new()
		var collider = CollisionShape3D.new()
		var shape = CylinderShape3D.new()
		shape.radius = 0.30 * scale_value
		shape.height = 8.0 * scale_value
		collider.shape = shape
		collider.position.y = shape.height * 0.5
		body.position = at
		body.add_child(collider)
		node.add_child(body)
	instance_batch(node,tree_mesh,trees,Surfaces.pbr("bark_brown_02",Color(0.68,0.63,0.54),0.65),[],true,1300.0)
	instance_batch(node,leaf_mesh,needles,leaf_material,colors,false,1100.0)
	# Real photogrammetry rocks sit on the rendered surface, with reusable materials.
	for i in range([1,2,3][quality]):
		var p = corner + Vector2(rng.randf_range(8,72),rng.randf_range(8,72))
		if not clear_at(p,true): continue
		var rock = rock_scenes[rng.randi_range(0,6)].instantiate()
		var bounds: AABB = ActorBounds(rock,Transform3D.IDENTITY)
		var scale_value = rng.randf_range(0.8,2.6)
		rock.scale = Vector3.ONE * scale_value
		rock.position = Vector3(p.x-corner.x,terrain.height_at(p.x,p.y)-bounds.position.y*scale_value-0.06,p.y-corner.y)
		rock.rotation.y = rng.randf() * TAU
		node.add_child(rock)
		dress_rock(rock)

func instance_batch(parent: Node3D, mesh: Mesh, transforms: Array[Transform3D], surface: Material, colors: Array[Color], shadows: bool, distance_value: float) -> void:
	var instances = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = not colors.is_empty()
	instances.mesh = mesh
	instances.instance_count = transforms.size()
	for i in range(transforms.size()):
		instances.set_instance_transform(i,transforms[i])
		if not colors.is_empty(): instances.set_instance_custom_data(i,colors[i])
	var visual = MultiMeshInstance3D.new()
	visual.multimesh = instances
	visual.material_override = surface
	visual.visibility_range_end = distance_value
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)

func ActorBounds(node: Node3D, transform_value: Transform3D) -> AABB:
	var transform_next = transform_value * node.transform
	var value = AABB()
	if node is MeshInstance3D: value = transform_next * node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var child_bounds = ActorBounds(child,transform_next)
			if child_bounds.size.length() > 0:
				value = value.merge(child_bounds) if value.size.length() > 0 else child_bounds
	return value

func dress_rock(node: Node3D) -> void:
	if node is MeshInstance3D:
		node.material_override = Surfaces.pbr("rock_moss",Color.WHITE,1.0,false)
		node.visibility_range_end = 700.0
		node.create_trimesh_collision()
	for child in node.get_children():
		if child is Node3D and child is not StaticBody3D: dress_rock(child)
