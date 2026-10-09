extends Node3D

const GAMEPLAY_MESH_PREFIXES := [
    "PK_Town_Castle",
    "PK_Town_Market",
    "PK_Town_Academy",
    "PK_Town_Blacksmith",
    "PK_Town_Warehouse",
    "PK_Town_Stable",
    "PK_Town_Windmill",
    "PK_Town_Farm",
    "PK_Town_Lumber",
    "PK_Town_Quarry",
    "PK_Town_Wall_",
    "PK_Town_Gate",
    "PK_Town_Watchtower"
]

func _is_gameplay_mesh(text: String) -> bool:
    for prefix in GAMEPLAY_MESH_PREFIXES:
        if text.begins_with(prefix):
            return true
    return false

func _ready() -> void:
    _configure_lods(self)

func _configure_lods(node: Node) -> void:
    if node is MeshInstance3D:
        var level: int = -1
        var text: String = str(node.name)
        if _is_gameplay_mesh(text):
            node.visible = false
            return
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
