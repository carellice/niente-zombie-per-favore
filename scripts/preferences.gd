extends Node
## Device settings live separately from the colony, so a new game keeps them.

signal changed

var settings_path: String = "user://preferences.cfg"
var master_volume: float = 0.85
var effects_volume: float = 0.8
var music_volume: float = 0.2
var sound_enabled: bool = true
var screen_shake: bool = true
var reduced_motion: bool = false
var fullscreen: bool = false
var interface_size: String = "compact"
var android_high_refresh: bool = true

func _ready() -> void:
	load_settings()

func snapshot() -> Dictionary:
	return {
		"master_volume":master_volume, "effects_volume":effects_volume,
		"music_volume":music_volume, "sound_enabled":sound_enabled,
		"screen_shake":screen_shake, "fullscreen":fullscreen,
		"interface_size":interface_size, "reduced_motion":reduced_motion,
		"android_high_refresh":android_high_refresh
	}

func apply_settings(values: Dictionary, persist: bool = true) -> void:
	master_volume = clampf(float(values.get("master_volume",master_volume)),0.0,1.0)
	effects_volume = clampf(float(values.get("effects_volume",effects_volume)),0.0,1.0)
	music_volume = clampf(float(values.get("music_volume",music_volume)),0.0,1.0)
	sound_enabled = bool(values.get("sound_enabled",sound_enabled))
	screen_shake = bool(values.get("screen_shake",screen_shake))
	reduced_motion = bool(values.get("reduced_motion",reduced_motion))
	android_high_refresh = bool(values.get("android_high_refresh",android_high_refresh))
	fullscreen = bool(values.get("fullscreen",fullscreen))
	var requested_size: String = str(values.get("interface_size",interface_size))
	interface_size = requested_size if requested_size in ["compact","medium","large"] else "compact"
	if persist:
		save_settings()
	changed.emit()

func save_settings() -> Error:
	var config: ConfigFile = ConfigFile.new()
	for key: String in snapshot():
		config.set_value("preferences",key,snapshot()[key])
	return config.save(settings_path)

func load_settings() -> Error:
	var config: ConfigFile = ConfigFile.new()
	var result: Error = config.load(settings_path)
	if result != OK:
		return result
	var values: Dictionary = {}
	for key: String in snapshot():
		values[key] = config.get_value("preferences",key,snapshot()[key])
	apply_settings(values,false)
	return OK
