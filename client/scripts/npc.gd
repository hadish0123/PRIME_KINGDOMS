extends CharacterBody3D

const Actor = preload("res://scripts/actor.gd")
var actor: Node3D
var home = Vector3.ZERO
var phase: float = 0.0
var npc_id: String = ""
var role: String = "villager"
var clock: float = 0.0

func setup(data: Dictionary, local_position: Vector3) -> void:
	npc_id = str(data.id)
	role = str(data.role)
	home = local_position
	position = home + Vector3(0, 0.1, 0)
	phase = float(data.ordinal) * 1.7
	var collider = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	collider.shape = capsule
	collider.position.y = 0.88
	add_child(collider)
	actor = Actor.new()
	add_child(actor)
	actor.setup(role, 1.8)
	var title = Label3D.new()
	title.text = str(data.name)
	title.font_size = 28
	title.pixel_size = 0.007
	title.position.y = 2.15
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.modulate = Color(0.86, 0.78, 0.51) if role == "soldier" else Color(0.76, 0.86, 0.77)
	title.no_depth_test = false
	title.visibility_range_end = 28.0
	add_child(title)

func _physics_process(delta: float) -> void:
	# Presentation patrols only. Identity, population and home are owned by the server.
	clock += delta
	var target = home + Vector3(sin(clock * 0.18 + phase) * 1.5, 0, cos(clock * 0.22 + phase) * 1.5)
	var direction = target - position
	direction.y = 0
	var moving = direction.length() > 0.35 and fmod(clock + phase, 13.0) < 8.0
	if moving:
		direction = direction.normalized()
		velocity.x = direction.x * 1.0
		velocity.z = direction.z * 1.0
		actor.rotation.y = lerp_angle(actor.rotation.y, atan2(direction.x, direction.z), delta * 5.0)
	else:
		velocity.x = 0
		velocity.z = 0
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	actor.play_motion("walk" if moving else "idle")
	move_and_slide()
	if position.y < home.y - 0.25:
		position.y = home.y + 0.1
		velocity.y = 0.0
