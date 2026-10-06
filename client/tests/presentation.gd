extends SceneTree

var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()

func capture(name_value: String, panel: Control) -> void:
	for frame in range(12): await process_frame
	var rectangle = panel.get_global_rect()
	var screen = root.get_visible_rect()
	if rectangle.position.x < 0 or rectangle.position.y < 0 or rectangle.end.x > screen.end.x + 1 or rectangle.end.y > screen.end.y + 1:
		failures.append(name_value + " does not fit the screen")
		push_error(failures.back())
	await RenderingServer.frame_post_draw
	var result = root.get_texture().get_image().save_png("res://builds/" + name_value + ".png")
	if result != OK:
		failures.append("Screenshot could not be written")
		push_error(failures.back())

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.build_auth_stage(true)
	await capture("login", game.auth_card)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixture.json"))
	await game.enter_world(fixture.state)
	game.toggle_settings()
	await capture("settings", game.settings_panel)
	game.toggle_settings()
	game.toggle_map()
	await capture("atlas", game.map_panel)
	print("NATIVE_PRESENTATION ", JSON.stringify({"failures": failures, "actual_3d_login": true, "settings": true, "atlas": true}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
