extends Node3D

const Surfaces = preload("res://scripts/visual_materials.gd")
var batches: Dictionary = {}
var mats: Dictionary = {}

func begin() -> void:
	mats.wood = Surfaces.pbr("wood_planks", Color(0.65, 0.53, 0.39), 0.7)
	mats.plaster = Surfaces.pbr("rough_plaster_03", Color(0.91, 0.85, 0.72), 0.22)
	mats.plaster.normal_scale = 0.22
	mats.stone = Surfaces.pbr("stone_wall_02", Color(0.78, 0.79, 0.74), 0.32)
	mats.roof = Surfaces.pbr("grey_roof_tiles", Color(0.61, 0.67, 0.71), 0.28)
	mats.iron = Surfaces.plain(Color(0.20, 0.23, 0.25), 0.56, 0.8)
	mats.dark = Surfaces.plain(Color(0.025, 0.033, 0.035))
	mats.fabric = Surfaces.pbr("rough_linen", Color(0.54, 0.31, 0.15), 0.6)
	mats.water = Surfaces.plain(Color(0.065, 0.12, 0.14), 0.16, 0.28)
	mats.slate = Surfaces.plain(Color(0.20, 0.26, 0.30), 0.77)
	mats.gold = Surfaces.plain(Color(0.57, 0.40, 0.16), 0.35, 0.8)

func piece(mesh: Mesh, at: Vector3, material_name: String, rotation_value: Vector3 = Vector3.ZERO) -> void:
	var surface: SurfaceTool
	if not batches.has(material_name):
		surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches[material_name] = surface
	else: surface = batches[material_name]
	surface.append_from(mesh, 0, Transform3D(Basis.from_euler(rotation_value), at))

func block(size_value: Vector3, at: Vector3, material_name: String, rotation_value: Vector3 = Vector3.ZERO) -> void:
	var mesh = BoxMesh.new()
	mesh.size = size_value
	piece(mesh, at, material_name, rotation_value)

func cylinder(radius: float, height: float, at: Vector3, material_name: String, rotation_value: Vector3 = Vector3.ZERO) -> void:
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	piece(mesh, at, material_name, rotation_value)

func cone(radius: float, height: float, at: Vector3, material_name: String) -> void:
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.035
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	piece(mesh, at, material_name)

func beam(from: Vector3, to: Vector3, thickness: float, material_name: String = "wood") -> void:
	var direction = to - from
	var mesh = CylinderMesh.new()
	mesh.top_radius = thickness
	mesh.bottom_radius = thickness
	mesh.height = direction.length()
	mesh.radial_segments = 6
	var basis = Basis(Quaternion(Vector3.UP, direction.normalized()))
	if not batches.has(material_name):
		var surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches[material_name] = surface
	batches[material_name].append_from(mesh, 0, Transform3D(basis, (from + to) * 0.5))

func finish() -> void:
	for key in batches:
		var visual = MeshInstance3D.new()
		visual.mesh = batches[key].commit()
		visual.material_override = mats[key]
		visual.visibility_range_end = 1000.0
		add_child(visual)
	batches.clear()

func collision(size_value: Vector3, at: Vector3) -> void:
	var body = StaticBody3D.new()
	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size_value
	collider.shape = shape
	body.add_child(collider)
	body.position = at
	add_child(body)

func house(width: float, depth: float, levels: int, variant: int) -> void:
	var height = 3.2 * levels
	block(Vector3(width + 0.18, 0.65, depth + 0.18), Vector3(0, 0.325, 0), "stone")
	block(Vector3(width, height - 0.5, depth), Vector3(0, (height + 0.5) * 0.5, 0), "plaster")
	collision(Vector3(width, height, depth), Vector3(0, height * 0.5, 0))
	for y in [0.65, 3.15, height]:
		block(Vector3(width + 0.16, 0.19, depth + 0.16), Vector3(0, y, 0), "wood")
	for x in [-width * 0.5, 0, width * 0.5]:
		for z in [-depth * 0.5, depth * 0.5]:
			block(Vector3(0.20, height, 0.20), Vector3(x, height * 0.5, z), "wood")
	for z in [-depth * 0.5, 0, depth * 0.5]:
		for x in [-width * 0.5, width * 0.5]:
			block(Vector3(0.20, height, 0.20), Vector3(x, height * 0.5, z), "wood")
	# Thick gable slabs, ridge, rafters and eaves have real silhouettes and shadows.
	var rise = width * 0.37
	var span = width * 0.5 + 0.55
	var roof_length = Vector2(span, rise).length()
	var slope = atan2(rise, span)
	for side in [-1, 1]:
		block(Vector3(roof_length, 0.16, depth + 1.1), Vector3(side * span * 0.5, height + rise * 0.5, 0), "roof", Vector3(0, 0, -side * slope))
		block(Vector3(0.15, 0.24, depth + 1.15), Vector3(side * span, height - 0.05, 0), "wood")
		for z in [-depth * 0.5 - 0.50, depth * 0.5 + 0.50]:
			beam(Vector3(0, height + rise, z), Vector3(side * span, height - 0.05, z), 0.09)
	block(Vector3(0.20, 0.20, depth + 1.2), Vector3(0, height + rise, 0), "wood")
	for z in [-depth * 0.5, depth * 0.5]:
		var triangle = SurfaceTool.new()
		triangle.begin(Mesh.PRIMITIVE_TRIANGLES)
		triangle.set_normal(Vector3(0, 0, signf(z)))
		var points = [Vector3(-width * 0.5, height, z), Vector3(0, height + rise, z), Vector3(width * 0.5, height, z)]
		if z < 0: points.reverse()
		for p in points:
			triangle.set_uv(Vector2(p.x, p.y))
			triangle.add_vertex(p)
		# Material batches already use indexed meshes; unindexed appended triangles
		# otherwise have no indices in the combined surface and disappear.
		triangle.index()
		piece(triangle.commit(), Vector3.ZERO, "plaster")
		beam(Vector3(-width * 0.5, 0.8, z * 1.015), Vector3(-0.15, minf(3.0, height), z * 1.015), 0.075)
		beam(Vector3(width * 0.5, 0.8, z * 1.015), Vector3(0.15, minf(3.0, height), z * 1.015), 0.075)
	# Door planks, iron hinges and a sheltered stone threshold.
	var front = depth * 0.5 + 0.04
	block(Vector3(1.42, 2.45, 0.15), Vector3(0, 1.44, front), "wood")
	for x in [-0.72, 0.72]: block(Vector3(0.14, 2.6, 0.24), Vector3(x, 1.45, front), "wood")
	for y in [0.6, 1.7]: block(Vector3(1.35, 0.07, 0.035), Vector3(0, y, front + 0.085), "iron")
	cylinder(0.045, 0.10, Vector3(0.48, 1.28, front + 0.13), "iron", Vector3(PI * 0.5, 0, 0))
	for step in range(3): block(Vector3(1.9, 0.12, 0.6), Vector3(0, 0.06 + step * 0.12, front + 1.5 - step * 0.45), "stone")
	for level in range(levels):
		for x in [-width * 0.30, width * 0.30]:
			for z in [-depth * 0.5 - 0.05, depth * 0.5 + 0.05]:
				var y = 2.0 + level * 3.2
				block(Vector3(1.16, 1.40, 0.10), Vector3(x, y, z), "dark")
				for dx in [-0.62, 0, 0.62]: block(Vector3(0.07, 1.58, 0.16), Vector3(x + dx, y, z), "wood")
				for dy in [-0.77, 0, 0.77]: block(Vector3(1.35, 0.07, 0.16), Vector3(x, y + dy, z), "wood")
				for side in [-1, 1]: block(Vector3(0.35, 1.40, 0.10), Vector3(x + side * 0.94, y, z), "wood", Vector3(0, side * 0.2, 0))
	block(Vector3(1.0, 3.8, 1.15), Vector3(width * 0.28, height + rise - 0.2, -depth * 0.20), "stone")
	block(Vector3(1.15, 0.18, 1.30), Vector3(width * 0.28, height + rise + 1.78, -depth * 0.20), "stone")
	if variant % 2 == 0:
		for i in range(7):
			cylinder(0.13, 1.8, Vector3(width * 0.5 + 0.22 + (i % 3) * 0.22, 0.14 + int(i / 3) * 0.21, 0.8), "wood", Vector3(PI * 0.5, 0, 0))
	# Broken roof edges and overlap cast a silhouette instead of a single flat slab.
	for side in [-1, 1]:
		for row in range(7):
			var t = (row + 0.5) / 7.0
			var x = side * span * t
			var y = height + rise * (1.0 - t) + 0.10
			for column in range(ceili(depth / 0.64)):
				var z = -depth * 0.5 + column * 0.64 + 0.30
				block(Vector3(roof_length / 7.0 + 0.055, 0.047, 0.60), Vector3(x, y, z), "slate", Vector3(0, 0, -side * slope))
	# Corner ashlar, balcony, gutters, brackets and a recessed attic window.
	for x in [-width * 0.5, width * 0.5]:
		for z in [-depth * 0.5, depth * 0.5]:
			for row in range(ceili(height / 0.48)):
				block(Vector3(0.38 if row % 2 else 0.62, 0.43, 0.40), Vector3(x, row * 0.48 + 0.22, z), "stone")
	for z in [-depth * 0.5 - 0.05, depth * 0.5 + 0.05]:
		block(Vector3(0.78, 0.95, 0.10), Vector3(0, height + rise * 0.34, z), "dark")
		for x in [-0.45, 0.45]: block(Vector3(0.08, 1.08, 0.13), Vector3(x, height + rise * 0.34, z), "wood")
	if levels > 1:
		block(Vector3(width * 0.65, 0.18, 1.30), Vector3(0, 3.31, front + 0.48), "wood")
		for i in range(8):
			block(Vector3(0.075, 0.82, 0.075), Vector3(-width * 0.31 + i * width * 0.62 / 7.0, 3.80, front + 1.0), "wood")
		block(Vector3(width * 0.69, 0.09, 0.09), Vector3(0, 4.25, front + 1.0), "wood")

func well() -> void:
	for i in range(16):
		var a = i * TAU / 16.0
		block(Vector3(0.45, 0.85, 0.32), Vector3(sin(a) * 0.95, 0.43, cos(a) * 0.95), "stone", Vector3(0, a, 0))
	cylinder(0.76, 0.03, Vector3(0, 0.2, 0), "water")
	for x in [-1.2, 1.2]: block(Vector3(0.16, 3.2, 0.16), Vector3(x, 1.6, 0), "wood")
	block(Vector3(2.8, 0.16, 1.9), Vector3(0, 3.10, 0), "roof")
	cylinder(0.13, 2.6, Vector3(0, 1.8, 0), "wood", Vector3(0, 0, PI * 0.5))
	beam(Vector3(0.15, 1.8, 0), Vector3(0.15, 0.65, 0), 0.017)
	collision(Vector3(2.1, 0.9, 2.1), Vector3(0, 0.45, 0))

func fence() -> void:
	for x in [-3.5, 0, 3.5]: block(Vector3(0.18, 1.5, 0.18), Vector3(x, 0.75, 0), "wood")
	for y in [0.5, 1.15]: block(Vector3(7.7, 0.16, 0.12), Vector3(0, y, 0), "wood")
	beam(Vector3(-3.5, 0.45, 0), Vector3(0, 1.2, 0), 0.055)
	beam(Vector3(0, 1.2, 0), Vector3(3.5, 0.45, 0), 0.055)
	collision(Vector3(7.7, 1.5, 0.22), Vector3(0, 0.75, 0))

func market() -> void:
	for x in [-1.7, 1.7]:
		for z in [-0.8, 0.8]: block(Vector3(0.10, 2.5, 0.10), Vector3(x, 1.25, z), "wood")
	block(Vector3(3.5, 0.16, 1.5), Vector3(0, 0.9, 0), "wood")
	block(Vector3(3.9, 0.04, 2.15), Vector3(0, 2.5, 0), "fabric", Vector3(0.12, 0, 0))
	for i in range(6):
		block(Vector3(0.43, 0.18, 0.65), Vector3(-1.4 + i * 0.55, 1.07, 0), "wood")
		for k in range(3): cylinder(0.09, 0.09, Vector3(-1.4 + i * 0.55, 1.20, -0.20 + k * 0.20), "fabric")
	collision(Vector3(3.5, 0.95, 1.5), Vector3(0, 0.475, 0))

func cart() -> void:
	block(Vector3(1.5, 0.16, 2.5), Vector3(0, 0.75, 0), "wood")
	for x in [-0.8, 0.8]:
		block(Vector3(0.12, 0.65, 2.5), Vector3(x, 1.0, 0), "wood")
		for z in [-0.85, 0.85]:
			cylinder(0.45, 0.09, Vector3(x + signf(x) * 0.18, 0.48, z), "wood", Vector3(0, 0, PI * 0.5))
	for x in [-0.55, 0.55]: block(Vector3(0.10, 0.10, 2.8), Vector3(x, 0.65, 2.15), "wood")
	collision(Vector3(2.0, 1.3, 2.5), Vector3(0, 0.65, 0))

func barrel(at: Vector3, radius: float = 0.37) -> void:
	for ring in range(6):
		var y = float(ring) / 5.0
		cylinder(radius * (0.86 + sin(y * PI) * 0.14), 0.16, at + Vector3(0, y * 0.75 + 0.08, 0), "wood")
	for y in [0.12, 0.67]: cylinder(radius + 0.013, 0.045, at + Vector3(0, y, 0), "iron")

func tower(radius: float, height: float, at: Vector3, roofed: bool = false) -> void:
	cylinder(radius + 0.28, 0.6, at + Vector3(0, 0.3, 0), "stone")
	cylinder(radius, height, at + Vector3(0, height * 0.5, 0), "stone")
	for y in [1.1, height * 0.5, height - 0.25]: cylinder(radius + 0.12, 0.20, at + Vector3(0, y, 0), "stone")
	for i in range(8):
		var a = i * TAU / 8.0
		var p = at + Vector3(sin(a) * radius, height * 0.58, cos(a) * radius)
		block(Vector3(0.24, 1.35, 0.08), p, "dark", Vector3(0, a, 0))
	if roofed:
		cone(radius + 0.38, radius * 2.5, at + Vector3(0, height + radius * 1.25, 0), "roof")
		cone(0.10, 0.70, at + Vector3(0, height + radius * 2.5 + 0.35, 0), "gold")
	else:
		cylinder(radius + 0.20, 0.45, at + Vector3(0, height + 0.05, 0), "stone")
		for i in range(12):
			var a = i * TAU / 12.0
			block(Vector3(0.64, 0.9, 0.60), at + Vector3(sin(a) * radius, height + 0.65, cos(a) * radius), "stone", Vector3(0, a, 0))
	collision(Vector3(radius * 1.7, height, radius * 1.7), at + Vector3(0, height * 0.5, 0))

func wall(length_value: float, height: float = 5.5) -> void:
	block(Vector3(length_value, height, 1.6), Vector3(0, height * 0.5, 0), "stone")
	block(Vector3(length_value + 0.2, 0.25, 1.95), Vector3(0, height - 0.25, 0), "stone")
	block(Vector3(length_value, 0.26, 2.0), Vector3(0, 0.13, 0), "stone")
	for i in range(ceili(length_value / 1.8)):
		block(Vector3(0.9, 0.86, 1.7), Vector3(-length_value * 0.5 + i * 1.8 + 0.45, height + 0.43, 0), "stone")
	for i in range(ceili(length_value / 9.0)):
		block(Vector3(0.65, height * 0.70, 2.2), Vector3(-length_value * 0.5 + i * 9.0 + 2.0, height * 0.35, 0), "stone")
	collision(Vector3(length_value, height + 0.75, 1.65), Vector3(0, (height + 0.75) * 0.5, 0))

func gate() -> void:
	for side in [-1, 1]: tower(2.25, 9.2, Vector3(side * 7.0, 0, 0), false)
	block(Vector3(9.4, 2.1, 2.6), Vector3(0, 7.1, 0), "stone")
	collision(Vector3(9.4, 2.1, 2.6), Vector3(0, 7.1, 0))
	for i in range(10):
		var a = i * PI / 9.0
		block(Vector3(0.62, 0.65, 2.65), Vector3(cos(a) * 4.0, 4.0 + sin(a) * 2.1, 0), "stone", Vector3(0, 0, a - PI * 0.5))
	for side in [-1, 1]:
		block(Vector3(0.24, 3.0, 0.18), Vector3(side * 4.35, 2.2, 0.6), "iron")
	for i in range(9): block(Vector3(0.06, 0.9, 0.08), Vector3(-3.6 + i * 0.9, 5.7, 0.70), "iron")
	for i in range(5): block(Vector3(0.92, 0.86, 2.7), Vector3(-3.7 + i * 1.85, 8.55, 0), "stone")

func keep(width: float, depth: float) -> void:
	# The ruler's hall is a compact stone keep; existing spawn routes remain clear.
	house(width, depth, 2, 3)
	for side in [-1, 1]:
		tower(1.40, 11.5, Vector3(side * (width * 0.5 - 0.65), 0, -depth * 0.35), true)
		tower(1.05, 9.7, Vector3(side * (width * 0.5 - 0.35), 0, depth * 0.35), true)
	block(Vector3(width * 0.65, 0.25, 1.35), Vector3(0, 5.4, depth * 0.5 + 0.65), "stone")
	for i in range(7): block(Vector3(0.10, 1.0, 0.12), Vector3(-width * 0.28 + i * width * 0.56 / 6.0, 5.96, depth * 0.5 + 1.2), "iron")
	for x in [-width * 0.21, width * 0.21]:
		block(Vector3(1.1, 2.5, 0.1), Vector3(x, 4.4, depth * 0.5 + 0.11), "dark")
		for y in [3.20, 5.65]: block(Vector3(1.35, 0.18, 0.22), Vector3(x, y, depth * 0.5 + 0.12), "stone")

func props() -> void:
	for p in [Vector3(0,0,0), Vector3(0.9,0,0.3), Vector3(-0.7,0,0.5)]: barrel(p)
	block(Vector3(0.95, 0.9, 0.95), Vector3(1.4, 0.45, -0.9), "wood")
	for z in [-1.36, -0.44]:
		for y in [0.15, 0.78]: block(Vector3(1.0, 0.09, 0.05), Vector3(1.4, y, z), "iron")

func bench() -> void:
	block(Vector3(2.4,0.15,0.64),Vector3(0,0.53,0),"wood")
	for x in [-0.91,0.91]:
		for z in [-0.22,0.22]: block(Vector3(0.13,0.51,0.13),Vector3(x,0.255,z),"wood")
		block(Vector3(0.10,0.84,0.10),Vector3(x,0.70,-0.31),"wood")
	for y in [0.80,1.03]: block(Vector3(2.4,0.16,0.09),Vector3(0,y,-0.31),"wood")
	collision(Vector3(2.4,0.60,0.7),Vector3(0,0.30,0))

func build(asset_name: String, width: float) -> void:
	begin()
	if asset_name == "fence": fence()
	elif asset_name == "well": well()
	elif asset_name.begins_with("market"): market()
	elif asset_name == "cart": cart()
	elif asset_name == "wall": wall(width)
	elif asset_name == "gate": gate()
	elif asset_name == "tower": tower(width * 0.5, 8.5, Vector3.ZERO, false)
	elif asset_name == "props": props()
	elif asset_name == "bench": bench()
	elif asset_name == "inn": keep(width * 0.78, width * 0.68)
	else:
		var levels = 2 if asset_name in ["inn", "house_2"] else 1
		house(width * 0.78, width * 0.68, levels, asset_name.hash())
	finish()
