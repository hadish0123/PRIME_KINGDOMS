extends SceneTree

const Contract = preload("res://scripts/contract.gd")
const Preferences = preload("res://scripts/preferences.gd")
var failures: Array[String] = []

class Reply extends RefCounted:
	signal received(response: Dictionary)

class ControlledApi extends Node:
	var token = "test-token"
	var pending: Array = []
	func save_session(value: String) -> void: token = value
	func call_api(path: String, _body = null) -> Dictionary:
		var reply = Reply.new()
		pending.append({"path": path, "reply": reply})
		return await reply.received
	func complete(response: Dictionary) -> void:
		var request: Dictionary = pending.pop_front()
		request.reply.received.emit(response)

func _initialize() -> void: run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixture.json"))
	check(Contract.state(fixture.state), "Valid persisted village was rejected")
	var broken: Dictionary = fixture.state.duplicate(true)
	broken.village.npcs[0].position = {"x": "not a number"}
	check(not Contract.state(broken), "Malformed NPC coordinates could create scene nodes")
	broken = fixture.state.duplicate(true)
	broken.village.npcs[1].id = broken.village.npcs[0].id
	check(not Contract.state(broken), "Duplicate NPC identities were accepted")
	check(not Contract.accepts("/v1/game", {"error": "maintenance"}), "An invalid success response was accepted as a world")
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await game.enter_world(fixture.state.duplicate(true))
	game.api.queue_free()
	var api = ControlledApi.new()
	game.add_child(api)
	game.api = api
	game.connection_failed()
	check(game.player.frozen, "Connection loss failed to stop movement")
	game.toggle_map()
	game.toggle_map()
	check(game.player.frozen, "Closing the map bypassed a connection freeze")
	game.toggle_settings()
	game.toggle_settings()
	check(game.player.frozen, "Closing settings bypassed a connection freeze")
	game.player.position += Vector3(20, 0, 0)
	game.recover_connection()
	api.complete({"ok": true, "status": 200, "data": fixture.state.duplicate(true)})
	check(game.network_online and not game.player.frozen, "Reconnect did not resume the controls")
	check(game.player.position.distance_to(game.decode_position(fixture.state.player.position)) < 0.001, "Reconnect did not restore the server position")
	# A late movement response from a previous login must never mutate a new world.
	game.sync_position()
	game.leave_world("Testing an old request")
	await process_frame
	await game.enter_world(fixture.state.duplicate(true))
	api.complete({"ok": false, "status": 401, "error": "unauthorized"})
	check(game.in_world and not game.player.frozen, "Old login response signed out the new world")
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(game.player.frozen, "Backgrounding the app left movement active")
	api.complete({"ok": true, "status": 200, "data": {"position": fixture.state.player.position, "yaw": 0.0}})
	check(game.player.frozen, "Save completion bypassed the background freeze")
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	game.recover_connection()
	api.complete({"ok": true, "status": 200, "data": fixture.state.duplicate(true)})
	check(not game.player.frozen, "Android resume could not restore play")
	var village = game.villages[fixture.state.village.id]
	var npc = village.population[0]
	npc.update_presence(Vector3(10000, 0, 10000), 55.0)
	check(not npc.visible and not npc.is_physics_processing() and not npc.actor.animation.active, "Distant NPC continued physics or animation")
	npc.update_presence(npc.global_position, 55.0)
	check(npc.visible and npc.is_physics_processing() and npc.actor.animation.active, "Returning to an NPC failed to reactivate it")
	game.preferences.quality = 0
	game.preferences.apply(game)
	game.terrain.stream_at(game.player.position)
	check(game.terrain.chunks.size() <= 81, "LOW quality did not bound terrain allocation")
	game.preferences.quality = 1
	game.preferences.apply(game)
	game.toggle_settings()
	check(game.player.frozen and not game.map_panel.visible, "Settings failed to own the movement freeze")
	game.toggle_settings()
	check(not game.player.frozen, "Closing settings failed to resume play")
	print("NATIVE_RESILIENCE ", JSON.stringify({"failures": failures, "reconnect": true, "late_response": true, "android_resume": true, "bounded_npc_processing": true}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
