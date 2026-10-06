extends Node3D

const Surfaces = preload("res://scripts/visual_materials.gd")
var health = 100
var recovery = 0.0
var target: Node3D
var title: Label3D

func _ready() -> void:
	add_to_group("practice_targets")
	target = Node3D.new()
	add_child(target)
	var post = CylinderMesh.new()
	post.top_radius = 0.09
	post.bottom_radius = 0.13
	post.height = 2.0
	shape(post,Vector3(0,1,0),Surfaces.pbr("wood_planks",Color(0.53,0.42,0.30)))
	var torso = CapsuleMesh.new()
	torso.radius = 0.27
	torso.height = 0.88
	shape(torso,Vector3(0,1.15,0),Surfaces.pbr("rough_linen",Color(0.53,0.42,0.25),1.0,false))
	var head = SphereMesh.new()
	head.radius = 0.18
	head.height = 0.36
	shape(head,Vector3(0,1.83,0),Surfaces.pbr("rough_linen",Color(0.67,0.55,0.30),1.0,false))
	var arms = BoxMesh.new()
	arms.size = Vector3(1.15,0.12,0.12)
	shape(arms,Vector3(0,1.45,0),Surfaces.pbr("wood_planks",Color(0.53,0.42,0.30)))
	title = Label3D.new()
	title.text = "PRACTICE · 100 / 100"
	title.position.y = 2.3
	title.font_size = 28
	title.pixel_size = 0.007
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.visibility_range_end = 15
	add_child(title)
	var body = StaticBody3D.new()
	var collider = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(0.56,1.95,0.56)
	collider.shape = box
	collider.position.y = 1.0
	body.add_child(collider)
	add_child(body)

func shape(mesh: Mesh,at: Vector3,surface: Material) -> void:
	var item = MeshInstance3D.new()
	item.mesh = mesh
	item.position = at
	item.material_override = surface
	target.add_child(item)

func hit(damage: int) -> void:
	if health <= 0: return
	health = maxi(0,health-damage)
	target.rotation.x = -0.18 if health > 0 else -0.72
	recovery = 5.0
	title.text = "PRACTICE · %d / 100" % health

func _process(delta: float) -> void:
	recovery -= delta
	if recovery <= 0 and health < 100:
		health = 100
		title.text = "PRACTICE · 100 / 100"
	target.rotation.x = lerpf(target.rotation.x,0.0,minf(1,delta*9)) if health > 0 else target.rotation.x
