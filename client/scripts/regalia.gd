extends RefCounted

const Surfaces = preload("res://scripts/visual_materials.gd")
var skeleton: Skeleton3D
var role = "player"
var variant = 0
var batches: Dictionary = {}
var materials: Dictionary = {}
var held_weapon: Node3D
var stowed_weapon: Node3D

func prepare(target: Skeleton3D, kind: String, appearance: int = 0) -> void:
	skeleton = target
	role = kind
	variant = appearance
	materials.steel = metal(Color(0.68,0.70,0.73) if role == "player" else Color(0.45,0.48,0.49))
	materials.gold = metal(Color(0.90,0.63,0.15),true)
	materials.leather = Surfaces.plain(Color(0.082,0.044,0.022),0.83)
	materials.dark = Surfaces.plain(Color(0.018,0.022,0.028),0.78)
	materials.hair = Surfaces.plain(Color(0.052,0.030,0.020),0.88)
	materials.crimson = Surfaces.plain(Color(0.33,0.014,0.025),0.76)
	for side in ["L","R"]:
		boots(side)
		if role != "villager": limbs(side)
	if role == "villager":
		belt()
	else:
		cuirass()
		if role == "player": royal_tabard()
		headpiece()
		cape()
	flush()
	if role != "villager":
		weapon()
		var equipment = flush()
		held_weapon = equipment.get("wrist.R")
		if role == "player":
			var grip = (rest("wrist.R")-rest("lowerarm01.R")).normalized()
			stowed_weapon = Node3D.new()
			stowed_weapon.position = Vector3(0.26,-0.07,-0.02)
			stowed_weapon.basis = Basis(Quaternion(grip,Vector3.DOWN))
			attach("spine03").add_child(stowed_weapon)
			var sword = MeshInstance3D.new()
			sword.mesh = held_weapon.get_child(0).mesh
			stowed_weapon.add_child(sword)
			box("spine03",Vector3(0.055,0.83,0.04),Vector3(0.26,-0.57,-0.02),"leather")
			box("spine03",Vector3(0.060,0.035,0.045),Vector3(0.26,-0.17,-0.02),"gold")
			box("spine03",Vector3(0.060,0.050,0.045),Vector3(0.26,-0.96,-0.02),"gold")
			flush()
			set_weapon_drawn(false)

func set_weapon_drawn(value: bool) -> void:
	if is_instance_valid(held_weapon): held_weapon.visible = value
	if is_instance_valid(stowed_weapon): stowed_weapon.visible = not value

static func metal(color_value: Color, gilded: bool = false) -> ShaderMaterial:
	var key = "metal:%s:%s" % [color_value,gilded]
	if Surfaces.cache.has(key): return Surfaces.cache[key]
	var surface = ShaderMaterial.new()
	surface.shader = load("res://shaders/metal.gdshader")
	surface.set_shader_parameter("color",color_value)
	surface.set_shader_parameter("gilded",1.0 if gilded else 0.0)
	Surfaces.cache[key] = surface
	return surface

func rest(bone: String) -> Vector3:
	return skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin

func piece(bone: String, mesh: Mesh, at: Vector3, surface: String, basis: Basis = Basis.IDENTITY) -> void:
	if not batches.has(bone): batches[bone] = {}
	if not batches[bone].has(surface):
		var builder = SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches[bone][surface] = builder
	batches[bone][surface].append_from(mesh,0,Transform3D(basis,at))

func box(bone: String, size_value: Vector3, at: Vector3, surface: String, basis: Basis = Basis.IDENTITY) -> void:
	var mesh = BoxMesh.new()
	mesh.size = size_value
	piece(bone,mesh,at,surface,basis)

func sphere(bone: String, radius: float, at: Vector3, surface: String, scale_value: Vector3 = Vector3.ONE) -> void:
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	piece(bone,mesh,at,surface,Basis.IDENTITY.scaled(scale_value))

func tube(bone: String, radius: float, height: float, at: Vector3, surface: String, basis: Basis = Basis.IDENTITY, top: float = -1.0, capped: bool = true) -> void:
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius if top < 0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.cap_top = capped
	mesh.cap_bottom = capped
	piece(bone,mesh,at,surface,basis)

func ring(bone: String, radius: float, thickness: float, at: Vector3, surface: String, basis: Basis = Basis.IDENTITY) -> void:
	var mesh = TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 28
	mesh.ring_segments = 6
	piece(bone,mesh,at,surface,basis)

func boots(side: String) -> void:
	var bone = "foot."+side
	var mesh = CapsuleMesh.new()
	mesh.radius = 0.066
	mesh.height = 0.29
	mesh.radial_segments = 16
	mesh.rings = 5
	piece(bone,mesh,Vector3(0,-0.027,0.08),"leather",Basis(Vector3.RIGHT,PI*0.5))
	tube(bone,0.071,0.17,Vector3(0,0.057,0),"leather",Basis.IDENTITY,0.064)
	box(bone,Vector3(0.115,0.022,0.25),Vector3(0,-0.073,0.075),"dark")
	if role != "villager":
		for i in range(3):
			box(bone,Vector3(0.13-i*0.008,0.029,0.073),Vector3(0,-0.004+i*0.014,0.16-i*0.06),"steel")
		for side_value in [-1,1]: sphere(bone,0.007,Vector3(side_value*0.059,0.001,0.12),"gold")

func limbs(side: String) -> void:
	for names in [["upperarm01","lowerarm01"],["lowerarm01","wrist"],["upperleg01","lowerleg01"],["lowerleg01","foot"]]:
		var bone: String = names[0]+"."+side
		var direction = rest(names[1]+"."+side)-rest(bone)
		var length_value = direction.length()
		var axis = Basis(Quaternion(Vector3.UP,direction.normalized()))
		var leg: bool = str(names[0]).contains("leg")
		var radius = (0.105 if names[0] == "upperleg01" else 0.078) if leg else (0.082 if names[0] == "upperarm01" else 0.063)
		tube(bone,radius,length_value*0.70,direction*0.47,"steel",axis,radius*0.86)
		for t in [0.17,0.77]: ring(bone,radius+0.003,0.005,direction*t,"gold",axis)
		if names[0] == "lowerleg01":
			box(bone,Vector3(0.016,length_value*0.64,0.011),direction*0.48+Vector3(0,0,0.075),"gold")
		if names[0] == "lowerarm01":
			for t in [0.24,0.46,0.65]: sphere(bone,0.005,direction*t+Vector3(0,0,0.066),"gold")
		if names[0] in ["lowerleg01","lowerarm01"]:
			sphere(bone,radius*1.12,Vector3(0,0,0.025),"steel",Vector3(1,0.75,0.85))
	var shoulder = "upperarm01."+side
	var direction = (rest("lowerarm01."+side)-rest(shoulder)).normalized()
	var axis = Basis(Quaternion(Vector3.UP,direction))
	for layer in range(3):
		var radius = 0.116-layer*0.010
		tube(shoulder,radius,0.076,direction*(0.018+layer*0.043),"steel",axis,radius*0.92,false)
		ring(shoulder,radius,0.003,direction*(0.048+layer*0.043),"gold",axis)
	var wrist = "wrist."+side
	var grip = (rest(wrist)-rest("lowerarm01."+side)).normalized()
	var hand_axis = Basis(Quaternion(Vector3.UP,grip))
	tube(wrist,0.049,0.17,grip*0.071,"leather",hand_axis,0.040)
	box(wrist,Vector3(0.072,0.12,0.016),grip*0.065+hand_axis*Vector3(0,0,0.035),"steel",hand_axis)
	for finger in range(4):
		tube(wrist,0.010,0.069,grip*0.143+hand_axis*Vector3((-1.5+finger)*0.022,0,0),"steel",hand_axis,0.008)

func cuirass() -> void:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ys = [0.225,0.13,0.01,-0.15,-0.26,-0.34]
	var widths = [0.108,0.222,0.238,0.216,0.198,0.202]
	var depths = [0.098,0.162,0.200,0.196,0.184,0.182]
	for row in range(5):
		for column in range(48):
			for pair in [[0,0],[0,1],[1,0],[0,1],[1,1],[1,0]]:
				var r: int = row+pair[0]
				var u = float(column+pair[1])/48.0
				var a = u*TAU
				var ridge = pow(maxf(cos(a),0.0),10.0)*0.020
				surface.set_normal(Vector3(sin(a),0,cos(a)).normalized())
				surface.set_uv(Vector2(u,r/5.0))
				surface.add_vertex(Vector3(sin(a)*widths[r],ys[r],cos(a)*depths[r]+0.052+ridge))
	surface.index()
	piece("spine01",surface.commit(),Vector3.ZERO,"steel")
	for y in [-0.335,-0.302]:
		ring("spine01",0.202,0.005,Vector3(0,y,0.052),"gold",Basis.IDENTITY.scaled(Vector3(1,1,0.90)))
	ring("spine01",0.111,0.006,Vector3(0,0.222,0.052),"gold",Basis.IDENTITY.scaled(Vector3(1,1,0.92)))
	# Raised center rib, gilded borders and rivets make the royal breastplate read
	# as articulated plate instead of a single smooth primitive.
	for y in [0.13,0.04,-0.05,-0.14,-0.23]:
		box("spine01",Vector3(0.018,0.082,0.014),Vector3(0,y,0.254),"gold")
		for side in [-1,1]:
			sphere("spine01",0.0065,Vector3(side*0.145,y+0.012,0.224),"gold")
	for side in [-1,1]:
		box("spine01",Vector3(0.014,0.39,0.012),Vector3(side*0.186,-0.05,0.186),"gold",Basis(Vector3.FORWARD,side*0.08))
		sphere("spine01",0.036,Vector3(side*0.172,0.175,0.182),"gold",Vector3(1.0,0.82,0.45))
	for i in range(11):
		var a = (i-5)*0.225
		var mesh = BoxMesh.new()
		mesh.size = Vector3(0.060,0.185,0.017)
		piece("spine03",mesh,Vector3(sin(a)*0.182,-0.19,cos(a)*0.148),"steel",Basis(Vector3.UP,a))
		box("spine03",Vector3(0.046,0.011,0.022),Vector3(sin(a)*0.183,-0.272,cos(a)*0.150),"gold",Basis(Vector3.UP,a))
	var emblem = QuadMesh.new()
	emblem.size = Vector2(0.125,0.175)
	var herald = StandardMaterial3D.new()
	herald.albedo_texture = load("res://assets/heraldry/lion.svg")
	herald.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	herald.alpha_scissor_threshold = 0.38
	herald.metallic = 0.86
	herald.roughness = 0.28
	var attachment_node = attach("spine01")
	var mark = MeshInstance3D.new()
	mark.mesh = emblem
	mark.material_override = herald
	mark.position = Vector3(0,-0.055,0.273)
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	attachment_node.add_child(mark)

func royal_tabard() -> void:
	var builder = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(18):
		for pair in [[0,0],[0,1],[1,0],[0,1],[1,1],[1,0]]:
			var v = float(row+pair[0])/18.0
			var u = float(pair[1])
			var width = lerpf(0.165,0.245,v)
			var x = lerpf(-width,width,u)
			var y = 0.15-v*0.94
			var z = 0.270+0.020*v+0.010*sin(v*PI)
			builder.set_uv(Vector2(u,v))
			builder.add_vertex(Vector3(x,y,z))
	builder.generate_normals()
	builder.index()
	var fabric = ShaderMaterial.new()
	fabric.shader = load("res://shaders/cloth.gdshader")
	fabric.set_shader_parameter("vertical",true)
	fabric.set_shader_parameter("albedo_map",load("res://assets/textures/rough_linen_diff.jpg"))
	fabric.set_shader_parameter("heraldry",load("res://assets/heraldry/lion.svg"))
	fabric.set_shader_parameter("royal",true)
	fabric.set_shader_parameter("tint",Color(0.62,0.020,0.034))
	var tabard = MeshInstance3D.new()
	tabard.mesh = builder.commit()
	tabard.material_override = fabric
	tabard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	attach("spine01").add_child(tabard)
	# Double royal belt with a large gilded clasp and hanging leather pouches.
	ring("spine03",0.184,0.013,Vector3(0,-0.105,0.035),"leather",Basis.IDENTITY.scaled(Vector3(1,1,0.74)))
	ring("spine03",0.177,0.006,Vector3(0,-0.105,0.037),"gold",Basis.IDENTITY.scaled(Vector3(1,1,0.74)))
	box("spine03",Vector3(0.075,0.062,0.018),Vector3(0,-0.105,0.145),"gold")
	for side in [-1,1]:
		box("spine03",Vector3(0.095,0.135,0.055),Vector3(side*0.18,-0.19,0.052),"leather",Basis(Vector3.FORWARD,side*0.06))
		sphere("spine03",0.008,Vector3(side*0.18,-0.137,0.083),"gold")

func belt() -> void:
	ring("spine03",0.17,0.012,Vector3(0,-0.10,0),"leather",Basis.IDENTITY.scaled(Vector3(1,1,0.72)))
	box("spine03",Vector3(0.045,0.041,0.012),Vector3(0,-0.10,0.131),"gold")
	box("spine03",Vector3(0.09,0.105,0.052),Vector3(0.17,-0.15,0.065),"leather")

func headpiece() -> void:
	if role == "player":
		# Bare-headed ruler: a coherent wavy hair mass with a few articulated
		# side/back locks reads naturally at gameplay distance without the old crown.
		var hair_cap = SphereMesh.new()
		hair_cap.radius = 0.132
		hair_cap.height = 0.235
		hair_cap.is_hemisphere = true
		hair_cap.radial_segments = 24
		hair_cap.rings = 12
		piece("head",hair_cap,Vector3(0,0.075,-0.018),"hair",Basis.IDENTITY.scaled(Vector3(1.04,0.92,1.05)))
		for i in range(14):
			var a = lerpf(PI*0.34,PI*1.66,float(i)/13.0)
			var side_bias = absf(sin(a))
			var height = 0.125+0.035*(1.0-side_bias)
			tube("head",0.012,height,Vector3(sin(a)*0.120,0.005-0.018*(1.0-side_bias),cos(a)*0.120-0.016),"hair",Basis(Vector3.FORWARD,0.20*sin(a)),0.005)
		# Trimmed jaw beard and moustache, deliberately sparse so the face remains visible.
		for i in range(13):
			var a = lerpf(-0.78,0.78,float(i)/12.0)
			tube("head",0.0085,0.055+0.018*cos(a),Vector3(sin(a)*0.064,-0.050-0.008*absf(sin(a)),0.143+cos(a)*0.008),"hair",Basis.IDENTITY,0.004)
		for side in [-1,1]:
			tube("head",0.0075,0.038,Vector3(side*0.026,-0.018,0.153),"hair",Basis(Vector3.FORWARD,side*0.22),0.004)
		for side in [-1,1]:
			sphere("spine01",0.025,Vector3(side*0.155,0.185,0.128),"gold",Vector3(1.0,0.82,0.44))
	else:
		var helmet = SphereMesh.new()
		helmet.radius = 0.126
		helmet.height = 0.252
		helmet.is_hemisphere = true
		helmet.radial_segments = 24
		helmet.rings = 12
		piece("head",helmet,Vector3(0,0.064,0),"steel")
		ring("head",0.122,0.006,Vector3(0,0.067,0),"gold",Basis.IDENTITY.scaled(Vector3(1,1,1.05)))
		for side in [-1,1]: box("head",Vector3(0.025,0.145,0.07),Vector3(side*0.10,-0.017,0.045),"steel",Basis(Vector3.UP,side*0.3))
		box("head",Vector3(0.019,0.12,0.020),Vector3(0,0.014,0.124),"steel")
		if variant % 3 == 1:
			box("head",Vector3(0.19,0.055,0.025),Vector3(0,-0.036,0.123),"steel")
			for x in [-0.046,0.046]: box("head",Vector3(0.054,0.012,0.003),Vector3(x,-0.014,0.137),"dark")

func weapon() -> void:
	var bone = "wrist.R"
	var grip = (rest(bone)-rest("lowerarm01.R")).normalized()
	var axis = Basis(Quaternion(Vector3.UP,grip))
	var builder = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cross_section = [Vector2(-0.030,0),Vector2(0,0.006),Vector2(0.030,0),Vector2(0,-0.006)]
	for side in range(4):
		for triangle in [[0,1,2],[0,2,3]]:
			var points = [Vector3(cross_section[side].x,0.10,cross_section[side].y),Vector3(cross_section[(side+1)%4].x,0.10,cross_section[(side+1)%4].y),Vector3(0,0.96,0),Vector3(0,0.96,0)]
			for index in triangle:
				builder.set_uv(Vector2(float(side)/4.0,float(index)/3.0))
				builder.add_vertex(points[index])
	builder.generate_normals()
	builder.index()
	piece(bone,builder.commit(),grip*0.080,"steel",axis)
	# Long royal crossguard with gilded terminals, leather grip and lion pommel.
	box(bone,Vector3(0.285,0.022,0.022),grip*0.176,"gold",axis)
	for side in [-1,1]:
		sphere(bone,0.022,grip*0.176+axis*Vector3(side*0.142,0,0),"gold",Vector3(0.74,1.0,0.74))
	tube(bone,0.020,0.165,grip*0.082,"leather",axis,0.017)
	for offset in [-0.045,0.0,0.045]:
		ring(bone,0.0215,0.0025,grip*(0.082+offset),"gold",axis)
	sphere(bone,0.034,-grip*0.012,"gold",Vector3(1,1,0.60))
	if role == "soldier" and variant % 2 == 0:
		var board = CylinderMesh.new()
		board.top_radius = 0.25
		board.bottom_radius = 0.25
		board.height = 0.045
		board.radial_segments = 24
		var shield_axis = Basis(Vector3.RIGHT,PI*0.5)
		piece("lowerarm01.L",board,Vector3(0,-0.045,0.13),"leather",shield_axis)
		ring("lowerarm01.L",0.248,0.013,Vector3(0,-0.045,0.158),"gold",shield_axis)
		sphere("lowerarm01.L",0.055,Vector3(0,-0.045,0.16),"steel",Vector3(1,1,0.55))

func cape() -> void:
	var builder = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(24):
		for x in range(18):
			for pair in [[0,0],[0,1],[1,0],[0,1],[1,1],[1,0]]:
				var u = float(x+pair[1])/18.0
				var v = float(y+pair[0])/24.0
				var tear = 0.060*absf(sin(u*PI*9.0))*pow(v,7.0)
				var width = lerpf(0.46,1.02,v)
				builder.set_uv(Vector2(u,v))
				builder.add_vertex(Vector3((u-0.5)*width,0.205-v*1.50+tear,-0.115-0.33*v+sin(u*TAU*4.0)*0.030*v))
	builder.generate_normals()
	builder.index()
	var fabric = ShaderMaterial.new()
	fabric.shader = load("res://shaders/cloth.gdshader")
	fabric.set_shader_parameter("vertical",true)
	fabric.set_shader_parameter("albedo_map",load("res://assets/textures/rough_linen_diff.jpg"))
	fabric.set_shader_parameter("heraldry",load("res://assets/heraldry/lion.svg"))
	fabric.set_shader_parameter("royal",true)
	fabric.set_shader_parameter("tint",Color(0.56,0.018,0.030) if role == "player" else Color(0.23,0.075,0.035))
	var visual = MeshInstance3D.new()
	visual.mesh = builder.commit()
	visual.material_override = fabric
	attach("spine01").add_child(visual)
	for side in [-1,1]:
		sphere("spine01",0.026,Vector3(side*0.163,0.173,-0.102),"gold",Vector3(1,0.80,0.48))
		ring("spine01",0.032,0.004,Vector3(side*0.163,0.173,-0.104),"gold",Basis(Vector3.RIGHT,PI*0.5))

func attach(bone: String) -> BoneAttachment3D:
	var node = BoneAttachment3D.new()
	node.bone_name = bone
	skeleton.add_child(node)
	return node

func flush() -> Dictionary:
	var created = {}
	for bone in batches:
		var attachment_node = attach(bone)
		var mesh = ArrayMesh.new()
		for key in batches[bone]:
			batches[bone][key].set_material(materials[key])
			batches[bone][key].commit(mesh)
		var visual = MeshInstance3D.new()
		visual.mesh = mesh
		attachment_node.add_child(visual)
		created[bone] = attachment_node
	batches.clear()
	return created
