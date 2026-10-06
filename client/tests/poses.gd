extends SceneTree

func _initialize() -> void: run.call_deferred()

func take(name_value: String,camera: Camera3D,at: Vector3,look: Vector3) -> void:
	camera.position = at
	camera.look_at(look)
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://builds/"+name_value+".png")==OK)

func pose(actor: Node3D,motion: String,at: float) -> void:
	actor.current_motion = motion
	actor.animation.play(motion,0.0)
	actor.animation.seek(at,true)
	actor.animation.pause()

func run() -> void:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixture.json"))
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await game.enter_world(fixture.state.duplicate(true))
	var p = game.player
	p.set_physics_process(false)
	for npc in game.villages[game.state.village.id].population: npc.set_physics_process(false)
	var camera = Camera3D.new()
	game.world_root.add_child(camera)
	camera.current = true
	for i in range(60): await process_frame
	p.actor.set_weapon_drawn(true)
	pose(p.actor,"attack",0.35)
	await take("sword",camera,p.position+Vector3(2.5,1.65,2.8),p.position+Vector3(0,1.15,0))
	p.actor.set_weapon_drawn(false)
	pose(p.actor,"prone",0.5)
	await take("prone",camera,p.position+Vector3(2.5,1.5,2.5),p.position+Vector3(0,0.35,0))
	p.position = game.horse.position
	p.apply_mount(true)
	pose(p.actor,"ride",0.45)
	game.horse.animation.seek(0.8,true)
	game.horse.animation.pause()
	await take("horse",camera,p.position+Vector3(4.8,2.6,3.4),p.position+Vector3(0,1.25,0))
	print("NATIVE_POSES real_runtime=true human_clips=16 horse_clips=5")
	game.queue_free()
	await process_frame
	quit(0)
