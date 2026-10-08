extends Node

const Contract = preload("res://scripts/contract.gd")

const BASE_URL = "https://prime-kingdoms-api-production.up.railway.app"
var base_url: String = BASE_URL
var token: String = ""

func load_session() -> void:
	var config = ConfigFile.new()
	if config.load("user://session.cfg") == OK:
		token = str(config.get_value("session", "token", ""))
		if token.length() != 43: token = ""

func save_session(value: String) -> void:
	token = value
	var config = ConfigFile.new()
	config.set_value("session", "token", value)
	if config.save("user://session.cfg") != OK:
		push_warning("Session is available for this run; device storage could not remember it.")

func call_api(path: String, body = null) -> Dictionary:
	var started = Time.get_ticks_msec()
	var http = HTTPRequest.new()
	http.timeout = 20.0
	http.body_size_limit = 1024 * 1024
	http.max_redirects = 0
	http.use_threads = true
	add_child(http)
	var headers = PackedStringArray(["Content-Type: application/json"])
	if not token.is_empty():
		headers.append("Authorization: Bearer " + token)
	var method = HTTPClient.METHOD_GET if body == null else HTTPClient.METHOD_POST
	var error = http.request(base_url + path, headers, method, "" if body == null else JSON.stringify(body, "", true, true))
	if error != OK:
		http.queue_free()
		return {"ok": false, "status": 0, "error": "connection_failed"}
	var response = await http.request_completed
	# Native CI diagnostics intentionally omit bodies, URLs and credentials.
	if "--smoke" in OS.get_cmdline_user_args():
		print("NATIVE_API ",JSON.stringify({"path":path,"result":response[0],"status":response[1],"elapsed_ms":Time.get_ticks_msec()-started}))
	http.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "status": 0, "error": "connection_timeout" if response[0] == HTTPRequest.RESULT_TIMEOUT else "connection_failed"}
	var parsed = JSON.parse_string(response[3].get_string_from_utf8())
	if not parsed is Dictionary:
		return {"ok": false, "status": response[1], "error": "invalid_response"}
	var success: bool = response[1] >= 200 and response[1] < 300
	if success and not Contract.accepts(path, parsed):
		return {"ok": false, "status": response[1], "error": "invalid_response"}
	return {"ok": success, "status": response[1], "data": parsed, "error": str(parsed.get("error", ""))}
