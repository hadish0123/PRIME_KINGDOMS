extends Control

signal target_selected(tile: Dictionary)
var tiles: Array = []
var campaigns: Array = []
var regions: Array = []
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

func origin() -> Vector2:
	if tiles.is_empty(): return Vector2.ZERO
	return Vector2(float(tiles[0].x),float(tiles[0].z))

func point(x: float,z: float) -> Vector2:
	return (Vector2(x,z)-origin()+Vector2(0.5,0.5))*Vector2(size.x/7.0,size.y/7.0)

func _draw() -> void:
	if tiles.is_empty(): return
	var cell=Vector2(size.x/7.0,size.y/7.0)
	for tile in tiles:
		var at=point(float(tile.x),float(tile.z))
		var tint=Color(str(tile.primaryColor)) if tile.get("primaryColor")!=null else Color(0.16,0.20,0.15)
		draw_rect(Rect2(at-cell*0.5,cell),tint.darkened(0.56))
		draw_rect(Rect2(at-cell*0.5,cell),Color(0.40,0.37,0.27),false,1.0)
		if tile.kind=="settlement":
			draw_rect(Rect2(at-Vector2(5,5),Vector2(10,10)),Color(0.82,0.73,0.52))
		elif tile.kind=="fort":
			draw_circle(at,5,Color(0.69,0.62,0.48))
		elif tile.kind=="resource":
			draw_circle(at,3,Color(0.60,0.68,0.42))
		if tile.ownerPlayerId==player_id:
			draw_rect(Rect2(at-cell*0.5+Vector2.ONE*2,cell-Vector2.ONE*4),Color(0.78,0.66,0.37),false,1.5)
	# Draw complete server-allocated clan perimeters; the viewport clips distant edges.
	for region in regions:
		var bounds: Dictionary = region.bounds
		var start = point(float(bounds.minX),float(bounds.minZ))-cell*0.5
		var finish = point(float(bounds.maxX),float(bounds.maxZ))+cell*0.5
		var area = Rect2(start,finish-start).grow(-2)
		var trim = Color(str(region.secondaryColor))
		draw_rect(area,trim,false,3,true)
		var marker = Rect2(start+Vector2(6,6),Vector2(24,24))
		var crest = load("res://assets/heraldry/%s.svg" % str(region.emblem))
		draw_texture_rect(crest,marker,false,trim)
	var now=server_time+(Time.get_ticks_msec()-received_ticks)/1000.0
	for march in campaigns:
		var route: Dictionary=march.route
		var from=point(float(route.from.x),float(route.from.z))
		var to=point(float(route.to.x),float(route.to.z))
		var tint=Color(0.82,0.70,0.40) if not march.has("realmName") else (Color(0.48,0.73,0.55) if march.kind=="reinforce" else Color(0.79,0.35,0.29))
		var at=to
		if route.arrivesAt!=null:
			var start=float(Time.get_unix_time_from_datetime_string(str(route.startedAt)))
			var finish=float(Time.get_unix_time_from_datetime_string(str(route.arrivesAt)))
			at=from.lerp(to,clampf((now-start)/maxf(1,finish-start),0,1))
			draw_line(from,to,tint.darkened(0.35),2.0,true)
			draw_line(from,at,tint,2.5,true)
		draw_colored_polygon(PackedVector2Array([at+Vector2(0,-7),at+Vector2(6,5),at+Vector2(-6,5)]),tint)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var relative=event.position/Vector2(size.x/7.0,size.y/7.0)
		var tile_at=origin()+Vector2(floorf(relative.x),floorf(relative.y))
		for tile in tiles:
			if tile_at==Vector2(float(tile.x),float(tile.z)):
				target_selected.emit(tile.duplicate(true))
				accept_event()
				return
