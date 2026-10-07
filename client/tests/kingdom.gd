extends SceneTree

var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool,message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	var base = OS.get_environment("PRIME_TEST_API_URL")
	if not base.begins_with("http://127.0.0.1:"):
		push_error("Strategy contract requires a disposable localhost API")
		quit(1)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.api.base_url = base
	var created: Dictionary = await game.api.call_api("/v1/auth/register",{"email":"strategy-%d@example.com"%Time.get_ticks_usec(),"password":"safe-native-strategy-password","displayName":"Strategy Ruler"})
	check(created.ok,"Strategy account registration failed")
	if not created.ok:
		quit(1)
		return
	game.api.token = created.data.session.token
	var scene: Dictionary = await game.api.call_api("/v2/scene")
	check(scene.ok,"Bounded settlement response failed contract validation")
	if not scene.ok:
		quit(1)
		return
	await game.enter_world(scene.data)
	await game.kingdom_panel.refresh()
	check(game.strategy_mode and game.player.scene_half_size == 128,"Strategy entry did not select a bounded settlement")
	check(game.terrain.chunks.size()==4 and game.terrain.horizon.is_empty(),"Settlement allocated streamed world geometry")
	game.terrain.stream_at(Vector3(9600,0,-9600))
	check(game.terrain.chunks.size()==4 and game.terrain.pending.is_empty(),"Player travel allocated new settlement terrain")
	for frame in range(12): await physics_frame
	check(game.player.is_on_floor(),"Ruler could not stand in the settlement")
	var start: Vector3 = game.player.position
	game.player.touch_move = Vector2(0,-1)
	for frame in range(35): await physics_frame
	game.player.touch_move = Vector2.ZERO
	check(game.player.position.distance_to(start)>0.4,"Touch movement failed in the bounded settlement")
	check(await game.sync_position(),"Bounded scene movement could not be saved")
	var panel = game.kingdom_panel
	check(not panel.kingdom.is_empty() and panel.kingdom.progression.level==1,"Persistent kingdom snapshot did not reach native UI")
	await panel.open()
	check(game.player.frozen,"Management controls did not freeze movement")
	await panel.submit("/v2/buildings/upgrade",{"key":"keep"})
	check(panel.kingdom.tasks.size()==1,"Building button did not create a persistent server task")
	await panel.submit("/v2/units/train",{"key":"swordsman","quantity":1})
	check(panel.kingdom.tasks.size()==2,"Army training button did not create a server task")
	await panel.submit("/v2/empire/customize",{"name":"Emerald Empire","primaryColor":"#117744","secondaryColor":"#ddcc22","emblem":"eagle","bannerStyle":"square"})
	check(panel.kingdom.empire.emblem=="eagle","Empire customization did not persist")
	check(has_emblem(game.player,"eagle"),"Ruler did not display the server-selected emblem")
	check(has_emblem(game.villages[game.state.village.id],"eagle"),"Settlement flags or soldiers did not receive the emblem")
	await panel.load_map()
	check(panel.map_data.tiles.size()==49,"Strategic ownership map did not load")
	await panel.load_clans()
	check(not panel.clan_data.is_empty() and panel.clan_data.creationLevel==15,"Clan contract did not reach the native client")
	await panel.submit("/v2/clans/create",{"name":"Too Early","tag":"EAR","emblem":"lion","primaryColor":"#770000","secondaryColor":"#ffcc00","admission":"open"})
	check(panel.clan_data.own==null and panel.status.text.contains("15"),"Native clan creation bypassed the server level gate")
	var test_clan = OS.get_environment("PRIME_TEST_CLAN_ID")
	if not test_clan.is_empty():
		var settlement_id: String = panel.kingdom.settlementId
		var building_tasks: Array = panel.kingdom.tasks.duplicate(true)
		await panel.submit("/v2/clans/join",{"clanId":test_clan})
		check(panel.clan_data.own != null and panel.clan_data.own.id==test_clan,"Native join did not enter the real clan region")
		check(panel.kingdom.settlementId==settlement_id and panel.kingdom.tasks==building_tasks,"Native join lost the village identity or queue")
		await panel.load_map()
		check(panel.map_data.region.kind=="clan" and panel.map_data.region.plots.size()==64,"Native map did not display the allocated clan plots")
		await panel.submit("/v2/clans/donate",{"resource":"wood","amount":10})
		check(panel.clan_data.own.treasury.wood==10,"Native donation did not reach the persistent treasury")
		await panel.submit("/v2/clans/leave",{})
		check(panel.last_error=="clan_cooldown","Native relocation bypassed server cooldown")
	# Recover an exact unresolved request after an application restart.
	panel.pending_path = "/v2/units/train"
	panel.pending_body = {"requestId":panel.request_id(),"key":"swordsman","quantity":1}
	var saved_request: String = panel.pending_body.requestId
	panel.save_pending()
	panel.pending_path = ""
	panel.pending_body = {}
	panel.load_pending()
	check(panel.pending_body.get("requestId")==saved_request,"Restart changed an unresolved purchase request ID")
	panel.remove_pending()
	panel.pending_path = ""
	panel.pending_body = {}
	panel.close()
	check(not game.player.frozen,"Closing management failed to release touch controls")
	for quality in range(4):
		game.preferences.quality = quality
		game.preferences.apply(game)
		game.terrain.stream_at(game.player.position)
		check(game.terrain.chunks.size()==4,"Graphics profile rebuilt an open world")
	game.connection_failed()
	check(game.player.frozen,"Lost connection left scene controls active")
	await game.recover_connection()
	check(game.network_online and not game.player.frozen,"Strategy reconnect failed")
	if DisplayServer.get_name() != "headless":
		await panel.open()
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://builds/kingdom.png")==OK,"Strategy screenshot could not be written")
	print("NATIVE_KINGDOM ",JSON.stringify({"failures":failures,"bounded_chunks":4,"direct_control":true,"server_tasks":2,"empire_emblems":true,"strategic_map":true,"graphics_profiles":4,"reconnect":true}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func has_emblem(node: Node,value: String) -> bool:
	if node.get_meta("empire_emblem","")==value: return true
	for child in node.get_children():
		if has_emblem(child,value): return true
	return false
