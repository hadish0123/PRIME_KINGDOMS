extends Control

var player: Node
var move_finger = -1
var look_finger = -1
var origin = Vector2.ZERO
var stick = Vector2.ZERO
var enabled = true:
	set(value):
		enabled = value
		if is_instance_valid(jump): jump.disabled = not value
		if is_instance_valid(sprint): sprint.disabled = not value
		if not value: release_input()
var sprint: Button
var jump: Button
var blocked_regions: Array[Control] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	jump = Button.new()
	jump.text = "JUMP"
	jump.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	jump.position = Vector2(-120, -110)
	jump.size = Vector2(96, 76)
	jump.pressed.connect(func():
		if player and enabled: player.jump_requested = true)
	add_child(jump)
	sprint = Button.new()
	sprint.text = "RUN"
	sprint.toggle_mode = true
	sprint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	sprint.position = Vector2(-240, -110)
	sprint.size = Vector2(96, 76)
	sprint.toggled.connect(func(value):
		if player and enabled: player.touch_sprint = value)
	add_child(sprint)
	blocked_regions.append_array([jump, sprint])
	enabled = enabled

func _input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree() or not is_instance_valid(player): return
	if event is InputEventScreenTouch:
		var point = get_global_transform().affine_inverse() * event.position
		if event.pressed:
			# HUD buttons own their touches; dragging MAP cannot orbit the camera.
			if blocked_regions.any(func(control): return is_instance_valid(control) and control.is_visible_in_tree() and control.get_global_rect().has_point(event.position)): return
			if point.x < size.x * 0.42 and point.y > size.y * 0.3 and move_finger < 0:
				move_finger = event.index
				origin = point
				stick = origin
				get_viewport().set_input_as_handled()
			elif point.x > size.x * 0.45 and point.y < size.y - 125 and look_finger < 0:
				look_finger = event.index
				get_viewport().set_input_as_handled()
		else:
			var owned = event.index == move_finger or event.index == look_finger
			if event.index == move_finger:
				move_finger = -1
				player.touch_move = Vector2.ZERO
			if event.index == look_finger: look_finger = -1
			if owned: get_viewport().set_input_as_handled()
		queue_redraw()
	if event is InputEventScreenDrag:
		if event.index == move_finger:
			var offset = (get_global_transform().affine_inverse() * event.position - origin).limit_length(72.0)
			stick = origin + offset
			player.touch_move = offset / 72.0
			get_viewport().set_input_as_handled()
			queue_redraw()
		elif event.index == look_finger:
			player.look(event.relative)
			get_viewport().set_input_as_handled()

func release_input() -> void:
	move_finger = -1
	look_finger = -1
	if is_instance_valid(player):
		player.touch_move = Vector2.ZERO
		player.touch_sprint = false
		player.jump_requested = false
	if is_instance_valid(sprint): sprint.set_pressed_no_signal(false)
	queue_redraw()

func _draw() -> void:
	var base = origin if move_finger >= 0 else Vector2(135, size.y - 125)
	var knob = stick if move_finger >= 0 else base
	draw_circle(base, 76, Color(0.04, 0.09, 0.12, 0.35))
	draw_arc(base, 76, 0, TAU, 64, Color(0.85, 0.76, 0.53, 0.65), 2, true)
	draw_circle(knob, 29, Color(0.88, 0.80, 0.58, 0.42))
