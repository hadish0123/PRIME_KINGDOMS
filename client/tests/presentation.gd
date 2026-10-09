extends SceneTree

var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()

func capture(name_value: String,panel: Control) -> void:
	for frame in range(6): await process_frame
	var rectangle = panel.get_global_rect()
	if not root.get_visible_rect().encloses(rectangle):
		failures.append(name_value+" does not fit the screen")
		push_error(failures.back())
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png("res://builds/"+name_value+".png")!=OK:
			failures.append("Capture failed")
			push_error(failures.back())

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://builds")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.build_auth_stage(true)
	await capture("login",game.auth_card)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixture.json"))
	await game.enter_world(fixture.state)
	game.toggle_settings()
	await capture("settings",game.settings_panel)
	game.toggle_settings()
	print("NATIVE_PRESENTATION ",JSON.stringify({"failures":failures,"login":true,"settings":true}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
