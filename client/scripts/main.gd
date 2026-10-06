extends Node3D

const Api = preload("res://scripts/api.gd")
const Terrain = preload("res://scripts/terrain.gd")
const Player = preload("res://scripts/player.gd")
const Village = preload("res://scripts/village.gd")
const Actor = preload("res://scripts/actor.gd")
const TouchControls = preload("res://scripts/touch_controls.gd")
const Atlas = preload("res://scripts/atlas.gd")
const Preferences = preload("res://scripts/preferences.gd")
const Contract = preload("res://scripts/contract.gd")
var api: Node
var terrain: Node3D
var player: CharacterBody3D
var world_root: Node3D
var villages: Dictionary = {}
var known_villages: Dictionary = {}
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
var saved_session_button: Button
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
var world_epoch = 0
var network_online = true
var reconnecting = false
var reconnect_clock = 0.0
var reconnect_delay = 1.0
var presence_clock = 0.0
var app_paused = false
var quitting = false
var preferences = Preferences.new()
var settings_panel: Control
var render_distance = 480.0
var sun: DirectionalLight3D
var auth_stage: Node3D
var auth_camera: Camera3D
var auth_angle = 0.6
var auth_scroll: ScrollContainer
var auth_card: PanelContainer

func _ready() -> void:
	get_tree().auto_accept_quit = false
	preferences.load_preferences()
	api = Api.new()
	add_child(api)
	setup_lighting()
	build_ui()
	build_settings()
	preferences.apply(self)
	if "--smoke" in OS.get_cmdline_user_args(): return
	build_auth_stage()
	api.load_session()
	if not api.token.is_empty():
		await attempt_saved_session()

func attempt_saved_session() -> void:
	if api.token.is_empty() or in_world: return
	set_auth_busy(true, "Returning to your village…")
	var response: Dictionary = await api.call_api("/v1/game")
	if response.ok:
		await enter_world(response.data)
	else:
		if response.status == 401: api.save_session("")
		set_auth_busy(false, error_message(response.error))
		saved_session_button.visible = not api.token.is_empty()

func build_auth_stage(force: bool = false) -> void:
	if ("--smoke" in OS.get_cmdline_user_args() and not force) or is_instance_valid(auth_stage): return
	# Decorative real 3D scenery. This is never used as an account or a saved village.
	auth_stage = Node3D.new()
	add_child(auth_stage)
	var ground = Terrain.new()
	auth_stage.add_child(ground)
	var base = Vector3(0, Terrain.raw_height(0, 0, 7331), 0)
	var preview = {"id": "menu-scenery", "name": "", "position": {"x": 0, "y": base.y, "z": 0}, "npcs": []}
	ground.configure({"seed": 7331, "sizeM": 65536}, base, [preview])
	ground.ensure_spawn(Vector3.ZERO)
	var settlement = Village.new()
	auth_stage.add_child(settlement)
	settlement.configure(preview, base, false)
	var hero = Actor.new()
	auth_stage.add_child(hero)
	hero.setup("player")
	hero.position = Vector3(-1, 0.1, 22)
	hero.rotation.y = 0.6
	auth_camera = Camera3D.new()
	auth_stage.add_child(auth_camera)
	auth_camera.fov = 55
	auth_camera.current = true
	update_auth_camera(0.0)

func update_auth_camera(delta: float) -> void:
	if not is_instance_valid(auth_camera): return
	auth_angle += delta * 0.025
	auth_camera.position = Vector3(sin(auth_angle) * 35, 13, cos(auth_angle) * 35 + 8)
	auth_camera.look_at(Vector3(0, 3, -8))

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
	environment.ambient_light_energy = 0.42
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.70, 0.75, 0.70)
	environment.fog_density = 0.0015
	environment.fog_sky_affect = 0.12
	var world_environment = WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.light_color = Color(1.0, 0.89, 0.72)
	sun.light_energy = 1.1
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
	backdrop.color = Color(0.03, 0.07, 0.10, 0.38)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	auth_panel.add_child(backdrop)
	auth_scroll = ScrollContainer.new()
	auth_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	auth_scroll.follow_focus = true
	auth_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	auth_panel.add_child(auth_scroll)
	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	auth_scroll.add_child(center)
	var card = PanelContainer.new()
	auth_card = card
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
	password.text_submitted.connect(func(_text):
		if not login_button.disabled: authenticate_user(false))
	saved_session_button = button("RETRY SAVED SESSION", attempt_saved_session)
	saved_session_button.visible = false
	column.add_child(saved_session_button)
	status_label = label("8 soldiers · 5 villagers · one permanent home", 15, Color(0.69, 0.76, 0.72))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(420, 45)
	column.add_child(status_label)
	column.add_child(label("PRIME KINGDOMS · 0.3 · Online world", 13, Color(0.47, 0.57, 0.60)))

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
	top_actions.position = Vector2(-448, 20)
	top_actions.add_theme_constant_override("separation", 12)
	hud.add_child(top_actions)
	top_actions.add_child(button("MAP", toggle_map))
	top_actions.add_child(button("SETTINGS", toggle_settings))
	top_actions.add_child(button("SIGN OUT", sign_out))
	var hint = label("WASD · Shift run · Space jump · Hold right mouse to look", 14)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(26, -38)
	hud.add_child(hint)
	if DisplayServer.is_touchscreen_available():
		hint.text = "Left thumb: move   ·   Right thumb: look"
		touch_controls = TouchControls.new()
		hud.add_child(touch_controls)
		touch_controls.blocked_regions.append_array([info, top_actions])
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
	get_viewport().size_changed.connect(update_safe_area)
	update_safe_area()

func update_safe_area() -> void:
	if OS.get_name() != "Android": return
	var screen = Vector2(DisplayServer.window_get_size())
	if screen.x <= 0 or screen.y <= 0: return
	var safe = DisplayServer.get_display_safe_area()
	var factor = get_viewport().get_visible_rect().size / screen
	hud.offset_left = maxf(0.0, safe.position.x * factor.x)
	hud.offset_top = maxf(0.0, safe.position.y * factor.y)
	hud.offset_right = -maxf(0.0, (screen.x - safe.end.x) * factor.x)
	hud.offset_bottom = -maxf(0.0, (screen.y - safe.end.y) * factor.y)
	auth_scroll.offset_bottom = -float(DisplayServer.virtual_keyboard_get_height()) * factor.y

func build_settings() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	settings_panel.position = Vector2(-260, -235)
	settings_panel.size = Vector2(520, 470)
	settings_panel.add_theme_stylebox_override("panel", panel_style(Color(0.04, 0.09, 0.11, 0.98)))
	hud.add_child(settings_panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 15)
	settings_panel.add_child(column)
	column.add_child(label("SETTINGS", 27, Color(0.9, 0.78, 0.5)))
	column.add_child(label("Graphics quality", 18))
	var quality = OptionButton.new()
	quality.custom_minimum_size.y = 44
	for profile in Preferences.PROFILES: quality.add_item(profile.name)
	quality.selected = preferences.quality
	quality.item_selected.connect(func(index):
		preferences.quality = index
		preferences.apply(self)
		preferences.save()
		presence_clock = 1.0)
	column.add_child(quality)
	column.add_child(label("Camera sensitivity", 18))
	var sensitivity = HSlider.new()
	sensitivity.custom_minimum_size.y = 35
	sensitivity.min_value = 0.5
	sensitivity.max_value = 2.0
	sensitivity.step = 0.1
	sensitivity.value = preferences.sensitivity
	sensitivity.value_changed.connect(func(value):
		preferences.sensitivity = value
		preferences.apply(self)
		preferences.save())
	column.add_child(sensitivity)
	var invert = CheckButton.new()
	invert.text = "Invert vertical camera"
	invert.button_pressed = preferences.invert_y
	invert.toggled.connect(func(value):
		preferences.invert_y = value
		preferences.apply(self)
		preferences.save())
	column.add_child(invert)
	var details = label("LOW saves battery. Select BALANCED or HIGH for more distant scenery and shadows. FPS is a target and depends on your device.", 15)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.x = 440
	column.add_child(details)
	column.add_child(button("RETURN TO WORLD", toggle_settings))
	settings_panel.visible = false

func set_auth_busy(value: bool, message: String) -> void:
	login_button.disabled = value
	register_button.disabled = value
	saved_session_button.disabled = value
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
		"invalid_response": "The world could not be loaded safely. Retry your connection.",
		"world_capacity": "This world is full. Please try again later.",
	}
	return str(messages.get(code, "Cannot reach the world server. Check your connection and retry."))

func authenticate_user(registering: bool) -> void:
	if login_button.disabled or in_world: return
	if password.text.length() < 10 or password.text.to_utf8_buffer().size() > 256:
		set_auth_busy(false, error_message("password_length"))
		return
	if registering and (display_name.text.strip_edges().length() < 2 or display_name.text.strip_edges().length() > 24):
		set_auth_busy(false, error_message("invalid_name"))
		return
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
	if not Contract.state(game_state):
		set_auth_busy(false, error_message("invalid_response"))
		return
	world_epoch += 1
	if is_instance_valid(world_root): world_root.queue_free()
	if is_instance_valid(auth_stage): auth_stage.queue_free()
	auth_stage = null
	auth_camera = null
	villages.clear()
	known_villages.clear()
	remote_players.clear()
	state = game_state
	var vp: Dictionary = state.village.position
	origin = Vector3(float(vp.x), float(vp.y), float(vp.z))
	world_root = Node3D.new()
	world_root.name = "PersistentWorld"
	add_child(world_root)
	terrain = Terrain.new()
	world_root.add_child(terrain)
	terrain.configure(state.world, origin, [state.village])
	known_villages[state.village.id] = state.village
	player = Player.new()
	world_root.add_child(player)
	player.terrain = terrain
	player.half_world = float(state.world.sizeM) / 2.0 - 20.0
	player.position = decode_position(state.player.position)
	# Models face +Z, while the orbit camera looks toward -Z.
	player.yaw = wrapf(float(state.player.yaw) - PI, -PI, PI)
	player.actor.rotation.y = float(state.player.yaw)
	preferences.apply(self)
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
	network_online = true
	reconnecting = false
	saving = false
	polling = false
	app_paused = false
	reconnect_clock = 0.0
	reconnect_delay = 1.0
	map_panel.visible = false
	settings_panel.visible = false
	update_settlements()
	apply_control_state()
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

func update_settlements() -> void:
	if not is_instance_valid(player): return
	for id in villages.keys():
		var distance: float = villages[id].position.distance_to(player.position)
		if not known_villages.has(id) or distance > render_distance + 100.0:
			villages[id].queue_free()
			villages.erase(id)
	for settlement in known_villages.values():
		if decode_position(settlement.position).distance_to(player.position) < render_distance:
			add_village(settlement)
	for settlement in villages.values():
		settlement.update_population(player.global_position, 80.0 if preferences.quality > 0 else 55.0)
	for remote in remote_players.values():
		var active: bool = remote.node.position.distance_to(player.position) < 150.0
		remote.node.visible = active
		if remote.actor.animation: remote.actor.animation.active = active

func apply_control_state() -> void:
	if not in_world or not is_instance_valid(player): return
	var blocked: bool = not network_online or app_paused or signing_out or quitting or map_panel.visible or settings_panel.visible
	if blocked:
		player.touch_move = Vector2.ZERO
		player.touch_sprint = false
		player.jump_requested = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.frozen = blocked
	if touch_controls:
		touch_controls.enabled = not blocked
		if blocked: touch_controls.release_input()

func connection_failed(message: String = "Connection lost · reconnecting…") -> void:
	if not in_world: return
	network_online = false
	reconnect_clock = 0.0
	connection_label.text = message
	apply_control_state()

func expire_session() -> void:
	api.save_session("")
	leave_world("Session expired. Sign in to return to your village.")

func _process(delta: float) -> void:
	if not in_world:
		update_auth_camera(delta)
		update_safe_area()
		return
	terrain.stream_at(player.position)
	var p = player.position + origin
	position_label.text = "X %d   Z %d" % [p.x, p.z]
	for remote in remote_players.values():
		var distance: float = remote.node.position.distance_to(remote.target)
		remote.node.position = remote.node.position.lerp(remote.target, minf(delta * 4.0, 1.0))
		remote.node.rotation.y = lerp_angle(remote.node.rotation.y, remote.yaw, delta * 5.0)
		remote.actor.play_motion("walk" if distance > 0.25 else "idle")
	presence_clock += delta
	if presence_clock >= 0.5:
		presence_clock = 0.0
		update_settlements()
	if "--smoke" in OS.get_cmdline_user_args(): return
	if app_paused or signing_out or quitting: return
	if not network_online:
		reconnect_clock += delta
		if reconnect_clock >= reconnect_delay and not reconnecting and not saving and not polling:
			recover_connection()
		return
	save_clock += delta
	poll_clock += delta
	if save_clock >= 1.5 and not saving and not signing_out:
		save_clock = 0
		sync_position()
	if poll_clock >= 5.0 and not polling and not signing_out:
		poll_clock = 0
		poll_world()

func sync_position() -> bool:
	if not in_world or saving or not network_online: return false
	var epoch = world_epoch
	saving = true
	var p = player.position + origin
	var response: Dictionary = await api.call_api("/v1/player/move", {"position": {"x": p.x, "y": p.y, "z": p.z}, "yaw": player.actor.rotation.y})
	if epoch != world_epoch or not in_world: return false
	saving = false
	if response.ok:
		state.player.position = response.data.position
		state.player.yaw = response.data.yaw
		connection_label.text = "Connected · position saved"
		apply_control_state()
		return true
	if response.status == 401: expire_session()
	else: connection_failed("Restoring saved position…" if response.status == 409 else "Connection lost · reconnecting…")
	return false

func recover_connection() -> void:
	if not in_world or reconnecting or saving or polling: return
	var epoch = world_epoch
	reconnecting = true
	reconnect_clock = 0.0
	var response: Dictionary = await api.call_api("/v1/game")
	if epoch != world_epoch or not in_world: return
	reconnecting = false
	if response.status == 401:
		expire_session()
		return
	if not response.ok:
		reconnect_delay = minf(15.0, reconnect_delay * 2.0)
		connection_label.text = "Connection lost · retrying automatically"
		return
	if response.data.player.id != state.player.id or response.data.village.id != state.village.id:
		expire_session()
		return
	state = response.data
	player.position = decode_position(state.player.position)
	player.actor.rotation.y = float(state.player.yaw)
	player.velocity = Vector3.ZERO
	player.jump_requested = false
	terrain.ensure_spawn(player.position)
	known_villages[state.village.id] = state.village
	network_online = true
	reconnect_delay = 1.0
	save_clock = 0.0
	poll_clock = 5.0
	connection_label.text = "Reconnected · saved position restored"
	update_settlements()
	apply_control_state()

func poll_world() -> void:
	if not in_world or polling or not network_online: return
	var epoch = world_epoch
	polling = true
	var response: Dictionary = await api.call_api("/v1/world/nearby")
	if epoch != world_epoch or not in_world: return
	polling = false
	if response.ok and in_world:
		var visible_villages: Array = response.data.villages
		# Own home stays represented in terrain even while exploring far away.
		if not visible_villages.any(func(v): return v.id == state.village.id):
			visible_villages.append(state.village)
		known_villages.clear()
		for village in visible_villages: known_villages[village.id] = village
		terrain.update_villages(visible_villages)
		terrain.ensure_spawn(player.position)
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
				var body = StaticBody3D.new()
				body.collision_layer = 4
				body.collision_mask = 0
				var collider = CollisionShape3D.new()
				var capsule = CapsuleShape3D.new()
				capsule.radius = 0.32
				capsule.height = 1.8
				collider.shape = capsule
				collider.position.y = 0.9
				body.add_child(collider)
				node.add_child(body)
				node.position = decode_position(data.position)
				var name_tag = Label3D.new()
				name_tag.text = str(data.displayName)
				name_tag.position.y = 2.3
				name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				name_tag.font_size = 36
				name_tag.pixel_size = 0.008
				name_tag.visibility_range_end = 25.0
				node.add_child(name_tag)
				remote_players[data.id] = {"node": node, "actor": actor, "target": node.position, "yaw": float(data.yaw)}
			remote_players[data.id].target = decode_position(data.position)
			remote_players[data.id].yaw = float(data.yaw)
		update_settlements()
	elif response.status == 401: expire_session()
	else: connection_failed()

func toggle_map() -> void:
	if not in_world: return
	map_panel.visible = not map_panel.visible
	settings_panel.visible = false
	apply_control_state()
	var p = player.position + origin
	var v: Dictionary = state.village.position
	map_text.text = "65.536 × 65.536 km · shared persistent terrain\n\nYour location:  X %d   /   Z %d\nYour village:   X %d   /   Z %d\nHome distance:  %.0f m\n\nKnown nearby settlements: %d\nBeyond the villages, the world is currently empty." % [p.x, p.z, v.x, v.z, Vector2(p.x - float(v.x), p.z - float(v.z)).length(), known_villages.size()]

func toggle_settings() -> void:
	if not in_world: return
	settings_panel.visible = not settings_panel.visible
	map_panel.visible = false
	apply_control_state()

func _unhandled_input(event: InputEvent) -> void:
	if in_world and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M or event.keycode == KEY_TAB: toggle_map()
		elif event.keycode == KEY_ESCAPE:
			if map_panel.visible: toggle_map()
			else: toggle_settings()

func sign_out() -> void:
	if signing_out or not in_world: return
	if not network_online:
		connection_label.text = "Reconnect to save and sign out"
		return
	var epoch = world_epoch
	signing_out = true
	apply_control_state()
	connection_label.text = "Saving before sign out…"
	while epoch == world_epoch and in_world and (saving or polling): await get_tree().process_frame
	if epoch != world_epoch or not in_world: return
	var saved = await sync_position()
	if epoch != world_epoch or not in_world: return
	if not saved:
		signing_out = false
		apply_control_state()
		return
	var response: Dictionary = await api.call_api("/v1/auth/logout", {})
	if epoch != world_epoch or not in_world: return
	if not response.ok and response.status != 401:
		signing_out = false
		connection_failed("Position saved · reconnect to sign out")
		return
	api.save_session("")
	leave_world("Signed out. Your village and people are saved.")

func leave_world(message: String) -> void:
	world_epoch += 1
	in_world = false
	if is_instance_valid(world_root): world_root.queue_free()
	villages.clear()
	known_villages.clear()
	remote_players.clear()
	hud.visible = false
	map_panel.visible = false
	settings_panel.visible = false
	auth_panel.visible = true
	if touch_controls:
		touch_controls.release_input()
		touch_controls.player = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_auth_busy(false, message)
	saved_session_button.visible = false
	saving = false
	polling = false
	reconnecting = false
	signing_out = false
	build_auth_stage()

func request_quit() -> void:
	if quitting: return
	quitting = true
	if in_world:
		apply_control_state()
		while saving or polling: await get_tree().process_frame
		if in_world and network_online: await sync_position()
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and in_world:
		app_paused = true
		apply_control_state()
		if not saving and network_online: sync_position()
	elif what == NOTIFICATION_APPLICATION_RESUMED and in_world:
		app_paused = false
		connection_failed("Returning to the world…")
		update_safe_area()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST: request_quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if in_world:
			if map_panel.visible: toggle_map()
			else: toggle_settings()
		else: request_quit()
