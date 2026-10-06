extends CharacterBody3D

const Actor = preload("res://scripts/actor.gd")
var actor: Node3D
var pivot: Node3D
var arm: SpringArm3D
var camera: Camera3D
var yaw: float = 0.0
var pitch: float = -0.22
var touch_move = Vector2.ZERO
var touch_sprint = false
var jump_requested = false
var frozen = false
var grounded_seconds = 0.0
var terrain: Node3D
var half_world: float = 32748.0

func _ready() -> void:
	var collider = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	floor_snap_length = 0.5
	actor = Actor.new()
	add_child(actor)
	actor.setup("player")
	pivot = Node3D.new()
	pivot.position.y = 1.55
	add_child(pivot)
	arm = SpringArm3D.new()
	arm.spring_length = 5.4
	arm.margin = 0.22
	arm.add_excluded_object(get_rid())
	pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 65.0
	camera.far = 3000.0
	camera.current = true
	arm.add_child(camera)

func look(delta_value: Vector2) -> void:
	yaw -= delta_value.x * 0.004
	pitch = clampf(pitch - delta_value.y * 0.003, -0.9, 0.32)

func _unhandled_input(event: InputEvent) -> void:
	if frozen: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		jump_requested = true
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: arm.spring_length = maxf(2.5, arm.spring_length - 0.4)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: arm.spring_length = minf(8.0, arm.spring_length + 0.4)

func _physics_process(delta: float) -> void:
	pivot.rotation = Vector3(pitch, yaw, 0.0)
	if frozen:
		velocity = Vector3.ZERO
		actor.play_motion("idle")
		return
	var movement = touch_move
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): movement.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): movement.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): movement.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): movement.y += 1.0
	movement = movement.limit_length()
	var direction = (Basis(Vector3.UP, yaw) * Vector3(movement.x, 0, movement.y)).normalized()
	var sprint = touch_sprint or Input.is_physical_key_pressed(KEY_SHIFT)
	var speed = 8.2 if sprint else 4.5
	velocity.x = move_toward(velocity.x, direction.x * speed * movement.length(), delta * 28.0)
	velocity.z = move_toward(velocity.z, direction.z * speed * movement.length(), delta * 28.0)
	if is_on_floor():
		if jump_requested: velocity.y = 6.0
	else: velocity.y -= 20.0 * delta
	jump_requested = false
	if direction.length_squared() > 0.001:
		actor.rotation.y = lerp_angle(actor.rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * 12.0))
	actor.play_motion(("run" if sprint else "walk") if movement.length() > 0.1 else "idle")
	move_and_slide()
	if terrain:
		# Newly streamed chunks and terrain edges cannot strand the character beneath the ground.
		var ground: float = terrain.height_at(position.x, position.z)
		if position.y < ground - 0.2:
			position.y = ground + 0.1
			velocity.y = 0.0
		position.x = clampf(position.x, -half_world - terrain.origin.x, half_world - terrain.origin.x)
		position.z = clampf(position.z, -half_world - terrain.origin.z, half_world - terrain.origin.z)
