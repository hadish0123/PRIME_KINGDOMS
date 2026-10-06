extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	var base_url = OS.get_environment("PRIME_TEST_API_URL")
	if not base_url.begins_with("http://127.0.0.1:"):
		push_error("Native account test requires a disposable localhost API")
		quit(1)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.api.base_url = base_url
	var credentials = {"email": "native-%d@example.com" % Time.get_ticks_usec(), "password": "N".repeat(256), "displayName": "Native Tester"}
	game.password.text = credentials.password
	check(game.password.text == credentials.password, "Native password field truncated a server-valid password")
	var created: Dictionary = await game.api.call_api("/v1/auth/register", credentials)
	check(created.ok and created.status == 201, "Native HTTP registration failed")
	if not created.ok:
		quit(1)
		return
	game.api.token = str(created.data.session.token)
	var initial: Dictionary = created.data.state
	await game.enter_world(initial)
	check(game.villages[initial.village.id].population.size() == 13, "Native registered village does not contain 13 people")
	var saved: Dictionary = initial.player.position.duplicate()
	saved.x = float(saved.x) + 2.1466295719
	saved.z = float(saved.z) - 0.3490549028
	var movement: Dictionary = await game.api.call_api("/v1/player/move", {"position": saved, "yaw": 0.5})
	check(movement.ok, "Native position save failed")
	game.player.position = game.decode_position(saved)
	game.player.frozen = true
	for i in range(3):
		game.player.position.x += 0.125
		check(await game.sync_position(),"Continuous fractional movement lost its saved position")
	saved = game.state.player.position.duplicate()
	var confirmed = await game.api.call_api("/v1/game")
	check(confirmed.ok and confirmed.data.player.position==saved,"Movement was rolled back by the server")
	await game.command_army("follow")
	check(game.state.player.armyOrder=="follow","Native march order did not persist")
	var nearby: Dictionary = await game.api.call_api("/v1/world/nearby")
	check(nearby.ok and nearby.data.villages.any(func(v): return v.id == initial.village.id), "Native account is missing from the shared map")
	var logout: Dictionary = await game.api.call_api("/v1/auth/logout", {})
	check(logout.ok, "Native logout failed")
	var revoked: Dictionary = await game.api.call_api("/v1/game")
	check(revoked.status == 401, "Revoked session was accepted")
	game.leave_world("Testing re-entry")
	await process_frame
	game.api.token = ""
	var joined: Dictionary = await game.api.call_api("/v1/auth/login", credentials)
	check(joined.ok, "Native account could not rejoin")
	if joined.ok:
		var restored: Dictionary = joined.data.state
		check(restored.village.id == initial.village.id, "Re-entry created a second village")
		check(restored.player.id == initial.player.id, "Re-entry created a second player")
		check(restored.village.soldierCount == 8 and restored.village.villagerCount == 5, "Re-entry changed the starter population")
		check(restored.player.position == saved, "Native saved position was not restored")
		check(restored.player.armyOrder=="follow" and restored.territories.owned==1,"Re-entry did not preserve army order and land")
		check(restored.village.npcs.map(func(n): return n.id) == initial.village.npcs.map(func(n): return n.id), "Re-entry replaced NPC identities")
		await game.enter_world(restored)
		game.api.token = str(joined.data.session.token)
		await game.sign_out()
		check(not game.in_world and game.api.token.is_empty(), "Native save-and-sign-out did not leave the world safely")
	print("NATIVE_ACCOUNT_CONTRACT ", JSON.stringify({"failures": failures, "starter_soldiers": 8, "starter_villagers": 5, "same_home_on_reentry": failures.is_empty()}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
