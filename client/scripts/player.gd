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
var jump_buffer = 0.0
var look_sensitivity = 1.0
var invert_y = false
var terrain: Node3D
var half_world: float = 32748.0
var collider: CollisionShape3D
var standing_shape: CapsuleShape3D
var prone_shape: BoxShape3D
var mounted_shape: BoxShape3D
var lying = false
var action_motion = ""
var action_clock = 0.0
var action_elapsed = 0.0
var action_event_done = false
var action_duration = 0.0
var game: Node3D
var horse: Node3D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 7
	collider = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.32
	capsule.height = 1.8
	standing_shape = capsule
	prone_shape = BoxShape3D.new()
	prone_shape.size = Vector3(0.58,0.52,1.9)
	mounted_shape = BoxShape3D.new()
	mounted_shape.size = Vector3(0.92,2.85,2.8)
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
	arm.spring_length = 4.8
	arm.margin = 0.22
	arm.collision_mask = 1
	arm.add_excluded_object(get_rid())
	pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.far = 6500.0
	camera.current = true
	arm.add_child(camera)

func look(delta_value: Vector2) -> void:
	if frozen: return
	yaw = wrapf(yaw - delta_value.x * 0.004 * look_sensitivity, -PI, PI)
	pitch = clampf(pitch + delta_value.y * 0.003 * look_sensitivity * (1.0 if invert_y else -1.0), -0.9, 0.32)

func _unhandled_input(event: InputEvent) -> void:
	if frozen: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look(event.relative)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		jump_requested = true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F: toggle_weapon()
		elif event.keycode == KEY_X: toggle_lying()
		elif event.keycode == KEY_E: toggle_mount()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT: attack()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: arm.spring_length = maxf(2.5, arm.spring_length - 0.4)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: arm.spring_length = minf(8.0, arm.spring_length + 0.4)

func _physics_process(delta: float) -> void:
	pivot.rotation = Vector3(pitch, yaw, 0.0)
	if frozen:
		if horse:
			horse.rotation.y = actor.rotation.y
			collider.rotation.y = actor.rotation.y
		velocity = Vector3.ZERO
		jump_buffer = 0.0
		jump_requested = false
		actor.play_motion("ride" if horse else ("prone" if lying else "idle"))
		return
	var movement = touch_move
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): movement.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): movement.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): movement.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): movement.y += 1.0
	movement = movement.limit_length()
	var direction = (Basis(Vector3.UP, yaw) * Vector3(movement.x, 0, movement.y)).normalized()
	var sprint = touch_sprint or Input.is_physical_key_pressed(KEY_SHIFT)
	var speed = (9.5 if sprint else 4.0) if horse else (0.85 if lying else (6.4 if sprint else 2.4))
	if not action_motion.is_empty(): speed = 0.0
	velocity.x = move_toward(velocity.x, direction.x * speed * movement.length(), delta * 28.0)
	velocity.z = move_toward(velocity.z, direction.z * speed * movement.length(), delta * 28.0)
	grounded_seconds = 0.10 if is_on_floor() else maxf(0.0, grounded_seconds - delta)
	jump_buffer = 0.12 if jump_requested else maxf(0.0, jump_buffer - delta)
	if jump_requested and lying:
		toggle_lying()
		jump_buffer = 0.0
	if grounded_seconds > 0.0 and jump_buffer > 0.0:
		velocity.y = 6.0
		jump_buffer = 0.0
		grounded_seconds = 0.0
	elif is_on_floor():
		velocity.y = 0.0
	else: velocity.y -= 20.0 * delta
	jump_requested = false
	if direction.length_squared() > 0.001:
		actor.rotation.y = lerp_angle(actor.rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * 12.0))
	move_and_slide()
	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	if not action_motion.is_empty():
		action_clock -= delta
		action_elapsed += delta
		actor.update_weapon(action_motion,action_elapsed/action_duration)
		if action_clock <= 0.0:
			if action_motion in ["draw","sheathe"]: actor.set_weapon_drawn(action_motion == "draw")
			action_motion = ""
			actor.update_weapon("",0)
	elif horse:
		actor.play_motion("ride")
		horse.rotation.y = actor.rotation.y
		horse.animate(horizontal_speed,is_on_floor(),delta)
	elif lying: actor.play_motion("crawl" if horizontal_speed > 0.1 else "prone")
	else: actor.locomotion(horizontal_speed, is_on_floor(), velocity.y, delta)
	pivot.position.y = lerpf(pivot.position.y,2.4 if horse else (0.75 if lying else 1.55),minf(1,delta*8))
	if lying or horse: collider.rotation.y = actor.rotation.y
	if terrain:
		# Newly streamed chunks and terrain edges cannot strand the character beneath the ground.
		var ground: float = terrain.height_at(position.x, position.z)
		if position.y < ground - 0.2:
			position.y = ground + 0.1
			velocity.y = 0.0
		position.x = clampf(position.x, -half_world - terrain.origin.x, half_world - terrain.origin.x)
		position.z = clampf(position.z, -half_world - terrain.origin.z, half_world - terrain.origin.z)

func start_action(motion: String) -> void:
	action_motion = motion
	action_clock = actor.animation.get_animation(motion).length
	action_duration = action_clock
	action_elapsed = 0.0
	action_event_done = false
	actor.play_motion(motion)
	actor.update_weapon(motion,0)

func cancel_actions() -> void:
	action_motion = ""
	actor.update_weapon("",0)
	jump_requested = false
	jump_buffer = 0.0

func toggle_weapon() -> void:
	if frozen or lying or horse or not action_motion.is_empty(): return
	start_action("sheathe" if actor.weapon_drawn else "draw")

func attack() -> void:
	if frozen or lying or horse or not actor.weapon_drawn or not action_motion.is_empty() or not is_on_floor(): return
	start_action("attack")

func sweep_sword(base: Vector3,tip: Vector3,old_base: Vector3,old_tip: Vector3) -> void:
	if action_motion != "attack" or action_event_done or frozen: return
	# Contact comes from the blade and its swept path, not a cone around the body.
	# Only practice equipment accepts damage in this milestone.
	for segment in [[base,tip],[old_tip,tip],[old_base.lerp(old_tip,0.5),base.lerp(tip,0.5)]]:
		if segment[0].distance_squared_to(segment[1]) < 0.00001: continue
		var ray = PhysicsRayQueryParameters3D.create(segment[0],segment[1],7,[get_rid()])
		var hit = get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty(): continue
		# A swept tip can already be beyond a wall when the arms animate through
		# it. Require an unobstructed path from the player's body to that contact.
		var clearance = PhysicsRayQueryParameters3D.create(global_position+Vector3(0,1.2,0),hit.position,7,[get_rid()])
		var obstruction = get_world_3d().direct_space_state.intersect_ray(clearance)
		if not obstruction.is_empty() and obstruction.collider != hit.collider: continue
		for target in get_tree().get_nodes_in_group("practice_targets"):
			if target.is_ancestor_of(hit.collider):
				target.hit(25)
				action_event_done = true
				return

func can_stand(at: Vector3) -> bool:
	var query = PhysicsShapeQueryParameters3D.new()
	var normal_shape = CapsuleShape3D.new()
	normal_shape.height = 1.8
	normal_shape.radius = 0.32
	query.shape = normal_shape
	query.transform = Transform3D(Basis.IDENTITY,at+Vector3(0,0.94,0))
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func can_mount_at(mount: Node3D) -> bool:
	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = mounted_shape
	query.transform = Transform3D(Basis(Vector3.UP,actor.rotation.y),mount.global_position+Vector3(0,1.425,0))
	query.collision_mask = collision_mask
	query.exclude = [get_rid(),mount.body.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func toggle_lying() -> void:
	if frozen or horse or not action_motion.is_empty() or not is_on_floor(): return
	if lying and not can_stand(global_position): return
	lying = not lying
	collider.shape = prone_shape if lying else standing_shape
	collider.position.y = 0.30 if lying else 0.90
	collider.rotation.y = actor.rotation.y if lying else 0.0
	if lying: actor.set_weapon_drawn(false)
	start_action("lie_down" if lying else "stand_up")

func toggle_mount() -> void:
	if frozen or lying or not action_motion.is_empty() or not is_on_floor() or not is_instance_valid(game): return
	game.toggle_horse()

func apply_mount(value: bool) -> void:
	if value and horse: return
	lying = false
	cancel_actions()
	collider.shape = standing_shape
	collider.rotation = Vector3.ZERO
	if horse:
		var released = horse
		horse = null
		released.reparent(game.world_root,true)
		released.set_occupied(false)
		actor.position.y = 0.0
		collider.position.y = 0.9
	else:
		if not value: return
		horse = game.horse
		horse.set_occupied(true)
		horse.reparent(self,true)
		horse.position = Vector3.ZERO
		horse.rotation = Vector3(0,actor.rotation.y,0)
		actor.set_weapon_drawn(false)
		actor.position.y = 0.57
		collider.shape = mounted_shape
		collider.position.y = 1.425
		collider.rotation.y = actor.rotation.y
		actor.play_motion("ride")
