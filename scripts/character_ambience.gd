extends Node
## Sparse, visible zombie groans. Survivors and admission dialogs stay silent.

signal voice_started(kind: String, look: int, world_x: float)

const Voices = preload("res://scripts/character_voices.gd")
const SHARED_GAP: float = 2.5
const VISIBLE_MARGIN: float = 35.0

var last_voice: Dictionary = {}
var voice_count: int = 0
var zombie_player: AudioStreamPlayer
# Kept as a silent diagnostic/API slot; no survivor player is created.
var civilian_player: AudioStreamPlayer
var _view: Control
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _clock: float = 0.0
var _zombie_due: float = 6.0
var _next_allowed: float = 0.0
var _shot_quiet_until: float = 0.0
var _active: Dictionary = {}
var _variants: Dictionary = {}

func setup(view: Control) -> void:
	_view = view
	_rng.randomize()
	_zombie_due = _clock + _rng.randf_range(4.0, 7.0)
	if zombie_player == null:
		zombie_player = AudioStreamPlayer.new()
		zombie_player.name = "ZombieVoice"
		add_child(zombie_player)
		zombie_player.finished.connect(_on_voice_finished)
	if not Game.shot_fired.is_connected(_on_shot_fired):
		Game.shot_fired.connect(_on_shot_fired)
	if not Preferences.changed.is_connected(_on_preferences_changed):
		Preferences.changed.connect(_on_preferences_changed)

func _process(delta: float) -> void:
	_clock += delta
	if not _sound_available() or Game.paused:
		_stop_voice()
		_zombie_due = maxf(_zombie_due, _clock + 2.0)
		return
	if not _active.is_empty():
		var fresh: Dictionary = _refresh_candidate(_active)
		if fresh.is_empty():
			_stop_voice()
		else:
			_active.world_x = fresh.world_x
			_update_active_volume()
	if _clock < _next_allowed or _is_playing() or _clock < _zombie_due:
		return
	var zombies: Array[Dictionary] = ambient_candidates("zombie")
	_zombie_due = _clock + _rng.randf_range(6.0, 11.0) if not zombies.is_empty() else _clock + 2.0
	if not zombies.is_empty():
		_try_play(zombies[_rng.randi_range(0, zombies.size() - 1)])

func _sound_available() -> bool:
	return is_instance_valid(_view) and not bool(_view.get("in_main_menu")) and Preferences.sound_enabled and Preferences.effects_volume > 0.001 and Preferences.master_volume > 0.001

func _visible(world_x: float) -> bool:
	if not is_instance_valid(_view) or _view.size.x < VISIBLE_MARGIN * 2.0:
		return false
	var screen_x: float = float(_view.call("_sx", world_x))
	return screen_x >= VISIBLE_MARGIN and screen_x <= _view.size.x - VISIBLE_MARGIN

func ambient_candidates(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if kind != "zombie" or not is_instance_valid(_view):
		return result
	for enemy: Dictionary in Game.threats:
		var x: float = float(enemy.x)
		if float(enemy.get("hp", 1.0)) > 0.0 and _visible(x):
			var voice_kind: String = str(enemy.kind) if str(enemy.kind) in ["walker", "runner", "brute"] else "walker"
			result.append({"kind":"zombie", "source":"zombie", "id":int(enemy.id), "look":0, "voice_kind":voice_kind, "world_x":x})
	return result

func _refresh_candidate(candidate: Dictionary) -> Dictionary:
	for current: Dictionary in ambient_candidates(str(candidate.get("kind", ""))):
		if int(current.id) == int(candidate.get("id", -1)):
			return current
	return {}

func on_panel_changed(_opened: bool) -> void:
	# Admission no longer triggers speech, including while the world is paused.
	if Game.paused:
		_stop_voice()

func _try_play(candidate: Dictionary, _greeting: bool = false) -> bool:
	if candidate.is_empty() or str(candidate.get("kind", "")) != "zombie":
		return false
	if not _sound_available() or Game.paused or zombie_player == null:
		return false
	if _clock < _next_allowed or _clock < _shot_quiet_until or _is_playing():
		return false
	var fresh: Dictionary = _refresh_candidate(candidate)
	if fresh.is_empty():
		return false
	var voice_key: String = str(fresh.get("voice_kind", "walker"))
	var count: int = Voices.zombie_count(voice_key)
	if count <= 0:
		return false
	var variant: int = _rng.randi_range(0, count - 1)
	if count > 1 and variant == int(_variants.get(voice_key, -1)):
		variant = (variant + 1) % count
	var stream: AudioStream = Voices.zombie(voice_key, variant)
	if stream == null:
		return false
	_active = fresh.duplicate(true)
	_active.base_db = -12.0
	zombie_player.stream = stream
	zombie_player.pitch_scale = _rng.randf_range(0.97, 1.03)
	_update_active_volume()
	zombie_player.play()
	_variants[voice_key] = variant
	_next_allowed = _clock + maxf(SHARED_GAP, stream.get_length() / zombie_player.pitch_scale + 1.0)
	last_voice = _active.duplicate(true)
	last_voice.variant = variant
	voice_count += 1
	voice_started.emit("zombie", 0, float(fresh.world_x))
	return true

func _is_playing() -> bool:
	return zombie_player != null and zombie_player.playing

func _update_active_volume() -> void:
	if _active.is_empty() or not is_instance_valid(_view):
		return
	var screen_x: float = float(_view.call("_sx", float(_active.world_x)))
	var distance: float = absf(screen_x - _view.size.x * 0.5) / maxf(_view.size.x * 0.5, 1.0)
	zombie_player.volume_db = float(_active.base_db) + linear_to_db(maxf(Preferences.effects_volume, 0.0001)) - distance * 4.0

func _on_voice_finished() -> void:
	if not _is_playing():
		_active.clear()

func _on_shot_fired(_threat_id: int, _damage: float) -> void:
	_stop_voice()
	_shot_quiet_until = _clock + 0.75
	_next_allowed = maxf(_next_allowed, _clock + SHARED_GAP)

func _on_preferences_changed() -> void:
	if not _sound_available():
		_stop_voice()
	else:
		_update_active_volume()

func _stop_voice() -> void:
	if zombie_player != null:
		zombie_player.stop()
	_active.clear()

func _exit_tree() -> void:
	_stop_voice()
	if zombie_player != null:
		zombie_player.stream = null
