extends SceneTree

var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool,message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://builds")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixture.json"))
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await game.enter_world(fixture.state)
	check(game.in_world and game.strategy_camera.camera.current,"Strategy camera did not become active")
	check(game.ruler is Node3D and not game.ruler is CharacterBody3D,"Ruler still requires an avatar controller")
	check(game.terrain.chunks.size()==4,"Settlement geometry is not bounded")
	var village = game.villages[fixture.state.village.id]
	check(village.population.size()==13,"Starter residents were not preserved")
	for actor in [game.ruler,village.population[0].actor,village.population[8].actor]:
		check(actor.animation!=null and actor.skeleton!=null,"Licensed animated character did not load")
	var start: Vector3 = game.ruler.position
	var input = InputEventKey.new()
	input.keycode = KEY_W
	input.physical_keycode = KEY_W
	input.pressed = true
	Input.parse_input_event(input)
	for frame in range(20): await physics_frame
	input.pressed = false
	Input.parse_input_event(input)
	check(game.ruler.position.is_equal_approx(start),"Keyboard input moved the decorative ruler")
	var camera = game.strategy_camera
	camera.pan_screen(Vector2(80,-20))
	check(camera.focus.length()>1,"Camera pan did not move the kingdom view")
	camera.pan_screen(Vector2(100000,100000))
	check(abs(camera.focus.x)<=76 and abs(camera.focus.z)<=76,"Camera left the settlement")
	camera.zoom(-10000)
	check(camera.distance==32,"Minimum camera zoom failed")
	camera.zoom(10000)
	check(camera.distance==155,"Maximum camera zoom failed")
	camera.set_focus(Vector3.ZERO)
	camera.distance = 105
	# A real pinch and rotation must update the strategic camera.
	var touch = InputEventScreenTouch.new()
	touch.index = 1
	touch.position = Vector2(500,300)
	touch.pressed = true
	camera._unhandled_input(touch)
	touch.index = 2
	touch.position = Vector2(600,300)
	camera._unhandled_input(touch)
	var old_yaw: float = camera.yaw
	var drag = InputEventScreenDrag.new()
	drag.index = 2
	drag.position = Vector2(650,335)
	drag.relative = Vector2(50,35)
	camera._unhandled_input(drag)
	check(camera.distance<105 and not is_equal_approx(camera.yaw,old_yaw),"Pinch or rotation did not affect strategy camera")
	camera.enabled = false
	check(camera.touch_points.is_empty(),"Modal left a touch gesture active")
	game.apply_control_state()
	camera.yaw = -0.55
	camera.set_focus(Vector3.ZERO)
	camera.distance = 105
	for quality in range(4):
		game.preferences.quality = quality
		game.preferences.apply(game)
		game.terrain.stream_at(Vector3(9600,0,-9600))
		check(game.terrain.chunks.size()==4 and game.terrain.pending.is_empty(),"Quality tier allocated an endless world")
	var npc = village.population[0]
	npc.update_presence(Vector3(10000,0,10000),55)
	check(not npc.visible and not npc.is_physics_processing() and not npc.actor.animation.active,"Distant resident kept processing")
	npc.update_presence(npc.global_position,55)
	check(npc.visible and npc.is_physics_processing(),"Resident failed to resume")
	game.preferences.quality = 1
	game.preferences.apply(game)
	for frame in range(12): await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://builds/settlement.png")==OK,"Settlement render could not be saved")
	print("NATIVE_STRATEGY_SMOKE ",JSON.stringify({"failures":failures,"residents":13,"chunks":4,"direct_control":false,"pinch_and_rotation":true,"graphics_tiers":4}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
