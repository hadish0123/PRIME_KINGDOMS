extends Button

var action_icon = ""

func _draw() -> void:
	var color = Color(0.94,0.86,0.68,0.45 if disabled else 0.95)
	var center = Vector2(size.x/2,29)
	if action_icon in ["sword","attack"]:
		var a = center+Vector2(-12,11)
		var b = center+Vector2(12,-13)
		draw_line(a,b,color,3,true)
		draw_polyline(PackedVector2Array([b+Vector2(-7,1),b,b+Vector2(-1,7)]),color,2,true)
		draw_line(a+Vector2(-5,-5),a+Vector2(5,5),color,3,true)
		draw_line(a,a+Vector2(-7,7),color,4,true)
		if action_icon == "attack": draw_arc(center,21,-1.1,1.2,16,color,2,true)
	elif action_icon == "ride":
		draw_polyline(PackedVector2Array([center+Vector2(-15,8),center+Vector2(-14,-5),center+Vector2(3,-5),center+Vector2(8,-18),center+Vector2(17,-11),center+Vector2(10,-3),center+Vector2(9,8)]),color,3,true)
		draw_line(center+Vector2(-9,1),center+Vector2(-9,16),color,3,true)
		draw_line(center+Vector2(7,1),center+Vector2(5,16),color,3,true)
	elif action_icon == "lie":
		draw_circle(center+Vector2(-15,5),5,color)
		draw_line(center+Vector2(-6,6),center+Vector2(16,7),color,4,true)
		draw_line(center+Vector2(-19,15),center+Vector2(20,15),color,1,true)
	else:
		draw_circle(center+Vector2(0,-14),5,color)
		draw_polyline(PackedVector2Array([center+Vector2(-10,-2),center+Vector2(0,-5),center+Vector2(8,1)]),color,3,true)
		draw_line(center+Vector2(0,-5),center+Vector2(-1,5),color,4,true)
		draw_polyline(PackedVector2Array([center+Vector2(-12,15),center+Vector2(-1,5),center+Vector2(11,13)]),color,3,true)
		if action_icon == "jump": draw_polyline(PackedVector2Array([center+Vector2(20,10),center+Vector2(20,-12),center+Vector2(16,-7)]),color,2,true)
