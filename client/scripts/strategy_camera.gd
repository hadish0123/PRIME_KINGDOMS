extends Node3D

signal selected(screen_position: Vector2)
var game: Node
var camera: Camera3D
var focus = Vector3(0,0.8,0)
var displayed_focus = focus
var yaw: float = -0.55
var displayed_yaw: float = yaw
var elevation: float = 0.69
var distance: float = 115.0
var displayed_distance: float = distance
var council_offset: float = 0.0
var enabled: bool = true:
	set(value):
		enabled = value
		if not value: cancel_gestures()
var touch_points: Dictionary = {}
var starts: Dictionary = {}
var gesture_pair = Vector2.ZERO
var multi_touch = false
var mouse_down = false
var mouse_motion = 0.0
var velocity = Vector3.ZERO

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 48.0
	camera.near = 0.25
	camera.far = 1400.0
	camera.current = true
	add_child(camera)
	_update_camera()

func cancel_gestures() -> void:
	touch_points.clear()
	starts.clear()
	gesture_pair = Vector2.ZERO
	multi_touch = false
	mouse_down = false
	velocity = Vector3.ZERO

func set_focus(value: Vector3) -> void:
	focus = value
	velocity = Vector3.ZERO
	_clamp_focus()

func _process(delta: float) -> void:
	if enabled and touch_points.is_empty() and not mouse_down:
		focus += velocity * delta
		velocity *= exp(-7.5 * delta)
		_clamp_focus()
	var blend = 1.0-exp(-10.0*delta)
	displayed_focus = displayed_focus.lerp(focus,blend)
	displayed_distance = lerpf(displayed_distance,distance,blend)
	displayed_yaw = lerp_angle(displayed_yaw,yaw,blend)
	var sidebar = is_instance_valid(game) and is_instance_valid(game.kingdom_panel) and game.kingdom_panel.visible and game.kingdom_panel.anchor_right<0.5
	council_offset = lerpf(council_offset,-displayed_distance*0.18 if sidebar else 0.0,blend)
	_update_camera()

func _input(event: InputEvent) -> void:
	# Observe releases over UI as well; a modal cannot leave a stale drag.
	if event is InputEventScreenTouch and not event.pressed and touch_points.has(event.index):
		var tapped: bool = not multi_touch and touch_points.size()==1 and starts[event.index].distance_to(event.position)<12.0
		touch_points.erase(event.index)
		starts.erase(event.index)
		gesture_pair = Vector2.ZERO
		if touch_points.is_empty(): multi_touch = false
		if enabled and tapped: selected.emit(event.position)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		var tapped: bool = mouse_down and mouse_motion<10.0
		mouse_down = false
		if enabled and tapped: selected.emit(event.position)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled: return
	if event is InputEventMouseButton:
		if event.device == -1: return
		if event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
			mouse_down = true
			mouse_motion = 0
			velocity = Vector3.ZERO
		elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP: zoom(-6)
		elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN: zoom(6)
	elif event is InputEventMouseMotion:
		if mouse_down:
			mouse_motion += event.relative.length()
			pan_screen(event.relative)
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): rotate_view(-event.relative.x*0.005)
	elif event is InputEventScreenTouch and event.pressed:
		touch_points[event.index] = event.position
		starts[event.index] = event.position
		velocity = Vector3.ZERO
		if touch_points.size()>1: multi_touch = true
		gesture_pair = pair_vector()
	elif event is InputEventScreenDrag and touch_points.has(event.index):
		touch_points[event.index] = event.position
		if touch_points.size()==1: pan_screen(event.relative)
		elif touch_points.size()==2:
			var current = pair_vector()
			if gesture_pair.length()>10 and current.length()>10:
				zoom((gesture_pair.length()-current.length())*0.13)
				rotate_view(gesture_pair.angle_to(current))
			gesture_pair = current
		get_viewport().set_input_as_handled()

func pair_vector() -> Vector2:
	if touch_points.size()!=2: return Vector2.ZERO
	var keys = touch_points.keys()
	keys.sort()
	return Vector2(touch_points[keys[1]])-Vector2(touch_points[keys[0]])

func pan_screen(motion: Vector2) -> void:
	var sensitivity: float = game.preferences.sensitivity if is_instance_valid(game) else 1.0
	var scale_value = distance*0.0016*sensitivity
	var right = Vector3(cos(yaw),0,-sin(yaw))
	var forward = Vector3(sin(yaw),0,cos(yaw))
	var movement = (right*-motion.x+forward*-motion.y)*scale_value
	focus += movement
	velocity = movement*24.0
	_clamp_focus()

func zoom(amount: float) -> void: distance = clampf(distance+amount,32.0,155.0)
func rotate_view(amount: float) -> void: yaw = wrapf(yaw+amount,-PI,PI)

func _clamp_focus() -> void:
	focus.x = clampf(focus.x,-76,76)
	focus.z = clampf(focus.z,-76,76)
	focus.y = 0.8

func _update_camera() -> void:
	if not is_instance_valid(camera): return
	camera.position = displayed_focus+Vector3(sin(displayed_yaw)*cos(elevation),sin(elevation),cos(displayed_yaw)*cos(elevation))*displayed_distance
	camera.look_at(displayed_focus,Vector3.UP)
	# Project building picking through the same smooth council camera composition.
	camera.h_offset = council_offset
