extends Control

var game: Node3D
var view: SubViewport
var camera: Camera3D
var clock = 0.0
var overlay: Control

func _ready() -> void:
	custom_minimum_size = Vector2(184,184)
	size = custom_minimum_size
	view = SubViewport.new()
	view.size = Vector2i(192,192)
	view.world_3d = game.get_viewport().find_world_3d()
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.gui_disable_input = true
	add_child(view)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 175.0
	camera.far = 1500.0
	camera.rotation.x = -PI*0.5
	camera.current = true
	view.add_child(camera)
	var picture = TextureRect.new()
	picture.texture = view.get_texture()
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var surface = ShaderMaterial.new()
	surface.shader = load("res://shaders/minimap.gdshader")
	picture.material = surface
	add_child(picture)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.draw.connect(draw_markers)

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not game.in_world or not is_instance_valid(game.strategy_camera): return
	clock += delta
	if clock < 0.45: return
	clock = 0.0
	camera.position = Vector3(0,700,0)
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	overlay.queue_redraw()

func draw_markers() -> void:
	var center = size*0.5
	overlay.draw_arc(center,size.x*0.5-4,0,TAU,80,Color(0.78,0.62,0.34),2,true)
	overlay.draw_arc(center,size.x*0.5-9,0,TAU,80,Color(0.78,0.62,0.34,0.5),1,true)
	for index in range(4):
		var angle = index*PI*0.5
		var at = center+Vector2(cos(angle),sin(angle))*(size.x*0.5-4)
		var jewel = PackedVector2Array([at+Vector2(0,-5),at+Vector2(4,0),at+Vector2(0,5),at+Vector2(-4,0),at+Vector2(0,-5)])
		overlay.draw_colored_polygon(jewel,Color(0.31,0.23,0.13))
		overlay.draw_polyline(jewel,Color(0.80,0.66,0.37),1.0,true)
	if not game.in_world or not is_instance_valid(game.strategy_camera): return
	var focus: Vector3 = game.strategy_camera.focus
	var marker = center+Vector2(focus.x,focus.z)*size.x/175.0
	overlay.draw_arc(marker,9,0,TAU,24,Color(0.96,0.78,0.25),2,true)
	overlay.draw_string(ThemeDB.fallback_font,Vector2(center.x-5,20),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(0.97,0.89,0.64))
