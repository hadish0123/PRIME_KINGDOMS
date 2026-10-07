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
		push_error("Account test requires a disposable localhost API")
		quit(1)
		return
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.api.base_url = base
	var credentials = {"email":"native-%d@example.com"%Time.get_ticks_usec(),"password":"N".repeat(256),"displayName":"Royal Court"}
	game.password.text = credentials.password
	check(game.password.text==credentials.password,"Password field truncated valid credentials")
	var created: Dictionary = await game.api.call_api("/v1/auth/register",credentials)
	check(created.ok,"Account registration failed")
	if not created.ok:
		quit(1)
		return
	game.api.token = created.data.session.token
	var initial: Dictionary = created.data.state
	var scene: Dictionary = await game.api.call_api("/v2/scene")
	check(scene.ok,"Settlement contract failed")
	if not scene.ok:
		quit(1)
		return
	await game.enter_world(scene.data)
	await game.kingdom_panel.refresh()
	check(game.in_world and game.villages[initial.village.id].population.size()==13,"Registered settlement did not enter native scene")
	var logout: Dictionary = await game.api.call_api("/v1/auth/logout",{})
	check(logout.ok,"Logout failed")
	var revoked: Dictionary = await game.api.call_api("/v2/kingdom")
	check(revoked.status==401,"Revoked session was accepted")
	game.leave_world("Signed out")
	game.api.token = ""
	var joined: Dictionary = await game.api.call_api("/v1/auth/login",credentials)
	check(joined.ok,"Account could not rejoin")
	if joined.ok:
		game.api.token = joined.data.session.token
		var restored: Dictionary = joined.data.state
		check(restored.village.id==initial.village.id and restored.player.id==initial.player.id,"Sign-in changed permanent identities")
		check(restored.village.soldierCount==8 and restored.village.villagerCount==5,"Sign-in granted duplicate residents")
		check(restored.village.npcs.map(func(n):return n.id)==initial.village.npcs.map(func(n):return n.id),"Sign-in replaced resident identities")
		scene = await game.api.call_api("/v2/scene")
		await game.enter_world(scene.data)
		await game.sign_out()
		check(not game.in_world and game.api.token.is_empty(),"Secure sign-out did not leave the realm")
	print("NATIVE_ACCOUNT ",JSON.stringify({"failures":failures,"identity_preserved":true,"starter_residents":13,"session_revocation":true}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
