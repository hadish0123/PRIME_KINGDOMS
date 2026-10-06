extends SceneTree

var failures: Array[String] = []
var game: Node3D

func _initialize() -> void: run.call_deferred()

func check(value: bool,message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func ticks(count: int) -> void:
	for i in range(count): await physics_frame

func capture(name_value: String,at: Vector3,look: Vector3) -> void:
	if DisplayServer.get_name() == "headless": return
	var camera = Camera3D.new()
	game.world_root.add_child(camera)
	camera.position = at
	camera.look_at(look)
	camera.current = true
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/"+name_value+".png")
	camera.queue_free()
	game.player.camera.current = true

func run() -> void:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixture.json"))
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await game.enter_world(fixture.state.duplicate(true))
	var p = game.player
	await ticks(12)
	check(p.is_on_floor(),"Actions need actual ground contact")
	check(game.horse.skeleton.get_bone_count()==19,"Horse anatomical rig failed to load")
	for motion in ["idle","walk","trot","gallop","jump"]:
		check(game.horse.animation.has_animation(motion),"Missing horse motion: "+motion)
	var bounds: AABB = p.actor.model_bounds(game.horse.model,Transform3D.IDENTITY)
	print("HORSE_BOUNDS ",bounds)
	check(bounds.size.y > 1.70 and bounds.size.y < 2.1,"Horse has incorrect physical scale")
	check(not p.actor.weapon_drawn,"Sword must start in its scabbard")
	p.attack()
	check(p.action_motion.is_empty(),"Sheathed sword could attack")
	game.touch_controls.actions[0].pressed.emit()
	check(p.action_motion == "draw","Sword button did not start drawing animation")
	await ticks(60)
	check(p.actor.weapon_drawn and p.actor.wardrobe.held_weapon.visible and not p.actor.wardrobe.stowed_weapon.visible,"Draw did not transfer the visible weapon into the hand")
	var target = get_nodes_in_group("practice_targets")[0]
	p.position = target.position+Vector3(0,0.1,-1.6)
	p.actor.rotation.y = PI
	await ticks(6)
	p.attack()
	await ticks(50)
	check(target.health==100,"A strike behind the character damaged equipment")
	p.actor.rotation.y = 0
	p.attack()
	await ticks(50)
	check(target.health==75,"Sword animation did not hit nearby practice equipment")
	await capture("sword",p.position+Vector3(2.6,1.65,2.0),p.position+Vector3(0,1.2,0))
	p.toggle_weapon()
	await ticks(60)
	check(not p.actor.weapon_drawn and p.actor.wardrobe.stowed_weapon.visible,"Sheathing did not restore the visible scabbard")
	p.position = Vector3(0,0.1,20)
	p.velocity = Vector3.ZERO
	await ticks(6)
	p.toggle_lying()
	await ticks(50)
	check(p.lying and p.collider.shape==p.prone_shape and p.actor.current_motion=="prone","Lying did not change posture and collision shape")
	var head = p.actor.skeleton.find_bone("head")
	check(p.actor.skeleton.get_bone_global_pose(head).origin.y<0.7,"Prone clip did not lower the actual skeleton to the ground")
	var start: Vector3 = p.position
	p.touch_move = Vector2(0,-1)
	await ticks(45)
	p.touch_move = Vector2.ZERO
	check(p.position.distance_to(start)>0.35,"Prone crawling did not move the player")
	await ticks(6)
	await capture("prone",p.position+Vector3(2.0,1.2,2.0),p.position+Vector3(0,0.40,0))
	var ceiling = StaticBody3D.new()
	game.world_root.add_child(ceiling)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(3.0,0.25,3.0)
	shape.shape = box
	ceiling.add_child(shape)
	ceiling.position = p.position+Vector3(0,1.1,0)
	await ticks(2)
	p.toggle_lying()
	check(p.lying,"Standing up penetrated a low ceiling")
	ceiling.queue_free()
	await ticks(2)
	p.toggle_lying()
	await ticks(50)
	check(not p.lying and p.collider.shape==p.standing_shape,"Standing did not restore full-height collision")
	# Local fixture exercises the same rider controller; real API persistence
	# and distance/ownership checks are covered separately by PostgreSQL tests.
	p.position = game.horse.position
	p.apply_mount(true)
	await ticks(5)
	check(p.horse==game.horse and game.horse.occupied and game.horse.collider.disabled,"Riding did not release the parked horse collider")
	check(p.actor.current_motion=="ride","Mounted player did not select the riding pose")
	start = p.position
	p.touch_move = Vector2(0,1)
	p.touch_sprint = true
	await ticks(40)
	p.touch_move = Vector2.ZERO
	p.touch_sprint = false
	check(p.position.distance_to(start)>4.0 and game.horse.motion=="gallop","Mounted controller did not travel at a gallop")
	await ticks(10)
	await capture("horse",p.position+Vector3(4.5,2.25,3.3),p.position+Vector3(0,1.3,0))
	var dismount_at = p.global_position+Vector3(1.35,0,0)
	check(p.can_stand(dismount_at),"Normal dismount incorrectly used the mounted capsule height")
	p.apply_mount(false)
	p.global_position = dismount_at
	await ticks(3)
	check(not p.horse and not game.horse.collider.disabled and is_equal_approx(p.actor.position.y,0.0),"Dismount failed to restore player and horse collision")
	# Save projection must preserve every fractional X/Z and height above ground.
	for point in [Vector3(250.34173,60.234,-900.34905),Vector3(-3000.1466,56.01,1850.125)]:
		var rendered: Vector3 = game.terrain.to_view(point)
		check(game.terrain.to_canonical(rendered).distance_to(point)<0.001,"Mountain scenery altered persisted coordinates")
	check(game.terrain.horizon.size()<=121,"Distant terrain allocation is unbounded")
	check(game.minimap.view.world_3d==game.get_viewport().find_world_3d(),"Minimap does not render the actual shared 3D world")
	for texture in ["grass_ground_diff.jpg","brown_mud_diff.jpg","meadow_alpha.png"]:
		check(load("res://assets/textures/"+texture).get_image().has_mipmaps(),"Photographic texture is missing distant-detail mipmaps: "+texture)
	print("NATIVE_ACTIONS ",JSON.stringify({"failures":failures,"human_clips":16,"horse_clips":5,"practice_hit":target.health,"mount_controller":true,"canonical_coordinates":true}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
