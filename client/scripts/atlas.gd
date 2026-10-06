extends Control

var game: Node
var entire_world = false

func _ready() -> void:
	custom_minimum_size = Vector2(310, 310)

func _process(_delta: float) -> void:
	if visible: queue_redraw()

func _draw() -> void:
	if not is_instance_valid(game) or not game.in_world: return
	var rectangle = Rect2(Vector2.ZERO, size)
	draw_style_box(game.panel_style(Color(0.08, 0.15, 0.15)), rectangle)
	var point: Vector3 = game.player.position + game.origin
	var center = Vector2.ZERO if entire_world else Vector2(point.x, point.z)
	var span = float(game.state.world.sizeM) if entire_world else 2200.0
	var scale_value = (minf(size.x, size.y) - 36.0) / span
	var half = size * 0.5
	for i in range(1, 6):
		var offset = float(i) / 6.0
		draw_line(Vector2(size.x * offset, 10), Vector2(size.x * offset, size.y - 10), Color(0.21, 0.30, 0.26), 1)
		draw_line(Vector2(10, size.y * offset), Vector2(size.x - 10, size.y * offset), Color(0.21, 0.30, 0.26), 1)
	for settlement in game.known_villages.values():
		var global_point = Vector3(float(settlement.position.x), float(settlement.position.y), float(settlement.position.z))
		var at = half + (Vector2(global_point.x, global_point.z) - center) * scale_value
		if rectangle.has_point(at):
			draw_rect(Rect2(at - Vector2(5, 5), Vector2(10, 10)), Color(0.85, 0.69, 0.38))
	var at = half + (Vector2(point.x, point.z) - center) * scale_value
	var direction = Vector2(sin(game.player.actor.rotation.y), cos(game.player.actor.rotation.y))
	var side = direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([at + direction * 10, at - direction * 6 + side * 6, at - direction * 6 - side * 6]), Color(0.83, 0.94, 0.91))
	draw_string(ThemeDB.fallback_font, Vector2(14, 27), "N ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.89, 0.82, 0.64))
	draw_string(ThemeDB.fallback_font, Vector2(14, size.y - 16), "65.536 km world" if entire_world else "2.2 km surrounding region", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.68, 0.77, 0.71))
