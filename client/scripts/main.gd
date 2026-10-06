extends Node3D

const Api = preload("res://scripts/api.gd")
const Terrain = preload("res://scripts/terrain.gd")
const Player = preload("res://scripts/player.gd")
const Village = preload("res://scripts/village.gd")
const Actor = preload("res://scripts/actor.gd")
const TouchControls = preload("res://scripts/touch_controls.gd")
const Atlas = preload("res://scripts/atlas.gd")
var api: Node
var terrain: Node3D
var player: CharacterBody3D
var world_root: Node3D
var villages: Dictionary = {}
var remote_players: Dictionary = {}
var state: Dictionary = {}
var origin = Vector3.ZERO
var ui: CanvasLayer
var auth_panel: Control
var hud: Control
var email: LineEdit
var password: LineEdit
var display_name: LineEdit
var status_label: Label
var connection_label: Label
var position_label: Label
var village_label: Label
var login_button: Button
var register_button: Button
var touch_controls: Control
var map_panel: Control
var map_text: Label
var atlas: Control
var saving = false
var polling = false
var save_clock = 0.0
var poll_clock = 0.0
var in_world = false
var signing_out = false

func _ready() -> void:
	Engine.max_fps = 60
	api = Api.new()
	add_child(api)
	setup_lighting()
	build_ui()
	if "--smoke" in OS.get_cmdline_user_args(): return
	api.load_session()
	if not api.token.is_empty():
		set_auth_busy(true, "Returning to your village…")
		var response: Dictionary = await api.call_api("/v1/game")
		if response.ok:
			await enter_world(response.data)
		else:
			if response.status == 401: api.save_session("")
			set_auth_busy(false, error_message(response.error))

func setup_lighting() -> void:
	var environment = Environment.new()
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.25, 0.43, 0.61)
	sky_material.sky_horizon_color = Color(0.79, 0.78, 0.64)
	sky_material.ground_bottom_color = Color(0.30, 0.32, 0.22)
	sky_material.ground_horizon_color = Color(0.79, 0.78, 0.64)
	sky_material.sun_angle_max = 12.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.75
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.70, 0.75, 0.70)
	environment.fog_density = 0.0015
	var world_environment = WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.light_color = Color(1.0, 0.89, 0.72)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	sun.shadow_bias = 0.04
	add_child(sun)

func panel_style(color: Color, border: Color = Color(0.47, 0.40, 0.26)) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style

func label(text_value: String, font_size: int = 18, color = Color(0.88, 0.89, 0.83)) -> Label:
	var item = Label.new()
	item.text = text_value
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	return item

func button(text_value: String, callback: Callable) -> Button:
	var item = Button.new()
	item.text = text_value
	item.custom_minimum_size.y = 46
	item.add_theme_font_size_override("font_size", 17)
	item.add_theme_stylebox_override("normal", panel_style(Color(0.10, 0.18, 0.21)))
	item.add_theme_stylebox_override("hover", panel_style(Color(0.18, 0.28, 0.29), Color(0.83, 0.69, 0.40)))
	item.add_theme_stylebox_override("pressed", panel_style(Color(0.30, 0.29, 0.20)))
	item.pressed.connect(callback)
	return item

func input_field(placeholder: String, secret: bool = false) -> LineEdit:
	var item = LineEdit.new()
	item.placeholder_text = placeholder
	item.secret = secret
	item.custom_minimum_size.y = 45
	item.add_theme_font_size_override("font_size", 18)
	item.max_length = 254 if not secret else 128
	item.add_theme_stylebox_override("normal", panel_style(Color(0.06, 0.11, 0.14), Color(0.24, 0.32, 0.33)))
	return item

func build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	auth_panel = Control.new()
	auth_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(auth_panel)
	var backdrop = ColorRect.new()
	backdrop.color = Color(0.03, 0.07, 0.10, 0.97)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	auth_panel.add_child(backdrop)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	auth_panel.add_child(center)
	var card = PanelContainer.new()
	card.custom_minimum_size.x = 480
	card.add_theme_stylebox_override("panel", panel_style(Color(0.055, 0.10, 0.13)))
	center.add_child(card)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 13)
	card.add_child(column)
	column.add_child(label("P R I M E   K I N G D O M S", 27, Color(0.90, 0.77, 0.48)))
	column.add_child(label("Your story begins with a village.", 17))
	display_name = input_field("Ruler name · required for a new account")
	display_name.max_length = 24
	column.add_child(display_name)
	email = input_field("Email")
	email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	column.add_child(email)
	password = input_field("Password · at least 10 characters", true)
	column.add_child(password)
	var actions = HBoxContainer.new()
	login_button = button("ENTER WORLD", func(): authenticate_user(false))
	register_button = button("CREATE ACCOUNT", func(): authenticate_user(true))
	for item in [login_button, register_button]:
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(item)
	column.add_child(actions)
	status_label = label("8 soldiers · 5 villagers · one permanent home", 15, Color(0.69, 0.76, 0.72))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(420, 45)
	column.add_child(status_label)
	column.add_child(label("Native 3D · Development build 0.2", 13, Color(0.47, 0.57, 0.60)))

	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	ui.add_child(hud)
	var info = PanelContainer.new()
	info.position = Vector2(22, 18)
	info.custom_minimum_size.x = 315
	info.add_theme_stylebox_override("panel", panel_style(Color(0.035, 0.07, 0.09, 0.88)))
	hud.add_child(info)
	var info_column = VBoxContainer.new()
	info.add_child(info_column)
	info_column.add_child(label("PRIME KINGDOMS", 20, Color(0.9, 0.78, 0.5)))
	village_label = label("", 17)
	info_column.add_child(village_label)
	info_column.add_child(label("8 SOLDIERS    /    5 VILLAGERS", 13))
	connection_label = label("Connected", 13, Color(0.62, 0.79, 0.61))
	info_column.add_child(connection_label)
	position_label = label("", 12, Color(0.66, 0.71, 0.67))
	info_column.add_child(position_label)
	var top_actions = HBoxContainer.new()
	top_actions.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top_actions.position = Vector2(-288, 20)
	top_actions.add_theme_constant_override("separation", 12)
	hud.add_child(top_actions)
	top_actions.add_child(button("MAP", toggle_map))
	top_actions.add_child(button("SIGN OUT", sign_out))
	var hint = label("WASD · Shift run · Space jump · Hold right mouse to look", 14)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(26, -38)
	hud.add_child(hint)
	if DisplayServer.is_touchscreen_available():
		hint.text = "Left thumb: move   ·   Right thumb: look"
		touch_controls = TouchControls.new()
		hud.add_child(touch_controls)
	map_panel = PanelContainer.new()
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	map_panel.position = Vector2(-380, -240)
	map_panel.size = Vector2(760, 480)
	map_panel.add_theme_stylebox_override("panel", panel_style(Color(0.04, 0.09, 0.11, 0.98)))
	hud.add_child(map_panel)
	var map_column = VBoxContainer.new()
	map_panel.add_child(map_column)
	map_column.add_child(label("WORLD ATLAS", 28, Color(0.90, 0.78, 0.50)))
	var map_row = HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 22)
	map_column.add_child(map_row)
	map_text = label("", 16)
	map_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_text.custom_minimum_size.x = 355
	map_row.add_child(map_text)
	atlas = Atlas.new()
	atlas.game = self
	map_row.add_child(atlas)
	map_column.add_child(button("REGION / ENTIRE WORLD", func(): atlas.entire_world = not atlas.entire_world))
	map_column.add_child(button("RETURN TO WORLD", toggle_map))
	map_panel.visible = false

func set_auth_busy(value: bool, message: String) -> void:
	login_button.disabled = value
	register_button.disabled = value
	status_label.text = message

func error_message(code: String) -> String:
	var messages = {
		"invalid_credentials": "Email or password is incorrect.",
		"account_exists": "This account already exists. Use ENTER WORLD.",
		"invalid_email": "Enter a valid email address.",
		"invalid_name": "Choose a ruler name of 2–24 characters.",
		"password_length": "Use a password with at least 10 characters.",
		"unauthorized": "Your session expired. Sign in again.",
		"rate_limited": "Too many attempts. Try again in a minute.",
		"authentication_busy": "The server is busy. Please try again shortly.",
	}
	return str(messages.get(code, "Cannot reach the world server. Check your connection and retry."))

func authenticate_user(registering: bool) -> void:
	set_auth_busy(true, "Creating your permanent village…" if registering else "Opening your village…")
	var body = {"email": email.text.strip_edges(), "password": password.text}
	if registering: body.displayName = display_name.text.strip_edges()
	var response: Dictionary = await api.call_api("/v1/auth/register" if registering else "/v1/auth/login", body)
	if response.ok:
		api.save_session(str(response.data.session.token))
		password.clear()
		await enter_world(response.data.state)
	else: set_auth_busy(false, error_message(response.error))

func enter_world(game_state: Dictionary) -> void:
	state = game_state
	var vp: Dictionary = state.village.position
	origin = Vector3(float(vp.x), float(vp.y), float(vp.z))
	world_root = Node3D.new()
	world_root.name = "PersistentWorld"
	add_child(world_root)
	terrain = Terrain.new()
	world_root.add_child(terrain)
	terrain.configure(state.world, origin, [state.village])
	add_village(state.village)
	player = Player.new()
	world_root.add_child(player)
	player.terrain = terrain
	player.half_world = float(state.world.sizeM) / 2.0 - 20.0
	player.position = decode_position(state.player.position)
	player.yaw = float(state.player.yaw)
	player.actor.rotation.y = float(state.player.yaw)
	terrain.ensure_spawn(player.position)
	if touch_controls:
		touch_controls.player = player
		touch_controls.enabled = true
		touch_controls.release_input()
	village_label.text = str(state.player.displayName) + " · " + str(state.village.stage).capitalize()
	auth_panel.visible = false
	hud.visible = true
	in_world = true
	signing_out = false
	save_clock = 0
	poll_clock = 5
	connection_label.text = "Connected · home restored"
	await get_tree().process_frame

func decode_position(p: Dictionary) -> Vector3:
	return Vector3(float(p.x), float(p.y), float(p.z)) - origin

func add_village(data: Dictionary) -> void:
	if villages.has(data.id): return
	var settlement = Village.new()
	world_root.add_child(settlement)
	settlement.configure(data, origin, data.ownerPlayerId == state.player.id)
	villages[data.id] = settlement

func _process(delta: float) -> void:
	if not in_world: return
	terrain.stream_at(player.position)
	var p = player.position + origin
	position_label.text = "X %d   Z %d   ·   %d FPS" % [p.x, p.z, Engine.get_frames_per_second()]
	for remote in remote_players.values():
		var distance: float = remote.node.position.distance_to(remote.target)
		remote.node.position = remote.node.position.lerp(remote.target, minf(delta * 4.0, 1.0))
		remote.node.rotation.y = lerp_angle(remote.node.rotation.y, remote.yaw, delta * 5.0)
		remote.actor.play_motion("walk" if distance > 0.25 else "idle")
	if "--smoke" in OS.get_cmdline_user_args(): return
	save_clock += delta
	poll_clock += delta
	if save_clock >= 1.5 and not saving and not signing_out:
		save_clock = 0
		sync_position()
	if poll_clock >= 5.0 and not polling and not signing_out:
		poll_clock = 0
		poll_world()

func sync_position() -> void:
	saving = true
	var p = player.position + origin
	var response: Dictionary = await api.call_api("/v1/player/move", {"position": {"x": p.x, "y": p.y, "z": p.z}, "yaw": player.actor.rotation.y})
	if in_world:
		if response.ok:
			connection_label.text = "Connected · position saved"
			player.frozen = map_panel.visible or signing_out
		elif response.status == 401:
			api.save_session("")
			leave_world("Session expired. Sign in to return to your village.")
		else:
			player.frozen = true
			connection_label.text = "Reconnecting · movement paused"
			if response.status == 409:
				var current: Dictionary = await api.call_api("/v1/game")
				if current.ok and in_world:
					player.position = decode_position(current.data.player.position)
					player.velocity = Vector3.ZERO
	saving = false

func poll_world() -> void:
	polling = true
	var response: Dictionary = await api.call_api("/v1/world/nearby")
	if response.ok and in_world:
		var visible_villages: Array = response.data.villages
		# Own home stays represented in terrain even while exploring far away.
		if not visible_villages.any(func(v): return v.id == state.village.id):
			visible_villages.append(state.village)
		var ids = visible_villages.map(func(v): return v.id)
		for id in villages.keys():
			if id not in ids:
				villages[id].queue_free()
				villages.erase(id)
		for village in visible_villages: add_village(village)
		terrain.update_villages(visible_villages)
		var remote_ids = response.data.players.map(func(p): return p.id)
		for id in remote_players.keys():
			if id not in remote_ids:
				remote_players[id].node.queue_free()
				remote_players.erase(id)
		for data in response.data.players:
			if not remote_players.has(data.id):
				var node = Node3D.new()
				world_root.add_child(node)
				var actor = Actor.new()
				node.add_child(actor)
				actor.setup("player")
				node.position = decode_position(data.position)
				var name_tag = Label3D.new()
				name_tag.text = str(data.displayName)
				name_tag.position.y = 2.3
				name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				name_tag.font_size = 36
				node.add_child(name_tag)
				remote_players[data.id] = {"node": node, "actor": actor, "target": node.position, "yaw": float(data.yaw)}
			remote_players[data.id].target = decode_position(data.position)
			remote_players[data.id].yaw = float(data.yaw)
	polling = false

func toggle_map() -> void:
	if not in_world: return
	map_panel.visible = not map_panel.visible
	player.frozen = map_panel.visible
	if touch_controls:
		touch_controls.enabled = not map_panel.visible
		touch_controls.release_input()
	var p = player.position + origin
	var v: Dictionary = state.village.position
	map_text.text = "65.536 × 65.536 km · shared persistent terrain\n\nYour location:  X %d   /   Z %d\nYour village:   X %d   /   Z %d\nHome distance:  %.0f m\n\nNearby settlements: %d\nBeyond the villages, the world is currently empty." % [p.x, p.z, v.x, v.z, Vector2(p.x - float(v.x), p.z - float(v.z)).length(), villages.size()]

func _unhandled_input(event: InputEvent) -> void:
	if in_world and event is InputEventKey and event.pressed:
		if event.keycode == KEY_M or event.keycode == KEY_TAB: toggle_map()

func sign_out() -> void:
	if signing_out or not in_world: return
	signing_out = true
	player.frozen = true
	connection_label.text = "Saving before sign out…"
	while saving or polling: await get_tree().process_frame
	await sync_position()
	if not in_world: return
	if connection_label.text.begins_with("Reconnecting"):
		signing_out = false
		connection_label.text = "Cannot save yet · reconnect to sign out"
		return
	await api.call_api("/v1/auth/logout", {})
	api.save_session("")
	leave_world("Signed out. Your village and people are saved.")

func leave_world(message: String) -> void:
	in_world = false
	if is_instance_valid(world_root): world_root.queue_free()
	villages.clear()
	remote_players.clear()
	hud.visible = false
	map_panel.visible = false
	auth_panel.visible = true
	if touch_controls:
		touch_controls.release_input()
		touch_controls.player = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_auth_busy(false, message)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and in_world and not saving:
		if touch_controls: touch_controls.release_input()
		sync_position()
