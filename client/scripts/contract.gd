extends RefCounted

# Validate before a network response is allowed to create or mutate scene nodes.
static func number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func position(value) -> bool:
	return value is Dictionary and number(value.get("x")) and number(value.get("y")) and number(value.get("z"))

static func village(value) -> bool:
	if not value is Dictionary: return false
	if not value.get("id") is String or not value.get("ownerPlayerId") is String: return false
	if not value.get("name") is String or not value.get("stage") is String or not position(value.get("position")): return false
	if not value.get("npcs") is Array or value.npcs.size() != 13: return false
	var ids: Dictionary = {}
	var roles = {"soldier": 0, "villager": 0}
	for npc in value.npcs:
		if not npc is Dictionary or not npc.get("id") is String or ids.has(npc.id): return false
		if not npc.get("name") is String or not npc.get("ordinal") is float and not npc.get("ordinal") is int: return false
		if not npc.get("role") in roles or not position(npc.get("position")): return false
		ids[npc.id] = true
		roles[npc.role] += 1
	return roles.soldier == 8 and roles.villager == 5 and value.get("soldierCount") == 8 and value.get("villagerCount") == 5

static func player(value) -> bool:
	if not (value is Dictionary and value.get("id") is String and value.get("displayName") is String and position(value.get("position")) and number(value.get("yaw"))): return false
	if value.has("armyOrder") and not value.armyOrder in ["guard","follow"]: return false
	if value.has("mount") and not (value.mount is Dictionary and value.mount.get("mounted") is bool and position(value.mount.get("position"))): return false
	return true

static func cell(value) -> bool:
	return value is Dictionary and number(value.get("x")) and number(value.get("z")) and float(value.x) == int(value.x) and float(value.z) == int(value.z) and absf(value.x) <= 63 and absf(value.z) <= 63 and value.get("ownerPlayerId") is String and value.get("home") is bool

static func territories(value) -> bool:
	return value is Dictionary and number(value.get("owned")) and float(value.owned) == int(value.owned) and value.owned >= 1 and value.owned <= 16129 and value.get("cells") is Array and value.cells.size() <= 169 and value.cells.all(cell)

static func state(value) -> bool:
	if not value is Dictionary or not player(value.get("player")) or not village(value.get("village")): return false
	if value.has("scene"):
		var scene = value.scene
		if not scene is Dictionary or scene.get("type") != "settlement" or not scene.get("id") is String or not number(scene.get("halfSize")) or scene.halfSize != 128: return false
	if value.has("territories") and not territories(value.territories): return false
	var world = value.get("world")
	return world is Dictionary and world.get("id") is String and number(world.get("seed")) and number(world.get("sizeM")) and world.sizeM == 65536 and world.get("terrainVersion") == 1 and value.village.ownerPlayerId == value.player.id

static func accepts(path: String, value: Dictionary) -> bool:
	path = path.get_slice("?",0)
	if path == "/v2/scene": return state(value) and value.has("scene")
	if path == "/v2/kingdom": return kingdom(value)
	if path in ["/v2/buildings/upgrade","/v2/research/start","/v2/units/train","/v2/empire/customize"]: return kingdom(value.get("kingdom"))
	if path == "/v2/world/map": return strategic_map(value)
	if path == "/v2/clans": return clans(value)
	if path.begins_with("/v2/clans/"): return clans(value.get("clans"))
	if path in ["/v1/auth/register", "/v1/auth/login"]:
		var session = value.get("session")
		return session is Dictionary and session.get("token") is String and session.token.length() == 43 and state(value.get("state"))
	if path == "/v1/game": return state(value)
	if path == "/v1/world/nearby":
		if not value.get("villages") is Array or not value.get("players") is Array: return false
		if value.has("territories") and not territories(value.territories): return false
		return value.villages.size() <= 25 and value.players.size() <= 50 and value.villages.all(village) and value.players.all(player)
	return true

static func kingdom(value) -> bool:
	if not value is Dictionary: return false
	for key in ["resources","productionPerHour","buildings","research","empire","progression"]:
		if not value.get(key) is Dictionary: return false
	for key in ["food","wood","stone","iron","gold"]:
		if not number(value.resources.get(key)) or value.resources[key] < 0 or value.resources[key] > 1000000000000: return false
	if not value.get("serverTime") is String or not value.get("settlementId") is String or not value.get("stage") is String: return false
	if not number(value.get("storageCapacity")) or not number(value.get("armyCapacity")): return false
	if not number(value.progression.get("level")) or value.progression.level < 1 or value.progression.level > 100 or not number(value.progression.get("xp")): return false
	var empire = value.empire
	if not empire.get("name") is String or not empire.get("primaryColor") is String or not empire.get("secondaryColor") is String: return false
	if not empire.get("emblem") in ["lion","eagle","crown","stag","sun","wolf"] or not empire.get("bannerStyle") in ["square","swallowtail","pennant"]: return false
	if not value.get("catalog") is Array or value.catalog.size() > 64 or not value.get("quotes") is Array or value.quotes.size() > 48: return false
	if not value.get("tasks") is Array or value.tasks.size() > 3 or not value.get("units") is Array or value.units.size() > 20: return false
	for task in value.tasks:
		if not task is Dictionary or not task.get("id") is String or not task.get("kind") is String or not task.get("key") is String or not number(task.get("quantity")) or not number(task.get("target_level")) or not task.get("finishes_at") is String: return false
	for unit in value.units:
		if not unit is Dictionary or not unit.get("type") is String: return false
		for key in ["alive","wounded","dead"]:
			if not number(unit.get(key)) or unit[key] < 0: return false
	for quote in value.quotes:
		if not quote is Dictionary or not quote.get("key") is String or not quote.get("kind") is String or not quote.get("cost") is Dictionary: return false
		for key in ["current","next","maxLevel","durationSeconds"]:
			if not number(quote.get(key)): return false
	for entry in value.catalog:
		if not entry is Dictionary or not entry.get("key") is String or not entry.get("kind") in ["building","unit","research"] or not entry.get("data") is Dictionary or not entry.data.get("name") is String: return false
	return true

static func strategic_map(value) -> bool:
	if not value is Dictionary or not value.get("tiles") is Array or value.tiles.size() > 49 or not value.get("region") is Dictionary: return false
	if not value.region.get("id") is String or not value.region.get("name") is String or not number(value.region.get("ownPlot")): return false
	for tile in value.tiles:
		if not tile is Dictionary or not number(tile.get("x")) or not number(tile.get("z")) or not tile.get("kind") in ["settlement","neutral","resource","npc","fort"]: return false
	return true

static func clans(value) -> bool:
	if not value is Dictionary or not value.get("serverTime") is String or value.get("creationLevel") != 15 or value.get("memberCapacity") != 63: return false
	for key in ["directory","applications","invitations"]:
		if not value.get(key) is Array or value[key].size() > 50: return false
	for group in value.directory:
		if not group is Dictionary or not group.get("id") is String or not group.get("name") is String or not group.get("tag") is String or not number(group.get("members")): return false
	for invite in value.invitations:
		if not invite is Dictionary or not invite.get("clanId") is String or not invite.get("name") is String or not invite.get("expiresAt") is String: return false
	for application in value.applications:
		if not application is Dictionary or not application.get("clanId") is String or not application.get("name") is String or not application.get("status") is String: return false
	if value.get("own") == null: return true
	var group = value.own
	if not group is Dictionary or not group.get("id") is String or not group.get("regionId") is String or not group.get("name") is String or not group.get("tag") is String or not group.get("role") in ["leader","officer","member"]: return false
	if not group.get("capital") is Dictionary or not number(group.capital.get("x")) or not number(group.capital.get("z")): return false
	if not group.get("treasury") is Dictionary or not group.get("members") is Array or group.members.size() > 63 or not group.get("applications") is Array or group.applications.size() > 100: return false
	for key in ["food","wood","stone","iron","gold"]:
		if not number(group.treasury.get(key)) or group.treasury[key] < 0 or group.treasury[key] > 1000000000000: return false
	for member in group.members:
		if not member is Dictionary or not member.get("playerId") is String or not member.get("empireName") is String or not member.get("role") in ["leader","officer","member"] or not number(member.get("plot")): return false
	for application in group.applications:
		if not application is Dictionary or not application.get("playerId") is String or not application.get("empireName") is String: return false
	return true
