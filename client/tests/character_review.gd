extends SceneTree

# The decorative ruler and actual wardrobe, under neutral inspection light.
var failures: Array[String] = []
var actor: Node3D
var camera: Camera3D

func triangles(node: Node) -> int:
	var total = 0
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			var arrays = node.mesh.surface_get_arrays(surface)
			var indices = arrays[Mesh.ARRAY_INDEX]
			# SurfaceTool may emit an unindexed surface (ARRAY_INDEX is Nil).
			# A typed assignment aborted this traversal and undercounted armor.
			if indices is PackedInt32Array and not indices.is_empty():
				total += indices.size()/3
			else:
				total += arrays[Mesh.ARRAY_VERTEX].size()/3
	for child in node.get_children(): total += triangles(child)
	return total

func _initialize() -> void: run.call_deferred()
func check(value: bool,message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func capture(name_value: String,at: Vector3,target: Vector3) -> void:
	camera.position = at
	camera.look_at(target)
	for i in range(3): await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://builds/"+name_value+".png")==OK,"Character render failed")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://builds")
	# Regression: a valid unindexed triangle must not disappear from the
	# geometry budget when ARRAY_INDEX is absent.
	var unindexed = MeshInstance3D.new()
	unindexed.mesh = ArrayMesh.new()
	var triangle_arrays = []
	triangle_arrays.resize(Mesh.ARRAY_MAX)
	triangle_arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP])
	unindexed.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,triangle_arrays)
	check(triangles(unindexed)==1,"Unindexed geometry was omitted from the player budget")
	unindexed.free()
	var scene = Node3D.new()
	root.add_child(scene)
	var world = WorldEnvironment.new()
	var environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055,0.065,0.080)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.67,0.76,0.90)
	environment.ambient_light_energy = 0.65
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var sky = Sky.new()
	var panorama = PanoramaSkyMaterial.new()
	panorama.panorama = load("res://assets/textures/sky.hdr")
	sky.sky_material = panorama
	environment.sky = sky
	world.environment = environment
	scene.add_child(world)
	for item in [[Color(1,0.88,0.74),1.3,Vector3(-28,-32,0)],[Color(0.65,0.78,1),0.7,Vector3(-20,145,0)]]:
		var light = DirectionalLight3D.new()
		light.light_color = item[0]
		light.light_energy = item[1]
		light.rotation_degrees = item[2]
		scene.add_child(light)
	var ground = StaticBody3D.new()
	scene.add_child(ground)
	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(20,0.2,20)
	collider.shape = shape
	collider.position.y = -0.1
	ground.add_child(collider)
	actor = load("res://scripts/actor.gd").new()
	scene.add_child(actor)
	actor.setup("player")
	actor.position.y = 0.1
	camera = Camera3D.new()
	camera.fov = 38
	camera.current = true
	scene.add_child(camera)
	for i in range(30): await physics_frame
	check(actor.skeleton.get_bone_count()==49,"Decorative ruler rig missing")
	var triangle_count = triangles(actor)
	check(triangle_count<210000,"Ruler mesh exceeded the medium-quality geometry budget")
	await capture("character-front",Vector3(1.0,1.32,3.30),Vector3(0,1.0,0))
	await capture("character-face",Vector3(0.26,1.79,0.93),Vector3(0,1.69,0))
	await capture("character-profile",Vector3(-0.83,1.79,0.28),Vector3(0,1.69,0))
	await capture("character-back",Vector3(-1.0,1.32,-3.30),Vector3(0,1.0,0))
	print("CHARACTER_REVIEW ",JSON.stringify({"failures":failures,"decorative_ruler":true,"triangles":triangle_count,"reference_match":"not_certified"}))
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
