extends SceneTree

var Soundscape: GDScript

class TestView extends Control:
	var in_main_menu: bool = false
	var camera_x: float = 0.0
	func _sx(world_x: float) -> float:
		return world_x - camera_x

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func fixture(seconds: float) -> AudioStreamWAV:
	var result: AudioStreamWAV = AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = 22050
	result.stereo = false
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(roundi(seconds * result.mix_rate) * 2)
	result.data = pcm
	# Injection must actively disable decoder loops as well as the real asset's.
	result.loop_mode = AudioStreamWAV.LOOP_FORWARD
	result.loop_end = pcm.size() / 2
	return result

func run() -> void:
	Soundscape = load("res://scripts/zombie_soundscape.gd") as GDScript
	var supplied_stream: AudioStream = load("res://assets/audio/user/zombie.ogg") as AudioStream
	expect(supplied_stream is AudioStreamOggVorbis, "The supplied zombie recording is imported as a streamable Ogg asset")
	expect(supplied_stream.get_length() > 90.0 and supplied_stream.get_length() < 94.0, "The full mixed groans recording is retained, with only terminal silence removed")
	expect(not supplied_stream.loop, "The supplied recording is not decoder-looped")
	var game: Node = root.get_node("Game")
	var preferences: Node = root.get_node("Preferences")
	game.set_process(false)
	game.save_path = "user://test-zombie-bed-isolated.json"
	game.paused = false
	var original_settings: Dictionary = preferences.snapshot()
	preferences.apply_settings({"sound_enabled":true, "effects_volume":0.8, "master_volume":0.85}, false)
	game.threats.assign([
		{"id":1, "kind":"walker", "x":300.0, "hp":100.0},
		{"id":2, "kind":"runner", "x":-100.0, "hp":100.0},
		{"id":3, "kind":"brute", "x":1300.0, "hp":100.0},
		{"id":4, "kind":"walker", "x":450.0, "hp":0.0}
	])
	game.visitors.assign([{"id":10, "x":500.0, "citizen":{"look":1}}])
	game.citizens.assign([{"id":11, "x":600.0, "look":0, "away":false, "guard":false}])
	var view: TestView = TestView.new()
	view.size = Vector2(1000.0, 700.0)
	root.add_child(view)
	var bed: Node = Soundscape.new()
	bed.stream_override = fixture(4.0)
	bed.crossfade_seconds = 0.4
	bed.use_audio_clock = false
	view.add_child(bed)
	bed.setup(view)
	bed.set_process(false)
	expect(bed.players.size() == 2, "The full recording has exactly two decoder players")
	expect(bed.players[0].stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Decoder hard loops are disabled")
	expect(bed.visible_zombie_count() == 1, "Only the visible living zombie counts; people and distant threats do not")
	expect(not bed.players[0].playing and not bed.players[1].playing, "Setup does not start stray menu audio")
	bed._process(0.1)
	expect(bed.playback_generation == 1 and bed.players[0].playing, "A visible zombie starts the complete recording once")
	expect(is_equal_approx(bed.audibility, 0.25), "Recording enters with a 400 ms fade")
	bed._process(0.4)
	expect(is_equal_approx(bed.audibility, 1.0), "Initial fade reaches full ambience gain")
	var position_before_panel: float = bed._positions[bed.active_index]
	for index: int in range(4):
		bed.on_panel_changed(true)
		bed.on_panel_changed(false)
	expect(bed.playback_generation == 1 and bed._positions[bed.active_index] == position_before_panel, "Dialog clicks never restart or seek the recording")
	game.paused = true
	bed.on_panel_changed(true)
	bed._process(2.0)
	expect(bed._positions[bed.active_index] == position_before_panel, "Pause freezes the playback clock")
	expect(bed.players[0].stream_paused, "Pause freezes the active decoder")
	game.paused = false
	bed.on_panel_changed(false)
	bed._positions[bed.active_index] = 3.55
	bed._process(0.1)
	expect(is_equal_approx(bed.crossfade_progress, 0.0), "Incoming recording starts before the final tail ends")
	expect(bed.players[0].playing and bed.players[1].playing, "The end and beginning genuinely overlap")
	bed._process(0.2)
	var halfway: Vector2 = bed.channel_gains()
	expect(absf(halfway.x - sqrt(0.5)) < 0.001 and absf(halfway.y - sqrt(0.5)) < 0.001, "Halfway gains follow an equal power curve")
	game.paused = true
	bed.on_panel_changed(true)
	var old_progress: float = bed.crossfade_progress
	var old_position: float = bed._positions[1]
	bed._process(2.0)
	expect(bed.crossfade_progress == old_progress and bed._positions[1] == old_position, "Pausing during the crossfade freezes both blend and incoming cursor")
	game.paused = false
	bed.on_panel_changed(false)
	bed._process(0.2)
	expect(bed.completed_crossfades == 1 and bed.active_index == 1 and bed.crossfade_progress < 0.0, "Completion swaps decoders once")
	expect(not bed.players[0].playing and bed.players[1].playing, "Outgoing recording stops while the incoming recording continues")
	expect(absf(bed._positions[1] - 0.4) < 0.001, "New active stream retains the already played overlapping passage")
	for loop_index: int in range(8):
		bed._positions[bed.active_index] = 3.65
		bed._process(0.0)
		for step: int in range(4):
			bed._process(0.1)
			var gains: Vector2 = bed.channel_gains()
			expect(absf(gains.length_squared() - 1.0) < 0.001, "No amplitude hole while repeating crossfade " + str(loop_index))
	expect(bed.completed_crossfades == 9, "Multiple loops use the same seamless decoder handover")
	game.shot_fired.emit(1, 68.0)
	bed._process(0.04)
	expect(bed.duck_gain > 0.3 and bed.duck_gain < 0.5, "Gunshot ducks the background smoothly instead of stopping it")
	expect(bed.playback_generation == 1, "Weapon fire never restarts the zombie recording")
	bed._process(0.7)
	expect(bed.duck_gain > 0.99, "Zombie background recovers smoothly after gunshot priority")
	var initial_db: float = bed.players[bed.active_index].volume_db
	preferences.apply_settings({"effects_volume":0.4}, false)
	bed._process(0.0)
	expect(absf(bed.players[bed.active_index].volume_db - initial_db + 6.0206) < 0.02, "Effects slider adjusts the whole recording once")
	initial_db = bed.players[bed.active_index].volume_db
	preferences.apply_settings({"master_volume":0.4}, false)
	bed._process(0.0)
	expect(is_equal_approx(initial_db, bed.players[bed.active_index].volume_db), "Master gain is left to the shared mixer and is not applied twice")
	view.camera_x = 2000.0
	bed._process(0.1)
	expect(bed.audibility > 0.0 and bed.players[bed.active_index].playing, "Panning to town fades the zombie bed without an abrupt stop")
	view.camera_x = 0.0
	bed._process(0.1)
	expect(bed.playback_generation == 1, "Returning during the short fade preserves the current recording phase")
	view.in_main_menu = true
	bed._process(0.1)
	expect(bed.audibility > 0.0, "Return to menu also uses a short fade")
	bed._process(0.4)
	expect(not bed.players[0].playing and not bed.players[1].playing and bed.audibility == 0.0, "After menu fade both decoders stop fully")
	var suspended_positions: Array = bed._positions.duplicate()
	var suspended_active: int = bed.active_index
	var suspended_overlap: float = bed.crossfade_progress
	view.in_main_menu = false
	bed._process(0.0)
	expect(bed.playback_generation == 2, "Returning to a visible battle can start the bed again")
	expect(bed.active_index == suspended_active and bed._positions == suspended_positions and bed.crossfade_progress == suspended_overlap, "Returning after a full stop resumes the saved passage and overlap instead of repeating the introduction")
	bed._process(0.4)
	preferences.apply_settings({"sound_enabled":false}, false)
	bed._process(0.5)
	expect(not bed.players[0].playing and not bed.players[1].playing, "Muted audio stops both decoders after fade")
	preferences.apply_settings({"sound_enabled":true}, false)
	bed._process(0.4)
	game.threats.clear()
	bed._process(0.5)
	expect(not bed.players[0].playing and bed.visible_zombie_count() == 0, "Waiting visitors and resident citizens never sustain zombie audio")
	bed.reset()
	expect(bed.crossfade_progress < 0.0 and bed.audibility == 0.0 and bed.duck_gain == 1.0, "A new game clears playback and temporary battle state")
	bed.queue_free()
	await process_frame
	# The native run also verifies real-time decoder handovers and pause positions.
	if DisplayServer.get_name() != "headless":
		await native_decoder_check(view, game)
	view.queue_free()
	preferences.apply_settings(original_settings, false)
	await process_frame
	await create_timer(0.15).timeout
	print("ZOMBIE SOUNDSCAPE: ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)

func native_decoder_check(view: TestView, game: Node) -> void:
	game.paused = false
	game.threats.assign([{"id":1, "kind":"brute", "x":400.0, "hp":100.0}])
	var bed: Node = Soundscape.new()
	bed.stream_override = fixture(1.4)
	bed.crossfade_seconds = 0.3
	view.add_child(bed)
	bed.setup(view)
	await create_timer(1.25).timeout
	expect(bed.crossfade_progress >= 0.0 and bed.players[0].playing and bed.players[1].playing, "Native decoders enter overlap before EOF")
	game.paused = true
	bed.on_panel_changed(true)
	var progress: float = bed.crossfade_progress
	var position: float = bed.players[1].get_playback_position()
	await create_timer(0.35).timeout
	expect(bed.crossfade_progress == progress and absf(bed.players[1].get_playback_position() - position) < 0.03, "Native paused decoder and blend clock retain their phase")
	game.paused = false
	bed.on_panel_changed(false)
	await create_timer(1.6).timeout
	expect(bed.completed_crossfades >= 2 and bed.playback_generation == 1, "Native decoder completes repeated overlaps without hard restarts")
	bed.reset()
	expect(not bed.players[0].playing and not bed.players[1].playing, "Native reset releases playback voices")
	bed.queue_free()
	await process_frame
	var real_bed: Node = Soundscape.new()
	view.add_child(real_bed)
	real_bed.setup(view)
	await create_timer(0.45).timeout
	real_bed.players[0].seek(real_bed._length - 2.9)
	await create_timer(0.9).timeout
	expect(real_bed.crossfade_progress > 0.0 and real_bed.players[0].playing and real_bed.players[1].playing, "The real 92 second Ogg tail overlaps its beginning before EOF")
	await create_timer(2.3).timeout
	expect(real_bed.completed_crossfades == 1 and real_bed.players[1].playing and not real_bed.players[0].playing, "The real user recording completes its seamless handover")
	expect(real_bed.players[1].get_playback_position() > 2.5, "Real incoming recording continues after its overlapping beginning without replaying it")
	view.camera_x = 2000.0
	await create_timer(0.5).timeout
	expect(not real_bed.players[0].playing and not real_bed.players[1].playing, "Native trip to town releases both full-length decoders after fading")
	var saved_cursor: float = real_bed._positions[real_bed.active_index]
	view.camera_x = 0.0
	await create_timer(0.3).timeout
	var resumed_cursor: float = real_bed.players[real_bed.active_index].get_playback_position()
	expect(resumed_cursor >= saved_cursor - 0.04 and resumed_cursor < saved_cursor + 0.5, "Native return to battle resumes the saved recording cursor")
	real_bed.reset()
	real_bed.queue_free()
	await process_frame
