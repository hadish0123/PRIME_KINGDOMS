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
	return value is Dictionary and value.get("id") is String and value.get("displayName") is String and position(value.get("position")) and number(value.get("yaw"))

static func state(value) -> bool:
	if not value is Dictionary or not player(value.get("player")) or not village(value.get("village")): return false
	var world = value.get("world")
	return world is Dictionary and world.get("id") is String and number(world.get("seed")) and number(world.get("sizeM")) and world.sizeM == 65536 and world.get("terrainVersion") == 1 and value.village.ownerPlayerId == value.player.id

static func accepts(path: String, value: Dictionary) -> bool:
	if path in ["/v1/auth/register", "/v1/auth/login"]:
		var session = value.get("session")
		return session is Dictionary and session.get("token") is String and session.token.length() == 43 and state(value.get("state"))
	if path == "/v1/game": return state(value)
	if path == "/v1/player/move": return position(value.get("position")) and number(value.get("yaw"))
	if path == "/v1/world/nearby":
		if not value.get("villages") is Array or not value.get("players") is Array: return false
		return value.villages.size() <= 25 and value.players.size() <= 50 and value.villages.all(village) and value.players.all(player)
	return true
