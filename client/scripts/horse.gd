extends Node3D

const Actor = preload("res://scripts/actor.gd")
const Surfaces = preload("res://scripts/visual_materials.gd")
var model: Node3D
var animation: AnimationPlayer
var skeleton: Skeleton3D
var collider: CollisionShape3D
var title: Label3D
var motion = ""
var occupied = false

func _ready() -> void:
	model = load("res://assets/horse/horse.glb").instantiate()
	add_child(model)
	var helper = Actor.new()
	animation = helper.find_animation(model)
	skeleton = helper.find_skeleton(model)
	helper.free()
	for clip in animation.get_animation_list():
		animation.get_animation(clip).loop_mode = Animation.LOOP_NONE if clip == "jump" else Animation.LOOP_LINEAR
	var body = StaticBody3D.new()
	add_child(body)
	collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(0.80,1.5,2.4)
	collider.shape = shape
	collider.position.y = 0.80
	body.add_child(collider)
	title = Label3D.new()
	title.text = "YOUR HORSE · RIDE / E"
	title.position.y = 2.20
	title.font_size = 28
	title.pixel_size = 0.007
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.visibility_range_end = 12.0
	add_child(title)
	harness()
	play("idle")

func visual(mesh: Mesh,at: Vector3,surface: Material,basis: Basis = Basis.IDENTITY) -> void:
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.transform = Transform3D(basis,at)
	node.material_override = surface
	node.visibility_range_end = 300.0
	add_child(node)

func harness() -> void:
	var leather = Surfaces.plain(Color(0.13,0.065,0.026),0.83)
	var steel = Surfaces.plain(Color(0.38,0.31,0.18),0.37,0.8)
	var saddle = SphereMesh.new()
	saddle.radius = 0.45
	saddle.height = 0.90
	visual(saddle,Vector3(0,1.46,0),leather,Basis.IDENTITY.scaled(Vector3(0.72,0.15,1.15)))
	var blanket = SurfaceTool.new()
	blanket.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(8):
		for z in range(8):
			for p in [[0,0],[0,1],[1,0],[0,1],[1,1],[1,0]]:
				var u = float(x+p[0])/8.0
				var v = float(z+p[1])/8.0
				blanket.set_uv(Vector2(u,v))
				blanket.add_vertex(Vector3((u-0.5)*0.92,1.41-pow(absf(u-0.5)*2.0,2.0)*0.19,(v-0.5)*1.16))
	blanket.generate_normals()
	var cloth = ShaderMaterial.new()
	cloth.shader = load("res://shaders/cloth.gdshader")
	cloth.set_shader_parameter("albedo_map",load("res://assets/textures/rough_linen_diff.jpg"))
	cloth.set_shader_parameter("tint",Color(0.32,0.035,0.045))
	visual(blanket.commit(),Vector3.ZERO,cloth)
	for side in [-1,1]:
		var strap = CylinderMesh.new()
		strap.top_radius = 0.016
		strap.bottom_radius = 0.016
		strap.height = 0.38
		visual(strap,Vector3(side*0.40,1.20,0),leather)
		var stirrup = TorusMesh.new()
		stirrup.inner_radius = 0.08
		stirrup.outer_radius = 0.10
		visual(stirrup,Vector3(side*0.40,1.03,0),steel,Basis(Vector3.FORWARD,PI*0.5))

func set_occupied(value: bool) -> void:
	occupied = value
	collider.set_deferred("disabled",value)
	title.visible = not value
	if not value: play("idle")

func play(value: String) -> void:
	if value == motion: return
	animation.play(value,0.16)
	motion = value

func animate(speed: float,on_ground: bool,_delta: float) -> void:
	play("jump" if not on_ground else ("gallop" if speed > 6 else ("trot" if speed > 2.5 else ("walk" if speed > 0.1 else "idle"))))
	animation.speed_scale = clampf(speed/(8.8 if motion == "gallop" else (4.0 if motion == "trot" else 1.5)),0.6,1.8) if motion in ["walk","trot","gallop"] else 1.0
