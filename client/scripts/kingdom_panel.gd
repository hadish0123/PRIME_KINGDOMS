extends PanelContainer

const Text = preload("res://scripts/game_text.gd")
const CampaignMap = preload("res://scripts/campaign_map.gd")
const BattleReplay = preload("res://scripts/battle_replay.gd")
var game: Node
var kingdom: Dictionary = {}
var map_data: Dictionary = {}
var clan_data: Dictionary = {}
var command_data: Dictionary = {}
var selected_target: Dictionary = {}
var tabs: TabContainer
var status: Label
var busy = false
var pending_path = ""
var pending_body: Dictionary = {}
var token_epoch = -1
var timer_clock = 0.0
var last_error = ""
var selected_building = ""
var desired_section = ""
var extra_data: Dictionary = {}
var countdowns: Array = []
var received_ticks = 0
var server_seconds = 0
var replay_view: Control
var map_center: Dictionary = {}
var chat_channel = "global"
var view_request = 0
var waiting_reads = 0


func apply_section_layout(section: String) -> void:
	anchor_left = 0.015
	anchor_top = 0.16
	anchor_bottom = 0.88
	# Building/economy screens stay as a council sidebar so the settlement
	# remains visible. Tactical and social screens receive the full workspace.
	if section in ["Army","Empire","Clan","Map","Rankings","Wars","Chat"]:
		anchor_right = 0.97
	else:
		anchor_right = 0.435

func _ready() -> void:
	apply_section_layout("Buildings")
	add_theme_stylebox_override("panel",game.royal_style(false,15))
	visible = false

func _process(delta: float) -> void:
	if is_instance_valid(status): status.visible = not status.text.is_empty()
	timer_clock += delta
	if timer_clock < 0.25: return
	timer_clock = 0
	var now = server_seconds+int((Time.get_ticks_msec()-received_ticks)/1000)
	for item in countdowns:
		if is_instance_valid(item.label):
			var remaining = maxi(0,int(item.ends)-now)
			item.label.text = Text.duration(remaining) if remaining>0 else Text.copy("Completing…")
	if visible and not busy and waiting_reads==0 and not kingdom.is_empty() and game.network_online:
		if countdowns.any(func(item): return int(item.ends)<=now):
			countdowns.clear()
			if desired_section=="Wars": load_extra("Wars")
			else: refresh()

func open_section(section: String) -> void:
	view_request += 1
	var request = view_request
	desired_section = section
	visible = true
	select_section(section)
	apply_section_layout(section)
	game.set_nav_active("World" if section=="Map" else section)
	if not await wait_for_idle() or request!=view_request: return
	await open()
	if request!=view_request: return
	if section == "Map": await load_map()
	elif section == "Clan": await load_clans()
	elif section == "Army": await load_extra("Commanders")
	elif section in ["Goals","Inbox","Rankings","Commanders","Wars","Chat"]: await load_extra(section)
	if request==view_request: select_section(section)

func select_section(section: String) -> void:
	desired_section = section
	apply_section_layout(section)
	if not is_instance_valid(tabs): return
	for i in range(tabs.get_tab_count()):
		if tabs.get_tab_title(i)==section: tabs.current_tab=i

func replay_visible() -> bool:
	return is_instance_valid(replay_view) and replay_view.visible

func close_replay() -> void:
	if is_instance_valid(replay_view): replay_view.queue_free()
	replay_view = null
	game.apply_control_state()

func show_replay(report: Dictionary) -> void:
	if report.get("replay")==null:
		game.toast("This historical report has no recorded replay.")
		return
	close_replay()
	replay_view = BattleReplay.new()
	replay_view.game = game
	replay_view.report = report
	game.hud.add_child(replay_view)
	game.apply_control_state()

func catalog_name(kind: String,key: String) -> String:
	for entry in kingdom.get("catalog",[]):
		if entry.kind==kind and entry.key==key: return Text.copy(str(entry.data.name))
	return Text.name_for(key)

static func request_id() -> String:
	var bytes = Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var value = bytes.hex_encode()
	return Text.copy("%s-%s-%s-%s-%s") % [value.substr(0,8),value.substr(8,4),value.substr(12,4),value.substr(16,4),value.substr(20,12)]

func open() -> void:
	visible = true
	if not is_instance_valid(tabs): rebuild()
	game.settings_panel.visible = false
	game.apply_control_state()
	await refresh()

func close() -> void:
	view_request += 1
	visible = false
	game.set_nav_active("")
	game.apply_control_state()

func clear_session() -> void:
	close_replay()
	extra_data.clear()
	countdowns.clear()
	map_center.clear()
	kingdom.clear()
	map_data.clear()
	clan_data.clear()
	command_data.clear()
	selected_target.clear()
	pending_path = ""
	pending_body.clear()
	busy = false
	visible = false

func refresh() -> void:
	if busy or not game.in_world: return
	load_pending()
	busy = true
	var epoch: int = game.world_epoch
	var response: Dictionary = await game.api.call_api("/v2/kingdom")
	# A freshly-started local/production backend can need one warm-up request.
	# Retry only transient transport/server failures; never retry auth/contract errors.
	if not response.ok and (int(response.status)==0 or int(response.status)>=500):
		await get_tree().create_timer(0.35).timeout
		if epoch != game.world_epoch or not game.in_world:
			busy = false
			return
		response = await game.api.call_api("/v2/kingdom")
	if epoch != game.world_epoch or not game.in_world:
		busy = false
		return
	if response.ok:
		kingdom = response.data
		received_ticks = Time.get_ticks_msec()
		server_seconds = int(Time.get_unix_time_from_datetime_string(kingdom.serverTime))
		game.apply_empire(kingdom.empire)
		game.apply_realm(kingdom.realm)
		game.update_garrison(kingdom)
		var command_response: Dictionary = await game.api.call_api("/v2/command")
		if epoch != game.world_epoch or not game.in_world: return
		if command_response.ok: command_data = command_response.data
		busy = false
		rebuild()
	elif response.status == 401:
		busy = false
		game.expire_session()
	else:
		busy = false
		rebuild()
		status.text = "Could not refresh realm. Retry when connected."

func submit(path: String, body: Dictionary) -> void:
	if busy or not game.network_online: return
	var requested = body.duplicate(true)
	requested.erase("requestId")
	var previous = pending_body.duplicate(true)
	previous.erase("requestId")
	if not pending_path.is_empty() and (pending_path != path or previous != requested):
		status.text = "Retry the pending action before starting another."
		return
	if pending_path.is_empty():
		pending_path = path
		pending_body = body.duplicate(true)
		pending_body.requestId = request_id()
		if not save_pending():
			pending_path = ""
			pending_body.clear()
			status.text = Text.copy("Your device could not save this order. Free some storage and try again.")
			return
	busy = true
	disable_actions(self)
	last_error = ""
	var epoch: int = game.world_epoch
	status.text = "Saving…"
	var response: Dictionary = await game.api.call_api(pending_path,pending_body)
	if epoch != game.world_epoch or not game.in_world: return
	busy = false
	if response.ok:
		for entry in [["goals","Goals"],["commanders","Commanders"],["wars","Wars"],["chat","Chat"]]:
			if response.data.has(entry[0]): extra_data[entry[1]]=response.data[entry[0]]
		if response.data.has("read"): extra_data.erase("Inbox")
		remove_pending()
		pending_path = ""
		pending_body.clear()
		if response.data.has("kingdom"):
			kingdom = response.data.kingdom
			game.apply_empire(kingdom.empire)
			game.apply_realm(kingdom.realm)
			game.update_garrison(kingdom)
		if response.data.has("clans"):
			clan_data = response.data.clans
		if response.data.has("command"):
			command_data = response.data.command
		if response.data.has("realm"):
			game.apply_realm(response.data.realm)
		if response.data.has("battle"):
			var battle: Dictionary = response.data.battle
			battle.won = battle.result=="attacker"
			show_replay(battle)
			status.text = "Victory." if battle.result == "attacker" else ("Draw." if battle.result == "draw" else "Defeat.")
			selected_target.clear()
			map_data.clear()
		else:
			status.text = Text.order(path)
			game.toast(status.text)
		rebuild()
		await refresh()
	else:
		last_error = str(response.error)
		if response.status > 0 and response.status < 500 and response.status not in [401,408,429]:
			remove_pending()
			pending_path = ""
			pending_body.clear()
		status.text = Text.error(last_error)
		game.toast(status.text)
		if response.status == 401: game.expire_session()
		elif response.status==0 or response.status>=500: game.connection_failed()
		rebuild()
		if is_instance_valid(status): status.text = Text.error(last_error)

func disable_actions(node: Node) -> void:
	for child in node.get_children():
		if child is Button: child.disabled = true
		disable_actions(child)

func pending_file() -> String:
	return Text.copy("user://kingdom-action-%s.json") % game.state.player.id

func save_pending() -> bool:
	var file = FileAccess.open(pending_file(),FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify({"path":pending_path,"body":pending_body}))
	file.flush()
	return file.get_error()==OK

func remove_pending() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pending_file()))

func load_pending() -> void:
	if not pending_path.is_empty() or not FileAccess.file_exists(pending_file()): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(pending_file()))
	if data is Dictionary and data.get("path") is String and data.path.begins_with("/v2/") and data.get("body") is Dictionary and data.body.get("requestId") is String:
		pending_path = data.path
		pending_body = data.body

func page(title: String) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	tabs.add_child(scroll)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",10)
	scroll.add_child(column)
	return column

func council_resource_chip(key: String, value: int) -> PanelContainer:
	var chip = PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.custom_minimum_size.y = 37
	chip.add_theme_stylebox_override("panel",game.royal_style(false,5))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",5)
	chip.add_child(row)
	row.add_child(game.ui_icon(game.resource_icon_index(key),Vector2(25,25)))
	var amount = game.label(game.format_amount(value),13,Color(0.99,0.91,0.73))
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(amount)
	return chip

func build_cost_row(cost: Dictionary, duration_seconds: int = -1) -> HFlowContainer:
	var row = HFlowContainer.new()
	row.add_theme_constant_override("h_separation",4)
	row.add_theme_constant_override("v_separation",4)
	for key in ["food","wood","stone","iron","gold"]:
		if not cost.has(key): continue
		var chip = PanelContainer.new()
		var chip_style = game.panel_style(Color(0.034,0.030,0.023,0.98),Color(0.42,0.31,0.15))
		chip_style.set_corner_radius_all(6)
		chip_style.content_margin_left = 7
		chip_style.content_margin_right = 7
		chip_style.content_margin_top = 4
		chip_style.content_margin_bottom = 4
		chip.add_theme_stylebox_override("panel",chip_style)
		var value_row = HBoxContainer.new()
		value_row.add_theme_constant_override("separation",4)
		chip.add_child(value_row)
		value_row.add_child(game.ui_icon(game.resource_icon_index(key),Vector2(21,21)))
		value_row.add_child(game.label(str(int(cost[key])),13,Color(0.96,0.88,0.71)))
		row.add_child(chip)
	if duration_seconds >= 0:
		var time_chip = PanelContainer.new()
		var time_style = game.panel_style(Color(0.034,0.030,0.023,0.98),Color(0.42,0.31,0.15))
		time_style.set_corner_radius_all(6)
		time_style.content_margin_left = 8
		time_style.content_margin_right = 8
		time_style.content_margin_top = 4
		time_style.content_margin_bottom = 4
		time_chip.add_theme_stylebox_override("panel",time_style)
		var time_row = HBoxContainer.new()
		time_row.add_theme_constant_override("separation",4)
		time_chip.add_child(time_row)
		time_row.add_child(game.ui_icon(14,Vector2(20,20)))
		time_row.add_child(game.label(Text.duration(duration_seconds),13,Color(0.88,0.84,0.74)))
		row.add_child(time_chip)
	return row

func building_thumbnail(kind: String,key: String) -> PanelContainer:
	var frame = PanelContainer.new()
	frame.custom_minimum_size = Vector2(112,124)
	frame.clip_contents = true
	frame.add_theme_stylebox_override("panel",game.royal_style(false,5))
	var picture = TextureRect.new()
	picture.texture = game.RoyalUI.building(key if kind=="building" else "academy")
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(picture)
	return frame

func gold_action_button(text_value: String, callback: Callable) -> Button:
	var item = game.button("",callback)
	item.custom_minimum_size.y = 50
	var center = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item.add_child(center)
	var row = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",10)
	center.add_child(row)
	var icon = game.ui_icon(18,Vector2(26,26))
	row.add_child(icon)
	var title = game.label(text_value,20,Color(0.14,0.09,0.025))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	item.draw.connect(func():
		var icon_color = Color(0.32,0.26,0.15) if item.disabled else Color(0.18,0.12,0.04)
		var title_color = Color(0.18,0.16,0.12) if item.disabled else Color(0.14,0.09,0.025)
		if icon.modulate!=icon_color: icon.modulate = icon_color
		if title.get_theme_color("font_color")!=title_color: title.add_theme_color_override("font_color",title_color))
	for entry in [["normal",Color.WHITE],["hover",Color(1.10,1.07,1.0)],["pressed",Color(0.78,0.70,0.55)],["disabled",Color(0.62,0.59,0.50)]]:
		item.add_theme_stylebox_override(entry[0],game.royal_style(true,10,entry[1]))
	return item

func rebuild() -> void:
	countdowns.clear()
	var selected = tabs.current_tab if is_instance_valid(tabs) else 0
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	add_child(column)
	var heading_card = PanelContainer.new()
	heading_card.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	column.add_child(heading_card)
	var heading = VBoxContainer.new()
	heading.add_theme_constant_override("separation",7)
	heading_card.add_child(heading)
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation",9)
	heading.add_child(title_row)
	var crown_frame = PanelContainer.new()
	crown_frame.custom_minimum_size = Vector2(54,54)
	crown_frame.add_theme_stylebox_override("panel",game.royal_style(false,4))
	var crown_center = CenterContainer.new()
	crown_frame.add_child(crown_center)
	crown_center.add_child(game.ui_icon(17,Vector2(38,38)))
	title_row.add_child(crown_frame)
	var council_title = game.label("ROYAL COUNCIL",31,Color(0.99,0.86,0.56))
	council_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	council_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	council_title.tooltip_text = "Command construction, armies, research and realm affairs."
	title_row.add_child(council_title)
	var close_button = game.button("",close)
	close_button.icon = game.ui_icon_texture(19)
	close_button.expand_icon = true
	close_button.tooltip_text = Text.copy("Return to Realm")
	close_button.custom_minimum_size = Vector2(42,42)
	close_button.add_theme_font_size_override("font_size",24)
	title_row.add_child(close_button)
	var navigation = OptionButton.new()
	navigation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.custom_minimum_size.y = 44
	for title in ["Overview","Queues","Buildings","Army","Research","Empire","Clan","Map","Reports","Commanders","Goals","Inbox","Rankings","Wars","Chat"]:
		navigation.add_item(Text.copy("World" if title=="Map" else title))
		navigation.set_item_metadata(navigation.item_count-1,title)
	navigation.item_selected.connect(func(index): open_section(str(navigation.get_item_metadata(index))))
	heading.add_child(navigation)
	status = game.label("",14)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.visible = false
	column.add_child(status)
	if not kingdom.is_empty():
		column.add_child(game.label(Text.copy("%s · Level %d · %s") % [kingdom.empire.name,int(kingdom.progression.level),str(kingdom.realm.name)],17,Color(0.92,0.86,0.74)))
		var resource_strip = GridContainer.new()
		resource_strip.columns = 5
		resource_strip.add_theme_constant_override("h_separation",6)
		resource_strip.add_theme_constant_override("v_separation",4)
		column.add_child(resource_strip)
		for key in ["food","wood","stone","iron","gold"]:
			resource_strip.add_child(council_resource_chip(key,int(kingdom.resources.get(key,0))))
	tabs = TabContainer.new()
	tabs.custom_minimum_size.y = 100
	tabs.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	tabs.tabs_visible = false
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	if kingdom.is_empty():
		column.add_child(game.label("Summoning your realm…",18))
	if not kingdom.is_empty():
		build_overview(page("Overview"))
		build_queue(page("Queues"))
		build_upgrades(page("Buildings"),"building","/v2/buildings/upgrade")
		build_units(page("Army"))
		build_upgrades(page("Research"),"research","/v2/research/start")
		build_empire(page("Empire"))
		build_clans(page("Clan"))
		build_map(page("Map"))
		build_reports(page("Reports"))
		for title in ["Commanders","Goals","Inbox","Rankings","Wars","Chat"]: build_extra(page(title),title)
	var tab_count = tabs.get_tab_count()
	if tab_count > 0:
		var target_tab = clampi(selected,0,tab_count-1)
		tabs.current_tab = target_tab
		if not desired_section.is_empty(): select_section(desired_section)
		navigation.selected = maxi(0,tabs.current_tab)
	else:
		# Empty kingdom/error states intentionally render without management pages.
		# Do not assign current_tab when no tabs exist; Godot reports that as an error.
		navigation.selected = 0
	var action_shell = PanelContainer.new()
	action_shell.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	column.add_child(action_shell)
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation",6)
	action_shell.add_child(actions)
	var refresh_button = game.button("Refresh",refresh)
	refresh_button.icon = game.ui_icon_texture(15)
	refresh_button.expand_icon = true
	refresh_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(refresh_button)
	if not pending_path.is_empty():
		var retry_button = game.button("Retry Order",func(): submit(pending_path,pending_body))
		retry_button.icon = game.ui_icon_texture(15)
		retry_button.expand_icon = true
		actions.add_child(retry_button)
	var return_button = game.button("Return to Realm",close)
	return_button.icon = game.ui_icon_texture(16)
	return_button.expand_icon = true
	return_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return_button.add_theme_font_size_override("font_size",16)
	actions.add_child(return_button)

func cost_text(cost: Dictionary) -> String:
	var values: Array[String] = []
	var ordered = ["food","wood","stone","iron","gold"]
	for key in ordered:
		if cost.has(key):
			values.append(Text.copy(key.capitalize())+" "+game.format_amount(int(cost[key])))
	for key in cost:
		if str(key) not in ordered:
			values.append(Text.copy("%s %d") % [str(key).capitalize(),int(cost[key])])
	return "   ".join(values)

func build_overview(column: VBoxContainer) -> void:
	var realm: Dictionary = kingdom.realm
	column.add_child(game.label(Text.copy("%s · %d controlled territories") % [realm.name,int(realm.ownedTiles)],20,Color(0.94,0.80,0.50)))
	column.add_child(game.label(Text.copy("Ruler level %d · Keep %d · Conquests %d · Prestige %d") % [kingdom.progression.level,kingdom.buildings.keep,kingdom.progression.conquests,kingdom.progression.prestige],15))
	if realm.next != null:
		var next: Dictionary = realm.next
		column.add_child(game.label(Text.copy("NEXT: %s") % next.name,17))
		column.add_child(game.label(Text.copy("Requirements · Keep %d · Ruler level %d · %d territories · %d conquests") % [next.keep,next.playerLevel,next.ownedTiles,next.conquests],14))
	else:
		column.add_child(game.label("Empire tier reached. Endgame prestige and level progression continue.",14))
	column.add_child(game.label("Drag to survey your settlement. Tap a building to inspect it. Open the World to expand your borders.",14))
	if realm.next!=null:
		column.add_child(game.label(Text.copy("Economic development %d · Research %d · Prestige %d") % [realm.next.economy,realm.next.research,realm.next.prestige],14))

func build_queue(column: VBoxContainer) -> void:
	column.add_child(game.label("Production per hour: "+cost_text(kingdom.productionPerHour),15))
	column.add_child(game.label(Text.copy("Storage per resource: %d · XP: %d") % [kingdom.storageCapacity,kingdom.progression.xp],15))
	if kingdom.progression.next != null:
		column.add_child(game.label(Text.copy("Next level needs %d total XP; prestige and achievements also apply at high levels.") % kingdom.progression.next.xp,14))
	if kingdom.tasks.is_empty(): column.add_child(game.label("No active construction, training or research.",16))
	for task in kingdom.tasks:
		column.add_child(game.label(Text.copy("%s · %s") % [Text.name_for(str(task.kind)),catalog_name("unit" if task.kind=="training" else str(task.kind),str(task.key))],17))
		var timer = game.label("",15)
		column.add_child(timer)
		countdowns.append({"label":timer,"ends":Time.get_unix_time_from_datetime_string(str(task.finishes_at))})
	for task in kingdom.get("healing",[]):
		column.add_child(game.label(Text.copy("Hospital · %d soldiers recovering") % task.quantity,16))
		var timer = game.label("",15)
		column.add_child(timer)
		countdowns.append({"label":timer,"ends":Time.get_unix_time_from_datetime_string(str(task.finishes_at))})
	column.add_child(game.label("Work continues while you are away.",14))

func build_upgrades(column: VBoxContainer,kind: String,path: String) -> void:
	var quotes: Array = kingdom.quotes.filter(func(q): return q.kind==kind)
	if kind=="building" and not selected_building.is_empty():
		quotes = quotes.filter(func(q): return q.key==selected_building)
		column.add_child(game.button("View All Buildings",func():
			selected_building=""
			rebuild()))
	var queue: Array = kingdom.tasks.filter(func(task): return task.kind==kind)
	if not queue.is_empty():
		column.add_child(game.label(Text.copy("%s is in progress. This queue can begin another order when it finishes.") % catalog_name(kind,str(queue[0].key)),14))
		var queue_timer = game.label("",15)
		column.add_child(queue_timer)
		countdowns.append({"label":queue_timer,"ends":Time.get_unix_time_from_datetime_string(str(queue[0].finishes_at))})
	for quote in quotes:
		var key_value: String = quote.key
		var card = PanelContainer.new()
		card.add_theme_stylebox_override("panel",game.royal_style(false,11))
		column.add_child(card)
		var details = VBoxContainer.new()
		details.add_theme_constant_override("separation",7)
		card.add_child(details)
		var card_header = HBoxContainer.new()
		card_header.add_theme_constant_override("separation",11)
		details.add_child(card_header)
		card_header.add_child(building_thumbnail(kind,key_value))
		var title_stack = VBoxContainer.new()
		title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_stack.add_theme_constant_override("separation",5)
		card_header.add_child(title_stack)
		var title = game.label(Text.copy("%s · Level %d") % [catalog_name(kind,key_value),quote.current],18,Color(0.98,0.83,0.51))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_override("font",load("res://assets/fonts/Cinzel.ttf"))
		title_stack.add_child(title)
		var purpose = game.label(str(quote.get("purpose","")),13,Color(0.87,0.82,0.72))
		purpose.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_stack.add_child(purpose)
		var effect: Dictionary = quote.get("currentEffect",{})
		var next_effect: Dictionary = quote.get("nextEffect",{})
		if not effect.is_empty():
			var preview = game.label(Text.copy("%d → %d %s") % [effect.value,next_effect.value,str(effect.unit)],13)
			preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			title_stack.add_child(preview)
		title_stack.add_child(build_cost_row(quote.cost,int(quote.durationSeconds)))
		var unmet = false
		for requirement in quote.get("requirements",[]):
			var missing: bool = int(requirement.current)<int(requirement.level)
			unmet = unmet or missing
			details.add_child(game.label(Text.copy("Requires %s · Level %d (%d reached)") % [catalog_name(str(requirement.kind),str(requirement.key)),int(requirement.level),int(requirement.current)],13,Color(0.82,0.56,0.43) if missing else Color(0.66,0.76,0.62)))
		if quote.current>=quote.maxLevel: details.add_child(game.label("This improvement has reached its highest level.",14))
		var shortfall: Dictionary = {}
		for resource in quote.cost:
			if int(quote.cost[resource])>int(kingdom.resources[resource]): shortfall[resource]=int(quote.cost[resource])-int(kingdom.resources[resource])
		if not shortfall.is_empty(): details.add_child(game.label("Needed: "+cost_text(shortfall),13,Color(0.82,0.56,0.43)))
		var task = kingdom.tasks.filter(func(t): return t.kind==kind)
		if not task.is_empty() and task[0].key==key_value:
			var timer = game.label("",16)
			details.add_child(timer)
			countdowns.append({"label":timer,"ends":Time.get_unix_time_from_datetime_string(str(task[0].finishes_at))})
		var action_label = "Research" if kind=="research" else ("Construct" if quote.current==0 else "Upgrade")
		var action = gold_action_button(action_label,func(): submit(path,{"key":key_value}))
		action.disabled = quote.current>=quote.maxLevel or not task.is_empty() or not shortfall.is_empty() or unmet
		details.add_child(action)

func build_marches(column: VBoxContainer) -> void:
	column.add_child(game.label("Army Campaigns",18,Color(0.94,0.80,0.50)))
	var marches: Array = command_data.get("marches",[])
	if marches.is_empty(): column.add_child(game.label("Your armies are home. Select a holding on the world map to issue an order.",14))
	for march in marches:
		var card = PanelContainer.new()
		card.add_theme_stylebox_override("panel",game.panel_style(Color(0.07,0.066,0.057)))
		column.add_child(card)
		var details = VBoxContainer.new()
		card.add_child(details)
		details.add_child(game.label(str(march.name)+" · "+Text.name_for(str(march.phase)),17))
		details.add_child(game.label(Text.copy("%s · %s") % [Text.name_for(str(march.kind)),str(march.target.name)],14))
		var count = 0
		for unit in march.units: count+=int(unit.quantity)
		details.add_child(game.label(Text.copy("%d soldiers on duty") % count,14))
		if march.route.arrivesAt!=null:
			var timer = game.label("",15)
			details.add_child(timer)
			countdowns.append({"label":timer,"ends":Time.get_unix_time_from_datetime_string(str(march.route.arrivesAt))})
		if march.phase=="returning":
			details.add_child(game.label("Survivors become available when they reach your settlement.",13))
			if march.get("returnReason") not in [null,"recalled","battle_resolved"]:
				details.add_child(game.label(Text.error(str(march.returnReason)),13))
		else:
			var march_id: String = march.id
			details.add_child(game.button("Recall Army",func(): submit("/v2/army/recall",{"marchId":march_id})))
		var reports: Array = command_data.get("reports",[]).filter(func(report): return report.id==march.get("reportId"))
		if not reports.is_empty():
			var report: Dictionary = reports[0]
			details.add_child(game.button("View Report",func(): show_replay(report)))
	for arriving in command_data.get("incoming",[]):
		var friendly: bool = arriving.kind=="reinforce"
		column.add_child(game.label(Text.copy("%s · %s · %s") % [str(arriving.realmName),Text.copy("Allied Guard" if friendly else "Enemy Army"),Text.name_for(str(arriving.phase))],14,Color(0.73,0.83,0.69) if friendly else Color(0.90,0.55,0.45)))
		if arriving.route.arrivesAt!=null:
			var timer = game.label("",14)
			column.add_child(timer)
			countdowns.append({"label":timer,"ends":Time.get_unix_time_from_datetime_string(str(arriving.route.arrivesAt))})

func build_units(column: VBoxContainer) -> void:
	build_marches(column)
	var alive = 0
	var selectors: Dictionary = {}
	for unit in kingdom.units:
		alive += int(unit.alive)
		column.add_child(game.label(Text.copy("%s · %d ready · %d away · %d wounded · %d fallen") % [catalog_name("unit",str(unit.type)),unit.get("available",unit.alive),unit.get("deployed",0),unit.wounded,unit.dead],15))
		if int(unit.wounded)>0:
			var heal_key: String = unit.type
			var heal_count = mini(100,int(unit.wounded))
			column.add_child(game.button(Text.copy("Treat %d Wounded · %d Food · %d Gold") % [heal_count,heal_count*10,heal_count*2],func(): submit("/v2/units/heal",{"key":heal_key,"quantity":heal_count})))
		if int(unit.get("available",unit.alive)) > 0:
			var row = HBoxContainer.new()
			column.add_child(row)
			row.add_child(game.label("Assign "+catalog_name("unit",str(unit.type)),13))
			var amount = SpinBox.new()
			amount.min_value = 0
			amount.max_value = int(unit.get("available",unit.alive))
			amount.value = mini(int(unit.get("available",unit.alive)),8)
			amount.custom_minimum_size.x = 120
			row.add_child(amount)
			selectors[str(unit.type)] = amount
	column.add_child(game.label(Text.copy("Army capacity: %d / %d") % [alive,kingdom.armyCapacity],16))
	column.add_child(game.label("ARMY PRESET · choose the exact force you command into battle",16,Color(0.94,0.80,0.50)))
	var slot = SpinBox.new()
	slot.min_value = 1
	slot.max_value = 5
	slot.value = 1
	column.add_child(slot)
	var preset_name = game.input_field("Preset name")
	preset_name.text = "Royal Host"
	column.add_child(preset_name)
	var formation = OptionButton.new()
	for value in ["balanced","line","wedge","shield","square","skirmish"]:
		formation.add_item(Text.name_for(value))
		formation.set_item_metadata(formation.item_count-1,value)
	column.add_child(formation)
	var stance = OptionButton.new()
	for value in ["balanced","aggressive","defensive"]:
		stance.add_item(Text.name_for(value))
		stance.set_item_metadata(stance.item_count-1,value)
	column.add_child(stance)
	var defense = CheckButton.new()
	defense.text = "Use this preset as offline home defense"
	column.add_child(defense)
	var commander = OptionButton.new()
	commander.add_item("No Commander")
	commander.set_item_metadata(0,null)
	for leader in extra_data.get("Commanders",{}).get("commanders",[]):
		if leader.owned:
			commander.add_item(str(leader.name))
			commander.set_item_metadata(commander.item_count-1,leader.key)
	column.add_child(commander)
	column.add_child(game.button("Save Army",func():
		var chosen: Array = []
		for key in selectors:
			var quantity = int(selectors[key].value)
			if quantity > 0: chosen.append({"type":key,"quantity":quantity})
		submit("/v2/army/preset",{"slot":int(slot.value),"name":preset_name.text,"formation":formation.get_item_metadata(formation.selected),"stance":stance.get_item_metadata(stance.selected),"isDefense":defense.button_pressed,"commander":commander.get_item_metadata(commander.selected),"units":chosen})))
	if not command_data.is_empty():
		for preset in command_data.presets:
			var parts: Array[String] = []
			for unit in preset.units: parts.append("%s×%d"%[catalog_name("unit",str(unit.type)),int(unit.quantity)])
			column.add_child(game.label(Text.copy("Slot %d · %s · %s / %s%s\n%s") % [preset.slot,preset.name,Text.name_for(preset.formation),Text.name_for(preset.stance)," · DEFENSE" if preset.isDefense else "",", ".join(parts)],14))
			var delete_slot = int(preset.slot)
			column.add_child(game.button("Disband "+str(preset.name),func(): submit("/v2/army/preset/delete",{"slot":delete_slot})))
	column.add_child(game.label("Training",16,Color(0.94,0.80,0.50)))
	for entry in kingdom.catalog:
		if entry.kind != "unit": continue
		var key_value: String = entry.key
		column.add_child(game.label(Text.copy("%s · %s level %d · %s") % [entry.data.name,catalog_name("building",str(entry.data.facility)),entry.data.requiredLevel,cost_text(entry.data.cost)],14))
		var quantity = SpinBox.new()
		quantity.min_value = 1
		quantity.max_value = 100
		quantity.value = 1
		column.add_child(quantity)
		var train = game.button("Train "+str(entry.data.name),func(): submit("/v2/units/train",{"key":key_value,"quantity":int(quantity.value)}))
		train.disabled = int(kingdom.buildings.get(entry.data.facility,0))<int(entry.data.requiredLevel) or kingdom.tasks.any(func(t): return t.kind=="training")
		column.add_child(train)

func build_empire(column: VBoxContainer) -> void:
	var name_input = game.input_field("Empire name")
	name_input.text = kingdom.empire.name
	column.add_child(name_input)
	column.add_child(game.label("Primary Heraldic Color",16))
	var primary = ColorPickerButton.new()
	primary.edit_alpha = false
	primary.color = Color(str(kingdom.empire.primaryColor))
	primary.custom_minimum_size.y = 44
	column.add_child(primary)
	column.add_child(game.label("Secondary Heraldic Color",16))
	var secondary = ColorPickerButton.new()
	secondary.edit_alpha = false
	secondary.color = Color(str(kingdom.empire.secondaryColor))
	secondary.custom_minimum_size.y = 44
	column.add_child(secondary)
	var emblem = OptionButton.new()
	for key in ["lion","eagle","crown","stag","sun","wolf"]:
		emblem.add_item(Text.name_for(key))
		emblem.set_item_metadata(emblem.item_count-1,key)
	emblem.selected = ["lion","eagle","crown","stag","sun","wolf"].find(kingdom.empire.emblem)
	column.add_child(emblem)
	var banner = OptionButton.new()
	for key in ["square","swallowtail","pennant"]:
		banner.add_item(Text.name_for(key))
		banner.set_item_metadata(banner.item_count-1,key)
	banner.selected = ["square","swallowtail","pennant"].find(kingdom.empire.bannerStyle)
	column.add_child(banner)
	column.add_child(game.button("Save Heraldry",func(): submit("/v2/empire/customize",{"name":name_input.text,"primaryColor":"#"+primary.color.to_html(false),"secondaryColor":"#"+secondary.color.to_html(false),"emblem":emblem.get_item_metadata(emblem.selected),"bannerStyle":banner.get_item_metadata(banner.selected)})))

func build_map(column: VBoxContainer) -> void:
	column.add_child(game.button("Survey Region",load_map))
	if map_data.is_empty():
		column.add_child(game.label("Survey the frontier to find resources and neighboring holdings.",15))
		return
	column.add_child(game.label(str(map_data.region.name),20,Color(0.94,0.80,0.50)))
	var routes = CampaignMap.new()
	routes.tiles = map_data.tiles
	routes.campaigns = command_data.get("marches",[])+command_data.get("incoming",[])
	routes.server_time = server_seconds
	routes.received_ticks = received_ticks
	routes.player_id = str(game.state.player.id)
	routes.custom_minimum_size.y = 220
	routes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	routes.target_selected.connect(func(tile):
		selected_target = tile
		desired_section = "Map"
		rebuild())
	column.add_child(routes)
	build_marches(column)
	var navigation = HBoxContainer.new()
	column.add_child(navigation)
	for direction in [["West",-7,0],["North",0,-7],["Capital",0,0],["South",0,7],["East",7,0]]:
		var dx = int(direction[1])
		var dz = int(direction[2])
		var home: bool = direction[0]=="Capital"
		navigation.add_child(game.button(str(direction[0]),func():
			map_center = {} if home else {"x":int(map_data.center.x)+dx,"z":int(map_data.center.z)+dz}
			load_map()))
	var grid = GridContainer.new()
	grid.columns = 7
	column.add_child(grid)
	for tile in map_data.tiles:
		var tile_copy: Dictionary = tile.duplicate(true)
		var color = Color(str(tile.primaryColor)) if tile.primaryColor != null else Color(0.18,0.23,0.19)
		var own: bool = tile.ownerPlayerId==game.state.player.id
		var title: String = str(tile.get("name","Borderlands"))
		var kind_name: String = Text.name_for(str(tile.kind))
		var ownership = "Your Realm" if own else (str(tile.empireName) if tile.empireName!=null else "Unclaimed")
		var card = game.button(title+"\n"+kind_name,func():
			selected_target=tile_copy
			desired_section="Map"
			rebuild())
		card.custom_minimum_size = Vector2(116,62)
		card.add_theme_font_size_override("font_size",12)
		card.tooltip_text = ownership
		card.add_theme_stylebox_override("normal",game.panel_style(color.darkened(0.5),Color(0.74,0.64,0.32) if own else Color(0.36,0.38,0.30)))
		grid.add_child(card)
	if selected_target.is_empty(): return
	column.add_child(game.label(str(selected_target.get("name","Borderlands"))+" · "+Text.name_for(str(selected_target.kind)),20,Color(0.94,0.80,0.50)))
	var owner: String = str(selected_target.empireName) if selected_target.empireName!=null else "Unclaimed Territory"
	column.add_child(game.label(owner,15))
	var friendly = selected_target.kind=="settlement" and selected_target.ownerPlayerId!=game.state.player.id and selected_target.get("ownerClanId")!=null and selected_target.get("ownerClanId")==map_data.region.get("clanId")
	if not selected_target.attackable and not friendly:
		column.add_child(game.label("This holding cannot be attacked now. Review its borders and protection.",14))
		return
	if command_data.get("presets",[]).is_empty():
		column.add_child(game.button("Organize an Army",func(): open_section("Army")))
	else:
		for preset in command_data.presets:
			var slot_value = int(preset.slot)
			var target_x = int(selected_target.x)
			var target_z = int(selected_target.z)
			var march_kind = "reinforce" if friendly else "attack"
			column.add_child(game.button(("Reinforce · " if friendly else "March · ")+str(preset.name),func(): submit("/v2/army/march",{"x":target_x,"z":target_z,"presetSlot":slot_value,"kind":march_kind})))

func build_clans(column: VBoxContainer) -> void:
	column.add_child(game.label("Build lasting alliances and defend a shared region.",14))
	column.add_child(game.button("Browse Clans",load_clans))
	if clan_data.is_empty(): return
	if clan_data.own == null:
		column.add_child(game.label("Create at ruler level 15 · Gold 500 · 63 member plots",15))
		var name_input = game.input_field("Clan name (3–32 characters)")
		var tag_input = game.input_field("Unique tag (3–6 letters/digits)")
		column.add_child(name_input)
		column.add_child(tag_input)
		var admission = OptionButton.new()
		admission.add_item("By Application")
		admission.set_item_metadata(0,"approval")
		admission.add_item("Open Admission")
		admission.set_item_metadata(1,"open")
		column.add_child(admission)
		var create = game.button("Found Clan",func(): submit("/v2/clans/create",{"name":name_input.text,"tag":tag_input.text,"admission":admission.get_item_metadata(admission.selected),"emblem":kingdom.empire.emblem,"primaryColor":kingdom.empire.primaryColor,"secondaryColor":kingdom.empire.secondaryColor}))
		create.disabled = kingdom.progression.level < 15
		column.add_child(create)
		for invite in clan_data.invitations:
			var invited_id: String = invite.clanId
			column.add_child(game.button("Accept Invitation · "+str(invite.name),func(): submit("/v2/clans/join",{"clanId":invited_id})))
		for application in clan_data.applications:
			column.add_child(game.label(Text.copy("Application · %s · %s") % [application.name,Text.name_for(application.status)],13))
		for group in clan_data.directory:
			var group_id: String = group.id
			column.add_child(game.label(Text.copy("[%s] %s · %d/63 members") % [group.tag,group.name,group.members],15))
			column.add_child(game.button("Join Clan" if group.admission == "open" else "Apply",func(): submit("/v2/clans/join",{"clanId":group_id})))
		return
	var group: Dictionary = clan_data.own
	var group_id: String = group.id
	column.add_child(game.label(str(group.get("description","")),14))
	column.add_child(game.label(str(group.get("announcement","")),15))
	if group.role in ["leader","officer"]:
		var description = game.input_field("Clan charter")
		description.max_length = 240
		description.text = str(group.get("description",""))
		column.add_child(description)
		var announcement = game.input_field("Announcement to members")
		announcement.max_length = 240
		announcement.text = str(group.get("announcement",""))
		column.add_child(announcement)
		column.add_child(game.button("Publish Clan Charter",func(): submit("/v2/clans/describe",{"description":description.text,"announcement":announcement.text})))
		for rival in clan_data.directory:
			if rival.id==group.id: continue
			var rival_id: String = rival.id
			column.add_child(game.button("Declare War · "+str(rival.name)+" · 1,000 Treasury Gold",func(): submit("/v2/wars/declare",{"clanId":rival_id})))
	column.add_child(game.label(Text.copy("[%s] %s · %s · Level %d · %d members") % [group.tag,group.name,Text.name_for(str(group.role)),group.level,group.members.size()],17))
	column.add_child(game.label("Clan treasury · "+cost_text(group.treasury),14))
	for event in group.get("activity",[]): column.add_child(game.label(str(event.message),13))
	column.add_child(game.label("Relocation preserves your settlement. Server cooldowns and wars apply.",13))
	var resources = OptionButton.new()
	for key in ["food","wood","stone","iron","gold"]:
		resources.add_item(key.capitalize())
		resources.set_item_metadata(resources.item_count-1,key)
	var amount = SpinBox.new()
	amount.min_value = 1
	amount.max_value = 1000000
	amount.value = 25
	column.add_child(resources)
	column.add_child(amount)
	column.add_child(game.button("Contribute",func(): submit("/v2/clans/donate",{"resource":resources.get_item_metadata(resources.selected),"amount":int(amount.value)})))
	if group.role in ["leader","officer"]:
		var invite_id = game.input_field("Ruler or realm name to invite")
		column.add_child(invite_id)
		column.add_child(game.button("Invite Ruler",func(): submit("/v2/clans/invite",{"clanId":group_id,"rulerName":invite_id.text})))
		for application in group.applications:
			var target: String = application.playerId
			column.add_child(game.label("Applicant · "+str(application.empireName),14))
			var actions = HBoxContainer.new()
			column.add_child(actions)
			actions.add_child(game.button("Accept",func(): submit("/v2/clans/application",{"clanId":group_id,"playerId":target,"decision":"accept"})))
			actions.add_child(game.button("Decline",func(): submit("/v2/clans/application",{"clanId":group_id,"playerId":target,"decision":"reject"})))
	for member in group.members:
		column.add_child(game.label(Text.copy("%s · %s · %s · Contributions %d") % [member.empireName,Text.name_for(str(member.role)),"Online" if bool(member.get("online",false)) else "Away",int(member.get("contribution",0))],14))
		if member.playerId == game.state.player.id or member.role == "leader": continue
		var target: String = member.playerId
		var actions = HBoxContainer.new()
		column.add_child(actions)
		if group.role == "leader":
			var next_role = "member" if member.role == "officer" else "officer"
			actions.add_child(game.button("Appoint "+Text.name_for(next_role),func(): submit("/v2/clans/role",{"clanId":group_id,"playerId":target,"role":next_role})))
			actions.add_child(game.button("Transfer Leadership",func(): submit("/v2/clans/role",{"clanId":group_id,"playerId":target,"role":"leader"})))
		if group.role == "leader" or (group.role == "officer" and member.role == "member"):
			actions.add_child(game.button("Remove Member",func(): submit("/v2/clans/kick",{"playerId":target})))
	if group.role != "leader": column.add_child(game.button("Leave Clan",func(): submit("/v2/clans/leave",{})))

func build_reports(column: VBoxContainer) -> void:
	if command_data.get("reports",[]).is_empty():
		column.add_child(game.label("Your campaigns will be recorded here. Organize an army and explore the frontier.",15))
		return
	for report in command_data.reports:
		var outcome = "Victory" if report.won else ("Draw" if report.result=="draw" else "Defeat")
		var enemy: String = str(report.defenderName) if report.perspective=="attacker" and report.defenderName!=null else str(report.attackerName) if report.perspective=="defender" else "Border Garrison"
		column.add_child(game.label(outcome+" · "+str(report.target.get("name","Borderlands")),20,Color(0.94,0.80,0.50)))
		column.add_child(game.label(enemy+" · "+Text.name_for(str(report.territoryChange)),15))
		var losses: Dictionary = report.attackerLosses if report.perspective=="attacker" else report.defenderLosses
		for key in losses:
			var loss: Dictionary = losses[key]
			column.add_child(game.label(Text.copy("%s · %d wounded · %d fallen") % [catalog_name("unit",str(key)),loss.wounded,loss.dead],14))
		column.add_child(game.label(cost_text(report.rewards),14))
		var report_copy: Dictionary = report.duplicate(true)
		var replay = game.button("View Battle",func(): show_replay(report_copy))
		replay.disabled = report.get("replay")==null
		column.add_child(replay)

func wait_for_idle() -> bool:
	var epoch: int = game.world_epoch
	var deadline = Time.get_ticks_msec()+20000
	waiting_reads += 1
	while busy and game.in_world and epoch==game.world_epoch and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	waiting_reads -= 1
	if busy and is_instance_valid(status): status.text = Text.copy("Your realm is still updating. Try again in a moment.")
	return not busy and game.in_world and epoch==game.world_epoch

func load_clans() -> void:
	if not await wait_for_idle(): return
	busy = true
	var epoch: int = game.world_epoch
	var response: Dictionary = await game.api.call_api("/v2/clans")
	if epoch != game.world_epoch or not game.in_world: return
	busy = false
	if response.ok:
		clan_data = response.data
		rebuild()
	else:
		status.text = Text.error(str(response.error))
		if response.status==401: game.expire_session()

func load_map() -> void:
	if not await wait_for_idle(): return
	busy = true
	var epoch: int = game.world_epoch
	var response: Dictionary = await game.api.call_api("/v2/world/map"+(Text.copy("?x=%d&z=%d") % [map_center.x,map_center.z] if not map_center.is_empty() else ""))
	if epoch != game.world_epoch or not game.in_world: return
	busy = false
	if response.ok:
		map_data = response.data
		rebuild()
	else:
		status.text = Text.error(str(response.error))
		if response.status==401: game.expire_session()

func load_extra(section: String) -> void:
	if not await wait_for_idle(): return
	var paths = {"Commanders":"/v2/commanders","Goals":"/v2/goals","Inbox":"/v2/inbox","Rankings":"/v2/rankings","Wars":"/v2/wars","Chat":"/v2/chat?channel="+chat_channel}
	if not paths.has(section): return
	busy=true
	var epoch: int = game.world_epoch
	var response: Dictionary = await game.api.call_api(paths[section])
	if epoch!=game.world_epoch or not game.in_world: return
	busy=false
	if response.ok:
		extra_data[section]=response.data
		rebuild()
	else:
		status.text=Text.error(str(response.error))
		if response.status==401: game.expire_session()

func build_extra(column: VBoxContainer,section: String) -> void:
	column.add_child(game.button("Refresh "+section,func(): load_extra(section)))
	if not extra_data.has(section):
		column.add_child(game.label("Open this section to load your latest records.",15))
		return
	var data: Dictionary = extra_data[section]
	if section=="Commanders":
		for leader in data.commanders:
			column.add_child(game.label(str(leader.name)+" · "+str(leader.title),20,Color(0.94,0.80,0.50)))
			column.add_child(game.label(Text.copy("%s leadership · Level %d") % [Text.name_for(str(leader.specialty)),leader.level],15))
			var key: String = leader.key
			if not leader.owned:
				var action = game.button(Text.copy("Appoint · %d Gold") % leader.cost,func(): submit("/v2/commanders/recruit",{"key":key}))
				action.disabled = not leader.available
				column.add_child(action)
				column.add_child(game.label(Text.copy("Requires Commander Hall Level %d") % leader.hall,13))
		column.add_child(game.label("Assign an appointed commander while organizing your army. Campaigns improve their leadership.",14))
	elif section=="Goals":
		for goal in data.goals:
			column.add_child(game.label(str(goal.title),20,Color(0.94,0.80,0.50)))
			column.add_child(game.label(str(goal.message),15))
			column.add_child(game.label(Text.copy("%d / %d · %d XP · %d Gold") % [goal.progress,goal.target,goal.xp,goal.gold],14))
			var key: String = goal.key
			var action = game.button("Reward Claimed" if goal.claimed else "Claim Reward",func(): submit("/v2/goals/claim",{"key":key}))
			action.disabled = goal.claimed or not goal.complete
			column.add_child(action)
	elif section=="Inbox":
		if data.messages.is_empty(): column.add_child(game.label("Your couriers have no new dispatches.",16))
		for message in data.messages:
			column.add_child(game.label(str(message.title),20,Color(0.94,0.80,0.50)))
			column.add_child(game.label(str(message.message),15))
			var id: String = message.id
			if not message.read: column.add_child(game.button("Mark Read",func(): submit("/v2/inbox/read",{"id":id})))
	elif section=="Rankings":
		column.add_child(game.label("Realm Prestige",20,Color(0.94,0.80,0.50)))
		for ruler in data.rulers:
			column.add_child(game.label(Text.copy("%d · %s · %d Prestige · %d Conquests") % [ruler.rank,ruler.name,ruler.prestige,ruler.conquests],15))
		column.add_child(game.label("Clan Accomplishments",20,Color(0.94,0.80,0.50)))
		for group in data.clans: column.add_child(game.label(Text.copy("[%s] %s · Level %d") % [group.tag,group.name,group.level],15))
	elif section=="Wars":
		if data.wars.is_empty(): column.add_child(game.label("Your clan is at peace. Officers may declare a war from the clan directory.",16))
		for war in data.wars:
			column.add_child(game.label(str(war.attackerName)+" · "+str(war.defenderName),20,Color(0.94,0.80,0.50)))
			column.add_child(game.label(Text.copy("%s · %d : %d") % [Text.name_for(str(war.phase)),war.attackerScore,war.defenderScore],16))
			if war.phase in ["preparation","battle"]:
				var timer = game.label("",15)
				column.add_child(timer)
				countdowns.append({"label":timer,"ends":Time.get_unix_time_from_datetime_string(str(war.preparationEndsAt if war.phase=="preparation" else war.battleEndsAt))})
			for contribution in war.contributions: column.add_child(game.label(Text.copy("%s · %d contribution") % [contribution.name,contribution.score],14))
	elif section=="Chat":
		var channels = HBoxContainer.new()
		column.add_child(channels)
		for value in ["global","clan"]:
			var channel: String = value
			channels.add_child(game.button(Text.name_for(value),func():
				chat_channel=channel
				load_extra("Chat")))
		if data.messages.is_empty(): column.add_child(game.label("No dispatches in this channel yet.",15))
		for message in data.messages:
			column.add_child(game.label(str(message.name)+" · "+str(message.message),15))
			if not message.self:
				var id = int(message.id)
				var row = HBoxContainer.new()
				column.add_child(row)
				row.add_child(game.button("Block Ruler",func(): submit("/v2/chat/block",{"channel":chat_channel,"messageId":id})))
				row.add_child(game.button("Report Message",func(): submit("/v2/chat/report",{"channel":chat_channel,"messageId":id,"reason":"Inappropriate message"})))
		var text_input = game.input_field("Write a dispatch")
		text_input.max_length=240
		column.add_child(text_input)
		column.add_child(game.button("Send",func(): submit("/v2/chat/send",{"channel":chat_channel,"message":text_input.text})))
