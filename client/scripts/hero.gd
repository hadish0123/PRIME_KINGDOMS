extends "res://scripts/regalia.gd"

const SwordRig = preload("res://scripts/sword_rig.gd")
const Ornament = preload("res://scripts/hero_ornament.gd")
var ornament: RefCounted
var actor: Node3D
var sword: Node3D
var scabbard: Node3D
var scabbard_rest: Transform3D
var blade_length = 1.02
var extraction_length = 0.92
var drawn = false
var motion = ""
var progress = 0.0
var rig: SkeletonModifier3D

func prepare(target: Skeleton3D, kind: String, appearance: int = 0) -> void:
	skeleton = target
	role = kind
	variant = appearance
	materials.steel = metal(Color(0.53,0.56,0.58))
	materials.gold = metal(Color(0.72,0.49,0.17),true)
	materials.leather = ShaderMaterial.new()
	materials.leather.shader = load("res://shaders/leather.gdshader")
	materials.dark = Surfaces.plain(Color(0.03,0.022,0.017),0.93)
	materials.chain = ShaderMaterial.new()
	materials.chain.shader = load("res://shaders/chainmail.gdshader")
	materials.hair = Surfaces.plain(Color(0.10,0.051,0.027),0.88)
	ornament = Ornament.new(self)
	for side in ["L","R"]:
		boots(side)
		limbs(side)
	cuirass()
	headpiece()
	cape()
	flush()
	make_weapon()
	rig = SwordRig.new()
	rig.wardrobe = self
	skeleton.add_child(rig)

func shell(bone: String, radius: float, length_value: float, at: Vector3, axis: Basis, surface: String, taper: float = 0.82, arc: float = TAU) -> void:
	# Profiled metal shells with a rolled edge and an embossed central ridge.
	var builder = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows = 8
	var columns = 32
	for y in range(rows):
		for x in range(columns):
			for pair in [[0,0],[1,0],[0,1],[0,1],[1,0],[1,1]]:
				var u = float(x+pair[1])/columns
				var v = float(y+pair[0])/rows
				var angle = (u-0.5)*arc
				var edge = pow(absf(v-0.5)*2.0,12.0)*0.0025
				var r = radius*lerpf(1.0,taper,v)+edge
				var ridge = pow(maxf(cos(angle),0),16)*radius*0.09
				builder.set_uv(Vector2(u,v))
				builder.add_vertex(Vector3(sin(angle)*r,(v-0.5)*length_value,cos(angle)*r*0.86+ridge))
	builder.generate_normals()
	builder.generate_tangents()
	builder.index()
	piece(bone,builder.commit(),at,surface,axis)
	if surface == "steel": ornament.plate(bone,radius,length_value,at,axis,taper,arc)

func armor_axis(direction: Vector3) -> Basis:
	# Keep the open rear seam behind the limb, including downward arm rests.
	var up = direction.normalized()
	var forward = Vector3.BACK-up*Vector3.BACK.dot(up)
	if forward.length_squared()<0.01: forward = Vector3.RIGHT-up*Vector3.RIGHT.dot(up)
	forward = forward.normalized()
	return Basis(up.cross(forward).normalized(),up,forward)

func shoulder_cap(bone: String,radius: float,at: Vector3,axis: Basis) -> void:
	# Convex crown closes the uppermost pauldron over the shoulder joint.
	var builder = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(10):
		for col in range(40):
			for pair in [[0,0],[0,1],[1,0],[0,1],[1,1],[1,0]]:
				var u = float(col+pair[1])/40.0
				var v = float(row+pair[0])/10.0
				var angle = u*TAU
				var theta = v*PI*0.5
				builder.set_uv(Vector2(u,v))
				builder.add_vertex(Vector3(sin(angle)*sin(theta)*radius,-cos(theta)*radius*0.66,cos(angle)*sin(theta)*radius*0.86))
	builder.generate_normals()
	builder.generate_tangents()
	builder.index()
	piece(bone,builder.commit(),at,"steel",axis)

func limbs(side: String) -> void:
	for names in [["upperarm01","lowerarm01"],["lowerarm01","wrist"],["upperleg01","lowerleg01"],["lowerleg01","foot"]]:
		var bone: String = names[0]+"."+side
		var direction = rest(names[1]+"."+side)-rest(bone)
		var length_value = direction.length()
		var axis = armor_axis(direction)
		var leg: bool = str(names[0]).contains("leg")
		var radius = (0.101 if names[0]=="upperleg01" else 0.078) if leg else (0.078 if names[0]=="upperarm01" else 0.061)
		shell(bone,radius*0.96,length_value*0.95,direction*0.5,axis,"chain",0.85)
		if names[0] == "upperarm01":
			shoulder_cap(bone,0.125,direction.normalized()*0.002,axis)
			for layer in range(5):
				var r = 0.125-layer*0.009
				var center = direction.normalized()*(0.04+layer*0.043)
				shell(bone,r,0.084,center,axis,"steel",0.88,PI*1.42)
				for angle in [-1.0,1.0]:
					sphere(bone,0.003,center+axis*Vector3(sin(angle)*r,0.034,cos(angle)*r*0.87),"gold")
		elif names[0] == "upperleg01":
			shell(bone,radius*1.06,length_value*0.59,direction*0.31,axis,"steel",0.88,PI*1.20)
		else:
			shell(bone,radius*1.12,length_value*0.74,direction*0.49,axis,"steel",0.81)
			for t in [0.12,0.84]: ring(bone,radius*(1.10-t*0.2),0.0035,direction*t,"gold",axis.scaled(Vector3(1,1,0.87)))
			# Flared elbow/knee couter plus gold perimeter and rivets.
			sphere(bone,radius*1.24,Vector3(0,0,0.025),"steel",Vector3(1.12,0.90,0.92))
			for i in range(7):
				var a = (i-3)*0.34
				sphere(bone,0.0035,Vector3(sin(a)*radius*1.15,-0.008,0.028+cos(a)*radius*1.08),"gold")
	var wrist = "wrist."+side
	var grip = (rest(wrist)-rest("lowerarm01."+side)).normalized()
	var axis = Basis(Quaternion(Vector3.UP,grip))
	shell(wrist,0.045,0.15,grip*0.063,axis,"leather",0.86)
	box(wrist,Vector3(0.071,0.069,0.010),grip*0.054+axis*Vector3(0,0,0.031),"steel",axis)
	# Fingers are the skinned anatomical mesh, with their own animated joints.
	ring(wrist,0.046,0.003,grip*0.018,"gold",axis)

func cuirass() -> void:
	# Dark fitted mail under the heraldic textile, rather than a plain breast box.
	shell("spine01",0.215,0.41,Vector3(0,-0.065,0.04),Basis.IDENTITY.scaled(Vector3(1,1,0.81)),"chain",0.85)
	textile_panel("TabardChest",1.53,1.015,0.116,0.170,0.24,false)
	textile_panel("TabardSkirt",1.03,0.40,0.157,0.168,0.20,true)
	# Cross-body strap, double belts, loops, buckles and suspended leather pouch.
	beam("spine01",Vector3(-0.20,0.16,0.218),Vector3(0.17,-0.15,0.235),0.036,"leather")
	for y in [-0.11,-0.15]:
		ring("spine03",0.195,0.021,Vector3(0,y,0.024),"leather",Basis.IDENTITY.scaled(Vector3(1,1,1.12)))
	for x in [-0.10,0.10]:
		box("spine03",Vector3(0.053,0.043,0.012),Vector3(x,-0.115,0.249),"gold")
		box("spine03",Vector3(0.039,0.029,0.014),Vector3(x,-0.115,0.258),"dark")
		box("spine03",Vector3(0.047,0.005,0.006),Vector3(x,-0.115,0.267),"gold")
	for i in range(13): sphere("spine03",0.0024,Vector3(-0.16+i*0.026,-0.15,0.199),"gold")
	box("spine03",Vector3(0.091,0.123,0.055),Vector3(0.21,-0.224,0.073),"leather",Basis(Vector3.UP,0.33))
	box("spine03",Vector3(0.080,0.021,0.061),Vector3(0.21,-0.174,0.073),"leather",Basis(Vector3.UP,0.33))
	for side in [-1,1]:
		ornament.lion("spine01",Vector3(side*0.174,0.149,0.247))

func beam(bone: String,a: Vector3,b: Vector3,width: float,surface: String) -> void:
	box(bone,Vector3(width,a.distance_to(b),0.011),(a+b)*0.5,surface,Basis(Quaternion(Vector3.UP,(b-a).normalized())))

func textile_surface(skirt: bool = false) -> ShaderMaterial:
	var material = ShaderMaterial.new()
	material.shader = load("res://shaders/royal_textile.gdshader")
	material.set_shader_parameter("albedo_map",load("res://assets/heraldry/royal-skirt.svg" if skirt else "res://assets/heraldry/royal-textile.png"))
	return material

func textile_panel(name_value: String,top: float,bottom: float,top_width: float,bottom_width: float,depth: float,skirt: bool) -> void:
	var builder = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hips = skeleton.find_bone("spine03")
	var chest = skeleton.find_bone("spine01")
	var left = skeleton.find_bone("upperleg01.L")
	var right = skeleton.find_bone("upperleg01.R")
	for y in range(24):
		for x in range(16):
			for pair in [[0,0],[1,0],[0,1],[0,1],[1,0],[1,1]]:
				var u = float(x+pair[1])/16.0
				var v = float(y+pair[0])/24.0
				var width_value = lerpf(top_width,bottom_width,v) if skirt else (lerpf(top_width,0.220,smoothstep(0,0.25,v)) if v < 0.25 else lerpf(0.220,bottom_width,(v-0.25)/0.75))
				var px = (u-0.5)*2.0*width_value
				var center_depth = depth if skirt else (lerpf(0.135,depth,smoothstep(0,0.25,v)) if v < 0.25 else lerpf(depth,0.192,(v-0.25)/0.75))
				var pz = center_depth-(0.065 if not skirt else 0.0)*pow(absf(u-0.5)*2,2)+sin(u*TAU*3)*0.009*(v if skirt else 0.3)
				builder.set_uv(Vector2(u,v))
				if skirt:
					var leg_weight = v*0.42
					builder.set_bones(PackedInt32Array([hips,left if u>0.5 else right,0,0]))
					builder.set_weights(PackedFloat32Array([1.0-leg_weight,leg_weight,0,0]))
				else:
					builder.set_bones(PackedInt32Array([chest,hips,0,0]))
					builder.set_weights(PackedFloat32Array([1.0-v*0.7,v*0.7,0,0]))
				builder.add_vertex(Vector3(px,lerpf(top,bottom,v),pz))
	builder.generate_normals()
	builder.generate_tangents()
	builder.index()
	var visual = MeshInstance3D.new()
	visual.name = name_value
	visual.mesh = builder.commit()
	visual.material_override = textile_surface(skirt)
	visual.skin = skeleton.create_skin_from_rest_transforms()
	visual.skeleton = NodePath("..")
	skeleton.add_child(visual)

func headpiece() -> void:
	# The fitted source groom supplies the silhouette and animated roots.
	pass

func cape() -> void:
	var builder = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(26):
		for x in range(24):
			for pair in [[0,0],[1,0],[0,1],[0,1],[1,0],[1,1]]:
				var u = float(x+pair[1])/24.0
				var v = float(y+pair[0])/26.0
				var hem = sin(u*64)*0.014*pow(v,14)
				builder.set_uv(Vector2(u,v))
				builder.add_vertex(Vector3((u-0.5)*lerpf(0.39,0.96,v),0.18-v*1.30+hem,-0.136-0.20*v+sin(u*TAU*5)*0.035*v))
	builder.generate_normals()
	builder.generate_tangents()
	builder.index()
	var visual = MeshInstance3D.new()
	visual.mesh = builder.commit()
	visual.material_override = textile_surface()
	visual.material_override.set_shader_parameter("cape",true)
	attach("spine01").add_child(visual)
	# One continuous folded mantle, fitted between the neck and shoulder clasps.
	var folds = SurfaceTool.new()
	folds.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(16):
		for col in range(80):
			for pair in [[0,0],[0,1],[1,0],[0,1],[1,1],[1,0]]:
				var u = float(col+pair[1])/80.0
				var v = float(row+pair[0])/16.0
				var angle = u*TAU
				var wave = sin(v*PI*5.0+sin(angle*3)*0.8)*0.004+sin(angle*9+v*4)*0.002
				var radius = lerpf(0.088,0.165,v)+wave
				folds.set_uv(Vector2(u*3,v))
				folds.add_vertex(Vector3(sin(angle)*radius*1.48,0.233-v*0.091+sin(angle*2+0.4)*0.010,0.036+cos(angle)*radius*1.08))
	folds.generate_normals()
	folds.generate_tangents()
	folds.index()
	var cloth = ShaderMaterial.new()
	cloth.shader = load("res://shaders/hero_mantle.gdshader")
	cloth.set_shader_parameter("albedo_map",load("res://assets/textures/rough_linen_diff.jpg"))
	cloth.set_shader_parameter("normal_map",load("res://assets/textures/rough_linen_normal.jpg"))
	cloth.set_shader_parameter("tint",Color(0.42,0.024,0.041))
	var mantle = MeshInstance3D.new()
	mantle.mesh = folds.commit()
	mantle.material_override = cloth
	attach("spine01").add_child(mantle)

func make_weapon() -> void:
	var direction = Vector3(-0.57,0.77,-0.17).normalized()
	scabbard_rest = Transform3D(Basis(Quaternion(Vector3.UP,direction)),Vector3(0.20,-0.017,0.12))
	scabbard = Node3D.new()
	scabbard.name = "OpenScabbard"
	scabbard.transform = scabbard_rest
	attach("spine03").add_child(scabbard)
	# Hollow elliptical sleeve: its mouth stays open and its walls hide the blade.
	var builder = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(12):
		for col in range(24):
			for pair in [[0,0],[0,1],[1,0],[0,1],[1,1],[1,0]]:
				var u = float(col+pair[1])/24.0
				var v = float(row+pair[0])/12.0
				var a = u*TAU
				# Keep the sleeve wider than the blade until its tapered point.
				var taper = lerpf(1.0,0.32,smoothstep(0.79,1.0,v))
				builder.set_uv(Vector2(u,v))
				builder.add_vertex(Vector3(sin(a)*0.040*taper,-0.13-v*(blade_length-0.10),cos(a)*0.014*taper))
	builder.generate_normals()
	builder.generate_tangents()
	builder.index()
	var sleeve = MeshInstance3D.new()
	sleeve.mesh = builder.commit()
	sleeve.material_override = materials.leather
	scabbard.add_child(sleeve)
	for v in [-0.13,-0.17,-blade_length+0.01]:
		var band = TorusMesh.new()
		band.inner_radius = 0.011 if v < -0.5 else 0.036
		band.outer_radius = 0.016 if v < -0.5 else 0.041
		band.rings = 24
		band.ring_segments = 5
		var node = MeshInstance3D.new()
		node.mesh = band
		node.material_override = materials.gold
		node.position.y = v
		node.scale.z = 0.39
		scabbard.add_child(node)
	var cap = MeshInstance3D.new()
	var cap_mesh = SphereMesh.new()
	cap_mesh.radius = 0.016
	cap_mesh.height = 0.047
	cap_mesh.radial_segments = 16
	cap_mesh.rings = 8
	cap.mesh = cap_mesh
	cap.position.y = -blade_length-0.025
	cap.scale.z = 0.39
	cap.material_override = materials.gold
	scabbard.add_child(cap)
	sword = Node3D.new()
	sword.name = "PlayerSword"
	skeleton.add_child(sword)
	# One blade, with parallel edges, a fuller and a tapered diamond point.
	var blade = SurfaceTool.new()
	blade.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows = [Vector2(-0.12,0.030),Vector2(-0.30,0.027),Vector2(-0.88,0.024),Vector2(-blade_length,0.0003)]
	for row in range(rows.size()-1):
		for col in range(4):
			for pair in [[0,0],[0,1],[1,0],[0,1],[1,1],[1,0]]:
				var r: int = row+pair[0]
				var section = (col+pair[1])%4
				var section_points = [Vector2(-rows[r].y,0),Vector2(0,0.005),Vector2(rows[r].y,0),Vector2(0,-0.005)]
				var p: Vector2 = section_points[section]
				blade.set_uv(Vector2(float(col+pair[1])/4.0,float(r)/3))
				blade.add_vertex(Vector3(p.x,rows[r].x,p.y))
	blade.generate_normals()
	blade.generate_tangents()
	blade.index()
	var visual = MeshInstance3D.new()
	visual.mesh = blade.commit()
	visual.material_override = materials.steel
	sword.add_child(visual)
	for item in [[Vector3(0.028,0.135,0.027),Vector3(0,-0.005,0),"leather"]]:
		var mesh = BoxMesh.new()
		mesh.size = item[0]
		var node = MeshInstance3D.new()
		node.mesh = mesh
		node.position = item[1]
		node.material_override = materials[item[2]]
		sword.add_child(node)
	# Ornament is geometry on the same sword; no detached or swapped prop.
	for side in [-1.0,1.0]:
		var curve = PackedVector3Array()
		for i in range(17):
			var t = float(i)/16.0
			curve.append(Vector3(side*(0.015+t*0.126),-0.087-0.030*sin(t*PI*0.9),0))
		ornament.cord("wrist.R",curve,0.009)
	ornament.lion("wrist.R",Vector3(0,-0.086,0.011),0.018)
	var guard_attachment: Node3D = flush()["wrist.R"]
	var guard_mesh: Node3D = guard_attachment.get_child(0)
	guard_mesh.reparent(sword,false)
	guard_mesh.name = "SculptedCrossguard"
	guard_attachment.queue_free()
	for y in [0.075,-0.089]:
		var pommel = SphereMesh.new()
		pommel.radius = 0.024 if y>0 else 0.016
		pommel.height = pommel.radius*2
		var node = MeshInstance3D.new()
		node.mesh = pommel
		node.position.y = y
		node.material_override = materials.gold
		sword.add_child(node)
	# Compatibility names point to the SAME sword, never a visibility switch.
	held_weapon = sword
	stowed_weapon = scabbard
	sword.transform = skeleton.get_bone_global_rest(skeleton.find_bone("spine03"))*scabbard_rest

func set_weapon_drawn(value: bool) -> void:
	drawn = value
	motion = ""
	progress = 0

func update_action(name_value: String,phase: float) -> void:
	motion = name_value
	progress = clampf(phase,0,1)
