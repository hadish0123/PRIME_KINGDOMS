extends Control

const Text = preload("res://scripts/game_text.gd")
signal holding_selected(member: Dictionary)
var group: Dictionary = {}
var player_id = ""
var emblem: Texture2D

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func grid_rect() -> Rect2:
	var edge = minf(size.x-32.0,size.y-32.0)
	return Rect2((size-Vector2.ONE*edge)*0.5,Vector2.ONE*edge)

func _draw() -> void:
	if group.is_empty(): return
	var area = grid_rect()
	var cell = area.size/8.0
	var tint = Color(str(group.primaryColor))
	var trim = Color(str(group.secondaryColor))
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.035,0.055,0.050))
	for plot in range(64):
		var rect = Rect2(area.position+Vector2(plot%8,plot/8)*cell,cell)
		var terrain = tint.darkened(0.70-float((plot*17)%5)*0.025)
		draw_rect(rect,terrain)
		draw_rect(rect.grow(-1),Color(0.40,0.45,0.32,0.23),false,1)
		# Quiet field and grove motifs keep empty, reserved plots readable.
		if plot%9 in [3,6]:
			var grove = rect.position+cell*Vector2(0.72,0.72)
			for offset in [Vector2(-3,0),Vector2(3,2),Vector2(0,-4)]:
				draw_circle(grove+offset,cell.x*0.10,tint.lightened(0.12))
		if plot==0:
			draw_rect(rect.grow(-3),trim.darkened(0.58))
			if emblem!=null: draw_texture_rect(emblem,rect.grow(-6),false,trim)
	for member in group.members:
		var rect = Rect2(area.position+Vector2(int(member.plot)%8,int(member.plot)/8)*cell,cell)
		draw_rect(rect.grow(-3),tint.lightened(0.12))
		var at = rect.get_center()
		var width = minf(14,cell.x*0.30)
		draw_rect(Rect2(at-Vector2(width*0.5,width*0.3)+Vector2(2,3),Vector2(width,width*0.7)),Color(0,0,0,0.25))
		draw_rect(Rect2(at-Vector2(width*0.5,width*0.3),Vector2(width,width*0.7)),Color(0.78,0.73,0.58))
		draw_colored_polygon(PackedVector2Array([at+Vector2(-width*0.6,-width*0.3),at+Vector2(0,-width*0.8),at+Vector2(width*0.6,-width*0.3)]),Color(0.35,0.30,0.22))
		draw_rect(Rect2(at+Vector2(-width*0.10,width*0.12),Vector2(width*0.20,width*0.28)),Color(0.17,0.21,0.17))
		if member.playerId==player_id: draw_rect(rect.grow(-2),Color(0.95,0.84,0.55),false,2)
		if member.online: draw_circle(rect.position+Vector2(cell.x-7,7),2.5,Color(0.47,0.72,0.49))
	# A continuous perimeter encloses the entire allocated region, including free plots.
	draw_rect(area.grow(3),Color(0.09,0.08,0.05),false,8)
	draw_rect(area.grow(3),trim,false,3)
	draw_rect(area.grow(8),Color(trim,0.40),false,1)
	draw_rect(area.grow(-2),Color(trim,0.55),false,1)
	for corner in [area.position,Vector2(area.end.x,area.position.y),area.end,Vector2(area.position.x,area.end.y)]:
		draw_colored_polygon(PackedVector2Array([corner+Vector2(0,-5),corner+Vector2(5,0),corner+Vector2(0,5),corner+Vector2(-5,0)]),trim)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var area = grid_rect()
		if not area.has_point(event.position): return
		var at = (event.position-area.position)/(area.size/8.0)
		var plot = int(at.x)+int(at.y)*8
		for member in group.get("members",[]):
			if int(member.plot)==plot:
				holding_selected.emit(member.duplicate(true))
				accept_event()
				return
