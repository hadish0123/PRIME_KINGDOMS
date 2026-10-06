extends Node3D

var animation: AnimationPlayer
var model: Node3D
var current_motion = ""

func setup(kind: String, target_height: float = 1.85) -> void:
	var path = "res://assets/characters/Warrior.glb"
	if kind == "villager": path = "res://assets/characters/Monk.glb"
	if kind == "player": path = "res://assets/characters/Ranger.glb"
	model = load(path).instantiate()
	add_child(model)
	var bounds = model_bounds(model, Transform3D.IDENTITY)
	var height = bounds.size.y
	if height > 0.01:
		model.scale *= target_height / height
		model.position.y = -bounds.position.y * target_height / height
	animation = find_animation(model)
	if animation:
		for name_value in animation.get_animation_list():
			var lower = name_value.to_lower()
			if "idle" in lower or "walk" in lower or "run" in lower:
				animation.get_animation(name_value).loop_mode = Animation.LOOP_LINEAR
	play_motion("idle")

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
