extends PanelContainer

var game: Node
var kingdom: Dictionary = {}
var map_data: Dictionary = {}
var tabs: TabContainer
var status: Label
var busy = false
var pending_path = ""
var pending_body: Dictionary = {}
var token_epoch = -1
var timer_clock = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	position = Vector2(-440,-300)
	size = Vector2(880,600)
	add_theme_stylebox_override("panel",game.panel_style(Color(0.035,0.045,0.055,0.98)))
	visible = false

static func request_id() -> String:
	var bytes = Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var value = bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [value.substr(0,8),value.substr(8,4),value.substr(12,4),value.substr(16,4),value.substr(20,12)]

func open() -> void:
	visible = true
	game.map_panel.visible = false
	game.settings_panel.visible = false
	game.residents_panel.visible = false
	game.apply_control_state()
	await refresh()

func close() -> void:
	visible = false
	game.apply_control_state()

func clear_session() -> void:
	kingdom.clear()
	map_data.clear()
	pending_path = ""
	pending_body.clear()
	busy = false
	visible = false

func refresh() -> void:
	if busy or not game.in_world: return
	busy = true
	var epoch: int = game.world_epoch
	var response: Dictionary = await game.api.call_api("/v2/kingdom")
	if epoch != game.world_epoch or not game.in_world: return
	busy = false
	if response.ok:
		kingdom = response.data
		game.apply_empire(kingdom.empire)
		game.update_garrison(kingdom)
		rebuild()
	elif response.status == 401: game.expire_session()
	else:
		rebuild()
		status.text = "Could not refresh settlement. Retry when connected."

func submit(path: String, body: Dictionary) -> void:
	if busy or not game.network_online: return
	# Keep the exact request after a lost response; a retry replays rather than pays twice.
	if not pending_path.is_empty() and (pending_path != path or pending_body.get("key") != body.get("key")):
		status.text = "Retry the pending action before starting another."
		return
	if pending_path.is_empty():
		pending_path = path
		pending_body = body.duplicate(true)
		pending_body.requestId = request_id()
	busy = true
	var epoch: int = game.world_epoch
	status.text = "Saving…"
	var response: Dictionary = await game.api.call_api(pending_path,pending_body)
	if epoch != game.world_epoch or not game.in_world: return
	busy = false
	if response.ok:
		pending_path = ""
		pending_body.clear()
		if response.data.has("kingdom"):
			kingdom = response.data.kingdom
			game.apply_empire(kingdom.empire)
			game.update_garrison(kingdom)
		rebuild()
		status.text = "Saved by the server."
		await refresh()
	else:
		if response.status != 0:
			pending_path = ""
			pending_body.clear()
		status.text = str(response.error).replace("_"," ").capitalize()
		if response.status == 401: game.expire_session()

func page(title: String) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.name = title
	tabs.add_child(scroll)
	var column = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",8)
	scroll.add_child(column)
	return column

func rebuild() -> void:
	var selected = tabs.current_tab if is_instance_valid(tabs) else 0
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var column = VBoxContainer.new()
	add_child(column)
	column.add_child(game.label("YOUR KINGDOM",25,Color(0.94,0.80,0.50)))
	status = game.label("",14)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	if not kingdom.is_empty():
		column.add_child(game.label("%s · Level %d · %s" % [kingdom.empire.name,int(kingdom.progression.level),str(kingdom.stage).replace("_"," ")],17))
		column.add_child(game.label("Food %d   Wood %d   Stone %d   Iron %d   Gold %d" % [kingdom.resources.food,kingdom.resources.wood,kingdom.resources.stone,kingdom.resources.iron,kingdom.resources.gold],16))
	tabs = TabContainer.new()
	tabs.custom_minimum_size.y = 350
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	if not kingdom.is_empty():
		build_queue(page("Queues"))
		build_upgrades(page("Buildings"),"building","/v2/buildings/upgrade")
		build_units(page("Army"))
		build_upgrades(page("Research"),"research","/v2/research/start")
		build_empire(page("Empire"))
		build_map(page("Map"))
	tabs.current_tab = mini(selected,maxi(0,tabs.get_tab_count()-1))
	var actions = HBoxContainer.new()
	column.add_child(actions)
	actions.add_child(game.button("REFRESH",refresh))
	actions.add_child(game.button("RETRY PENDING",func():
		if not pending_path.is_empty(): submit(pending_path,pending_body)))
	actions.add_child(game.button("RETURN TO SETTLEMENT",close))

func cost_text(cost: Dictionary) -> String:
	var values: Array[String] = []
	for key in cost: values.append("%s %d" % [str(key).capitalize(),int(cost[key])])
	return ", ".join(values)

func build_queue(column: VBoxContainer) -> void:
	column.add_child(game.label("Production per hour: "+cost_text(kingdom.productionPerHour),15))
	column.add_child(game.label("Storage per resource: %d · XP: %d" % [kingdom.storageCapacity,kingdom.progression.xp],15))
	if kingdom.progression.next != null:
		column.add_child(game.label("Next level needs %d total XP; prestige and achievements also apply at high levels." % kingdom.progression.next.xp,14))
	if kingdom.tasks.is_empty(): column.add_child(game.label("No active construction, training or research.",16))
	for task in kingdom.tasks:
		column.add_child(game.label("%s · %s → %d ×%d\nServer completion: %s" % [str(task.kind).capitalize(),str(task.key).replace("_"," "),task.target_level,task.quantity,str(task.finishes_at)],15))
	column.add_child(game.label("Timers continue while offline. REFRESH retrieves completed work.",14))

func build_upgrades(column: VBoxContainer,kind: String,path: String) -> void:
	for quote in kingdom.quotes:
		if quote.kind != kind: continue
		var definitions: Array = kingdom.catalog.filter(func(c): return c.kind == kind and c.key == quote.key)
		var name_value = str(definitions[0].data.name) if not definitions.is_empty() else str(quote.key)
		column.add_child(game.label("%s · Level %d/%d\n%s · %d seconds" % [name_value,quote.current,quote.maxLevel,cost_text(quote.cost),quote.durationSeconds],15))
		var key_value: String = quote.key
		var action = game.button("UPGRADE "+name_value,func(): submit(path,{"key":key_value}))
		action.disabled = quote.current >= quote.maxLevel
		column.add_child(action)

func build_units(column: VBoxContainer) -> void:
	var orders = HBoxContainer.new()
	column.add_child(orders)
	orders.add_child(game.button("FOLLOW RULER",func(): game.command_army("follow")))
	orders.add_child(game.button("HOLD POSITION",func(): game.command_army("guard")))
	var alive = 0
	for unit in kingdom.units:
		alive += int(unit.alive)
		column.add_child(game.label("%s · %d alive · %d wounded · %d dead" % [str(unit.type).replace("_"," ").capitalize(),unit.alive,unit.wounded,unit.dead],15))
	column.add_child(game.label("Army capacity: %d / %d" % [alive,kingdom.armyCapacity],16))
	for entry in kingdom.catalog:
		if entry.kind != "unit": continue
		var key_value: String = entry.key
		column.add_child(game.label("%s · %s level %d · %s" % [entry.data.name,str(entry.data.facility).replace("_"," "),entry.data.requiredLevel,cost_text(entry.data.cost)],14))
		column.add_child(game.button("TRAIN 1 "+str(entry.data.name),func(): submit("/v2/units/train",{"key":key_value,"quantity":1})))

func build_empire(column: VBoxContainer) -> void:
	var name_input = game.input_field("Empire name")
	name_input.text = kingdom.empire.name
	column.add_child(name_input)
	var primary = game.input_field("Primary color #rrggbb")
	primary.text = kingdom.empire.primaryColor
	column.add_child(primary)
	var secondary = game.input_field("Secondary color #rrggbb")
	secondary.text = kingdom.empire.secondaryColor
	column.add_child(secondary)
	var emblem = OptionButton.new()
	for key in ["lion","eagle","crown","stag","sun","wolf"]: emblem.add_item(key)
	emblem.selected = ["lion","eagle","crown","stag","sun","wolf"].find(kingdom.empire.emblem)
	column.add_child(emblem)
	var banner = OptionButton.new()
	for key in ["square","swallowtail","pennant"]: banner.add_item(key)
	banner.selected = ["square","swallowtail","pennant"].find(kingdom.empire.bannerStyle)
	column.add_child(banner)
	column.add_child(game.button("SAVE EMPIRE",func(): submit("/v2/empire/customize",{"name":name_input.text,"primaryColor":primary.text,"secondaryColor":secondary.text,"emblem":emblem.get_item_text(emblem.selected),"bannerStyle":banner.get_item_text(banner.selected)})))

func build_map(column: VBoxContainer) -> void:
	column.add_child(game.button("LOAD STRATEGIC REGION",load_map))
	if map_data.is_empty(): return
	column.add_child(game.label("%s · Settlement plot %d" % [map_data.region.name,map_data.region.ownPlot],17))
	var grid = GridContainer.new()
	grid.columns = 7
	column.add_child(grid)
	for tile in map_data.tiles:
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(94,57)
		var color = Color(str(tile.primaryColor)) if tile.primaryColor != null else Color(0.12,0.17,0.15)
		card.add_theme_stylebox_override("panel",game.panel_style(color.darkened(0.55)))
		var title = "%d,%d\n%s" % [tile.x,tile.z,str(tile.kind).capitalize()]
		if tile.ownerPlayerId == game.state.player.id: title += " · YOURS"
		card.add_child(game.label(title,12))
		grid.add_child(card)
	column.add_child(game.label("Starter settlements are protected. Colors show confirmed ownership.",13))

func load_map() -> void:
	if busy: return
	busy = true
	var epoch: int = game.world_epoch
	var response: Dictionary = await game.api.call_api("/v2/world/map")
	if epoch != game.world_epoch or not game.in_world: return
	busy = false
	if response.ok:
		map_data = response.data
		rebuild()
		tabs.current_tab = tabs.get_tab_count()-1
	else: status.text = "Region could not be loaded."
