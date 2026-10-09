extends SceneTree

var failed = false
func _initialize() -> void:
	scan("res://scripts")
	scan("res://tests")
	quit(1 if failed else 0)

func scan(path: String) -> void:
	var directory = DirAccess.open(path)
	for file in directory.get_files():
		if not file.ends_with(".gd"): continue
		var script = load(path+"/"+file)
		if script==null or not script.can_instantiate():
			failed = true
			push_error("GDScript could not be loaded: "+path+"/"+file)
