extends SceneTree
## Real scheduler: humans stay silent; visible zombies respect pause and volume.
const Voices = preload("res://scripts/character_voices.gd")

class TestView extends Control:
	var in_main_menu: bool = false
	var ui: Dictionary = {"panel_kind":"", "panel_id":-1}
	var camera_x: float = 0.0
	var zoom: float = 1.0
	func _sx(world_x: float) -> float:
		return (world_x - camera_x) * zoom

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)

func run() -> void:
	var game: Node = root.get_node("Game")
	var preferences: Node = root.get_node("Preferences")
	game.set_process(false)
	game.save_path = "res://.runtime/character-ambience-save.json"
	game.paused = true
	game.threats.assign([{"id":201, "kind":"walker", "x":-150.0, "hp":50.0}, {"id":202, "kind":"brute", "x":230.0, "hp":50.0}, {"id":203, "kind":"runner", "x":1250.0, "hp":50.0}])
	game.visitors.assign([{"id":401, "x":420.0, "citizen":{"look":1}}])
	game.citizens.assign([{"id":301, "x":610.0, "look":0, "away":false, "guard":false}])
	var original_settings: Dictionary = preferences.snapshot()
	preferences.apply_settings({"sound_enabled":true, "effects_volume":0.8, "master_volume":0.85}, false)
	var view: TestView = TestView.new()
	view.size = Vector2(1000.0, 700.0)
	root.add_child(view)
	var ambience: Node = load("res://scripts/character_ambience.gd").new()
	view.add_child(ambience)
	ambience.setup(view)
	ambience.set_process(false)
	expect(ambience.zombie_player != null and ambience.civilian_player == null, "Only the zombie player is created")
	var zombies: Array[Dictionary] = ambience.ambient_candidates("zombie")
	expect(zombies.size() == 1 and zombies[0].id == 202, "Only the visible living threat is eligible")
	expect(ambience.ambient_candidates("civilian").is_empty(), "Visible residents and waiting survivors remain silent")
	for look: int in range(20):
		expect(Voices.civilian_count(look) == 0 and Voices.civilian(look, 3) == null, "Human bank disabled for appearance " + str(look))
	var human: Dictionary = {"kind":"civilian", "id":401, "look":1, "world_x":420.0}
	expect(not ambience._try_play(human, true), "Legacy greeting requests stay silent")
	view.camera_x = 1000.0
	var moved: Array[Dictionary] = ambience.ambient_candidates("zombie")
	expect(moved.size() == 1 and moved[0].id == 203, "Camera changes zombie candidates")
	view.camera_x = 0.0
	var zombie: Dictionary = zombies[0]
	view.in_main_menu = true
	expect(not ambience._try_play(zombie), "Title menu blocks groans")
	view.in_main_menu = false
	expect(not ambience._try_play(zombie), "Pause blocks groans")
	game.paused = false
	preferences.apply_settings({"sound_enabled":false}, false)
	expect(not ambience._try_play(zombie), "Mute blocks groans")
	preferences.apply_settings({"sound_enabled":true, "effects_volume":0.0}, false)
	expect(not ambience._try_play(zombie), "Zero effects volume blocks groans")
	preferences.apply_settings({"effects_volume":0.8, "master_volume":0.0}, false)
	expect(not ambience._try_play(zombie), "Zero master volume blocks groans")
	preferences.apply_settings({"master_volume":0.85}, false)
	expect(ambience._try_play(zombie), "Eligible zombie plays its recording")
	expect(ambience.voice_count == 1 and ambience.last_voice.kind == "zombie", "One real diagnostic event")
	expect(ambience.zombie_player.stream == Voices.zombie("brute", int(ambience.last_voice.variant)), "Brute uses actual bank variant")
	var old_volume: float = ambience.zombie_player.volume_db
	preferences.apply_settings({"effects_volume":0.4}, false)
	expect(ambience.zombie_player.volume_db < old_volume - 5.9, "Effects volume reaches active recording")
	game.shot_fired.emit(202, 34.0)
	expect(not ambience._is_playing(), "Gunfire interrupts groans")
	expect(not ambience._try_play(zombie), "Gunfire keeps initial attack clear")
	game.paused = true
	view.ui = {"panel_kind":"visitor", "panel_id":401}
	var before_admission: int = ambience.voice_count
	for index: int in range(3):
		ambience.on_panel_changed(true)
		ambience._process(10.0)
	expect(ambience.voice_count == before_admission and not ambience._is_playing(), "Repeated admission stays silent")
	game.paused = false
	ambience._clock += 10.0
	expect(ambience._try_play(zombie), "Zombie restarts after pause")
	view.camera_x = 1000.0
	ambience._process(0.0)
	expect(not ambience._is_playing(), "Panning actor off-screen stops groan")
	view.camera_x = 0.0
	ambience._clock += 10.0
	expect(ambience._try_play(zombie), "Zombie restarts for mute check")
	preferences.apply_settings({"sound_enabled":false}, false)
	expect(not ambience._is_playing(), "Mute stops playing voice immediately")
	preferences.apply_settings({"sound_enabled":true}, false)
	ambience._clock += 10.0
	ambience._zombie_due = ambience._clock
	ambience._process(0.0)
	expect(ambience._zombie_due - ambience._clock >= 6.0 and ambience._zombie_due - ambience._clock <= 11.0, "Sparse six-to-eleven-second cadence")
	var old_variant: int = int(ambience.last_voice.variant)
	ambience._stop_voice()
	ambience._clock += 10.0
	expect(ambience._try_play(zombie) and int(ambience.last_voice.variant) != old_variant, "Consecutive variants differ")
	view.in_main_menu = true
	ambience._process(0.0)
	expect(not ambience._is_playing(), "Returning to title stops active audio")
	ambience.queue_free()
	await process_frame
	preferences.apply_settings(original_settings, false)
	view.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("CHARACTER AMBIENCE: ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)
