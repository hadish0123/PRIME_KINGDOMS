extends SceneTree

# Cinematic final-character evidence rendered by the same Godot project that is
# exported to Android. Gameplay/action correctness is covered by actions.gd,
# smoke.gd and poses.gd; this short film is deliberately framed as character art.
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Character film requires the actual native renderer")
		quit(1)
		return
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixture.json"))
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.preferences.quality = 1
	await game.enter_world(fixture.state.duplicate(true))

	# Remove gameplay chrome and nearby test props so the exported movie is a
	# clean full-body presentation of the exact runtime ruler.
	for control in [game.hud,game.touch_controls,game.map_panel,game.settings_panel,game.minimap,game.residents_panel]:
		if is_instance_valid(control): control.visible = false
	for target in get_nodes_in_group("practice_targets"):
		if target is Node3D: target.visible = false
	if is_instance_valid(game.horse): game.horse.visible = false

	var p = game.player
	var actor = p.actor
	p.set_physics_process(false)
	p.position = Vector3(0,0.1,12)
	p.velocity = Vector3.ZERO
	p.actor.rotation.y = 0.0
	actor.set_weapon_drawn(false)
	actor.play_motion("idle")

	# Warm royal key light over the normal streamed village environment.
	if is_instance_valid(game.sun):
		game.sun.light_color = Color(1.0,0.72,0.48)
		game.sun.light_energy = 1.55
		game.sun.rotation_degrees = Vector3(-38,-32,0)

	var fill = DirectionalLight3D.new()
	fill.light_color = Color(0.44,0.56,0.86)
	fill.light_energy = 0.42
	fill.rotation_degrees = Vector3(-18,145,0)
	fill.shadow_enabled = false
	game.world_root.add_child(fill)

	var camera = Camera3D.new()
	camera.fov = 43.0
	game.world_root.add_child(camera)
	camera.current = true
	DirAccess.make_dir_recursive_absolute("res://builds/frames")
	for i in range(45): await process_frame

	var started = Time.get_ticks_msec()
	for frame in range(300):
		# A compact ten-second motion reel: regal idle, draw, strike, recovery,
		# walk cycle and final sword pose. No fake/pre-rendered character frames.
		if frame == 55: actor.play_motion("draw")
		if frame == 72: actor.set_weapon_drawn(true)
		if frame == 96: actor.play_motion("attack")
		if frame == 124: actor.play_motion("idle")
		if frame == 158: actor.play_motion("walk")
		if frame == 205: actor.play_motion("idle")
		if frame == 232: actor.play_motion("sheathe")
		if frame == 252:
			actor.set_weapon_drawn(false)
			actor.play_motion("idle")
		if frame == 270:
			actor.set_weapon_drawn(true)
			actor.play_motion("guard")

		var phase = float(frame)/299.0
		var orbit = lerpf(-0.32,0.32,phase)
		var distance = 3.15-0.32*sin(phase*PI)
		var height = 1.58+0.10*sin(phase*PI)
		camera.position = p.position+Vector3(1.45,height,distance).rotated(Vector3.UP,orbit)
		camera.look_at(p.position+Vector3(0,0.96,0))

		await process_frame
		await RenderingServer.frame_post_draw
		var frame_image = root.get_texture().get_image()
		check(not frame_image.is_empty(),"Empty rendered character frame %d" % frame)
		if not frame_image.is_empty():
			check(frame_image.save_png("res://builds/frames/frame-%04d.png" % frame)==OK,"Cannot save rendered character frame %d" % frame)
		if frame % 60 == 0:
			print("CHARACTER_FILM_PROGRESS frame=",frame,"/300 wall_seconds=",(Time.get_ticks_msec()-started)/1000.0)

	check(actor.skeleton != null and actor.skeleton.get_bone_count()==19,"Final character rig is not the verified 19-bone runtime rig")
	check(actor.animation != null,"Final character animation player missing")
	print("NATIVE_CHARACTER_FILM ",JSON.stringify({"failures":failures,"frames":300,"capture_fps":30,"quality":"BALANCED","native_runtime":true}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
