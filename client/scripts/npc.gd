extends CharacterBody3D

const Actor = preload("res://scripts/actor.gd")
var actor: Node3D
var home = Vector3.ZERO
var phase: float = 0.0
var npc_id: String = ""
var role: String = "villager"
var clock: float = 0.0
var title: Label3D
var simulating = true
var following = false
var follow_target: Node3D
var ordinal = 0
var terrain: Node3D

func setup(data: Dictionary, local_position: Vector3) -> void:
	collision_layer = 2
	collision_mask = 7
	npc_id = str(data.id)
	role = str(data.role)
	home = local_position
	position = home + Vector3(0, 0.1, 0)
	phase = float(data.ordinal) * 1.7
	ordinal = int(data.ordinal)
	var collider = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.75
	collider.shape = capsule
	collider.position.y = 0.88
	add_child(collider)
	actor = Actor.new()
	add_child(actor)
	actor.setup(role,1.76 + float(int(data.ordinal) % 4) * 0.025,int(data.ordinal))
	title = Label3D.new()
	title.text = str(data.name)
	title.font_size = 28
	title.pixel_size = 0.007
	title.position.y = 2.15
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.modulate = Color(0.86, 0.78, 0.51) if role == "soldier" else Color(0.76, 0.86, 0.77)
	title.no_depth_test = false
	title.visibility_range_end = 28.0
	add_child(title)

func update_presence(viewer: Vector3, simulation_distance: float) -> void:
	var distance = global_position.distance_to(viewer)
	visible = distance < simulation_distance + 25.0
	var active = distance < simulation_distance
	if active != simulating:
		simulating = active
		set_physics_process(active)
		if actor.animation: actor.animation.active = active
		velocity = Vector3.ZERO
	# Per-resident names are readable nearby without cluttering the village skyline.
	title.visible = distance < 18.0

func _physics_process(delta: float) -> void:
	# Presentation patrols only. Identity, population and home are owned by the server.
	clock += delta
	var target = home + Vector3(sin(clock * 0.18 + phase) * 1.5, 0, cos(clock * 0.22 + phase) * 1.5)
	if following and is_instance_valid(follow_target):
		var offset = Vector3((ordinal%2-0.5)*3.0,0,-4.0-floorf(ordinal/2.0)*1.8)
		target = to_local(follow_target.global_position+Basis(Vector3.UP,follow_target.actor.rotation.y)*offset)+position
	var direction = target - position
	direction.y = 0
	var moving = direction.length() > 0.35 and (following or fmod(clock + phase, 13.0) < 8.0)
	if moving:
		direction = direction.normalized()
		var speed = minf(5.4,maxf(1.0,(target-position).length())) if following else 1.0
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		actor.rotation.y = lerp_angle(actor.rotation.y, atan2(direction.x, direction.z), delta * 5.0)
	else:
		velocity.x = 0
		velocity.z = 0
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	actor.locomotion(Vector2(velocity.x, velocity.z).length(), is_on_floor(), velocity.y, delta, "work" if role == "villager" else "idle")
	var floor_height = terrain.height_at(global_position.x,global_position.z)-get_parent().global_position.y if is_instance_valid(terrain) else home.y
	if position.y < floor_height - 0.25:
		position.y = floor_height + 0.1
		velocity.y = 0.0
