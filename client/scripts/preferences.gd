extends RefCounted

const PROFILES = [
	{"name": "LOW", "fps": 30, "radius": 4, "distance": 320.0, "msaa": Viewport.MSAA_DISABLED, "shadows": false},
	{"name": "BALANCED", "fps": 60, "radius": 5, "distance": 480.0, "msaa": Viewport.MSAA_2X, "shadows": true},
	{"name": "HIGH", "fps": 60, "radius": 6, "distance": 720.0, "msaa": Viewport.MSAA_4X, "shadows": true},
	{"name": "ULTRA", "fps": 60, "radius": 6, "distance": 900.0, "msaa": Viewport.MSAA_8X, "shadows": true},
]
var quality: int = 1
var sensitivity: float = 1.0
var sound_volume: float = 0.7
var language: String = "en"
var path = "user://preferences.cfg"

func load_preferences() -> void:
	var config = ConfigFile.new()
	if config.load(path) != OK: return
	var saved_quality = config.get_value("graphics", "quality", 1)
	if saved_quality is int: quality = clampi(saved_quality, 0, 3)
	var saved_sensitivity = config.get_value("camera", "sensitivity", 1.0)
	if (saved_sensitivity is float or saved_sensitivity is int) and is_finite(float(saved_sensitivity)):
		sensitivity = clampf(float(saved_sensitivity), 0.5, 2.0)
	var volume = config.get_value("audio","volume",0.7)
	if (volume is float or volume is int) and is_finite(float(volume)): sound_volume = clampf(float(volume),0,1)
	language = str(config.get_value("language","locale","en"))
	if language != "en": language = "en"

func save() -> void:
	var config = ConfigFile.new()
	config.set_value("graphics", "quality", quality)
	config.set_value("camera", "sensitivity", sensitivity)
	config.set_value("audio","volume",sound_volume)
	config.set_value("language","locale",language)
	if config.save(path) != OK: push_warning("Settings could not be saved on this device.")

func apply(game: Node) -> void:
	var profile: Dictionary = PROFILES[quality]
	Engine.max_fps = profile.fps
	game.get_viewport().msaa_3d = profile.msaa
	game.sun.shadow_enabled = profile.shadows
	game.sun.directional_shadow_max_distance = 120.0 if quality == 1 else 180.0
	game.render_distance = profile.distance
	if is_instance_valid(game.terrain):
		game.terrain.set_radius(profile.radius)
		if game.terrain.nature: game.terrain.nature.set_quality(mini(quality,2))
	if game.in_world and is_instance_valid(game.kingdom_panel) and not game.kingdom_panel.kingdom.is_empty():
		game.update_garrison(game.kingdom_panel.kingdom)
