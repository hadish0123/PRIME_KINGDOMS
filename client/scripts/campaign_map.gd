extends Control

signal target_selected(tile: Dictionary)
var tiles: Array = []
var campaigns: Array = []
var server_time = 0
var received_ticks = 0
var player_id = ""
var elapsed = 0.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed>=0.25:
		elapsed=0
		queue_redraw()

func tile_bounds() -> Rect2i:
	if tiles.is_empty(): return Rect2i()
	var min_x = int(tiles[0].x)
	var max_x = min_x
	var min_z = int(tiles[0].z)
	var max_z = min_z
	for tile in tiles:
		min_x = mini(min_x,int(tile.x))
		max_x = maxi(max_x,int(tile.x))
		min_z = mini(min_z,int(tile.z))
		max_z = maxi(max_z,int(tile.z))
	return Rect2i(min_x,min_z,max_x-min_x+1,max_z-min_z+1)

func cell_size() -> Vector2:
	var bounds := tile_bounds()
	if bounds.size.x<=0 or bounds.size.y<=0: return Vector2.ONE
	return Vector2(size.x/float(bounds.size.x),size.y/float(bounds.size.y))

func point(x: float,z: float) -> Vector2:
	var bounds := tile_bounds()
	var cell := cell_size()
	return (Vector2(x,z)-Vector2(bounds.position)+Vector2(0.5,0.5))*cell

func base_tint(tile: Dictionary) -> Color:
	if bool(tile.get("divineOwner",false)): return Color(0.30,0.20,0.055)
	if tile.get("primaryColor")!=null:
		return Color(str(tile.primaryColor)).darkened(0.56)
	match str(tile.get("biome","grassland")):
		"forest": return Color(0.075,0.17,0.085)
		"highlands": return Color(0.18,0.17,0.145)
		"wetlands": return Color(0.075,0.15,0.14)
		_: return Color(0.16,0.20,0.15)

func _draw() -> void:
	if tiles.is_empty(): return
	var cell := cell_size()
	for tile in tiles:
		var at=point(float(tile.x),float(tile.z))
		draw_rect(Rect2(at-cell*0.5,cell),base_tint(tile))
		draw_rect(Rect2(at-cell*0.5,cell),Color(0.40,0.37,0.27,0.65),false,1.0)
		var site := str(tile.get("siteType",""))
		if tile.kind=="settlement":
			var settlement_tint = Color(1.0,0.78,0.22) if bool(tile.get("divineOwner",false)) else Color(0.82,0.73,0.52)
			draw_rect(Rect2(at-Vector2(5,5),Vector2(10,10)),settlement_tint)
			if bool(tile.get("divineOwner",false)):
				draw_arc(at,8,0,TAU,20,Color(1.0,0.83,0.28),2.0,true)
		elif tile.kind=="fort":
			draw_circle(at,5,Color(0.69,0.62,0.48))
		elif tile.kind=="resource":
			draw_circle(at,3.5,Color(0.60,0.68,0.42))
		elif site=="npc_camp":
			draw_colored_polygon(PackedVector2Array([at+Vector2(0,-6),at+Vector2(6,0),at+Vector2(0,6),at+Vector2(-6,0)]),Color(0.70,0.28,0.20))
		elif site=="wildlife":
			draw_circle(at,2.5,Color(0.72,0.57,0.33))
		if tile.ownerPlayerId==player_id:
			draw_rect(Rect2(at-cell*0.5+Vector2.ONE*2,cell-Vector2.ONE*4),Color(0.78,0.66,0.37),false,1.5)
	var now=server_time+(Time.get_ticks_msec()-received_ticks)/1000.0
	for march in campaigns:
		var route: Dictionary=march.route
		var from=point(float(route.from.x),float(route.from.z))
		var to=point(float(route.to.x),float(route.to.z))
		var at=to
		if route.arrivesAt!=null:
			var started=Time.get_unix_time_from_datetime_string(str(route.startedAt))
			var arrives=Time.get_unix_time_from_datetime_string(str(route.arrivesAt))
			var fraction=clampf((now-started)/maxf(1.0,arrives-started),0,1)
			at=from.lerp(to,fraction)
		var tint=Color(0.80,0.67,0.35) if march.kind=="attack" else Color(0.45,0.75,0.54)
		draw_line(from,to,Color(tint,0.24),1.0,true)
		draw_line(from,at,tint,2.5,true)
		draw_colored_polygon(PackedVector2Array([at+Vector2(0,-7),at+Vector2(6,5),at+Vector2(-6,5)]),tint)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var bounds := tile_bounds()
		var cell := cell_size()
		var relative=event.position/cell
		var tile_at=Vector2(bounds.position)+Vector2(floorf(relative.x),floorf(relative.y))
		for tile in tiles:
			if tile_at==Vector2(float(tile.x),float(tile.z)):
				target_selected.emit(tile.duplicate(true))
				accept_event()
				return
