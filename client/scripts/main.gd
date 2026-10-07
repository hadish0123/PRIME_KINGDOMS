extends Node3D

const Api = preload("res://scripts/api.gd")
const Terrain = preload("res://scripts/terrain.gd")
const SettlementTerrain = preload("res://scripts/settlement_terrain.gd")
const KingdomPanel = preload("res://scripts/kingdom_panel.gd")
const StrategyCamera = preload("res://scripts/strategy_camera.gd")
const EmpireVisuals = preload("res://scripts/empire_visuals.gd")
const Village = preload("res://scripts/village.gd")
const Actor = preload("res://scripts/actor.gd")
const Npc = preload("res://scripts/npc.gd")
const Horse = preload("res://scripts/horse.gd")
const Preferences = preload("res://scripts/preferences.gd")
const Contract = preload("res://scripts/contract.gd")
const Minimap = preload("res://scripts/minimap.gd")
const Text = preload("res://scripts/game_text.gd")
const RoyalUI = preload("res://scripts/royal_ui.gd")
var hud_crest: TextureRect
var hud_crest_card: PanelContainer
var api: Node
var terrain: Node3D
var ruler: Node3D
var world_root: Node3D
var villages: Dictionary = {}
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
var village_label: Label
var population_label: Label
var profile_name_label: Label
var profile_level_label: Label
var profile_stat_label: Label
var profile_xp_bar: ProgressBar
var nav_buttons: Dictionary = {}
var login_button: Button
var register_button: Button
var saved_session_button: Button
var in_world = false
var signing_out = false
var world_epoch = 0
var network_online = true
var reconnecting = false
var reconnect_clock = 0.0
var reconnect_delay = 1.0
var poll_clock = 0.0
var polling = false
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
var auth_ground: Node3D
var minimap: Control
var horse: Node3D
var kingdom_panel: Control
var army_display: Node3D
var army_display_signature = ""
var strategy_camera: Node3D
var resource_labels: Dictionary = {}
var displayed_resources: Dictionary = {}
var resource_targets: Dictionary = {}
var toast_label: Label
var toast_time = 0.0
var last_rank = 0
var settlement_clock = 0.0
var sound: AudioStreamPlayer

func _ready() -> void:
	get_tree().auto_accept_quit = false
	preferences.load_preferences()
	TranslationServer.set_locale(preferences.language)
	api = Api.new()
	add_child(api)
	setup_lighting()
	build_ui()
	build_settings()
	kingdom_panel = KingdomPanel.new()
	kingdom_panel.game = self
	hud.add_child(kingdom_panel)
	sound = AudioStreamPlayer.new()
	add_child(sound)
	preferences.apply(self)
	if "--smoke" in OS.get_cmdline_user_args(): return
	build_auth_stage()
	api.load_session()
	if not api.token.is_empty(): await attempt_saved_session()

func panel_style(color: Color, border: Color = Color(0.49,0.38,0.23)) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 11
	style.content_margin_bottom = 11
	style.shadow_color = Color(0,0,0,0.46)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0,2)
	return style

func ui_icon_texture(index: int) -> Texture2D:
	return RoyalUI.icon(index)

func royal_style(gold: bool = false,padding: float = 10.0,tint: Color = Color.WHITE) -> StyleBoxTexture:
	return RoyalUI.frame(gold,padding,tint)

func ui_icon(index: int,size_value: Vector2 = Vector2(34,34)) -> TextureRect:
	var icon = TextureRect.new()
	icon.texture = ui_icon_texture(index)
	icon.custom_minimum_size = size_value
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon

func resource_icon_index(key: String) -> int:
	match key.to_lower():
		"food": return 0
		"wood": return 1
		"stone": return 2
		"iron": return 3
		"gold": return 4
	return 14

func nav_icon_index(section: String) -> int:
	match section:
		"Buildings": return 5
		"Army": return 6
		"Research": return 7
		"World": return 8
		"Clan": return 9
		"Goals": return 10
		"Inbox": return 11
		"Settings": return 12
	return 14

func apply_nav_style(item: Button,active: bool) -> void:
	item.add_theme_stylebox_override("normal",royal_style(active,10))
	item.add_theme_stylebox_override("hover",royal_style(true,10,Color(1.05,1.03,0.97)))
	item.add_theme_stylebox_override("pressed",royal_style(true,10,Color(0.75,0.70,0.60)))
	var title: Label = item.get_meta("title_label",null)
	if is_instance_valid(title): title.modulate = Color(0.20,0.13,0.045) if active else Color.WHITE

func set_nav_active(section: String) -> void:
	for key in nav_buttons:
		apply_nav_style(nav_buttons[key],str(key)==section)

func premium_nav_button(section: String,callback: Callable) -> Button:
	var item = button("",callback)
	item.custom_minimum_size = Vector2(116,66)
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.set_meta("section",section)
	var center = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item.add_child(center)
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",8)
	center.add_child(row)
	row.add_child(ui_icon(nav_icon_index(section),Vector2(40,40)))
	var title = label(section,14,Color(0.97,0.88,0.69))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font",load("res://assets/fonts/Cinzel.ttf"))
	item.set_meta("title_label",title)
	row.add_child(title)
	nav_buttons[section]=item
	apply_nav_style(item,false)
	return item

func profile_panel() -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(207,78)
	card.add_theme_stylebox_override("panel",royal_style(false,7))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	card.add_child(row)
	var portrait_frame = PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(70,70)
	portrait_frame.add_theme_stylebox_override("panel",royal_style(false,3))
	row.add_child(portrait_frame)
	var portrait = TextureRect.new()
	portrait.texture = RoyalUI.PORTRAIT
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_frame.clip_contents = true
	portrait_frame.add_child(portrait)
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation",1)
	row.add_child(info)
	profile_name_label = label("Ruler",17,Color(0.98,0.83,0.49))
	profile_name_label.clip_text = true
	profile_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	profile_name_label.add_theme_font_override("font",load("res://assets/fonts/Cinzel.ttf"))
	profile_level_label = label("Lv. 1",12,Color(0.95,0.90,0.78))
	info.add_child(profile_name_label)
	info.add_child(profile_level_label)
	profile_xp_bar = ProgressBar.new()
	profile_xp_bar.custom_minimum_size = Vector2(108,7)
	profile_xp_bar.show_percentage = false
	profile_xp_bar.max_value = 100
	for entry in [["background",Color(0.09,0.085,0.06)],["fill",Color(0.91,0.69,0.29)]]:
		var bar = StyleBoxFlat.new()
		bar.bg_color = entry[1]
		bar.border_color = Color(0.44,0.34,0.15)
		bar.set_border_width_all(1)
		profile_xp_bar.add_theme_stylebox_override(entry[0],bar)
	info.add_child(profile_xp_bar)
	profile_stat_label = label("Prestige 0",11,Color(0.83,0.77,0.65))
	info.add_child(profile_stat_label)
	return card

func crest_panel() -> PanelContainer:
	hud_crest_card = PanelContainer.new()
	hud_crest_card.custom_minimum_size = Vector2(55,78)
	hud_crest_card.add_theme_stylebox_override("panel",royal_style(false,6))
	hud_crest = TextureRect.new()
	hud_crest.texture = load("res://assets/heraldry/lion.svg")
	hud_crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hud_crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hud_crest.modulate = Color(0.96,0.72,0.25)
	hud_crest_card.add_child(hud_crest)
	return hud_crest_card

func resource_card(key: String) -> PanelContainer:
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(91,78)
	card.add_theme_stylebox_override("panel",royal_style(false,6))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",2)
	card.add_child(row)
	row.add_child(ui_icon(resource_icon_index(key),Vector2(36,42)))
	var values = VBoxContainer.new()
	values.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	values.alignment = BoxContainer.ALIGNMENT_CENTER
	values.add_theme_constant_override("separation",2)
	row.add_child(values)
	values.add_child(label(key.capitalize(),10,Color(0.85,0.80,0.68)))
	var amount = label("—",17,Color(1.0,0.92,0.74))
	amount.clip_text = true
	amount.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	amount.custom_minimum_size.x = 34
	values.add_child(amount)
	resource_labels[key] = amount
	return card

func label(text_value: String, font_size: int = 18, color: Color = Color(0.86,0.84,0.76)) -> Label:
	var item = Label.new()
	item.text = Text.copy(text_value)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",color)
	if text_value.length()>64:
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if font_size >= 20: item.add_theme_font_override("font",load("res://assets/fonts/Cinzel.ttf"))
	return item

func button(text_value: String, callback: Callable) -> Button:
	var item = Button.new()
	item.text = Text.copy(text_value)
	item.custom_minimum_size.y = 46
	item.add_theme_font_size_override("font_size",16)
	item.add_theme_color_override("font_color",Color(0.96,0.86,0.66))
	item.add_theme_color_override("font_hover_color",Color(1.0,0.93,0.72))
	item.add_theme_constant_override("icon_max_width",24)
	item.add_theme_font_override("font",load("res://assets/fonts/Cinzel.ttf"))
	for entry in [["normal",Color.WHITE],["hover",Color(1.12,1.08,0.95)],["pressed",Color(0.7,0.65,0.55)],["disabled",Color(0.45,0.45,0.43)]]:
		item.add_theme_stylebox_override(entry[0],royal_style(false,10,entry[1]))
	item.add_theme_color_override("font_disabled_color",Color(0.42,0.40,0.35))
	item.pressed.connect(func():
		play_cue("select")
		callback.call())
	return item

func input_field(placeholder: String, secret: bool = false) -> LineEdit:
	var item = LineEdit.new()
	item.placeholder_text = Text.copy(placeholder)
	item.secret = secret
	item.custom_minimum_size.y = 44
	item.max_length = 254 if not secret else 256
	item.add_theme_font_size_override("font_size",17)
	item.add_theme_stylebox_override("normal",panel_style(Color(0.045,0.041,0.036)))
	return item

func royal_theme() -> Theme:
	var theme = Theme.new()
	theme.default_font_size = 16
	for type_name in ["Button","OptionButton","CheckButton","LineEdit","SpinBox"]:
		for entry in [["normal",Color(0.055,0.050,0.043)],["hover",Color(0.14,0.11,0.075)],["pressed",Color(0.24,0.17,0.08)],["focus",Color(0.10,0.083,0.060)],["disabled",Color(0.06,0.058,0.052)]]:
			theme.set_stylebox(entry[0],type_name,royal_style(false,10,Color(1.15,1.10,0.94) if entry[0]=="focus" else Color.WHITE))
		theme.set_color("font_color",type_name,Color(0.92,0.83,0.65))
		theme.set_color("font_hover_color",type_name,Color(1,0.9,0.7))
		theme.set_color("font_focus_color",type_name,Color(1,0.9,0.7))
		theme.set_color("font_placeholder_color",type_name,Color(0.59,0.56,0.49))
	theme.set_stylebox("panel","PopupMenu",panel_style(Color(0.045,0.042,0.034)))
	theme.set_stylebox("hover","PopupMenu",panel_style(Color(0.17,0.13,0.077)))
	theme.set_color("font_color","PopupMenu",Color(0.9,0.84,0.7))
	theme.set_color("font_hover_color","PopupMenu",Color(1,0.9,0.7))
	return theme

func build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	auth_panel = Control.new()
	auth_panel.theme = royal_theme()
	auth_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(auth_panel)
	auth_scroll = ScrollContainer.new()
	auth_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	auth_scroll.follow_focus = true
	auth_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	auth_panel.add_child(auth_scroll)
	var margins = MarginContainer.new()
	for side in ["left","right","top","bottom"]: margins.add_theme_constant_override("margin_"+side,28)
	margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margins.size_flags_vertical = Control.SIZE_EXPAND_FILL
	auth_scroll.add_child(margins)
	auth_card = PanelContainer.new()
	auth_card.custom_minimum_size.x = 440
	auth_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	auth_card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	auth_card.add_theme_stylebox_override("panel",panel_style(Color(0.035,0.032,0.028,0.94)))
	margins.add_child(auth_card)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	auth_card.add_child(column)
	column.add_child(label("PRIME KINGDOMS",32,Color(0.92,0.77,0.47)))
	column.add_child(label("Build a civilization. Command an empire.",17))
	display_name = input_field("Ruler name · for a new account")
	display_name.max_length = 24
	email = input_field("Email")
	email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	password = input_field("Password · at least 10 characters",true)
	for field in [display_name,email,password]: column.add_child(field)
	login_button = button("Enter Your Realm",func(): authenticate_user(false))
	register_button = button("Found Your Realm",func(): authenticate_user(true))
	column.add_child(login_button)
	column.add_child(register_button)
	password.text_submitted.connect(func(_value):
		if not login_button.disabled: authenticate_user(false))
	saved_session_button = button("Reconnect",attempt_saved_session)
	saved_session_button.visible = false
	column.add_child(saved_session_button)
	status_label = label("Your realm endures while you are away.",15)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.x = 360
	column.add_child(status_label)
	hud = Control.new()
	hud.theme = auth_panel.theme
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.visible = false
	ui.add_child(hud)
	var top = PanelContainer.new()
	top.name = "RealmHeader"
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 10
	top.offset_right = -10
	top.offset_top = 8
	top.add_theme_stylebox_override("panel",royal_style(false,7))
	hud.add_child(top)
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation",6)
	top.add_child(top_row)
	top_row.add_child(profile_panel())
	top_row.add_child(crest_panel())
	var identity_card = PanelContainer.new()
	identity_card.custom_minimum_size = Vector2(211,78)
	identity_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_card.add_theme_stylebox_override("panel",royal_style(false,8))
	top_row.add_child(identity_card)
	var identity = VBoxContainer.new()
	identity.add_theme_constant_override("separation",3)
	identity_card.add_child(identity)
	village_label = label("Village",17,Color(0.98,0.84,0.52))
	village_label.clip_text = true
	village_label.add_theme_font_override("font",load("res://assets/fonts/Cinzel.ttf"))
	population_label = label("",11,Color(0.88,0.83,0.72))
	population_label.clip_text = true
	population_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_child(village_label)
	identity.add_child(population_label)
	var wallets = HBoxContainer.new()
	wallets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wallets.add_theme_constant_override("separation",5)
	top_row.add_child(wallets)
	for key in ["food","wood","stone","iron","gold"]:
		wallets.add_child(resource_card(key))
	var status_card = PanelContainer.new()
	status_card.custom_minimum_size = Vector2(167,78)
	status_card.add_theme_stylebox_override("panel",royal_style(false,7))
	top_row.add_child(status_card)
	var status_box = VBoxContainer.new()
	status_box.add_theme_constant_override("separation",3)
	status_box.alignment = BoxContainer.ALIGNMENT_CENTER
	status_card.add_child(status_box)
	connection_label = label("● Connected",10,Color(0.47,0.94,0.47))
	connection_label.clip_text = true
	connection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_box.add_child(connection_label)
	var focus_row = HBoxContainer.new()
	focus_row.alignment = BoxContainer.ALIGNMENT_CENTER
	focus_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var focus = button("Focus Capital",func():
		if is_instance_valid(strategy_camera): strategy_camera.set_focus(Vector3(0,0.8,-20)))
	focus.custom_minimum_size = Vector2(143,38)
	focus.add_theme_font_size_override("font_size",12)
	focus.icon = ui_icon_texture(5)
	focus.expand_icon = true
	focus_row.add_child(focus)
	status_box.add_child(focus_row)
	minimap = Minimap.new()
	minimap.game = self
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -199
	minimap.offset_right = -18
	minimap.offset_top = 108
	minimap.offset_bottom = 289
	hud.add_child(minimap)
	var nav_shell = PanelContainer.new()
	nav_shell.name = "RealmNavigation"
	nav_shell.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	nav_shell.offset_left = -500
	nav_shell.offset_right = 500
	nav_shell.offset_top = -85
	nav_shell.offset_bottom = -7
	nav_shell.add_theme_stylebox_override("panel",royal_style(false,7))
	hud.add_child(nav_shell)
	var nav = HBoxContainer.new()
	nav.add_theme_constant_override("separation",5)
	nav_shell.add_child(nav)
	for section in ["Buildings","Army","Research","Map","Clan","Goals","Inbox"]:
		var name_value: String = section
		var display_name_value = "World" if section=="Map" else section
		nav.add_child(premium_nav_button(display_name_value,func():
			set_nav_active(display_name_value)
			kingdom_panel.open_section(name_value)))
	nav.add_child(premium_nav_button("Settings",func():
		set_nav_active("Settings")
		toggle_settings()))
	set_nav_active("Buildings")
	toast_label = label("",17,Color(0.94,0.83,0.59))
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.position = Vector2(-340,98)
	toast_label.custom_minimum_size.x = 680
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(toast_label)
	get_viewport().size_changed.connect(update_safe_area)
	update_safe_area()

func build_settings() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	settings_panel.position = Vector2(-260,-260)
	settings_panel.size = Vector2(520,520)
	settings_panel.add_theme_stylebox_override("panel",royal_style(false,16))
	hud.add_child(settings_panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	settings_panel.add_child(column)
	column.add_child(label("Settings",26,Color(0.92,0.77,0.47)))
	column.add_child(label("Graphics Quality",16))
	var quality = OptionButton.new()
	for profile in Preferences.PROFILES: quality.add_item(profile.name)
	quality.selected = preferences.quality
	quality.item_selected.connect(func(index):
		preferences.quality = index
		preferences.apply(self)
		preferences.save())
	column.add_child(quality)
	column.add_child(label("Camera Sensitivity",16))
	var sensitivity = HSlider.new()
	sensitivity.min_value = 0.5
	sensitivity.max_value = 2.0
	sensitivity.step = 0.1
	sensitivity.value = preferences.sensitivity
	sensitivity.value_changed.connect(func(value):
		preferences.sensitivity = value
		preferences.save())
	column.add_child(sensitivity)
	column.add_child(label("Sound Volume",16))
	var volume = HSlider.new()
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = preferences.sound_volume
	volume.value_changed.connect(func(value):
		preferences.sound_volume = value
		preferences.save())
	column.add_child(volume)
	column.add_child(label("Language · English",16))
	column.add_child(label("Progress is saved online. Your queues continue while away.",14))
	column.add_child(button("Sign Out",sign_out))
	column.add_child(button("Return to Realm",toggle_settings))
	settings_panel.visible = false

func update_safe_area() -> void:
	if OS.get_name() != "Android": return
	var screen = Vector2(DisplayServer.window_get_size())
	if screen.x<=0 or screen.y<=0: return
	var safe = DisplayServer.get_display_safe_area()
	var factor = get_viewport().get_visible_rect().size/screen
	hud.offset_left = maxf(0,safe.position.x*factor.x)
	hud.offset_top = maxf(0,safe.position.y*factor.y)
	hud.offset_right = -maxf(0,(screen.x-safe.end.x)*factor.x)
	hud.offset_bottom = -maxf(0,(screen.y-safe.end.y)*factor.y)
	auth_scroll.offset_bottom = -float(DisplayServer.virtual_keyboard_get_height())*factor.y

func error_message(code: String) -> String: return Text.error(code)

func apply_empire(empire: Dictionary) -> void:
	if in_world: EmpireVisuals.apply(world_root,empire)
	if is_instance_valid(hud_crest):
		hud_crest.texture = load("res://assets/heraldry/%s.svg" % str(empire.get("emblem","lion")))
		hud_crest.modulate = Color(str(empire.get("secondaryColor","#ddbb66")))

func apply_realm(realm: Dictionary) -> void:
	if not in_world or realm.is_empty(): return
	var rank_value = int(realm.get("rank",1))
	village_label.text = str(state.player.displayName)+" · "+str(realm.name)
	if last_rank>0 and rank_value>last_rank:
		toast("Your realm has risen to "+str(realm.name)+".")
		play_cue("complete")
	last_rank = rank_value

func update_garrison(kingdom: Dictionary) -> void:
	if not in_world: return
	resource_targets = kingdom.resources.duplicate()
	if displayed_resources.is_empty(): displayed_resources = resource_targets.duplicate()
	population_label.text = Text.copy("%s · Level %d · %d holdings") % [kingdom.empire.name,kingdom.progression.level,kingdom.realm.ownedTiles]
	profile_name_label.text = str(state.player.displayName).to_upper()
	profile_level_label.text = Text.copy("Lv. %d") % int(kingdom.progression.level)
	var xp_now = int(kingdom.progression.get("xp",0))
	var xp_target = xp_now+1
	if kingdom.progression.get("next") != null: xp_target = maxi(xp_now+1,int(kingdom.progression.next.xp))
	profile_xp_bar.max_value = xp_target
	profile_xp_bar.value = xp_now
	profile_stat_label.text = Text.copy("Prestige %s") % format_amount(int(kingdom.progression.get("prestige",0)))
	var settlement = villages[state.village.id]
	settlement.apply_development(kingdom)
	var base_soldiers = 0
	for unit in kingdom.units:
		if unit.type=="swordsman": base_soldiers = mini(8,int(unit.get("available",unit.alive)))
	for npc in settlement.population:
		if npc.get_parent()==settlement and npc.role=="soldier":
			npc.present_in_garrison = npc.ordinal<base_soldiers
			npc.update_presence(strategy_camera.focus,110 if preferences.quality>0 else 65)
	var signature = JSON.stringify(kingdom.units)+str(preferences.quality)
	if signature == army_display_signature: return
	army_display_signature = signature
	if is_instance_valid(army_display):
		for npc in army_display.get_children(): settlement.population.erase(npc)
		army_display.queue_free()
	army_display = Node3D.new()
	settlement.add_child(army_display)
	var count = 0
	var budget: int = [8,16,24,32][preferences.quality]
	for unit in kingdom.units:
		var remaining = maxi(0,int(unit.get("available",unit.alive))-(8 if unit.type=="swordsman" else 0))
		for index in range(mini(remaining,budget-count)):
			var npc = Npc.new()
			army_display.add_child(npc)
			var at = Vector3(-40+(count%8)*2.4,0.1,38+floorf(count/8.0)*2.4)
			npc.setup({"id":"army:%s:%d"%[unit.type,index],"name":kingdom_panel.catalog_name("unit",str(unit.type)),"role":"soldier","ordinal":count+8},at)
			npc.terrain = terrain
			settlement.population.append(npc)
			count += 1
		if count>=budget: break
	EmpireVisuals.apply(army_display,kingdom.empire)

func enter_world(game_state: Dictionary) -> void:
	if not Contract.state(game_state) or not game_state.has("scene"):
		set_auth_busy(false,"Your settlement could not be loaded. Reconnect to continue.")
		return
	world_epoch += 1
	kingdom_panel.clear_session()
	if is_instance_valid(world_root): world_root.queue_free()
	if is_instance_valid(auth_stage): auth_stage.queue_free()
	auth_stage = null
	auth_camera = null
	auth_ground = null
	villages.clear()
	state = game_state
	army_display = null
	army_display_signature = ""
	resource_targets.clear()
	displayed_resources.clear()
	last_rank = 0
	var vp: Dictionary = state.village.position
	origin = Vector3(float(vp.x),float(vp.y),float(vp.z))
	world_root = Node3D.new()
	world_root.name = "Kingdom"
	add_child(world_root)
	terrain = SettlementTerrain.new()
	world_root.add_child(terrain)
	terrain.configure(state.world,origin,[state.village])
	terrain.nature.settlement_sites = Village.SLOTS.values()
	terrain.ensure_spawn(Vector3.ZERO)
	var settlement = Village.new()
	world_root.add_child(settlement)
	settlement.configure(state.village,origin,true)
	villages[state.village.id] = settlement
	for npc in settlement.population: npc.terrain = terrain
	ruler = Actor.new()
	ruler.name = "Ruler"
	world_root.add_child(ruler)
	ruler.setup("player")
	ruler.position = Vector3(3,0.1,-15)
	ruler.rotation.y = 0.45
	horse = Horse.new()
	world_root.add_child(horse)
	horse.position = Vector3(14,0.1,24)
	strategy_camera = StrategyCamera.new()
	strategy_camera.game = self
	world_root.add_child(strategy_camera)
	strategy_camera.selected.connect(select_settlement)
	in_world = true
	network_online = true
	signing_out = false
	reconnecting = false
	polling = false
	app_paused = false
	reconnect_delay = 1
	poll_clock = 0
	auth_panel.visible = false
	hud.visible = true
	settings_panel.visible = false
	preferences.apply(self)
	connection_label.text = "● Connected · realm restored"
	apply_control_state()
	await get_tree().process_frame

func select_settlement(screen_position: Vector2) -> void:
	if not in_world or not strategy_camera.enabled: return
	var camera: Camera3D = strategy_camera.camera
	var query = PhysicsRayQueryParameters3D.create(camera.project_ray_origin(screen_position),camera.project_ray_origin(screen_position)+camera.project_ray_normal(screen_position)*700,1)
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return
	var node: Node = hit.collider
	while is_instance_valid(node):
		if node.has_meta("building_key"):
			var key_value = str(node.get_meta("building_key"))
			strategy_camera.set_focus(node.global_position)
			kingdom_panel.selected_building = key_value
			kingdom_panel.open_section("Buildings")
			return
		node = node.get_parent()

func apply_control_state() -> void:
	if not is_instance_valid(strategy_camera): return
	strategy_camera.enabled = in_world and network_online and not app_paused and not signing_out and not quitting and not settings_panel.visible and not kingdom_panel.visible and not kingdom_panel.replay_visible()

func connection_failed(message: String = "Reconnecting to your realm…") -> void:
	if not in_world: return
	network_online = false
	reconnect_clock = 0
	connection_label.text = message
	apply_control_state()

func expire_session() -> void:
	api.save_session("")
	leave_world("Your session expired. Sign in to continue.")

func _process(delta: float) -> void:
	if not in_world:
		update_auth_camera(delta)
		update_safe_area()
		return
	for key in resource_targets:
		displayed_resources[key] = lerpf(float(displayed_resources.get(key,resource_targets[key])),float(resource_targets[key]),1-exp(-8*delta))
		resource_labels[key].text = format_amount(int(round(displayed_resources[key])))
	toast_time = maxf(0,toast_time-delta)
	toast_label.visible = toast_time>0
	settlement_clock += delta
	if settlement_clock>=0.75:
		settlement_clock = 0
		terrain.stream_at(Vector3.ZERO)
		for settlement in villages.values(): settlement.update_population(strategy_camera.focus,110.0 if preferences.quality>0 else 65.0)
	if "--smoke" in OS.get_cmdline_user_args() or app_paused or signing_out or quitting: return
	if not network_online:
		reconnect_clock += delta
		if reconnect_clock>=reconnect_delay and not reconnecting and not polling: recover_connection()
		return
	poll_clock += delta
	if poll_clock>=10 and not polling:
		poll_clock = 0
		poll_world()

func format_amount(amount: int) -> String:
	if amount>=1000000: return Text.copy("%.1fM") % (float(amount)/1000000)
	if amount>=10000: return Text.copy("%.1fK") % (float(amount)/1000)
	return str(amount)

func toast(message: String) -> void:
	toast_label.text = Text.copy(message)
	toast_time = 4.0
	toast_label.visible = true

func play_cue(key: String) -> void:
	if not is_instance_valid(sound) or preferences.sound_volume<=0: return
	var path = "res://assets/audio/"+key+".wav"
	if ResourceLoader.exists(path):
		sound.stream = load(path)
		sound.volume_db = linear_to_db(preferences.sound_volume*0.3)
		sound.play()

func recover_connection() -> void:
	if not in_world or reconnecting or polling: return
	var epoch = world_epoch
	reconnecting = true
	reconnect_clock = 0
	var response: Dictionary = await api.call_api("/v2/scene")
	if epoch!=world_epoch or not in_world: return
	reconnecting = false
	if response.status==401:
		expire_session()
		return
	if not response.ok:
		reconnect_delay = minf(20,reconnect_delay*2)
		connection_label.text = "Reconnecting…"
		return
	if response.data.player.id!=state.player.id or response.data.village.id!=state.village.id:
		expire_session()
		return
	state = response.data
	network_online = true
	reconnect_delay = 1
	connection_label.text = "Connected · realm restored"
	await kingdom_panel.refresh()
	if epoch!=world_epoch or not in_world: return
	if not kingdom_panel.pending_path.is_empty():
		await kingdom_panel.submit(kingdom_panel.pending_path,kingdom_panel.pending_body)
	apply_control_state()

func poll_world() -> void:
	var epoch = world_epoch
	polling = true
	var response: Dictionary = await api.call_api("/v2/presence")
	if epoch!=world_epoch or not in_world: return
	polling = false
	if response.ok:
		connection_label.text = Text.copy("Online · %d rulers") % int(response.data.online)
		await kingdom_panel.refresh()
	elif response.status==401: expire_session()
	else: connection_failed()

func toggle_settings() -> void:
	if not in_world: return
	kingdom_panel.close()
	settings_panel.visible = not settings_panel.visible
	set_nav_active("Settings" if settings_panel.visible else "")
	apply_control_state()

func _unhandled_input(event: InputEvent) -> void:
	if in_world and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_M: kingdom_panel.open_section("Map")
		elif event.keycode==KEY_ESCAPE:
			if kingdom_panel.replay_visible(): kingdom_panel.close_replay()
			elif kingdom_panel.visible: kingdom_panel.close()
			else: toggle_settings()

func sign_out() -> void:
	if signing_out or not in_world: return
	var epoch = world_epoch
	signing_out = true
	apply_control_state()
	var response: Dictionary = await api.call_api("/v1/auth/logout",{})
	if epoch!=world_epoch or not in_world: return
	signing_out = false
	if not response.ok and response.status!=401:
		connection_failed("Reconnect to sign out securely.")
		return
	api.save_session("")
	leave_world("Signed out. Your realm is saved.")

func leave_world(message: String) -> void:
	world_epoch += 1
	kingdom_panel.clear_session()
	in_world = false
	if is_instance_valid(world_root): world_root.queue_free()
	villages.clear()
	ruler = null
	strategy_camera = null
	hud.visible = false
	settings_panel.visible = false
	auth_panel.visible = true
	polling = false
	reconnecting = false
	signing_out = false
	set_auth_busy(false,message)
	saved_session_button.visible = false
	build_auth_stage()

func request_quit() -> void:
	if quitting: return
	quitting = true
	apply_control_state()
	# All kingdom writes have durable request IDs before transmission.
	get_tree().quit()

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_PAUSED and in_world:
		app_paused = true
		apply_control_state()
	elif what==NOTIFICATION_APPLICATION_RESUMED and in_world:
		app_paused = false
		connection_failed("Restoring your realm…")
		update_safe_area()
	elif what==NOTIFICATION_WM_CLOSE_REQUEST: request_quit()
	elif what==NOTIFICATION_WM_GO_BACK_REQUEST:
		if in_world:
			if kingdom_panel.replay_visible(): kingdom_panel.close_replay()
			elif kingdom_panel.visible: kingdom_panel.close()
			else: toggle_settings()
		else: request_quit()

func build_auth_stage(force: bool = false) -> void:
	if ("--smoke" in OS.get_cmdline_user_args() and not force) or is_instance_valid(auth_stage): return
	# Decorative real 3D scenery. This is never used as an account or a saved village.
	auth_stage = Node3D.new()
	add_child(auth_stage)
	var ground = Terrain.new()
	auth_ground = ground
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
	hero.position = Vector3(5, 0.1, 25)
	hero.rotation.y = PI+0.2
	auth_camera = Camera3D.new()
	auth_stage.add_child(auth_camera)
	auth_camera.fov = 58
	auth_camera.far = 6500
	auth_camera.current = true
	update_auth_camera(0.0)


func update_auth_camera(delta: float) -> void:
	if not is_instance_valid(auth_camera): return
	auth_angle += delta * 0.08
	auth_camera.position = Vector3(3.1+sin(auth_angle)*0.3, 1.8, 29)
	auth_camera.look_at(Vector3(0, 3.4, -19))
	if is_instance_valid(auth_ground): auth_ground.stream_at(Vector3(5,0,25))


func setup_lighting() -> void:
	var environment = Environment.new()
	var sky = Sky.new()
	var sky_material = ShaderMaterial.new()
	sky_material.shader = load("res://shaders/sky.gdshader")
	sky_material.set_shader_parameter("panorama",load("res://assets/textures/sky.hdr"))
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = 0.34
	environment.ambient_light_color = Color(0.82, 0.80, 0.77)
	environment.ambient_light_sky_contribution = 0.25
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.69, 0.75, 0.80)
	environment.fog_density = 0.00012
	environment.fog_sky_affect = 0.0
	var world_environment = WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, -24, 0)
	sun.light_color = Color(1.0, 0.92, 0.80)
	sun.light_energy = 0.82
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 0.6
	add_child(sun)


func set_auth_busy(value: bool, message: String) -> void:
	login_button.disabled = value
	register_button.disabled = value
	saved_session_button.disabled = value
	status_label.text = message


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
		await enter_authenticated()
	else: set_auth_busy(false, error_message(response.error))


func enter_authenticated() -> void:
	var response: Dictionary = await api.call_api("/v2/scene")
	if response.ok:
		await enter_world(response.data)
		await kingdom_panel.refresh()
	else:
		set_auth_busy(false,"Settlement could not load. Retry your saved session.")
		saved_session_button.visible = true


func attempt_saved_session() -> void:
	if api.token.is_empty() or in_world: return
	set_auth_busy(true, "Returning to your village…")
	var response: Dictionary = await api.call_api("/v2/scene")
	if response.ok:
		await enter_world(response.data)
		await kingdom_panel.refresh()
	else:
		if response.status == 401: api.save_session("")
		set_auth_busy(false, error_message(response.error))
		saved_session_button.visible = not api.token.is_empty()


func decode_position(p: Dictionary) -> Vector3:
	var canonical = Vector3(float(p.x), float(p.y), float(p.z)) - origin
	return terrain.to_view(canonical) if is_instance_valid(terrain) else canonical
