extends Node
## Keep render pacing independent of the 60 Hz physics and elapsed-time gameplay.

const ANDROID_FRAME_RATE = preload("res://scripts/android_frame_rate.gd")
const RETRY_DELAYS: Array[float] = [0.25,0.5,1.0,2.0]
var android: bool = OS.has_feature("android")
var bridge: RefCounted = ANDROID_FRAME_RATE.new()
var requested_fps: int = 0
var last_result: Dictionary = {}
var _generation: int = 0
var _foreground: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not android: return
	get_node("/root/Preferences").changed.connect(_preferences_changed)
	get_tree().root.size_changed.connect(_surface_changed)
	_preferences_changed.call_deferred()

func _preferences_changed() -> void:
	if not android: return
	var target: int = 120 if get_node("/root/Preferences").android_high_refresh else 60
	if target==requested_fps: return
	requested_fps = target
	if _foreground: _apply()

func _surface_changed() -> void:
	if android and _foreground and requested_fps>0: _apply()

func _notification(what: int) -> void:
	if not android or not is_inside_tree(): return
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		_foreground = false
		_generation += 1 # Invalidate callbacks/retries from the previous Surface.
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]:
		_foreground = true
		if requested_fps>0: _apply.call_deferred()

func _apply() -> void:
	if not android or not _foreground: return
	_generation += 1
	# VSync caps lower-refresh panels naturally; the display hint allows 90/120 Hz.
	Engine.max_fps = requested_fps
	if DisplayServer.get_name()!="headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	_request(_generation,0)

func _request(generation: int, attempt: int) -> void:
	if generation!=_generation or not _foreground or not android: return
	bridge.request(requested_fps,_completed.bind(generation,attempt))

func _completed(result: Dictionary, generation: int, attempt: int) -> void:
	if generation!=_generation or not _foreground: return
	last_result = result
	if bool(result.get("ok",false)) or not bool(result.get("retry",false)) or attempt>=RETRY_DELAYS.size(): return
	# Surface creation may trail startup/resume. Retry briefly, never poll per frame
	# or fight Android when battery/thermal policy chooses a lower refresh rate.
	await get_tree().create_timer(RETRY_DELAYS[attempt],true,false,true).timeout
	_request(generation,attempt+1)
