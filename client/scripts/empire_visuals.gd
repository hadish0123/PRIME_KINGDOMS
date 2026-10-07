extends RefCounted

static func apply(node: Node, empire: Dictionary) -> void:
	if node is MeshInstance3D:
		var material: Material = node.material_override
		if material is ShaderMaterial:
			var path: String = material.shader.resource_path
			if path in ["res://shaders/cloth.gdshader","res://shaders/hero_mantle.gdshader","res://shaders/royal_textile.gdshader"]:
				var surface: ShaderMaterial = material.duplicate()
				surface.set_shader_parameter("empire_primary",Color(str(empire.primaryColor)))
				surface.set_shader_parameter("empire_secondary",Color(str(empire.secondaryColor)))
				surface.set_shader_parameter("empire_enabled",true)
				surface.set_shader_parameter("emblem_mask",load("res://assets/heraldry/"+str(empire.emblem)+".svg"))
				surface.set_shader_parameter("tint",Color(str(empire.primaryColor)))
				node.material_override = surface
				node.set_meta("empire_emblem",empire.emblem)
				node.set_meta("empire_primary",empire.primaryColor)
	for child in node.get_children(): apply(child,empire)
