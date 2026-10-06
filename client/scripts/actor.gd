extends Node3D

const Surfaces = preload("res://scripts/visual_materials.gd")
var animation: AnimationPlayer
var model: Node3D
var current_motion = ""
var role = "player"
var skeleton: Skeleton3D
var grounded_before = true
var landing_seconds = 0.0

func setup(kind: String, target_height: float = 1.85) -> void:
	role = kind
	var path = "res://assets/humans/human.glb"
	model = load(path).instantiate()
	add_child(model)
	var bounds = model_bounds(model, Transform3D.IDENTITY)
	var height = bounds.size.y
	if height > 0.01:
		model.scale *= target_height / height
		model.position.y = -bounds.position.y * target_height / height
	animation = find_animation(model)
	skeleton = find_skeleton(model)
	dress(model)
	add_regalia()
	if animation:
		for name_value in animation.get_animation_list():
			var lower = name_value.to_lower()
			if lower in ["idle", "walk", "run", "fall", "guard", "work"]:
				animation.get_animation(name_value).loop_mode = Animation.LOOP_LINEAR
	play_motion("idle")

func dress(node: Node) -> void:
	if node is MeshInstance3D:
		for index in range(node.mesh.get_surface_count()):
			var surface: Material = node.mesh.surface_get_material(index)
			if not surface: continue
			if surface.resource_name in ["Fabric", "Trousers"]:
				var tint = Vector3(0.27, 0.34, 0.43) if role == "player" else (Vector3(0.39, 0.35, 0.28) if role == "soldier" else Vector3(0.51, 0.44, 0.32))
				if surface.resource_name == "Trousers": tint = Vector3(0.21, 0.17, 0.12)
				var key = "garment:%s:%s" % [role, surface.resource_name]
				if not Surfaces.cache.has(key):
					var tailored = ShaderMaterial.new()
					tailored.shader = load("res://shaders/garment.gdshader")
					tailored.set_shader_parameter("albedo_map", surface.albedo_texture)
					tailored.set_shader_parameter("normal_map", surface.normal_texture)
					tailored.set_shader_parameter("tint", tint)
					Surfaces.cache[key] = tailored
				node.set_surface_override_material(index, Surfaces.cache[key])
	for child in node.get_children(): dress(child)

func attachment(bone: String) -> BoneAttachment3D:
	var node = BoneAttachment3D.new()
	node.bone_name = bone
	skeleton.add_child(node)
	return node

func detail(parent: Node3D, mesh: Mesh, at: Vector3, surface: Material) -> MeshInstance3D:
	var visual = MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = surface
	visual.position = at
	parent.add_child(visual)
	return visual

func add_regalia() -> void:
	if not skeleton: return
	var leather = Surfaces.plain(Color(0.22, 0.14, 0.075), 0.82)
	for side in ["L", "R"]:
		var foot = attachment("foot." + side)
		var sole = CapsuleMesh.new()
		sole.radius = 0.063
		sole.height = 0.26
		sole.radial_segments = 16
		sole.rings = 4
		var boot = detail(foot, sole, Vector3(0, -0.04, 0.075), leather)
		boot.rotation.x = PI * 0.5
		var ankle = CylinderMesh.new()
		ankle.top_radius = 0.060
		ankle.bottom_radius = 0.065
		ankle.height = 0.18
		ankle.radial_segments = 16
		detail(foot, ankle, Vector3(0, 0.025, 0), leather)
	if role == "villager": return
	var metal = Surfaces.plain(Color(0.36, 0.40, 0.43), 0.46, 0.85)
	var gold = Surfaces.plain(Color(0.64, 0.46, 0.19), 0.37, 0.85)
	var head = attachment("head")
	if role == "soldier":
		var helmet = SphereMesh.new()
		helmet.radius = 0.118
		helmet.height = 0.236
		helmet.is_hemisphere = true
		helmet.radial_segments = 24
		helmet.rings = 12
		detail(head, helmet, Vector3(0, 0.07, -0.005), metal)
		var nasal = BoxMesh.new()
		nasal.size = Vector3(0.018, 0.115, 0.012)
		detail(head, nasal, Vector3(0, 0.045, 0.135), metal)
	else:
		var circlet = TorusMesh.new()
		circlet.inner_radius = 0.108
		circlet.outer_radius = 0.128
		circlet.rings = 24
		circlet.ring_segments = 8
		detail(head, circlet, Vector3(0, 0.12, 0.0), gold)
		for i in range(7):
			var spike = CylinderMesh.new()
			spike.top_radius = 0.0
			spike.bottom_radius = 0.021
			spike.height = 0.07
			spike.radial_segments = 4
			var a = i * TAU / 7.0
			detail(head, spike, Vector3(sin(a) * 0.115, 0.15, cos(a) * 0.115), gold)
	var chest = attachment("spine01")
	var cuirass = SurfaceTool.new()
	cuirass.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(4):
		for x in range(10):
			for pair in [[0, 0], [0, 1], [1, 0], [0, 1], [1, 1], [1, 0]]:
				var u = float(x + pair[1]) / 10.0
				var v = float(y + pair[0]) / 4.0
				var a = (u - 0.5) * PI * 0.85
				cuirass.set_uv(Vector2(u, v))
				cuirass.add_vertex(Vector3(sin(a) * lerpf(0.205, 0.17, v), 0.02 - v * 0.33, 0.105 + cos(a) * 0.085))
	cuirass.generate_normals()
	detail(chest, cuirass.commit(), Vector3.ZERO, metal if role == "soldier" else Surfaces.plain(Color(0.22, 0.14, 0.075), 0.77))
	for side in ["L", "R"]:
		var shoulder = attachment("upperarm01." + side)
		var pad = SphereMesh.new()
		pad.radius = 0.105
		pad.height = 0.18
		pad.is_hemisphere = true
		pad.radial_segments = 16
		pad.rings = 8
		detail(shoulder, pad, Vector3(0, 0.015, 0), metal if role == "soldier" else gold)
	if role == "player":
		var surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for y in range(12):
			for x in range(8):
				for pair in [[0, 0], [0, 1], [1, 0], [0, 1], [1, 1], [1, 0]]:
					var u = float(x + pair[1]) / 8.0
					var v = float(y + pair[0]) / 12.0
					surface.set_uv(Vector2(u, v))
					surface.add_vertex(Vector3((u - 0.5) * lerpf(0.35, 0.65, v), -v * 0.94, -0.15 - 0.12 * v + sin(u * TAU * 3.0) * 0.018 * v))
		surface.generate_normals()
		var cape = surface.commit()
		var fabric = ShaderMaterial.new()
		fabric.shader = load("res://shaders/cloth.gdshader")
		fabric.set_shader_parameter("vertical", true)
		fabric.set_shader_parameter("albedo_map", load("res://assets/textures/rough_linen_diff.jpg"))
		detail(chest, cape, Vector3(0, 0.05, 0), fabric)

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var found = find_skeleton(child)
		if found: return found
	return null

func locomotion(speed: float, on_ground: bool, vertical_speed: float, delta: float, rest_motion: String = "idle") -> void:
	if on_ground and not grounded_before: landing_seconds = 0.18
	grounded_before = on_ground
	landing_seconds = maxf(0.0, landing_seconds - delta)
	if not on_ground:
		play_motion("jump" if vertical_speed > 0.1 else "fall")
	elif landing_seconds > 0.0: play_motion("land")
	else: play_motion(("run" if speed > 3.2 else "walk") if speed > 0.15 else rest_motion)
	if animation:
		animation.speed_scale = clampf(speed / (3.7 if current_motion == "run" else 1.2), 0.5, 2.2) if current_motion in ["walk", "run"] else 1.0

func model_bounds(node: Node, parent: Transform3D) -> AABB:
	var transform_value = parent
	if node is Node3D: transform_value = parent * node.transform
	var result = AABB()
	if node is MeshInstance3D: result = transform_value * node.get_aabb()
	for child in node.get_children():
		var child_box = model_bounds(child, transform_value)
		if child_box.size.length_squared() > 0.0:
			result = child_box if result.size.length_squared() == 0.0 else result.merge(child_box)
	return result

func find_animation(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found = find_animation(child)
		if found: return found
	return null

func play_motion(motion: String) -> void:
	if motion == "idle" and role == "soldier": motion = "guard"
	if motion == current_motion or animation == null: return
	var selected = ""
	for name_value in animation.get_animation_list():
		if motion in name_value.to_lower():
			selected = name_value
			break
	if selected.is_empty() and motion == "run":
		play_motion("walk")
		return
	if not selected.is_empty():
		animation.play(selected, 0.2)
		current_motion = motion
