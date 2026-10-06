extends Node3D

const Actor = preload("res://scripts/actor.gd")
const Npc = preload("res://scripts/npc.gd")
const Architecture = preload("res://scripts/architecture.gd")
const Surfaces = preload("res://scripts/visual_materials.gd")
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
	var model = Architecture.new()
	model.name = asset_name
	loaded_models += 1
	add_child(model)
	model.position = at
	model.rotation.y = angle
	model.build(asset_name, width)
	return model

func configure(data: Dictionary, origin: Vector3, owner: bool) -> void:
	village_id = str(data.id)
	var p: Dictionary = data.position
	position = Vector3(float(p.x), float(p.y), float(p.z)) - origin
	var road = ShaderMaterial.new()
	road.shader = load("res://shaders/road.gdshader")
	road.set_shader_parameter("soil_map", load("res://assets/textures/brown_mud_diff.jpg"))
	road.set_shader_parameter("soil_normal", load("res://assets/textures/brown_mud_normal.jpg"))
	road.set_shader_parameter("soil_rough", load("res://assets/textures/brown_mud_rough.jpg"))
	road.set_shader_parameter("stone_map", load("res://assets/textures/rocky_terrain_02_diff.jpg"))
	palette.road = road
	palette.wood = Surfaces.pbr("wood_planks", Color(0.58, 0.46, 0.33), 0.7)
	palette.gold = material(Color(0.66, 0.47, 0.20), 0.48)
	palette.soil = Surfaces.pbr("brown_mud", Color(0.75, 0.68, 0.58))
	box(Vector3(8, 0.055, 112), Vector3(0, 0.025, 4), palette.road).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cross_road = road.duplicate()
	cross_road.set_shader_parameter("half_size",Vector2(46,3))
	box(Vector3(92, 0.05, 6), Vector3(0, 0.02, 8), cross_road).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var square = MeshInstance3D.new()
	var plaza = CylinderMesh.new()
	plaza.top_radius = 9
	plaza.bottom_radius = 9
	plaza.height = 0.065
	plaza.radial_segments = 48
	square.mesh = plaza
	square.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plaza_material = road.duplicate()
	plaza_material.set_shader_parameter("half_size",Vector2(9,9))
	plaza_material.set_shader_parameter("round_patch",true)
	square.material_override = plaza_material
	square.position.y = 0.04
	add_child(square)
	asset("inn", Vector3(0, 0, -27), 15.0)
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
		var banner = PlaneMesh.new()
		banner.size = Vector2(1.9, 2.2)
		banner.subdivide_width = 10
		banner.subdivide_depth = 8
		var cloth = ShaderMaterial.new()
		cloth.shader = load("res://shaders/cloth.gdshader")
		cloth.set_shader_parameter("albedo_map", load("res://assets/textures/rough_linen_diff.jpg"))
		cloth.set_shader_parameter("tint",Color(0.33,0.025,0.040))
		cloth.set_shader_parameter("heraldry",load("res://assets/heraldry/lion.svg"))
		cloth.set_shader_parameter("royal",true)
		cloth.set_shader_parameter("vertical",true)
		var flag = MeshInstance3D.new()
		flag.mesh = banner
		flag.material_override = cloth
		flag.position = Vector3(x + 0.9, 4.1, 42)
		flag.rotation.x = PI * 0.5
		add_child(flag)
	# The stone enclosure leaves the existing central road and all resident homes clear.
	for side in [-1, 1]:
		asset("wall", Vector3(side * 51, 0, 0), 106.0, PI * 0.5)
		for z in [-53.0, 53.0]: asset("tower", Vector3(side * 51, 0, z), 5.0)
	asset("wall", Vector3(0, 0, -53), 102.0)
	for side in [-1, 1]: asset("wall", Vector3(side * 29, 0, 53), 44.0)
	asset("gate", Vector3(0, 0, 53), 16.0)
	for at in [Vector3(-19,0,-15), Vector3(20,0,-17), Vector3(-18,0,31), Vector3(33,0,6)]:
		asset("props", at, 3.5)
	for index in range(3): asset("fence", Vector3(31,0,25 + index * 10), 7.7)
	for at in [Vector3(-17,0,-6),Vector3(16,0,3),Vector3(-18,0,17),Vector3(19,0,23),Vector3(38,0,-31),Vector3(-35,0,38)]:
		asset("bench", at, 2.4)
	for index in range(6):
		box(Vector3(11, 0.08, 0.35), Vector3(31, 0.04, 29 + index * 1.7), palette.soil)
	var name_label = Label3D.new()
	name_label.text = str(data.name) + ("  •  YOUR VILLAGE" if owner else "")
	name_label.position = Vector3(0, 21.0, -27)
	name_label.font_size = 48
	name_label.pixel_size = 0.011
	name_label.modulate = Color(0.90, 0.83, 0.61)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.visibility_range_end = 35.0
	add_child(name_label)
	for npc_data in data.npcs:
		var npc = Npc.new()
		add_child(npc)
		var n: Dictionary = npc_data.position
		npc.setup(npc_data, Vector3(float(n.x) - float(p.x), float(n.y) - float(p.y), float(n.z) - float(p.z)))
		population.append(npc)
