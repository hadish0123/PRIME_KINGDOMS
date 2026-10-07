extends SceneTree

func _initialize() -> void:
	var path := "res://scripts/kingdom_panel.gd"
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(path)
	var error := script.reload()
	print("KINGDOM_PANEL_PARSE result=",error)
	quit(0 if error == OK else 1)
