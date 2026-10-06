extends SceneTree

# Real native runtime character film. LOW is intentionally kept for the software
# renderer so the evidence video stays deterministic; the installed client still
# defaults to BALANCED/HIGH-capable presentation.
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Film requires the actual native renderer")
		quit(1)
		return

	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixture.json"))
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.preferences.quality = 0
	await game.enter_world(fixture.state.duplicate(true))
	game.connection_label.text = "FINAL PRIME CHARACTER · native runtime capture"

	var p = game.player
	var actor = p.actor
	p.frozen = true
	for frame in range(35):
		await process_frame
	p.frozen = false
	p.yaw = 0
	p.pitch = -0.17

	# Park the fixture horse on the central gate road. API ownership, range,
	# persistence and collision safety remain covered by the integration tests.
	game.horse.position = Vector3(0, 0.1, 20)

	var camera := Camera3D.new()
	game.world_root.add_child(camera)
	camera.fov = 45.0

	var target = get_nodes_in_group("practice_targets")[0]
	p.position = target.position + Vector3(0, 0.1, -1.7)
	p.actor.rotation.y = 0.0

	DirAccess.make_dir_recursive_absolute("res://builds/frames")
	var motions: Dictionary = {}
	var horse_motions: Dictionary = {}
	var started := Time.get_ticks_msec()

	for frame in range(600):
		p.touch_move = Vector2(0, -1) if (frame >= 180 and frame < 235) or (frame >= 280 and frame < 380) else Vector2.ZERO
		p.touch_sprint = frame >= 320 and frame < 380

		if frame == 125:
			check(target.health == 50, "Recorded controller strikes did not damage the practice target twice")

		if frame in [30, 125]:
			game.touch_controls.actions[0].pressed.emit()
		if frame in [65, 95]:
			game.touch_controls.actions[2].pressed.emit()
		if frame in [155, 245]:
			game.touch_controls.actions[4].pressed.emit()
		if frame in [330, 362, 505]:
			p.jump_requested = true

		if frame == 420:
			p.position = game.horse.position
			p.velocity = Vector3.ZERO
			p.apply_mount(true)

		if frame >= 430 and frame < 570:
			p.touch_move = Vector2(0, 1)
			p.touch_sprint = frame >= 465

		if frame == 575:
			p.apply_mount(false)
			p.position.x += 1.35

		# Hero showcase: orbit the upgraded armor, tabard, lion badge and sword
		# during draw/strike actions, then transition into real controller footage.
		if frame < 155:
			camera.current = true
			var t := float(frame) / 154.0
			var angle := lerpf(-0.72, 0.68, t)
			var distance := lerpf(3.35, 2.85, sin(t * PI))
			camera.position = p.position + Vector3(sin(angle) * distance, 1.82 + sin(t * PI) * 0.12, cos(angle) * distance)
			camera.look_at(p.position + Vector3(0, 1.08, 0))
		elif frame >= 420 and frame < 575:
			camera.current = true
			var ride_angle := -0.52 + sin(float(frame - 420) * 0.018) * 0.16
			camera.position = p.position + Vector3(sin(ride_angle) * 4.7, 2.72, cos(ride_angle) * 4.7)
			camera.look_at(p.position + Vector3(0, 1.34, 0))
		elif frame >= 575:
			camera.current = true
			var ending := float(frame - 575) / 24.0
			var end_angle := lerpf(0.45, -0.25, ending)
			camera.position = p.position + Vector3(sin(end_angle) * 3.1, 1.86, cos(end_angle) * 3.1)
			camera.look_at(p.position + Vector3(0, 1.08, 0))
		else:
			p.camera.current = true

		await process_frame
		motions[actor.current_motion] = true
		if p.horse:
			horse_motions[game.horse.motion] = true

		await RenderingServer.frame_post_draw
		var frame_image := root.get_texture().get_image()
		check(not frame_image.is_empty(), "Empty rendered frame %d" % frame)
		if not frame_image.is_empty():
			check(frame_image.save_png("res://builds/frames/frame-%04d.png" % frame) == OK, "Cannot save rendered frame %d" % frame)

		if frame % 60 == 0:
			print("FILM_PROGRESS frame=", frame, "/600 wall_seconds=", (Time.get_ticks_msec() - started) / 1000.0)

	for expected in ["idle", "walk", "run", "jump", "fall", "land", "draw", "sheathe", "attack", "lie_down", "prone", "crawl", "stand_up", "ride"]:
		check(motions.has(expected), "Controller film did not exercise " + expected)
	for expected in ["idle", "walk", "trot", "gallop", "jump"]:
		check(horse_motions.has(expected), "Mounted film did not exercise horse " + expected)

	check(p.position.z > 53.0, "Mounted recording did not travel through the village gate")
	p.touch_move = Vector2.ZERO
	p.touch_sprint = false

	print("NATIVE_FILM ", JSON.stringify({
		"failures": failures,
		"frames": 600,
		"capture_fps": 30,
		"quality": "LOW",
		"phone_benchmark": false,
		"final_prime_character": true,
		"human_motions": motions.keys(),
		"horse_motions": horse_motions.keys()
	}))

	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
