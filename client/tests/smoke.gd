extends SceneTree

const Terrain = preload("res://scripts/terrain.gd")
const TouchControls = preload("res://scripts/touch_controls.gd")
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixture.json"))
	for point in fixture.points:
		check(absf(Terrain.raw_height(float(point.x), float(point.z), int(fixture.state.world.seed)) - float(point.height)) < 0.000001, "Client/server terrain heights disagree")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await game.enter_world(fixture.state)
	check(game.player.camera.current, "Third-person camera is not active")
	check(game.player.arm.spring_length > 3.0, "Camera must sit behind the player")
	var village = game.villages[fixture.state.village.id]
	check(village.loaded_models >= 32, "Village buildings and props failed to load")
	check(village.population.size() == 13, "Village must contain exactly 13 people")
	check(village.population.filter(func(n): return n.role == "soldier").size() == 8, "Expected eight soldiers")
	check(village.population.filter(func(n): return n.role == "villager").size() == 5, "Expected five villagers")
	for node in [game.player.actor, village.population[0].actor, village.population[8].actor]:
		check(node.animation != null, "Real rigged model has no animation player")
		check(node.animation.get_animation_list().size() >= 3, "Movement animations missing")
	for frame in range(90): await physics_frame
	check(game.player.is_on_floor(), "Player cannot stand on the terrain collider")
	var start: Vector3 = game.player.position
	var event = InputEventKey.new()
	event.physical_keycode = KEY_W
	event.keycode = KEY_W
	event.pressed = true
	Input.parse_input_event(event)
	for frame in range(45): await physics_frame
	event.pressed = false
	Input.parse_input_event(event)
	check(game.player.position.distance_to(start) > 1.0, "Third-person walking did not move the player")
	var floor_y: float = game.player.position.y
	game.player.jump_requested = true
	for frame in range(8): await physics_frame
	check(game.player.position.y > floor_y + 0.1, "Jump failed")
	for frame in range(75): await physics_frame
	check(game.player.is_on_floor(), "Player failed to land after jumping")
	game.player.look(Vector2(130, 20))
	check(game.player.yaw < -0.4, "Orbit camera failed")
	var touch = TouchControls.new()
	game.hud.add_child(touch)
	touch.player = game.player
	var press = InputEventScreenTouch.new()
	press.index = 3
	press.position = Vector2(140, root.size.y - 160)
	press.pressed = true
	touch._input(press)
	var drag = InputEventScreenDrag.new()
	drag.index = 3
	drag.position = press.position + Vector2(40, -30)
	drag.relative = Vector2(40, -30)
	touch._input(drag)
	check(game.player.touch_move.length() > 0.5, "Android stick failed")
	press.pressed = false
	touch._input(press)
	check(game.player.touch_move == Vector2.ZERO, "Android stick did not release")
	touch.queue_free()
	var count_before: int = game.terrain.chunks.size()
	game.terrain.stream_at(Vector3(960, 0, 960))
	check(game.terrain.pending.size() > 0, "New terrain does not stream when moving")
	check(game.terrain.chunks.size() <= 169, "World allocation is not bounded")
	check(game.terrain.chunks[game.terrain.center].get_meta("near"), "Exploration must upgrade distant terrain to collision terrain")
	game.player.position = start
	game.player.velocity = Vector3.ZERO
	game.player.yaw = -0.35
	game.player.pitch = -0.17
	game.terrain.stream_at(start)
	for frame in range(120): await process_frame
	if "--screenshot" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var screenshot = root.get_texture().get_image()
		check(not screenshot.is_empty(), "Renderer returned an empty screenshot")
		if not screenshot.is_empty(): screenshot.save_png("res://builds/village.png")
	print("NATIVE_3D_SMOKE ", JSON.stringify({"failures": failures, "npcs": village.population.size(), "terrain_chunks": count_before, "player_walked": true}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
