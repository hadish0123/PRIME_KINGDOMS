extends "res://scripts/terrain.gd"

# A fixed settlement arena. Player travel never requests more terrain or horizon.
var built = false

func height_at(x: float, z: float) -> float:
	var wx = x + origin.x
	var wz = z + origin.z
	var y = raw_height(wx, wz, seed_value)
	for village in villages:
		var p: Dictionary = village.position
		var distance = Vector2(wx-float(p.x),wz-float(p.z)).length()
		if distance < 125.0: y = lerpf(float(p.y),y,smoothstep(78.0,125.0,distance))
	return y-origin.y

func to_view(canonical: Vector3) -> Vector3: return canonical
func to_canonical(visual: Vector3) -> Vector3: return visual

func stream_at(_position_value: Vector3) -> void:
	if not built: ensure_spawn(Vector3.ZERO)
	# Vegetation is fixed around the settlement, independently of player travel.
	if nature: nature.stream_at(Vector3.ZERO)

func ensure_spawn(_position_value: Vector3) -> void:
	if built: return
	built = true
	center = Vector2i.ZERO
	for z in [-1,0]:
		for x in [-1,0]: build_chunk(Vector2i(x,z))
	for side in [-1,1]:
		for axis in [0,1]:
			var body = StaticBody3D.new()
			var shape = CollisionShape3D.new()
			var box = BoxShape3D.new()
			box.size = Vector3(2,160,256) if axis == 0 else Vector3(256,160,2)
			shape.shape = box
			body.add_child(shape)
			body.position = Vector3(side*128,60,0) if axis == 0 else Vector3(0,60,side*128)
			add_child(body)

func update_villages(_settlements: Array) -> void: pass
