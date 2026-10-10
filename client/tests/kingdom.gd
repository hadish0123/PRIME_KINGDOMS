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
	DirAccess.make_dir_recursive_absolute("res://builds")
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
	check(game.in_world and game.state.scene.halfSize == 128,"Strategy entry did not select a bounded settlement")
	check(game.terrain.chunks.size()==4 and game.terrain.horizon.is_empty(),"Settlement allocated streamed world geometry")
	game.terrain.stream_at(Vector3(9600,0,-9600))
	check(game.terrain.chunks.size()==4 and game.terrain.pending.is_empty(),"Command view allocated streamed world geometry")
	for frame in range(12): await physics_frame
	check(game.ruler is Node3D and not game.ruler is CharacterBody3D,"Ruler still depends on direct character control")
	check(is_instance_valid(game.strategy_camera) and game.strategy_camera.camera.current,"Strategy camera is not active")
	var camera_start: Vector3 = game.strategy_camera.focus
	game.strategy_camera.pan_screen(Vector2(80,-20))
	check(game.strategy_camera.focus.distance_to(camera_start)>0.1,"Command camera could not pan independently")
	var panel = game.kingdom_panel
	check(not panel.kingdom.is_empty() and panel.kingdom.progression.level==1,"Persistent kingdom snapshot did not reach native UI")
	await panel.open()
	check(not game.strategy_camera.enabled,"Management panel did not own camera input")
	await issue(panel,"/v2/buildings/upgrade",{"key":"keep"})
	check((panel.kingdom.tasks.any(func(t):return t.key=="keep") or panel.kingdom.buildings.keep>=2),"Building button failed: "+panel.last_error)
	await issue(panel,"/v2/units/train",{"key":"swordsman","quantity":1})
	check((panel.kingdom.tasks.any(func(t):return t.kind=="training") or panel.kingdom.units.any(func(u):return u.type=="swordsman" and u.alive>=9)),"Army training failed: "+panel.last_error)
	await issue(panel,"/v2/empire/customize",{"name":"Emerald Empire","primaryColor":"#117744","secondaryColor":"#ddcc22","emblem":"eagle","bannerStyle":"square"})
	check(panel.kingdom.empire.emblem=="eagle","Empire customization did not persist")
	check(has_emblem(game.ruler,"eagle"),"Ruler did not display the server-selected emblem")
	check(has_emblem(game.villages[game.state.village.id],"eagle"),"Settlement flags or soldiers did not receive the emblem")
	await issue(panel,"/v2/army/preset",{"slot":1,"name":"Royal Host","formation":"wedge","stance":"aggressive","isDefense":false,"units":[{"type":"swordsman","quantity":8}]})
	check(not panel.command_data.is_empty() and panel.command_data.presets.size()==1,"Army preset did not reach the command UI")
	await panel.load_map()
	check(panel.map_data.tiles.size()==81 and int(panel.map_data.get("radius",0))==4,"Strategic ownership map did not load")
	var targets: Array = panel.map_data.tiles.filter(func(tile): return bool(tile.get("attackable",false)) and tile.ownerPlayerId == null and str(tile.get("siteType",""))=="empty")
	check(not targets.is_empty(),"Strategic map exposed no connected target")
	if not targets.is_empty():
		await issue(panel,"/v2/army/march",{"x":int(targets[0].x),"z":int(targets[0].z),"presetSlot":1,"kind":"attack"})
		check(not panel.command_data.get("marches",[]).is_empty(),"March did not reserve a real army")
		check(panel.command_data.get("reports",[]).is_empty(),"Departure fabricated an immediate battle")
		check(panel.kingdom.units[0].available<panel.kingdom.units[0].alive,"Deployed troops remained at home")
		var arrived = Time.get_ticks_msec()
		while panel.command_data.get("reports",[]).is_empty() and Time.get_ticks_msec()-arrived<60000:
			await create_timer(1.0).timeout
			await panel.refresh()
		if not panel.command_data.get("reports",[]).is_empty(): panel.show_replay(panel.command_data.reports[0])
		check(not panel.command_data.reports.is_empty(),"Battle result did not create a command report")
		check(panel.kingdom.realm.ownedTiles>=2,"Successful strategic battle did not expand territory")
		check(not panel.command_data.reports.is_empty() and panel.command_data.reports[0].replay!=null,"Server did not persist replay input")
		if DisplayServer.get_name()!="headless":
			for frame in range(3): await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://builds/battle.png")==OK,"Battle replay could not be rendered")
	panel.close_replay()
	var returned = Time.get_ticks_msec()
	while not panel.command_data.get("marches",[]).is_empty() and Time.get_ticks_msec()-returned<60000:
		await create_timer(1.0).timeout
		await panel.refresh()
	check(panel.command_data.get("marches",[]).is_empty(),"Army never released its reservation after returning")
	# A player can select a new screen while a real snapshot is still in flight.
	panel.refresh()
	await panel.open_section("Clan")
	check(panel.desired_section=="Clan","Background refresh overrode the selected council screen")
	check(not panel.clan_data.is_empty() and panel.clan_data.creationLevel==15,"Clan contract did not reach the native client")
	await issue(panel,"/v2/clans/create",{"name":"Too Early","tag":"EAR","emblem":"lion","primaryColor":"#770000","secondaryColor":"#ffcc00","admission":"open"})
	check(panel.clan_data.own==null and panel.status.text.contains("15"),"Native clan creation bypassed the server level gate")
	var test_clan = OS.get_environment("PRIME_TEST_CLAN_ID")
	if not test_clan.is_empty():
		var settlement_id: String = panel.kingdom.settlementId
		var building_tasks: Array = panel.kingdom.tasks.duplicate(true)
		await issue(panel,"/v2/clans/join",{"clanId":test_clan})
		check(panel.clan_data.own != null and panel.clan_data.own.id==test_clan,"Native join did not enter the real clan region")
		check(panel.kingdom.settlementId==settlement_id,"Native join changed the permanent village identity")
		# Relocation is lossless, but a real server timer may legitimately finish
		# while this rendered integration test is running. Only tasks whose finish
		# time is still in the future must remain in the active queue.
		var joined_server_time := str(panel.kingdom.serverTime)
		for task_before in building_tasks:
			if str(task_before.finishes_at) <= joined_server_time: continue
			var task_id := str(task_before.id)
			check(panel.kingdom.tasks.any(func(task_after): return str(task_after.id)==task_id),"Native join lost an unfinished server queue task")
		await panel.load_map()
		check(panel.map_data.region.kind=="clan" and panel.map_data.region.plots.size()==64,"Native map did not display the allocated clan plots")
		await issue(panel,"/v2/clans/donate",{"resource":"wood","amount":10})
		check(panel.clan_data.own!=null and panel.clan_data.own.treasury.wood==10,"Native donation did not reach the persistent treasury")
		await issue(panel,"/v2/clans/leave",{})
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
	check(game.strategy_camera.enabled,"Closing management did not return control to the strategic camera")
	for quality in range(4):
		game.preferences.quality = quality
		game.preferences.apply(game)
		game.terrain.stream_at(Vector3.ZERO)
		check(game.terrain.chunks.size()==4,"Graphics profile rebuilt an open world")
	game.connection_failed()
	check(not game.strategy_camera.enabled,"Lost connection left camera input active")
	await game.recover_connection()
	check(game.network_online and game.strategy_camera.enabled,"Strategy reconnect failed")
	# Observe the completed server queue and its architectural milestone.
	var completed = Time.get_ticks_msec()
	while panel.kingdom.tasks.any(func(task): return task.kind=="building") and Time.get_ticks_msec()-completed<60000:
		await create_timer(1.0).timeout
		await panel.refresh()
	check(panel.kingdom.buildings.keep>=2,"The real construction queue did not complete")
	check(game.villages[game.state.village.id].population.size()>=13,"Visual progression removed original residents")
	# Check the actual server-populated council at different viewport sizes.
	for viewport_size in [Vector2i(1280,720),Vector2i(1536,864),Vector2i(960,540)]:
		root.size = viewport_size
		for section in ["Buildings","Research","Reports","Queues","Goals"]:
			panel.visible = true
			panel.select_section(section)
			for frame in range(3): await process_frame
			check_layout(game,panel,section)
	root.size = Vector2i(1280,720)
	game.preferences.quality = 1
	game.preferences.apply(game)
	if DisplayServer.get_name() != "headless":
		await panel.open_section("Buildings")
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://builds/kingdom.png")==OK,"Strategy screenshot could not be written")
	print("NATIVE_KINGDOM ",JSON.stringify({"failures":failures,"bounded_chunks":4,"direct_control":false,"strategic_command":true,"server_tasks":2,"empire_emblems":true,"strategic_map":true,"battle_reports":true,"timed_marches":true,"reservations_released":true,"graphics_profiles":4,"reconnect":true}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func has_emblem(node: Node,value: String) -> bool:
	if node.get_meta("empire_emblem","")==value: return true
	for child in node.get_children():
		if has_emblem(child,value): return true
	return false

func issue(panel: Control,path: String,body: Dictionary) -> void:
	var started = Time.get_ticks_msec()
	while panel.busy and Time.get_ticks_msec()-started<20000: await process_frame
	check(not panel.busy,"Realm refresh remained busy before a player order")
	if panel.busy: return
	await panel.submit(path,body)
	# Mobile orders can time out after the server commits. Recover through the
	# actual reconnect path; its durable request ID must settle the same order.
	if not panel.game.network_online:
		print("NATIVE_ORDER_RECOVERY ",path," ",panel.last_error)
		await panel.game.recover_connection()
		check(panel.game.network_online and panel.pending_path.is_empty(),"Interrupted order did not recover: "+panel.last_error)

func check_layout(game: Node,panel: Control,section: String) -> void:
	var viewport = root.get_visible_rect()
	for node in [game.hud.get_node("RealmHeader"),game.hud.get_node("RealmNavigation"),panel]:
		check(viewport.encloses(node.get_global_rect()),section+": interface extends beyond the viewport")
	var page: ScrollContainer = panel.tabs.get_current_tab_control()
	if page==null: return
	check(page.get_child(0).size.x<=page.size.x+1.0,section+": council content requires horizontal scrolling")
