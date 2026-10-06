extends SceneTree

# The production controller and actual wardrobe, under neutral inspection light.
var failures: Array[String] = []
var player: CharacterBody3D
var camera: Camera3D

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
	player = load("res://scripts/player.gd").new()
	scene.add_child(player)
	player.position.y = 0.1
	camera = Camera3D.new()
	camera.fov = 38
	camera.current = true
	scene.add_child(camera)
	for i in range(30): await physics_frame
	check(player.actor.skeleton.get_bone_count()==49,"Production player rig missing")
	var identity: int = player.actor.wardrobe.sword.get_instance_id()
	await capture("character-front",Vector3(1.0,1.32,3.30),Vector3(0,1.0,0))
	await capture("character-face",Vector3(0.26,1.79,0.93),Vector3(0,1.69,0))
	await capture("character-back",Vector3(-1.0,1.32,-3.30),Vector3(0,1.0,0))
	player.toggle_weapon()
	for i in range(100): await physics_frame
	check(player.actor.weapon_drawn,"Production sword draw failed")
	check(player.actor.wardrobe.sword.get_instance_id()==identity,"Sword instance changed")
	await capture("character-sword",Vector3(1.10,1.32,3.30),Vector3(0,1.0,0))
	player.attack()
	for i in range(70): await physics_frame
	player.toggle_weapon()
	for i in range(100): await physics_frame
	check(not player.actor.weapon_drawn,"Production sword sheathe failed")
	if "--record" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("res://builds/character-frames")
		for frame in range(240):
			if frame == 25: player.toggle_weapon()
			if frame == 90: player.attack()
			if frame == 140: player.toggle_weapon()
			var angle = float(frame)/240.0*TAU
			camera.position = Vector3(sin(angle)*3.35,1.34,cos(angle)*3.35)
			camera.look_at(Vector3(0,1.0,0))
			await process_frame
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://builds/character-frames/%04d.png"%frame)==OK,"Character recording frame failed")
	print("CHARACTER_REVIEW ",JSON.stringify({"failures":failures,"actual_production_player":true,"reference_match":"not_certified"}))
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
