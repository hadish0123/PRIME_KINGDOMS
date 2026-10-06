extends SkeletonModifier3D

# A single physical mesh remains in the scabbard, slides through its mouth,
# then follows the right palm. IK is evaluated AFTER the animation mixer.
var wardrobe: RefCounted
var palm_error = 0.0
var extraction = 0.0
var previous_base = Vector3.ZERO
var previous_tip = Vector3.ZERO
var had_blade = false

func eased(value: float) -> float:
	return smoothstep(0.0,1.0,clampf(value,0.0,1.0))

func solve_arm(grip: Transform3D, amount: float) -> void:
	var s = get_skeleton()
	var upper = s.find_bone("upperarm01.R")
	var lower = s.find_bone("lowerarm01.R")
	var hand = s.find_bone("wrist.R")
	var a = s.get_bone_global_pose(upper).origin
	var rest_a = s.get_bone_global_rest(upper).origin
	var rest_b = s.get_bone_global_rest(lower).origin
	var rest_c = s.get_bone_global_rest(hand).origin
	var hand_direction = (rest_c-rest_b).normalized()
	var hand_basis = grip.basis * Basis(Quaternion(hand_direction,Vector3.DOWN))
	var target = grip.origin-hand_basis*hand_direction*0.075
	var animated = s.get_bone_global_pose(hand)
	target = animated.origin.lerp(target,amount)
	var l1 = rest_a.distance_to(rest_b)
	var l2 = rest_b.distance_to(rest_c)
	var ray = target-a
	var distance_value = clampf(ray.length(),absf(l1-l2)+0.002,l1+l2-0.001)
	var direction = ray.normalized()
	target = a+direction*distance_value
	var along = (l1*l1-l2*l2+distance_value*distance_value)/(2.0*distance_value)
	var bend = Vector3(-0.35,-0.3,-0.8)
	bend = (bend-direction*bend.dot(direction)).normalized()
	var elbow = a+direction*along+bend*sqrt(maxf(0,l1*l1-along*along))
	var upper_basis = Basis(Quaternion((rest_b-rest_a).normalized(),(elbow-a).normalized()))
	var lower_basis = Basis(Quaternion((rest_c-rest_b).normalized(),(target-elbow).normalized()))
	s.set_bone_global_pose(upper,Transform3D(upper_basis,a))
	s.set_bone_global_pose(lower,Transform3D(lower_basis,elbow))
	s.set_bone_global_pose(hand,Transform3D(animated.basis.slerp(hand_basis,amount),target))
	palm_error = (target+hand_basis*hand_direction*0.075).distance_to(grip.origin)

func _process_modification_with_delta(_delta: float) -> void:
	if not wardrobe or not wardrobe.sword: return
	var s = get_skeleton()
	var hip = s.get_bone_global_pose(s.find_bone("spine03"))*wardrobe.scabbard_rest
	var progress: float = wardrobe.progress
	var motion: String = wardrobe.motion
	var grip = hip
	extraction = 0.0
	if motion in ["draw","sheathe"]:
		var t = progress if motion == "draw" else 1.0-progress
		var pull = eased((t-0.22)/0.53)
		extraction = pull*wardrobe.extraction_length
		grip.origin += hip.basis.y*extraction
		if t > 0.75:
			var settle = eased((t-0.75)/0.25)
			var ready = Transform3D(Basis(Quaternion(Vector3.DOWN,Vector3(0.02,-0.50,0.86).normalized())),Vector3(-0.20,1.15,0.36))
			grip = grip.interpolate_with(ready,settle)
		solve_arm(grip,eased(t/0.22))
	elif wardrobe.drawn:
		var hand_pose = s.get_bone_global_pose(s.find_bone("wrist.R"))
		var rest_direction = (s.get_bone_global_rest(s.find_bone("wrist.R")).origin-s.get_bone_global_rest(s.find_bone("lowerarm01.R")).origin).normalized()
		grip = Transform3D(hand_pose.basis*Basis(Quaternion(Vector3.DOWN,rest_direction)),hand_pose.origin+hand_pose.basis*rest_direction*0.075)
		if motion == "attack":
			# A wind-up, diagonal cut and recovery; blade geometry drives contact.
			var cut = eased((progress-0.18)/0.44)
			var recover = eased((progress-0.64)/0.36)
			var point = Vector3(-0.30,1.63,0.32).lerp(Vector3(0.27,1.05,0.56),cut).lerp(Vector3(-0.20,1.15,0.36),recover)
			var direction = Vector3(-0.35,0.70,0.62).lerp(Vector3(0.45,-0.12,0.89),cut).lerp(Vector3(0.02,-0.50,0.86),recover).normalized()
			grip = Transform3D(Basis(Quaternion(Vector3.DOWN,direction)),point)
			solve_arm(grip,1.0)
		else:
			extraction = wardrobe.blade_length
	wardrobe.sword.transform = grip
	var clench = 1.0 if wardrobe.drawn else 0.0
	if motion in ["draw","sheathe"]:
		var t = progress if motion == "draw" else 1-progress
		clench = eased((t-0.10)/0.12)
	for finger in range(1,6):
		for joint in range(1,4):
			var index = s.find_bone("finger%d-%d.R"%[finger,joint])
			if index >= 0:
				var rotation_value = Quaternion(Vector3.UP,(0.55 if finger==1 else 1.1)*clench)
				s.set_bone_pose_rotation(index,rotation_value)
	var base: Vector3 = s.global_transform*(grip*Vector3(0,-0.12,0))
	var tip: Vector3 = s.global_transform*(grip*Vector3(0,-wardrobe.blade_length,0))
	if motion == "attack" and progress > 0.20 and progress < 0.67:
		var player = wardrobe.actor.get_parent()
		if player.has_method("sweep_sword"):
			player.sweep_sword(base,tip,previous_base if had_blade else base,previous_tip if had_blade else tip)
	previous_base = base
	previous_tip = tip
	had_blade = motion == "attack"
