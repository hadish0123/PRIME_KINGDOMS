extends RefCounted
## Export native layout/text/art references as editable design source, never a UI bitmap.

static func save(game: Node,file_name: String) -> void:
	var nodes: Array = []
	collect(game.ui,game.get_viewport().get_visible_rect(),nodes)
	var source = {"name":file_name,"viewport":{"width":1280,"height":720},"nodes":nodes}
	var output = FileAccess.open("res://builds/design-"+file_name+".json",FileAccess.WRITE)
	if output!=null: output.store_string(JSON.stringify(source,"\t"))

static func rectangle(value: Rect2) -> Array:
	return [value.position.x,value.position.y,value.size.x,value.size.y]

static func collect(node: Node,clip: Rect2,result: Array) -> void:
	if node is CanvasItem and not node.is_visible_in_tree(): return
	var next_clip = clip
	if node is Control:
		var bounds = node.get_global_rect()
		if not clip.intersects(bounds): return
		var record = {"bounds":rectangle(bounds),"clip":rectangle(clip),"name":str(node.name)}
		if node is PanelContainer or node is Button:
			var style = node.get_theme_stylebox("panel" if node is PanelContainer else ("disabled" if node.disabled else "normal"))
			record.role = "button" if node is Button else "panel"
			if style is StyleBoxTexture:
				record.skin = style.texture.resource_path
			elif style is StyleBoxFlat:
				record.color = "#"+style.bg_color.to_html(false)
				record.border = "#"+style.border_color.to_html(false)
			else: record.role = "group"
			if node is Button:
				record.disabled = node.disabled
				record.text = node.text
				record.fontSize = node.get_theme_font_size("font_size")
				record.colorText = "#"+node.get_theme_color("font_disabled_color" if node.disabled else "font_color").to_html(false)
				record.icon = node.icon.resource_path if node.icon!=null else ""
		elif node is Label:
			record.role = "text"
			record.text = node.text
			record.fontSize = node.get_theme_font_size("font_size")
			record.font = node.get_theme_font("font").get_font_name()
			record.color = "#"+node.get_theme_color("font_color").to_html(false)
			record.align = node.horizontal_alignment
		elif node is TextureRect and node.texture!=null and not node.texture.resource_path.is_empty():
			record.role = "art"
			record.source = node.texture.resource_path
			record.tint = "#"+node.modulate.to_html(false)
		elif node is LineEdit or node is TextEdit:
			record.role = "field"
			record.text = node.text if not node.text.is_empty() else node.placeholder_text
			if node is LineEdit and node.secret and not node.text.is_empty(): record.text = "••••••••••"
			record.fontSize = node.get_theme_font_size("font_size")
		elif node is ProgressBar or node is Slider:
			record.role = "progress" if node is ProgressBar else "slider"
			record.progress = (node.value-node.min_value)/maxf(1.0,node.max_value-node.min_value)
		elif node.get_script()!=null and str(node.get_script().resource_path).ends_with("clan_region_map.gd"):
			record.role = "clan_region"
			record.group = node.group
			record.playerId = node.player_id
		if record.has("role"): result.append(record)
		if node.clip_contents or node is ScrollContainer: next_clip = clip.intersection(bounds)
	for child in node.get_children(): collect(child,next_clip,result)
