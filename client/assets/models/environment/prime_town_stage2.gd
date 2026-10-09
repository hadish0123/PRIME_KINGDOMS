extends Node3D

func _ready() -> void:
    _configure_lods(self)

func _configure_lods(node: Node) -> void:
    if node is MeshInstance3D:
        var level: int = -1
        var text: String = str(node.name)
        for i in range(4):
            if text.ends_with("_LOD" + str(i)):
                level = i
        if level >= 0:
            var bounds: Array[float] = [0.0, 60.0, 100.0, 150.0, 100000.0]
            node.visibility_range_begin = bounds[level]
            node.visibility_range_end = bounds[level + 1]
            node.visibility_range_begin_margin = 0.0
            node.visibility_range_end_margin = 0.0
            node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
            node.visible = true
    for child in node.get_children():
        _configure_lods(child)
