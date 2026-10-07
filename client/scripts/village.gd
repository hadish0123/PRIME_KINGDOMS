extends Node3D

const Actor = preload("res://scripts/actor.gd")
const Npc = preload("res://scripts/npc.gd")
const Architecture = preload("res://scripts/architecture.gd")
const Surfaces = preload("res://scripts/visual_materials.gd")
var village_id: String = ""
var population: Array[Node] = []
var palette: Dictionary = {}
var loaded_models: int = 0
var development_signature = ""
var building_root: Node3D
var building_nodes: Dictionary = {}
const SLOTS = {
	"keep":Vector3(0,0,-27), "farm":Vector3(31,0,33), "lumber_mill":Vector3(-39,0,-15),
	"quarry":Vector3(40,0,-38), "iron_mine":Vector3(38,0,-24), "market":Vector3(15,0,-8),
	"warehouse":Vector3(-25,0,-30), "barracks":Vector3(-26,0,8), "archery_range":Vector3(-40,0,25),
	"stable":Vector3(27,0,16), "siege_workshop":Vector3(39,0,4), "blacksmith":Vector3(-25,0,32),
	"academy":Vector3(22,0,-30), "hospital":Vector3(24,0,-45), "embassy":Vector3(-18,0,-46),
	"clan_hall":Vector3(17,0,-43), "watch_towers":Vector3(-51,0,-53), "walls":Vector3(51,0,0),
	"gatehouse":Vector3(0,0,53), "workshop":Vector3(-40,0,40), "training_grounds":Vector3(-38,0,-1),
	"commander_hall":Vector3(25,0,-15), "trading_post":Vector3(-13,0,-7), "granary":Vector3(39,0,46),
}


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
	road.set_shader_parameter("soil_normal", load("res://assets/textures/cobblestone_normal.jpg"))
	road.set_shader_parameter("soil_rough", load("res://assets/textures/cobblestone_rough.jpg"))
	road.set_shader_parameter("stone_map", load("res://assets/textures/cobblestone_diff.jpg"))
	road.set_shader_parameter("height_map", load("res://assets/textures/cobblestone_height.jpg"))
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
	if not owner:
		asset("inn", Vector3(0, 0, -27), 15.0)
		asset("house_1", Vector3(-25, 0, -23), 11.0, PI * 0.5)
		asset("house_2", Vector3(25, 0, -26), 10.0, -PI * 0.5)
		asset("house_3", Vector3(-26, 0, 6), 10.0, PI * 0.5)
		asset("house_1", Vector3(28, 0, 14), 10.0, -PI * 0.5)
		asset("blacksmith", Vector3(-27, 0, 32), 12.0, PI * 0.5)
	for at in [Vector3(-15,0,22),Vector3(12,0,26),Vector3(-12,0,-19)]: asset("house_1",at,5.5)
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
		cloth.set_shader_parameter("vertical",false)
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
		if owner and npc.role=="villager":
			var jobs = [Vector3(33,0.1,28),Vector3(-34,0.1,-15),Vector3(37,0.1,-33),Vector3(11,0.1,-6),Vector3(-20,0.1,31)]
			npc.home = jobs[npc.ordinal%jobs.size()]
			npc.position = npc.home
		population.append(npc)

func apply_development(kingdom: Dictionary) -> void:
	var active: Dictionary = {}
	for task in kingdom.tasks:
		if task.kind=="building": active[task.key]=true
	var signature = JSON.stringify(kingdom.buildings)+JSON.stringify(active)+str(kingdom.realm.rank)
	if signature==development_signature: return
	development_signature=signature
	if is_instance_valid(building_root):
		remove_child(building_root)
		building_root.queue_free()
	building_nodes.clear()
	building_root=Node3D.new()
	add_child(building_root)
	for key in SLOTS:
		var level_value = int(kingdom.buildings.get(key,0))
		var architecture = Architecture.new()
		architecture.set_meta("building_key",key)
		building_root.add_child(architecture)
		architecture.position=SLOTS[key]
		building_nodes[key]=architecture
		architecture.begin()
		if key in ["walls","watch_towers","gatehouse"]:
			# Existing defensive silhouettes are selected through their upgrade stations.
			architecture.block(Vector3(3,0.15,3),Vector3(0,0.1,0),"stone")
			architecture.collision(Vector3(3,3,3),Vector3(0,1.5,0))
		elif level_value==0:
			# Surveyed building sites are part of construction gameplay.
			architecture.block(Vector3(7,0.12,6),Vector3(0,0.06,0),"stone")
			for x in [-3,3]:
				for z in [-2.5,2.5]: architecture.cylinder(0.08,1.1,Vector3(x,0.55,z),"wood")
			architecture.collision(Vector3(7,0.25,6),Vector3(0,0.13,0))
		elif key=="keep":
			if level_value<4: architecture.house(11,9,1,1)
			else:
				architecture.keep(12,10)
				if level_value>=12:
					for side in [-1,1]: architecture.tower(1.8,13,Vector3(side*9,0,-4),false)
				if level_value>=20:
					for side in [-1,1]: architecture.block(Vector3(4,7,10),Vector3(side*8,3.5,0),"stone")
		elif key in ["market","trading_post"]:
			architecture.market()
			if level_value>=5:
				architecture.position.x+=1
				architecture.house(5,5,1,1)
		elif key=="farm":
			architecture.house(5,4,1,1)
			architecture.fence()
		elif key in ["quarry","iron_mine"]:
			architecture.house(5,5,1,1)
			for index in range(4): architecture.block(Vector3(1.5,1.2,1.4),Vector3(index%2*2-2,0.6,5+index/2*2),"stone" if key=="quarry" else "iron")
		else:
			architecture.house(7.4,6.3,2 if level_value>=6 else 1,key.hash())
			if level_value>=14: architecture.tower(0.9,8,Vector3(3,0,-2),true)
		if active.has(key):
			for x in [-4,4]:
				for z in [-3.5,3.5]: architecture.beam(Vector3(x,0,z),Vector3(x,8,z),0.11)
			for y in [2,4,6]:
				architecture.beam(Vector3(-4,y,3.5),Vector3(4,y,3.5),0.10)
				architecture.block(Vector3(8,0.12,0.9),Vector3(0,y,3.5),"wood")
		architecture.finish()
		if key in ["blacksmith","keep"] and level_value>0:
			var smoke=CPUParticles3D.new()
			smoke.amount=8
			smoke.lifetime=4
			smoke.visibility_aabb=AABB(Vector3(-3,0,-3),Vector3(6,12,6))
			smoke.position=Vector3(1,5,0)
			smoke.direction=Vector3(0,1,0)
			smoke.initial_velocity_min=0.7
			smoke.initial_velocity_max=1.2
			smoke.gravity=Vector3(0,0.1,0)
			smoke.scale_amount_min=0.15
			smoke.scale_amount_max=0.4
			smoke.color=Color(0.33,0.33,0.31,0.2)
			var puff=SphereMesh.new()
			puff.radius=0.3
			puff.height=0.6
			var material=StandardMaterial3D.new()
			material.albedo_color=Color(0.4,0.4,0.38,0.16)
			material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			puff.material=material
			smoke.mesh=puff
			architecture.add_child(smoke)
