extends Node
## The complete supplied zombie recording, with overlapping tails instead of a hard loop.
## Only living zombies in the current view contribute; survivors never trigger this bed.

const STREAM_PATH: String = "res://assets/audio/user/zombie.ogg"
const BASE_VOLUME_DB: float = -9.0
const FADE_SECONDS: float = 0.4
const VISIBLE_MARGIN: float = 20.0

# Public diagnostics and injection points used by the audio integration checks.
var players: Array[AudioStreamPlayer] = []
var stream_override: AudioStream
var crossfade_seconds: float = 2.5
var use_audio_clock: bool = true
var active_index: int = 0
var crossfade_progress: float = -1.0
var audibility: float = 0.0
var duck_gain: float = 1.0
var completed_crossfades: int = 0
var playback_generation: int = 0

var _view: Control
var _stream: AudioStream
var _length: float = 0.0
var _positions: Array[float] = [0.0, 0.0]
var _overlap_elapsed: float = 0.0
var _duck_hold: float = 0.0
var _visible_count: int = 0
var _running: bool = false
var _suspended: bool = false
var _recover_gain: float = 1.0

func setup(view: Control) -> void:
	_view = view
	if not players.is_empty():
		return
	_stream = stream_override
	if _stream == null and ResourceLoader.exists(STREAM_PATH):
		_stream = load(STREAM_PATH) as AudioStream
	if _stream != null:
		# Never let the decoder restart on its own: both ends are mixed explicitly.
		_stream = _stream.duplicate(true) as AudioStream
		if _stream is AudioStreamWAV:
			(_stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
		elif _stream is AudioStreamOggVorbis:
			(_stream as AudioStreamOggVorbis).loop = false
		elif _stream is AudioStreamMP3:
			(_stream as AudioStreamMP3).loop = false
		_length = _stream.get_length()
	for index: int in range(2):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "ZombieBed" + str(index + 1)
		player.stream = _stream
		player.volume_db = -100.0
		add_child(player)
		players.append(player)
		player.finished.connect(_on_finished.bind(index))
	if not Game.shot_fired.is_connected(_on_shot_fired):
		Game.shot_fired.connect(_on_shot_fired)

func _process(delta: float) -> void:
	if players.size() != 2 or _stream == null or _length <= 0.0:
		return
	delta = maxf(delta, 0.0)
	var available: bool = _sound_available()
	_visible_count = visible_zombie_count() if available else 0
	var wanted: bool = available and _visible_count > 0
	var paused: bool = Game.paused
	for player: AudioStreamPlayer in players:
		player.stream_paused = paused
	if wanted:
		if not _running and not paused:
			_start_recording()
		audibility = move_toward(audibility, 1.0, delta / FADE_SECONDS)
	else:
		audibility = move_toward(audibility, 0.0, delta / FADE_SECONDS)
		if audibility <= 0.0:
			_stop_recording()
	if _running and not paused:
		_advance_recording(delta)
		_duck_hold = maxf(0.0, _duck_hold - delta)
		var duck_target: float = 0.3 if _duck_hold > 0.0 else 1.0
		duck_gain = lerpf(duck_gain, duck_target, 1.0 - exp(-delta * (45.0 if duck_target < duck_gain else 9.0)))
		_recover_gain = move_toward(_recover_gain, 1.0, delta / 0.18)
	_update_mix()

func _sound_available() -> bool:
	return is_instance_valid(_view) and not bool(_view.get("in_main_menu")) and Preferences.sound_enabled and Preferences.effects_volume > 0.001 and Preferences.master_volume > 0.001

func visible_zombie_count() -> int:
	if not is_instance_valid(_view) or _view.size.x < VISIBLE_MARGIN * 2.0:
		return 0
	var count: int = 0
	for enemy: Dictionary in Game.threats:
		if float(enemy.get("hp", 0.0)) <= 0.0:
			continue
		var screen_x: float = float(_view.call("_sx", float(enemy.get("x", -100000.0))))
		if screen_x >= -VISIBLE_MARGIN and screen_x <= _view.size.x + VISIBLE_MARGIN:
			count += 1
	return count

func on_panel_changed(_opened: bool) -> void:
	# Pausing freezes both decoder positions and the blend clock. Reopening a
	# dialog never calls play(), so a succession of clicks cannot restart voices.
	for player: AudioStreamPlayer in players:
		player.stream_paused = Game.paused

func reset() -> void:
	_stop_recording(true)
	duck_gain = 1.0
	_duck_hold = 0.0
	_visible_count = 0
	audibility = 0.0
	_update_mix()

func _overlap_duration() -> float:
	# Short injected fixtures also need enough uncontested recording to play.
	return clampf(crossfade_seconds, 0.02, maxf(0.02, _length * 0.4))

func _start_recording() -> void:
	_running = true
	_recover_gain = 1.0
	if not _suspended:
		active_index = 0
		crossfade_progress = -1.0
		_overlap_elapsed = 0.0
		_positions = [0.0, 0.0]
	players[active_index].volume_db = -100.0
	players[active_index].stream_paused = false
	players[active_index].play(_positions[active_index])
	if _suspended and crossfade_progress >= 0.0:
		var incoming: int = 1 - active_index
		players[incoming].volume_db = -100.0
		players[incoming].stream_paused = false
		players[incoming].play(_positions[incoming])
	_suspended = false
	playback_generation += 1

func _advance_recording(delta: float) -> void:
	for index: int in range(2):
		if players[index].playing:
			_positions[index] += delta
			if use_audio_clock:
				_positions[index] = maxf(0.0, players[index].get_playback_position() + AudioServer.get_time_since_last_mix())
	var overlap: float = _overlap_duration()
	if crossfade_progress < 0.0:
		if _positions[active_index] >= _length - overlap:
			_start_overlap()
	elif crossfade_progress >= 0.0:
		_overlap_elapsed += delta
		if use_audio_clock:
			_overlap_elapsed = _positions[1 - active_index]
		crossfade_progress = clampf(_overlap_elapsed / overlap, 0.0, 1.0)
		if crossfade_progress >= 1.0:
			_finish_overlap()

func _start_overlap() -> void:
	var incoming: int = 1 - active_index
	players[incoming].volume_db = -100.0
	players[incoming].stream_paused = false
	players[incoming].play()
	_positions[incoming] = 0.0
	_overlap_elapsed = 0.0
	crossfade_progress = 0.0

func _finish_overlap() -> void:
	players[active_index].stop()
	_positions[active_index] = 0.0
	active_index = 1 - active_index
	crossfade_progress = -1.0
	_overlap_elapsed = 0.0
	completed_crossfades += 1

func channel_gains() -> Vector2:
	if not _running:
		return Vector2.ZERO
	var outgoing: float = 1.0
	var incoming: float = 0.0
	if crossfade_progress >= 0.0:
		outgoing = cos(crossfade_progress * PI * 0.5)
		incoming = sin(crossfade_progress * PI * 0.5)
	return Vector2(outgoing, incoming) if active_index == 0 else Vector2(incoming, outgoing)

func _update_mix() -> void:
	var gains: Vector2 = channel_gains()
	var crowd_gain: float = 1.0 + minf(maxi(_visible_count - 1, 0), 4) * 0.06
	var base_gain: float = db_to_linear(BASE_VOLUME_DB) * Preferences.effects_volume * audibility * duck_gain * crowd_gain * _recover_gain
	for index: int in range(players.size()):
		players[index].volume_db = linear_to_db(maxf(0.00001, base_gain * gains[index]))

func _on_shot_fired(_threat_id: int, _damage: float) -> void:
	_duck_hold = 0.28

func _on_finished(index: int) -> void:
	if not _running:
		return
	if index == active_index and crossfade_progress >= 0.0:
		# If the decoder finishes a frame early, the incoming stream already
		# contains the next passage and must continue from its current position.
		_finish_overlap()
	elif index == active_index:
		# A late frame/device interruption can miss the overlap window. Recover
		# softly rather than asking the decoder to hard-loop the recording.
		active_index = 1 - active_index
		_positions[active_index] = 0.0
		_recover_gain = 0.0
		players[active_index].volume_db = -100.0
		players[active_index].play()

func _stop_recording(clear_position: bool = false) -> void:
	# Keep both cursors and any overlap through a trip to town/menu or mute.
	# Otherwise each group of zombies would repeat the same opening groans.
	if _running:
		if use_audio_clock:
			for index: int in range(players.size()):
				if players[index].playing:
					_positions[index] = clampf(players[index].get_playback_position(), 0.0, _length)
		_suspended = true
	for player: AudioStreamPlayer in players:
		player.stop()
		player.stream_paused = false
	_running = false
	if clear_position:
		_suspended = false
		crossfade_progress = -1.0
		_overlap_elapsed = 0.0
		_positions = [0.0, 0.0]

func _exit_tree() -> void:
	_stop_recording(true)
	for player: AudioStreamPlayer in players:
		player.stream = null
