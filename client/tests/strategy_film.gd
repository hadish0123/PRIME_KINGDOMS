extends SceneTree

# Visual proof for the 0.8 strategy conversion. Uses the disposable CI backend,
# a real v2 account and the same native scene/UI that ships in the Android build.
var failures: Array[String] = []
var target: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func select_tab(panel: Control, title: String) -> void:
	for index in range(panel.tabs.get_tab_count()):
		if panel.tabs.get_tab_title(index) == title:
			panel.tabs.current_tab = index
			return
	push_error("Film tab unavailable: "+title)
	failures.append("Film tab unavailable: "+title)

func capture_frame(frame: int) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(not image.is_empty(),"Strategy film produced an empty frame")
	if not image.is_empty():
		check(image.save_png("res://builds/strategy-frames/frame-%04d.png" % frame) == OK,"Strategy film frame could not be saved")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Strategy film requires the native renderer")
		quit(1)
		return
	var base := OS.get_environment("PRIME_TEST_API_URL")
	if not base.begins_with("http://127.0.0.1:"):
		push_error("Strategy film requires the disposable localhost API")
		quit(1)
		return

	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.preferences.quality = 1
	game.api.base_url = base
	var created: Dictionary = await game.api.call_api("/v1/auth/register",{
		"email":"film-%d@example.com" % Time.get_ticks_usec(),
		"password":"safe-strategy-film-password",
		"displayName":"PRIME Ruler"
	})
	check(created.ok,"Strategy film account registration failed")
	if not created.ok:
		quit(1)
		return
	game.api.token = created.data.session.token
	var scene: Dictionary = await game.api.call_api("/v2/scene")
	check(scene.ok,"Strategy film settlement did not load")
	if not scene.ok:
		quit(1)
		return
	await game.enter_world(scene.data)
	await game.kingdom_panel.refresh()
	await game.kingdom_panel.submit("/v2/empire/customize",{
		"name":"PRIME Dominion",
		"primaryColor":"#8f1824",
		"secondaryColor":"#d6aa48",
		"emblem":"lion",
		"bannerStyle":"swallowtail"
	})
	await game.kingdom_panel.submit("/v2/army/preset",{
		"slot":1,
		"name":"Royal Host",
		"formation":"wedge",
		"stance":"aggressive",
		"isDefense":false,
		"units":[{"type":"swordsman","quantity":8}]
	})
	await game.kingdom_panel.load_map()
	var candidates: Array = game.kingdom_panel.map_data.tiles.filter(func(tile):
		return bool(tile.get("attackable",false)) and tile.ownerPlayerId == null
	)
	check(not candidates.is_empty(),"Strategy film found no connected conquest target")
	if not candidates.is_empty():
		target = candidates[0].duplicate(true)

	DirAccess.make_dir_recursive_absolute("res://builds/strategy-frames")
	game.connection_label.text = "ONLINE · PRIME KINGDOMS 0.8.0 · STRATEGIC COMMAND"
	var panel = game.kingdom_panel
	panel.close()
	game.strategy_camera.distance = 50.0
	game.strategy_camera.yaw = -0.8
	game.strategy_camera.elevation = 0.72
	game.strategy_camera.set_focus(Vector3.ZERO)

	var started := Time.get_ticks_msec()
	for frame in range(450):
		# 0-119: living 3D settlement under strategy camera.
		if frame < 120:
			game.strategy_camera.rotate(0.0035)
			if frame < 70:
				game.strategy_camera.pan_screen(Vector2(-0.55,0.18))
			if frame >= 70 and frame < 105:
				game.strategy_camera.zoom(-0.055)
		# 120-209: realm overview and growth requirements.
		if frame == 120:
			await panel.open()
			select_tab(panel,"Overview")
		# 210-279: army command and formation.
		if frame == 210:
			select_tab(panel,"Army")
		# 280-359: strategic map, selectable connected territory and conquest.
		if frame == 280:
			await panel.load_map()
			select_tab(panel,"Map")
		if frame == 305 and not target.is_empty():
			panel.selected_target = target.duplicate(true)
			panel.rebuild()
			select_tab(panel,"Map")
		if frame == 330 and not target.is_empty():
			await panel.submit("/v2/battles/attack",{
				"x":int(target.x),
				"z":int(target.z),
				"presetSlot":1
			})
			select_tab(panel,"Reports")
		# 360-419: persistent battle report.
		if frame == 360:
			select_tab(panel,"Reports")
		# 420-449: return to the living realm.
		if frame == 420:
			panel.close()
			game.strategy_camera.distance = 60.0
			game.strategy_camera.set_focus(Vector3(10,0,4))
		if frame >= 420:
			game.strategy_camera.rotate(-0.004)
			game.strategy_camera.pan_screen(Vector2(0.22,-0.08))

		await capture_frame(frame)
		if frame % 90 == 0:
			print("STRATEGY_FILM_PROGRESS frame=",frame,"/450 wall_seconds=",(Time.get_ticks_msec()-started)/1000.0)

	check(game.strategy_mode,"Film was not rendered from v2 strategy mode")
	check(game.player.frozen,"Film accidentally restored direct character steering")
	check(is_instance_valid(game.strategy_camera) and game.strategy_camera.camera.current,"Strategy camera was not active")
	check(not game.touch_controls.visible,"Legacy character joystick appeared in strategy film")
	check(not panel.command_data.presets.is_empty(),"Film did not show a persisted army preset")
	if not target.is_empty():
		check(not panel.command_data.reports.is_empty(),"Film battle did not create a persistent report")
		check(panel.kingdom.realm.ownedTiles >= 2,"Film conquest did not expand the realm")
	print("STRATEGY_FILM ",JSON.stringify({
		"failures":failures,
		"version":"0.8.0",
		"frames":450,
		"captureFps":30,
		"onlineBackend":true,
		"directCharacterSteering":false,
		"strategyCamera":true,
		"armyPreset":true,
		"battleReport":not panel.command_data.reports.is_empty(),
		"realmStage":panel.kingdom.realm.stage
	}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
