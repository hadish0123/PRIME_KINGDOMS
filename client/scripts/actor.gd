extends Node3D

const Surfaces = preload("res://scripts/visual_materials.gd")
const Regalia = preload("res://scripts/regalia.gd")
var animation: AnimationPlayer
var model: Node3D
var current_motion = ""
var role = "player"
var skeleton: Skeleton3D
var grounded_before = true
var landing_seconds = 0.0
var appearance = 0
var wardrobe: RefCounted
var weapon_drawn = false

func setup(kind: String, target_height: float = 1.85, variant: int = 0) -> void:
	role = kind
	appearance = variant
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
			if lower in ["idle", "walk", "run", "fall", "guard", "work", "prone", "crawl", "ride"]:
				animation.get_animation(name_value).loop_mode = Animation.LOOP_LINEAR
	play_motion("idle")

func dress(node: Node) -> void:
	if node is MeshInstance3D:
		for index in range(node.mesh.get_surface_count()):
			var surface: Material = node.mesh.surface_get_material(index)
			if not surface: continue
			if surface.resource_name in ["Fabric", "Trousers"]:
				var tint = Vector3(0.055,0.062,0.073) if role == "player" else (Vector3(0.31,0.29,0.24) if role == "soldier" else Vector3(0.44,0.36,0.24))
				if surface.resource_name == "Trousers": tint = Vector3(0.050,0.042,0.036) if role == "player" else Vector3(0.21,0.17,0.12)
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
	wardrobe = Regalia.new()
	wardrobe.prepare(skeleton,role,appearance)
	weapon_drawn = role == "soldier"

func set_weapon_drawn(value: bool) -> void:
	weapon_drawn = value
	if wardrobe: wardrobe.set_weapon_drawn(value)

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
