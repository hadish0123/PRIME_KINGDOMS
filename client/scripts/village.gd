extends Node3D

const Actor = preload("res://scripts/actor.gd")
const Npc = preload("res://scripts/npc.gd")
var village_id: String = ""
var population: Array[Node] = []
var palette: Dictionary = {}
var loaded_models: int = 0

func update_population(viewer: Vector3, simulation_distance: float) -> void:
	for npc in population: npc.update_presence(viewer, simulation_distance)

func material(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var value = StandardMaterial3D.new()
	value.albedo_color = color
	value.roughness = roughness
	return value

func box(size_value: Vector3, at: Vector3, surface: Material, solid: bool = false) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size_value
	var visual = MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = surface
	visual.position = at
	add_child(visual)
	if solid:
		var body = StaticBody3D.new()
		var shape = BoxShape3D.new()
		shape.size = size_value
		var collision = CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
		body.position = at
	return visual

func asset(asset_name: String, at: Vector3, width: float, angle: float = 0.0, solid: bool = true) -> Node3D:
	var model = load("res://assets/village/" + asset_name + ".glb").instantiate()
	loaded_models += 1
	var helper = Actor.new()
	var bounds = helper.model_bounds(model, Transform3D.IDENTITY)
	helper.free()
	var factor = width / maxf(bounds.size.x, bounds.size.z)
	var container = Node3D.new()
	add_child(container)
	container.position = at
	container.rotation.y = angle
	container.add_child(model)
	model.scale *= factor
	model.position = Vector3(-bounds.get_center().x * factor, -bounds.position.y * factor, -bounds.get_center().z * factor)
	if solid:
		var body = StaticBody3D.new()
		var collision = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(bounds.size.x * factor * 0.88, bounds.size.y * factor * 0.7, bounds.size.z * factor * 0.88)
		collision.shape = shape
		collision.position.y = shape.size.y * 0.5
		body.add_child(collision)
		container.add_child(body)
	return container

func configure(data: Dictionary, origin: Vector3, owner: bool) -> void:
	village_id = str(data.id)
	var p: Dictionary = data.position
	position = Vector3(float(p.x), float(p.y), float(p.z)) - origin
	var road = ShaderMaterial.new()
	road.shader = load("res://shaders/road.gdshader")
	palette.road = road
	palette.wood = material(Color(0.23, 0.14, 0.08))
	palette.gold = material(Color(0.66, 0.47, 0.20), 0.48)
	palette.soil = material(Color(0.25, 0.20, 0.13))
	box(Vector3(8, 0.055, 112), Vector3(0, 0.025, 4), palette.road)
	box(Vector3(92, 0.05, 6), Vector3(0, 0.02, 8), palette.road)
	var square = MeshInstance3D.new()
	var plaza = CylinderMesh.new()
	plaza.top_radius = 9
	plaza.bottom_radius = 9
	plaza.height = 0.065
	plaza.radial_segments = 48
	square.mesh = plaza
	square.material_override = palette.road
	square.position.y = 0.04
	add_child(square)
	asset("inn", Vector3(0, 0, -27), 15.0, PI)
	asset("house_1", Vector3(-25, 0, -23), 11.0, PI * 0.5)
	asset("house_2", Vector3(25, 0, -26), 10.0, -PI * 0.5)
	asset("house_3", Vector3(-26, 0, 6), 10.0, PI * 0.5)
	asset("house_1", Vector3(28, 0, 14), 10.0, -PI * 0.5)
	asset("blacksmith", Vector3(-27, 0, 32), 12.0, PI * 0.5)
	asset("well", Vector3(0, 0.1, 0), 3.3)
	asset("market_stand_1", Vector3(12, 0, -7), 4.5, -PI * 0.5)
	asset("market_stand_2", Vector3(-12, 0, -7), 4.2, PI * 0.5)
	asset("cart", Vector3(17, 0, 12), 3.4, PI * 0.25)
	for x in [-7.0, 7.0]:
		box(Vector3(0.2, 5.4, 0.2), Vector3(x, 2.7, 42), palette.wood, true)
		box(Vector3(1.9, 2.2, 0.07), Vector3(x + 0.9, 4.1, 42), material(Color(0.06, 0.16, 0.22)))
		box(Vector3(0.4, 1.1, 0.1), Vector3(x + 0.9, 4.1, 42.05), palette.gold)
	for index in range(11):
		for side in [-1, 1]:
			asset("fence", Vector3(side * 47, 0, -39 + index * 8), 7.7, PI * 0.5)
	for index in range(6):
		box(Vector3(11, 0.08, 0.35), Vector3(31, 0.04, 29 + index * 1.7), palette.soil)
	var name_label = Label3D.new()
	name_label.text = str(data.name) + ("  •  YOUR VILLAGE" if owner else "")
	name_label.position = Vector3(0, 10, -27)
	name_label.font_size = 48
	name_label.pixel_size = 0.011
	name_label.modulate = Color(0.90, 0.83, 0.61)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.visibility_range_end = 75.0
	add_child(name_label)
	for npc_data in data.npcs:
		var npc = Npc.new()
		add_child(npc)
		var n: Dictionary = npc_data.position
		npc.setup(npc_data, Vector3(float(n.x) - float(p.x), float(n.y) - float(p.y), float(n.z) - float(p.z)))
		population.append(npc)
