extends SceneTree

var failures: Array[String] = []
var game: Node3D
var max_palm_error = 0.0
var sword_identity: int
var max_finger_angle = 0.0
var last_finger_angle = 0.0

func _initialize() -> void: run.call_deferred()

func check(value: bool,message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func ticks(count: int) -> void:
	for i in range(count): await physics_frame

func inspect_rig() -> void:
	var w = game.player.actor.wardrobe
	var s = game.player.actor.skeleton
	# Modifiers temporarily apply poses after the animation mixer. Read the
	# rendered joints in this signal before Godot restores the animation pose.
	last_finger_angle = s.get_bone_pose_rotation(s.find_bone("finger2-2.R")).get_angle()
	if w.drawn: max_finger_angle = maxf(max_finger_angle,last_finger_angle)
	if w.motion in ["draw","sheathe"]:
		var t: float = w.progress if w.motion == "draw" else 1-w.progress
		if t > 0.22:
			max_palm_error = maxf(max_palm_error,w.rig.palm_error)
	check(w.sword.get_instance_id()==sword_identity,"Weapon swapped mesh instances during the action")

func capture(name_value: String,position_value: Vector3,look: Vector3) -> void:
	if DisplayServer.get_name() == "headless": return
	var camera = game.get_node("HeroReviewCamera")
	camera.position = position_value
	camera.look_at(look)
	for i in range(2): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://builds/"+name_value+".png")==OK,"Cannot save actual hero image")

func run() -> void:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixture.json"))
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await game.enter_world(fixture.state.duplicate(true))
	var p = game.player
	p.actor.rotation.y = 0
	p.position = Vector3(0,0.1,20)
	await ticks(12)
	var w = p.actor.wardrobe
	check(p.actor.skeleton.get_bone_count()==49,"Player rig is missing the individual finger joints")
	var sleeve = w.scabbard.get_child(0).mesh.surface_get_arrays(0)
	var v: Vector3 = sleeve[Mesh.ARRAY_VERTEX][0]
	var n: Vector3 = sleeve[Mesh.ARRAY_NORMAL][0]
	check(Vector3(v.x,0,v.z).dot(n)>0,"Scabbard wall normals point inward and expose the stored blade")
	sword_identity = w.sword.get_instance_id()
	w.rig.modification_processed.connect(inspect_rig)
	check(p.actor.skeleton.get_node_or_null("TabardChest")!=null,"The actual player is missing the fitted reference tabard")
	check(p.actor.skeleton.get_node_or_null("TabardSkirt")!=null,"The lower tabard is not skinned to the legs")
	var camera = Camera3D.new()
	camera.name = "HeroReviewCamera"
	camera.fov = 42
	camera.current = true
	game.add_child(camera)
	for i in range(30): await process_frame
	await capture("hero-front",p.position+Vector3(1.05,1.55,3.05),p.position+Vector3(0,1.08,0))
	await capture("hero-back",p.position+Vector3(-1.15,1.60,-3.05),p.position+Vector3(0,1.07,0))
	await capture("hero-face",p.position+Vector3(0.34,1.80,1.10),p.position+Vector3(0,1.65,0))
	p.toggle_weapon()
	check(p.action_motion=="draw","Draw button did not start")
	for i in range(100):
		await physics_frame
		if i in [21,45,65]:
			await capture("hero-draw-%d"%i,p.position+Vector3(1.0,1.70,2.45),p.position+Vector3(0,1.18,0))
	check(p.actor.weapon_drawn,"Drawing never completed")
	check(max_palm_error<0.035,"Right palm lost the sword grip: %.4f m"%max_palm_error)
	check(max_finger_angle>0.5,"Right fingers did not close around the grip")
	var target = get_nodes_in_group("practice_targets")[0]
	p.position = target.position+Vector3(0,0.1,-1.35)
	p.actor.rotation.y = PI
	await ticks(8)
	p.attack()
	await ticks(60)
	check(target.health==100,"Blade damaged equipment behind the character")
	p.actor.rotation.y = 0
	var wall = StaticBody3D.new()
	game.world_root.add_child(wall)
	var wall_collision = CollisionShape3D.new()
	var wall_shape = BoxShape3D.new()
	wall_shape.size = Vector3(3,2,0.18)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	wall.position = p.position+Vector3(0,1,0.75)
	await ticks(2)
	p.attack()
	await ticks(60)
	check(target.health==100,"A swept sword damaged equipment through a wall")
	wall.queue_free()
	await ticks(2)
	p.attack()
	await ticks(60)
	check(target.health==75,"Swept physical blade did not contact nearby equipment")
	await capture("hero-sword",p.position+Vector3(1.9,1.5,2.6),p.position+Vector3(0,1.05,0))
	p.toggle_weapon()
	await ticks(100)
	check(not p.actor.weapon_drawn,"Sheathing never completed")
	check(last_finger_angle<0.05,"Right fingers stayed clenched after releasing the hilt")
	check(max_palm_error<0.035,"Sheathing lost hand contact")
	await capture("ground-detail",Vector3(0.6,0.62,27.0),Vector3(0,0.03,22))
	print("NATIVE_HERO ",JSON.stringify({"failures":failures,"one_sword":true,"max_palm_error_m":max_palm_error,"blade_contact_damage":100-target.health,"reference_match":"requires_visual_review"}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
