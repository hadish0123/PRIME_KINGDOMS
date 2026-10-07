extends SceneTree

const Contract = preload("res://scripts/contract.gd")
var failures: Array[String] = []
class Reply extends RefCounted:
	signal received(response: Dictionary)
class ControlledApi extends Node:
	var token = "test-token"
	var pending: Array = []
	var realm: Dictionary = {}
	func save_session(value: String) -> void: token = value
	func call_api(path: String,_body = null) -> Dictionary:
		if path=="/v2/kingdom": return {"ok":true,"status":200,"data":realm.duplicate(true)}
		if path=="/v2/command": return {"ok":true,"status":200,"data":{"presets":[],"reports":[]}}
		var reply = Reply.new()
		pending.append({"path":path,"reply":reply})
		return await reply.received
	func complete(response: Dictionary) -> void:
		var request: Dictionary = pending.pop_front()
		request.reply.received.emit(response)

func _initialize() -> void: run.call_deferred()
func check(value: bool,message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixture.json"))
	check(Contract.state(fixture.state),"Valid settlement was rejected")
	var broken: Dictionary = fixture.state.duplicate(true)
	broken.village.npcs[0].position = {"x":"not a number"}
	check(not Contract.state(broken),"Malformed resident coordinates were accepted")
	broken = fixture.state.duplicate(true)
	broken.village.npcs[1].id = broken.village.npcs[0].id
	check(not Contract.state(broken),"Duplicate resident identities were accepted")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await game.enter_world(fixture.state.duplicate(true))
	game.api.queue_free()
	var api = ControlledApi.new()
	api.realm = {"serverTime":"2026-01-01T00:00:00Z","settlementId":fixture.state.village.id,
		"empire":{"name":"Royal Court","primaryColor":"#781c2a","secondaryColor":"#d5b35e","emblem":"lion","bannerStyle":"square"},
		"realm":{"rank":1,"name":"Village","ownedTiles":1,"next":null},"progression":{"level":1,"xp":0,"next":null,"progress":0,"conquests":0,"prestige":0},
		"resources":{"food":100,"wood":100,"stone":100,"iron":100,"gold":100},"buildings":{"keep":1},"research":{},
		"units":[{"type":"swordsman","alive":8,"wounded":0,"dead":0}],"tasks":[],"healing":[],"catalog":[],"quotes":[],"productionPerHour":{},"storageCapacity":5000,"armyCapacity":100}
	game.add_child(api)
	game.api = api
	game.connection_failed()
	check(not game.strategy_camera.enabled,"Connection loss left camera input active")
	game.toggle_settings()
	game.toggle_settings()
	check(not game.strategy_camera.enabled,"Closing settings bypassed the connection freeze")
	game.recover_connection()
	api.complete({"ok":true,"status":200,"data":fixture.state.duplicate(true)})
	await process_frame
	check(game.network_online and game.strategy_camera.enabled,"Reconnect did not restore strategy input")
	# A response belonging to an earlier login cannot expire the new session.
	game.connection_failed()
	game.recover_connection()
	game.leave_world("Signed out")
	await process_frame
	await game.enter_world(fixture.state.duplicate(true))
	api.complete({"ok":false,"status":401,"error":"unauthorized"})
	await process_frame
	check(game.in_world and game.strategy_camera.enabled,"Late response expired a new login")
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not game.strategy_camera.enabled,"Android pause left camera input active")
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not game.strategy_camera.enabled,"Android resume skipped synchronization")
	game.recover_connection()
	api.complete({"ok":true,"status":200,"data":fixture.state.duplicate(true)})
	await process_frame
	check(game.network_online and game.strategy_camera.enabled,"Android resume failed to recover")
	var panel = game.kingdom_panel
	panel.pending_path = "/v2/units/train"
	panel.pending_body = {"requestId":panel.request_id(),"key":"swordsman","quantity":1}
	var identifier: String = panel.pending_body.requestId
	panel.save_pending()
	panel.pending_path = ""
	panel.pending_body = {}
	panel.load_pending()
	check(panel.pending_body.get("requestId")==identifier,"Restart changed an unresolved request ID")
	panel.remove_pending()
	panel.pending_path = ""
	panel.pending_body = {}
	var npc = game.villages[fixture.state.village.id].population[0]
	npc.update_presence(Vector3(10000,0,10000),55)
	check(not npc.visible and not npc.is_physics_processing() and not npc.actor.animation.active,"Culled NPC kept simulating")
	npc.update_presence(npc.global_position,55)
	check(npc.visible and npc.is_physics_processing(),"NPC did not resume")
	print("NATIVE_RESILIENCE ",JSON.stringify({"failures":failures,"reconnect":true,"late_response":true,"android_lifecycle":true,"durable_request_id":true}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
