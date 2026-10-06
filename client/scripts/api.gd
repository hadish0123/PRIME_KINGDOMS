extends Node

const BASE_URL = "https://prime-kingdoms-api-production.up.railway.app"
var base_url: String = BASE_URL
var token: String = ""

func load_session() -> void:
	var config = ConfigFile.new()
	if config.load("user://session.cfg") == OK:
		token = str(config.get_value("session", "token", ""))

func save_session(value: String) -> void:
	token = value
	var config = ConfigFile.new()
	config.set_value("session", "token", value)
	config.save("user://session.cfg")

func call_api(path: String, body = null) -> Dictionary:
	var http = HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var headers = PackedStringArray(["Content-Type: application/json"])
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	var method = HTTPClient.METHOD_GET if body == null else HTTPClient.METHOD_POST
	var error = http.request(base_url + path, headers, method, "" if body == null else JSON.stringify(body))
	if error != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "error": "connection_failed"}
	var response = await http.request_completed
	http.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "error": "connection_failed"}
	var parsed = JSON.parse_string(response[3].get_string_from_utf8())
	if not parsed is Dictionary:
		return {"ok": false, "status": response[1], "error": "invalid_response"}
	return {"ok": response[1] >= 200 and response[1] < 300, "status": response[1], "data": parsed, "error": parsed.get("error", "")}
