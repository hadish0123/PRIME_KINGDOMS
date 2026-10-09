extends PanelContainer

const Actor = preload("res://scripts/actor.gd")
const Surfaces = preload("res://scripts/visual_materials.gd")
const Text = preload("res://scripts/game_text.gd")
var game: Node
var report: Dictionary
var view: SubViewport
var stage: Node3D
var armies: Array = []
var phase_label: Label
var result_label: Label
var elapsed = 0.0
var finished = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 24
	offset_right = -24
	offset_top = 100
	offset_bottom = -82
	add_theme_stylebox_override("panel",game.panel_style(Color(0.03,0.03,0.027,0.99)))
	var column = VBoxContainer.new()
	add_child(column)
	var name_value: String = str(report.get("target",{}).get("name","The Borderlands"))
	column.add_child(game.label("Battle of "+name_value,24,Color(0.94,0.80,0.50)))
	phase_label = game.label("Deployment",16)
	column.add_child(phase_label)
	var container = SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size.y = 280
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(container)
	view = SubViewport.new()
	view.size = Vector2i(960,440)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(view)
	stage = Node3D.new()
	view.add_child(stage)
	var camera = Camera3D.new()
	camera.position = Vector3(18,16,26)
	camera.current = true
	stage.add_child(camera)
	camera.look_at(Vector3(0,0,-3))
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-26,0)
	sun.light_color = Color(1.0,0.88,0.70)
	sun.light_energy = 1.2
	stage.add_child(sun)
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.23,0.28,0.27)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.65,0.72,0.74)
	environment.environment.ambient_light_energy = 0.6
	stage.add_child(environment)
	var ground = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(120,120)
	ground.mesh = plane
	ground.material_override = Surfaces.pbr("brown_mud",Color(0.65,0.62,0.51))
	stage.add_child(ground)
	for side in range(2):
		var composition: Array = report.replay.attacker if side==0 else report.replay.defender
		var total = 0
		for unit in composition: total += int(unit.quantity)
		var count = mini(total,[8,12,16,18][game.preferences.quality])
		var losses: Dictionary = report.get("attackerLosses",{}) if side==0 else report.get("defenderLosses",{})
		var lost = 0
		for casualty in losses.values(): lost += int(casualty.wounded)+int(casualty.dead)
		for i in range(count):
			var actor = Actor.new()
			stage.add_child(actor)
			actor.setup("soldier",1.82,i+side*9)
			actor.set_weapon_drawn(true)
			var row = i/6
			var at = Vector3((i%6-2.5)*1.9,0.05,(10+row*2.0)*(1 if side==0 else -1))
			actor.position = at
			actor.rotation.y = PI if side==0 else 0
			armies.append({"actor":actor,"start":at,"side":side,"loss":i<int(round(float(lost)/maxi(1,total)*count))})
	result_label = game.label("",16)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(result_label)
	var actions = HBoxContainer.new()
	column.add_child(actions)
	actions.add_child(game.button("View Result",conclude))
	actions.add_child(game.button("Return to Reports",func(): game.kingdom_panel.close_replay()))

func _process(delta: float) -> void:
	if finished: return
	elapsed += delta
	var phase = "Deployment" if elapsed<2 else "Ranged Exchange" if elapsed<4 else "The Advance" if elapsed<6 else "Melee" if elapsed<9 else "Conclusion"
	phase_label.text = Text.copy(phase)
	var advance = clampf((elapsed-4)/2.0,0,1)
	for unit in armies:
		var actor: Node3D = unit.actor
		var at: Vector3 = unit.start
		actor.position = at.lerp(Vector3(at.x,0.05,at.z*0.17),advance)
		actor.play_motion("walk" if elapsed>=4 and elapsed<6 else "attack" if elapsed>=6 and elapsed<9 else "guard")
		if elapsed>=9 and unit.loss:
			actor.play_motion("death")
	if elapsed>=11: conclude()

func conclude() -> void:
	if finished: return
	finished = true
	for unit in armies:
		var actor: Node3D = unit.actor
		var at: Vector3 = unit.start
		actor.position = Vector3(at.x,0.05,at.z*0.17)
		actor.play_motion("death" if unit.loss else "guard")
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var outcome = "Victory" if bool(report.get("won",report.result=="attacker")) else ("Draw" if report.result=="draw" else "Defeat")
	phase_label.text = Text.copy(outcome)
	var wounds = 0
	var dead = 0
	var losses: Dictionary = report.get("defenderLosses",{}) if report.get("perspective","attacker")=="defender" else report.get("attackerLosses",{})
	for casualty in losses.values():
		wounds += int(casualty.wounded)
		dead += int(casualty.dead)
	result_label.text = Text.copy("%s · %d wounded · %d fallen\n%s") % [Text.name_for(str(report.territoryChange)),wounds,dead,game.kingdom_panel.cost_text(report.get("rewards",{}))]
	game.play_cue("complete")
