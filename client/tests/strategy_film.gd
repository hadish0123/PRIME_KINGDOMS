extends SceneTree

# Fast native visual proof for the 0.8 strategy conversion. The preview is built
# from real rendered keyframes of the shipping scene/UI instead of spending CI
# time simulating hundreds of frames under llvmpipe.
var failures: Array[String] = []
var target: Dictionary = {}
var captured := 0

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

func capture_frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	check(not image.is_empty(),"Strategy film produced an empty frame")
	if not image.is_empty():
		check(image.save_jpg("res://builds/strategy-frames/frame-%04d.jpg" % captured,0.86) == OK,"Strategy film frame could not be saved")
	captured += 1

func capture_settlement(game: Node) -> void:
	for index in range(4):
		game.strategy_camera.rotate(0.055)
		game.strategy_camera.pan_screen(Vector2(-7.0+index*2.0,2.0))
		await capture_frame()

func capture_panel(panel: Control, title: String, count: int) -> void:
	select_tab(panel,title)
	for _index in range(count):
		await capture_frame()

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
	game.preferences.quality = 0
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
	game.strategy_camera.distance = 48.0
	game.strategy_camera.yaw = -0.8
	game.strategy_camera.elevation = 0.72
	game.strategy_camera.set_focus(Vector3.ZERO)

	var started := Time.get_ticks_msec()
	# 4 keyframes: living settlement under the strategy camera.
	await capture_settlement(game)

	# 3 + 3 keyframes: progression and army command.
	await panel.open()
	await capture_panel(panel,"Overview",3)
	await capture_panel(panel,"Army",3)

	# 3 keyframes: connected strategic target.
	await panel.load_map()
	select_tab(panel,"Map")
	if not target.is_empty():
		panel.selected_target = target.duplicate(true)
		panel.rebuild()
		select_tab(panel,"Map")
	for _index in range(3):
		await capture_frame()

	# Resolve one authoritative battle and show its persistent report.
	if not target.is_empty():
		await panel.submit("/v2/battles/attack",{
			"x":int(target.x),
			"z":int(target.z),
			"presetSlot":1
		})
	await capture_panel(panel,"Reports",3)

	# 2 closing frames back in the realm.
	panel.close()
	game.strategy_camera.distance = 58.0
	game.strategy_camera.set_focus(Vector3(10,0,4))
	for _index in range(2):
		game.strategy_camera.rotate(-0.08)
		await capture_frame()

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
		"captureFrames":captured,
		"captureFps":2,
		"wallSeconds":(Time.get_ticks_msec()-started)/1000.0,
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
