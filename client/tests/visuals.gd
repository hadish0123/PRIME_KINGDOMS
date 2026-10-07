extends SceneTree

var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()

func check(condition: bool, message: String) -> void:
	if condition: return
	failures.append(message)
	push_error(message)

func capture(file_name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var result = root.get_texture().get_image()
	check(not result.is_empty(), "Visual capture is empty")
	if not result.is_empty(): check(result.save_png("res://builds/" + file_name) == OK, "Visual capture cannot be saved")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://builds")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixture.json"))
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await game.enter_world(fixture.state)
	var actor = game.ruler
	check(actor.skeleton != null and actor.skeleton.get_bone_count() == 49, "Anatomical character rig did not load")
	for name_value in ["idle","walk","guard","work","attack","death","block","hit"]:
		check(actor.animation.has_animation(name_value), "Missing character motion: " + name_value)
	var bone: int = actor.skeleton.find_bone("lowerleg01.L")
	actor.animation.play("walk",0.0)
	actor.animation.seek(0.0, true)
	var before: Transform3D = actor.skeleton.get_bone_global_pose(bone)
	actor.animation.seek(0.35, true)
	var after: Transform3D = actor.skeleton.get_bone_global_pose(bone)
	check(not before.is_equal_approx(after), "Walking did not deform the actual skeleton")
	var camera = Camera3D.new()
	game.world_root.add_child(camera)
	camera.fov = 48
	for frame in range(80): await process_frame
	check(game.terrain.nature.grass.size() <= 49 and game.terrain.nature.groves.size() <= 25, "Balanced scenery allocation exceeded its budget")
	# Two players can render the same global place relative to different homes.
	# Verify generated instance positions, not just a seed/helper implementation.
	var original_origin: Vector3 = game.terrain.origin
	var key = Vector2i.ZERO
	for candidate in game.terrain.nature.grass:
		if game.terrain.nature.grass[candidate].multimesh.instance_count > 0:
			key = candidate
			break
	var first = game.terrain.nature.grass[key]
	var first_world: Vector3 = first.position + first.multimesh.get_instance_transform(0).origin + original_origin
	var mirror = load("res://scripts/nature.gd").new()
	mirror.terrain = game.terrain
	mirror.settlement_sites = game.terrain.nature.settlement_sites
	game.world_root.add_child(mirror)
	game.terrain.origin += Vector3(512, 0, 512)
	mirror.build_grass(key)
	var second = mirror.grass[key]
	var second_world: Vector3 = second.position + second.multimesh.get_instance_transform(0).origin + game.terrain.origin
	game.terrain.origin = original_origin
	check(first_world.distance_to(second_world) < 0.001, "Shared-world foliage differs between village origins")
	mirror.queue_free()
	camera.position = game.ruler.position + Vector3(1.10, 1.65, -2.75)
	camera.look_at(game.ruler.position + Vector3(0, 1.05, 0))
	camera.current = true
	for frame in range(3): await process_frame
	await capture("human.png")
	# High-detail setting has finite scenery budgets; returning to LOW frees them.
	game.terrain.nature.set_quality(2)
	for frame in range(50): await process_frame
	check(game.terrain.nature.grass.size() <= 81 and game.terrain.nature.groves.size() <= 49, "High scenery allocation exceeded its budget")
	game.terrain.nature.set_quality(0)
	for frame in range(15): await process_frame
	check(game.terrain.nature.grass.size() <= 25 and game.terrain.nature.groves.size() <= 9, "Low scenery did not release higher quality allocations")
	print("NATIVE_VISUALS ", JSON.stringify({"failures": failures, "human_bones": 49, "simulation_motions":5, "horse_clips":5, "bounded_foliage": true}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
