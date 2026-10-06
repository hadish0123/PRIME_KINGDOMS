extends RefCounted

const Surfaces = preload("res://scripts/visual_materials.gd")

var skeleton: Skeleton3D
var role := "player"
var variant := 0
var batches: Dictionary = {}
var materials: Dictionary = {}
var held_weapon: Node3D
var stowed_weapon: Node3D

func prepare(target: Skeleton3D, kind: String, appearance: int = 0) -> void:
	skeleton = target
	role = kind
	variant = appearance

	materials.steel = metal(Color(0.43, 0.46, 0.49))
	materials.steel_bright = metal(Color(0.61, 0.64, 0.67))
	materials.gold = metal(Color(0.73, 0.50, 0.15), true)
	materials.leather = Surfaces.plain(Color(0.095, 0.052, 0.027), 0.82)
	materials.leather_light = Surfaces.plain(Color(0.18, 0.095, 0.042), 0.76)
	materials.dark = Surfaces.plain(Color(0.018, 0.021, 0.024), 0.86)
	materials.mail = Surfaces.plain(Color(0.12, 0.135, 0.15), 0.48, 0.72)
	materials.hair = Surfaces.plain(Color(0.068, 0.038, 0.024), 0.92)

	for side in ["L", "R"]:
		boots(side)
		if role != "villager":
			limbs(side)

	if role == "villager":
		belt()
	else:
		mail_underlayer()
		cuirass()
		pauldrons()
		war_belts()
		headpiece()
		tabard()

	flush()

	if role != "villager":
		weapon()
		var equipment := flush()
		held_weapon = equipment.get("wrist.R")
		if role == "player":
			build_stowed_weapon()
			cape()
			set_weapon_drawn(false)

func set_weapon_drawn(value: bool) -> void:
	if is_instance_valid(held_weapon):
		held_weapon.visible = value
	if is_instance_valid(stowed_weapon):
		stowed_weapon.visible = not value

static func metal(color_value: Color, gilded: bool = false) -> ShaderMaterial:
	var key := "prime_metal:%s:%s" % [color_value, gilded]
	if Surfaces.cache.has(key):
		return Surfaces.cache[key]
	var surface := ShaderMaterial.new()
	surface.shader = load("res://shaders/metal.gdshader")
	surface.set_shader_parameter("color", color_value)
	surface.set_shader_parameter("gilded", 1.0 if gilded else 0.0)
	Surfaces.cache[key] = surface
	return surface

func royal_cloth(tint: Color, crest: bool = true) -> ShaderMaterial:
	var key := "prime_royal:%s:%s" % [tint, crest]
	if Surfaces.cache.has(key):
		return Surfaces.cache[key]
	var fabric := ShaderMaterial.new()
	fabric.shader = load("res://shaders/cloth.gdshader")
	fabric.set_shader_parameter("vertical", true)
	fabric.set_shader_parameter("albedo_map", load("res://assets/textures/rough_linen_diff.jpg"))
	fabric.set_shader_parameter("heraldry", load("res://assets/heraldry/lion.svg"))
	fabric.set_shader_parameter("royal", crest)
	fabric.set_shader_parameter("tint", tint)
	Surfaces.cache[key] = fabric
	return fabric

func rest(bone: String) -> Vector3:
	return skeleton.get_bone_global_rest(skeleton.find_bone(bone)).origin

func piece(bone: String, mesh: Mesh, at: Vector3, surface: String, basis: Basis = Basis.IDENTITY) -> void:
	if not batches.has(bone):
		batches[bone] = {}
	if not batches[bone].has(surface):
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches[bone][surface] = builder
	batches[bone][surface].append_from(mesh, 0, Transform3D(basis, at))

func box(bone: String, size_value: Vector3, at: Vector3, surface: String, basis: Basis = Basis.IDENTITY) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size_value
	piece(bone, mesh, at, surface, basis)

func sphere(bone: String, radius: float, at: Vector3, surface: String, scale_value: Vector3 = Vector3.ONE) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 7
	piece(bone, mesh, at, surface, Basis.IDENTITY.scaled(scale_value))

func tube(bone: String, radius: float, height: float, at: Vector3, surface: String, basis: Basis = Basis.IDENTITY, top: float = -1.0, capped: bool = true) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0.0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.cap_top = capped
	mesh.cap_bottom = capped
	piece(bone, mesh, at, surface, basis)

func ring(bone: String, radius: float, thickness: float, at: Vector3, surface: String, basis: Basis = Basis.IDENTITY) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(0.001, radius - thickness)
	mesh.outer_radius = radius + thickness
	mesh.rings = 28
	mesh.ring_segments = 7
	piece(bone, mesh, at, surface, basis)

func boots(side: String) -> void:
	var bone := "foot." + side
	var sole := CapsuleMesh.new()
	sole.radius = 0.068
	sole.height = 0.30
	sole.radial_segments = 16
	sole.rings = 6
	piece(bone, sole, Vector3(0, -0.030, 0.082), "leather", Basis(Vector3.RIGHT, PI * 0.5))
	tube(bone, 0.074, 0.18, Vector3(0, 0.055, 0), "leather", Basis.IDENTITY, 0.066)
	box(bone, Vector3(0.122, 0.026, 0.255), Vector3(0, -0.078, 0.078), "dark")

	if role == "villager":
		return

	for layer in range(4):
		var width := 0.138 - layer * 0.007
		var z := 0.175 - layer * 0.052
		box(bone, Vector3(width, 0.027, 0.071), Vector3(0, -0.002 + layer * 0.014, z), "steel")
		box(bone, Vector3(width * 0.92, 0.008, 0.074), Vector3(0, 0.013 + layer * 0.014, z + 0.006), "gold")
	for side_value in [-1, 1]:
		sphere(bone, 0.007, Vector3(side_value * 0.060, 0.004, 0.135), "gold")
	box(bone, Vector3(0.020, 0.016, 0.245), Vector3(0, 0.008, 0.080), "gold")

func limbs(side: String) -> void:
	for names in [["upperarm01", "lowerarm01"], ["lowerarm01", "wrist"], ["upperleg01", "lowerleg01"], ["lowerleg01", "foot"]]:
		var bone: String = names[0] + "." + side
		var direction := rest(names[1] + "." + side) - rest(bone)
		var length_value := direction.length()
		var axis := Basis(Quaternion(Vector3.UP, direction.normalized()))
		var leg := str(names[0]).contains("leg")
		var radius := (0.108 if names[0] == "upperleg01" else 0.081) if leg else (0.084 if names[0] == "upperarm01" else 0.065)

		# Dark mail remains visible at the articulation gaps, with plate laid over it.
		tube(bone, radius * 0.92, length_value * 0.82, direction * 0.47, "mail", axis, radius * 0.82)
		tube(bone, radius, length_value * 0.68, direction * 0.46, "steel", axis, radius * 0.86)
		for t in [0.18, 0.76]:
			ring(bone, radius + 0.004, 0.0055, direction * t, "gold", axis)

		if names[0] in ["lowerleg01", "lowerarm01"]:
			box(bone, Vector3(0.018, length_value * 0.62, 0.012), direction * 0.48 + Vector3(0, 0, 0.074), "gold")
			sphere(bone, radius * 1.12, Vector3(0, 0, 0.026), "steel_bright", Vector3(1, 0.76, 0.87))
		if names[0] == "upperleg01":
			for plate_index in range(3):
				box(bone, Vector3(0.148 - plate_index * 0.010, 0.100, 0.020), direction * (0.26 + plate_index * 0.18) + Vector3(0, 0, 0.082), "steel")
		if names[0] == "lowerarm01":
			for rivet in range(3):
				sphere(bone, 0.005, direction * (0.24 + rivet * 0.20) + Vector3(0, 0, 0.067), "gold")

	var wrist := "wrist." + side
	var grip := (rest(wrist) - rest("lowerarm01." + side)).normalized()
	var hand_axis := Basis(Quaternion(Vector3.UP, grip))
	tube(wrist, 0.050, 0.17, grip * 0.071, "leather", hand_axis, 0.041)
	box(wrist, Vector3(0.076, 0.125, 0.018), grip * 0.064 + hand_axis * Vector3(0, 0, 0.036), "steel", hand_axis)
	box(wrist, Vector3(0.067, 0.108, 0.008), grip * 0.064 + hand_axis * Vector3(0, 0, 0.047), "gold", hand_axis)
	for finger in range(4):
		tube(wrist, 0.0105, 0.070, grip * 0.145 + hand_axis * Vector3((-1.5 + finger) * 0.0225, 0, 0), "steel", hand_axis, 0.008)
		sphere(wrist, 0.008, grip * 0.119 + hand_axis * Vector3((-1.5 + finger) * 0.0225, 0, 0.012), "gold")

func mail_underlayer() -> void:
	# A visible chain-mail collar and skirt keep the silhouette grounded between plates.
	for y in [0.18, 0.12, 0.06]:
		ring("spine03", 0.205 - (0.18 - y) * 0.08, 0.010, Vector3(0, y, 0.025), "mail", Basis.IDENTITY.scaled(Vector3(1, 1, 0.80)))
	for i in range(10):
		var a := (i - 4.5) * 0.19
		box("spine03", Vector3(0.082, 0.26, 0.025), Vector3(sin(a) * 0.177, -0.22, cos(a) * 0.125), "mail", Basis(Vector3.UP, a))

func cuirass() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ys := [0.225, 0.150, 0.060, -0.050, -0.165, -0.280, -0.345]
	var widths := [0.110, 0.205, 0.232, 0.238, 0.226, 0.210, 0.202]
	var depths := [0.105, 0.155, 0.188, 0.205, 0.202, 0.190, 0.180]

	for row in range(ys.size() - 1):
		for column in range(48):
			for pair in [[0, 0], [0, 1], [1, 0], [0, 1], [1, 1], [1, 0]]:
				var r: int = row + pair[0]
				var u := float(column + pair[1]) / 48.0
				var a := u * TAU
				var chest_ridge := pow(maxf(cos(a), 0.0), 12.0) * 0.024
				surface.set_normal(Vector3(sin(a), 0, cos(a)).normalized())
				surface.set_uv(Vector2(u, float(r) / float(ys.size() - 1)))
				surface.add_vertex(Vector3(sin(a) * widths[r], ys[r], cos(a) * depths[r] + 0.052 + chest_ridge))
	surface.index()
	piece("spine01", surface.commit(), Vector3.ZERO, "steel")

	# Gold piping, breast ridge and rivets echo the final royal reference.
	for y in [0.225, -0.345]:
		ring("spine01", 0.205 if y < 0.0 else 0.112, 0.006, Vector3(0, y, 0.052), "gold", Basis.IDENTITY.scaled(Vector3(1, 1, 0.92)))
	box("spine01", Vector3(0.018, 0.49, 0.015), Vector3(0, -0.040, 0.254), "gold")
	for side_value in [-1, 1]:
		for y in [0.105, 0.015, -0.085, -0.185]:
			sphere("spine01", 0.0055, Vector3(side_value * 0.139, y, 0.214), "gold")

	# Articulated waist lames.
	for layer in range(4):
		ring("spine03", 0.205 + layer * 0.002, 0.006, Vector3(0, -0.075 - layer * 0.055, 0.030), "gold", Basis.IDENTITY.scaled(Vector3(1, 1, 0.80)))
		box("spine03", Vector3(0.39, 0.045, 0.020), Vector3(0, -0.075 - layer * 0.055, 0.147), "steel")

	# Large lion badge centered on the chest.
	var emblem := QuadMesh.new()
	emblem.size = Vector2(0.105, 0.150)
	var herald := StandardMaterial3D.new()
	herald.albedo_texture = load("res://assets/heraldry/lion.svg")
	herald.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	herald.alpha_scissor_threshold = 0.35
	herald.metallic = 0.75
	herald.roughness = 0.30
	var attachment_node := attach("spine01")
	var mark := MeshInstance3D.new()
	mark.mesh = emblem
	mark.material_override = herald
	mark.position = Vector3(0, -0.020, 0.270)
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	attachment_node.add_child(mark)

func pauldrons() -> void:
	for side_value in ["L", "R"]:
		var side: String = str(side_value)
		var bone: String = "upperarm01." + side
		var sign: float = -1.0 if side == "L" else 1.0
		for layer in range(4):
			var radius := 0.132 - layer * 0.010
			var mesh := SphereMesh.new()
			mesh.radius = radius
			mesh.height = radius * 1.20
			mesh.is_hemisphere = true
			mesh.radial_segments = 20
			mesh.rings = 8
			var angle := sign * (0.10 + layer * 0.045)
			piece(bone, mesh, Vector3(sign * (0.005 + layer * 0.018), 0.010 - layer * 0.040, 0.010 - layer * 0.014), "steel", Basis(Vector3.FORWARD, angle))
			ring(bone, radius * 0.88, 0.005, Vector3(sign * (0.005 + layer * 0.018), -0.005 - layer * 0.040, 0.036), "gold", Basis(Vector3.RIGHT, PI * 0.5))
		sphere(bone, 0.052, Vector3(sign * 0.008, 0.055, 0.108), "gold", Vector3(1.0, 0.35, 1.0))
		sphere(bone, 0.038, Vector3(sign * 0.008, 0.056, 0.120), "steel_bright", Vector3(1.0, 0.24, 1.0))

func war_belts() -> void:
	for y in [-0.115, -0.180]:
		ring("spine03", 0.205, 0.012, Vector3(0, y, 0.020), "leather", Basis.IDENTITY.scaled(Vector3(1, 1, 0.72)))
		box("spine03", Vector3(0.072, 0.060, 0.018), Vector3(0, y, 0.150), "gold")
		box("spine03", Vector3(0.038, 0.026, 0.020), Vector3(0, y, 0.162), "dark")
	# Cross belt over the torso.
	var diagonal := Basis(Vector3.FORWARD, -0.46)
	box("spine01", Vector3(0.050, 0.56, 0.022), Vector3(-0.060, 0.015, 0.245), "leather", diagonal)
	for i in range(6):
		sphere("spine01", 0.006, Vector3(-0.137 + i * 0.030, 0.190 - i * 0.068, 0.262), "gold")
	# Pouches and sword suspension.
	box("spine03", Vector3(0.105, 0.130, 0.060), Vector3(0.205, -0.245, 0.075), "leather")
	box("spine03", Vector3(0.085, 0.105, 0.052), Vector3(-0.190, -0.230, 0.070), "leather_light")
	for x in [0.205, -0.190]:
		box("spine03", Vector3(0.072, 0.018, 0.008), Vector3(x, -0.195, 0.108), "gold")

func belt() -> void:
	ring("spine03", 0.17, 0.012, Vector3(0, -0.10, 0), "leather", Basis.IDENTITY.scaled(Vector3(1, 1, 0.72)))
	box("spine03", Vector3(0.045, 0.041, 0.012), Vector3(0, -0.10, 0.131), "gold")
	box("spine03", Vector3(0.09, 0.105, 0.052), Vector3(0.17, -0.15, 0.065), "leather")

func headpiece() -> void:
	if role != "player":
		var helmet := SphereMesh.new()
		helmet.radius = 0.126
		helmet.height = 0.252
		helmet.is_hemisphere = true
		helmet.radial_segments = 24
		helmet.rings = 12
		piece("head", helmet, Vector3(0, 0.064, 0), "steel")
		ring("head", 0.122, 0.006, Vector3(0, 0.067, 0), "gold", Basis.IDENTITY.scaled(Vector3(1, 1, 1.05)))
		for side_value in [-1, 1]:
			box("head", Vector3(0.025, 0.145, 0.07), Vector3(side_value * 0.10, -0.017, 0.045), "steel", Basis(Vector3.UP, side_value * 0.3))
		box("head", Vector3(0.019, 0.12, 0.020), Vector3(0, 0.014, 0.124), "steel")
		return

	# Open-headed ruler: no crown. Keep the face visible like the target artwork,
	# with a steel/gold gorget and a fuller trimmed beard under the existing hair.
	ring("neck03", 0.107, 0.010, Vector3(0, -0.020, 0.010), "steel", Basis.IDENTITY.scaled(Vector3(1, 1, 0.92)))
	ring("neck03", 0.110, 0.004, Vector3(0, -0.010, 0.012), "gold", Basis.IDENTITY.scaled(Vector3(1, 1, 0.93)))
	for i in range(35):
		var a := (i - 17) * 0.067
		var length_value := 0.058 + 0.012 * (1.0 - absf(float(i - 17)) / 17.0)
		tube("head", 0.0075, length_value, Vector3(sin(a) * 0.071, -0.050 - absf(sin(a)) * 0.010, 0.139 + cos(a) * 0.010), "hair", Basis(Vector3.FORWARD, sin(a) * 0.16), 0.0045)
	for side_value in [-1, 1]:
		tube("head", 0.009, 0.050, Vector3(side_value * 0.028, -0.016, 0.151), "hair", Basis(Vector3.FORWARD, side_value * 0.24), 0.0055)

func tabard() -> void:
	if role != "player":
		return

	var attachment_node := attach("spine03")
	var panel_builder := SurfaceTool.new()
	panel_builder.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rows := 18
	var columns := 8
	for y in range(rows):
		for x in range(columns):
			for pair in [[0, 0], [0, 1], [1, 0], [0, 1], [1, 1], [1, 0]]:
				var u := float(x + pair[1]) / float(columns)
				var v := float(y + pair[0]) / float(rows)
				var width := lerpf(0.31, 0.43, v)
				var rag := 0.025 * sin((u * 7.0 + 0.35) * TAU) * pow(v, 8.0)
				panel_builder.set_uv(Vector2(u, v))
				panel_builder.add_vertex(Vector3((u - 0.5) * width, -0.015 - v * 1.02 + rag, 0.212 - v * 0.015))
	panel_builder.generate_normals()
	panel_builder.index()

	var panel := MeshInstance3D.new()
	panel.mesh = panel_builder.commit()
	panel.material_override = royal_cloth(Color(0.48, 0.025, 0.037, 1.0), true)
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	attachment_node.add_child(panel)

	# Gold weighted hem pieces make the tabard read as embroidered rather than flat.
	for x in [-0.19, 0.0, 0.19]:
		box("spine03", Vector3(0.030, 0.020, 0.012), Vector3(x, -1.025, 0.218), "gold")

func cape() -> void:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 22
	var columns := 18
	for y in range(rows):
		for x in range(columns):
			for pair in [[0, 0], [0, 1], [1, 0], [0, 1], [1, 1], [1, 0]]:
				var u := float(x + pair[1]) / float(columns)
				var v := float(y + pair[0]) / float(rows)
				var lower_width := lerpf(0.44, 0.96, v)
				var rag := 0.035 * sin((u * 9.0 + 0.17) * TAU) * pow(v, 10.0)
				builder.set_uv(Vector2(u, v))
				builder.add_vertex(Vector3((u - 0.5) * lower_width, 0.20 - v * 1.42 + rag, -0.120 - 0.26 * v + sin(u * TAU * 3.0) * 0.018 * v))
	builder.generate_normals()
	builder.index()

	var fabric := MeshInstance3D.new()
	fabric.mesh = builder.commit()
	fabric.material_override = royal_cloth(Color(0.40, 0.018, 0.028, 1.0), true)
	attach("spine01").add_child(fabric)

	# Round shoulder clasps mirror the target artwork.
	for side_value in [-1, 1]:
		sphere("spine01", 0.036, Vector3(side_value * 0.165, 0.168, -0.102), "gold", Vector3(1.0, 0.34, 1.0))
		sphere("spine01", 0.024, Vector3(side_value * 0.165, 0.170, -0.118), "steel_bright", Vector3(1.0, 0.30, 1.0))
	flush()

func build_stowed_weapon() -> void:
	var grip := (rest("wrist.R") - rest("lowerarm01.R")).normalized()
	stowed_weapon = Node3D.new()
	stowed_weapon.position = Vector3(0.255, -0.080, -0.035)
	stowed_weapon.basis = Basis(Quaternion(grip, Vector3.DOWN))
	attach("spine03").add_child(stowed_weapon)

	var sword := MeshInstance3D.new()
	if is_instance_valid(held_weapon) and held_weapon.get_child_count() > 0 and held_weapon.get_child(0) is MeshInstance3D:
		sword.mesh = held_weapon.get_child(0).mesh
		sword.material_override = held_weapon.get_child(0).material_override
		stowed_weapon.add_child(sword)

	box("spine03", Vector3(0.064, 0.88, 0.050), Vector3(0.255, -0.59, -0.035), "leather")
	box("spine03", Vector3(0.070, 0.040, 0.056), Vector3(0.255, -0.170, -0.035), "gold")
	box("spine03", Vector3(0.070, 0.055, 0.056), Vector3(0.255, -1.015, -0.035), "gold")
	for y in [-0.37, -0.79]:
		ring("spine03", 0.036, 0.005, Vector3(0.255, y, -0.035), "gold", Basis(Vector3.FORWARD, PI * 0.5))
	flush()

func weapon() -> void:
	var bone := "wrist.R"
	var grip := (rest(bone) - rest("lowerarm01.R")).normalized()
	var axis := Basis(Quaternion(Vector3.UP, grip))

	# Long diamond-section sword with a strong central ridge.
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cross_section := [Vector2(-0.032, 0), Vector2(0, 0.0065), Vector2(0.032, 0), Vector2(0, -0.0065)]
	for side in range(4):
		var next_side := (side + 1) % 4
		var p0 := Vector3(cross_section[side].x, 0.11, cross_section[side].y)
		var p1 := Vector3(cross_section[next_side].x, 0.11, cross_section[next_side].y)
		var p2 := Vector3(0, 0.94, 0)
		builder.set_uv(Vector2(float(side) / 4.0, 0.0))
		builder.add_vertex(p0)
		builder.set_uv(Vector2(float(next_side) / 4.0, 0.0))
		builder.add_vertex(p1)
		builder.set_uv(Vector2((float(side) + 0.5) / 4.0, 1.0))
		builder.add_vertex(p2)
	builder.generate_normals()
	builder.index()
	piece(bone, builder.commit(), grip * 0.090, "steel_bright", axis)

	# Regal crossguard and grip.
	box(bone, Vector3(0.285, 0.021, 0.022), grip * 0.190, "gold", axis)
	for side_value in [-1, 1]:
		sphere(bone, 0.020, grip * 0.190 + axis * Vector3(side_value * 0.132, 0, 0), "gold", Vector3(1.0, 0.55, 0.55))
	tube(bone, 0.020, 0.175, grip * 0.083, "leather", axis)
	for i in range(5):
		ring(bone, 0.0205, 0.0022, grip * (0.030 + i * 0.032), "gold", axis)
	sphere(bone, 0.033, -grip * 0.015, "gold", Vector3(1.0, 1.0, 0.62))
	sphere(bone, 0.018, -grip * 0.023, "steel_bright", Vector3(1.0, 1.0, 0.60))

	if role == "soldier" and variant % 2 == 0:
		var board := CylinderMesh.new()
		board.top_radius = 0.25
		board.bottom_radius = 0.25
		board.height = 0.045
		board.radial_segments = 24
		var shield_axis := Basis(Vector3.RIGHT, PI * 0.5)
		piece("lowerarm01.L", board, Vector3(0, -0.045, 0.13), "leather", shield_axis)
		ring("lowerarm01.L", 0.248, 0.013, Vector3(0, -0.045, 0.158), "gold", shield_axis)
		sphere("lowerarm01.L", 0.055, Vector3(0, -0.045, 0.16), "steel", Vector3(1, 1, 0.55))

func attach(bone: String) -> BoneAttachment3D:
	var node := BoneAttachment3D.new()
	node.bone_name = bone
	skeleton.add_child(node)
	return node

func flush() -> Dictionary:
	var created := {}
	for bone in batches:
		var attachment_node := attach(bone)
		var mesh := ArrayMesh.new()
		for key in batches[bone]:
			batches[bone][key].set_material(materials[key])
			batches[bone][key].commit(mesh)
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		attachment_node.add_child(visual)
		created[bone] = attachment_node
	batches.clear()
	return created
