extends Node3D

# Strategy-first camera: the player commands a living settlement instead of steering
# the ruler avatar. UI controls consume their own events before this node sees them.
var game: Node
var camera: Camera3D
var focus := Vector3.ZERO
var yaw: float = -0.72
var elevation: float = 0.72
var distance: float = 54.0
var enabled: bool = true
var touch_points: Dictionary = {}
var last_pinch: float = 0.0

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 52.0
	camera.near = 0.15
	camera.far = 1400.0
	camera.current = true
	add_child(camera)
	_update_camera()

func set_focus(value: Vector3) -> void:
	focus = value
	_clamp_focus()
	_update_camera()

func _process(delta: float) -> void:
	if enabled:
		var motion := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): motion.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): motion.x += 1.0
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): motion.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): motion.y += 1.0
		if motion.length_squared() > 0.0:
			pan_screen(motion.normalized() * -420.0 * delta)
		if Input.is_physical_key_pressed(KEY_Q): yaw -= delta * 1.15
		if Input.is_physical_key_pressed(KEY_E): yaw += delta * 1.15
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom(-4.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom(4.0)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			pan_screen(event.relative)
			get_viewport().set_input_as_handled()
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			yaw = wrapf(yaw - event.relative.x * 0.006, -PI, PI)
			elevation = clampf(elevation + event.relative.y * 0.004, 0.48, 1.05)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
		else:
			touch_points.erase(event.index)
		last_pinch = 0.0
	elif event is InputEventScreenDrag:
		touch_points[event.index] = event.position
		if touch_points.size() == 1:
			pan_screen(event.relative)
		elif touch_points.size() >= 2:
			var keys := touch_points.keys()
			var a: Vector2 = touch_points[keys[0]]
			var b: Vector2 = touch_points[keys[1]]
			var pinch := a.distance_to(b)
			if last_pinch > 0.0:
				zoom((last_pinch - pinch) * 0.055)
			last_pinch = pinch
			yaw = wrapf(yaw - event.relative.x * 0.0025, -PI, PI)
		get_viewport().set_input_as_handled()

func pan_screen(delta_value: Vector2) -> void:
	var scale := distance * 0.0018
	var right := Vector3(cos(yaw),0.0,-sin(yaw))
	var forward := Vector3(sin(yaw),0.0,cos(yaw))
	focus += right * (-delta_value.x * scale) + forward * (-delta_value.y * scale)
	_clamp_focus()

func zoom(amount: float) -> void:
	distance = clampf(distance + amount, 22.0, 92.0)
	_update_camera()

func rotate_view(amount: float) -> void:
	yaw = wrapf(yaw + amount, -PI, PI)
	_update_camera()

func _clamp_focus() -> void:
	focus.x = clampf(focus.x,-108.0,108.0)
	focus.z = clampf(focus.z,-108.0,108.0)
	focus.y = 0.8

func _update_camera() -> void:
	if not is_instance_valid(camera): return
	var horizontal := distance * cos(elevation)
	var height := distance * sin(elevation)
	camera.position = focus + Vector3(sin(yaw) * horizontal,height,cos(yaw) * horizontal)
	camera.look_at(focus + Vector3(0.0,1.4,0.0),Vector3.UP)
