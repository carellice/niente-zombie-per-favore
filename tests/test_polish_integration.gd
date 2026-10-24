extends SceneTree
## Real main-scene wiring: zombie-only audio, silent admission and GUI clicks.

const PointerFeedback = preload("res://scripts/pointer_feedback.gd")
const Voices = preload("res://scripts/character_voices.gd")
const SoundBank = preload("res://scripts/sound_bank.gd")

var checks: int = 0
var failures: int = 0
var pulses: int = 0
var game: Node
var preferences: Node
var main: Control

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("POLISH INTEGRATION FAIL: ", description)

func count_script(script: Script) -> int:
	var count: int = 0
	for child: Node in main.get_children():
		if child.get_script() == script:
			count += 1
	return count

func playing_weapon() -> bool:
	return playing_sound("shot_" + str(game.weapon))

func playing_sound(kind: String) -> bool:
	for player: AudioStreamPlayer in main.audio_pool:
		if player.playing and player.stream == SoundBank.sound(kind):
			return true
	return false

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child: Node in node.get_children():
		var button: Button = find_button(child, text)
		if button:
			return button
	return null

func click(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Run test_polish_integration.gd with the native renderer; it verifies real audio players.")
		quit(1)
		return
	game = root.get_node("Game")
	preferences = root.get_node("Preferences")
	game.save_path = "user://polish-integration-save.json"
	preferences.settings_path = "user://polish-integration-settings.cfg"
	preferences.apply_settings({"sound_enabled": true, "effects_volume": 0.6, "master_volume": 0.6, "music_volume": 0.0, "fullscreen": false}, false)
	game._new_game()
	game.set_process(false)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	var ambience: Node = main.character_ambience
	ambience.set_process(false)
	await process_frame
	await process_frame
	expect(count_script(PointerFeedback) == 1, "main installs exactly one pointer layer")
	expect(count_script(load("res://scripts/zombie_soundscape.gd")) == 1, "main installs exactly one supplied zombie soundscape")
	expect(count_script(load("res://scripts/character_ambience.gd")) == 0, "archived individual zombie voices are not installed alongside the new recording")
	ambience._process(0.5)
	expect(main.in_main_menu and game.paused and ambience.playback_generation == 0 and not ambience.players[0].playing, "boot menu remains silent")
	main.ui._start_game()
	expect(not main.in_main_menu and not game.paused, "real start-game signal enables gameplay")
	game.tutorial_stage = "complete"
	main.ui._close_modal()
	game.paused = false
	game.threats.clear()
	game._add_threat("walker", 180.0)
	game.visitors.clear()
	game._spawn_visitor(true)
	game.visitors[0].x = 180.0
	main.camera_x = -420.0
	main.target_camera = -420.0
	main.zoom = 1.0
	main.shake = 0.0
	expect(ambience.visible_zombie_count() == 1, "real gate camera sees a living zombie")
	if ambience.visible_zombie_count() == 0:
		await teardown()
		return
	ambience._process(0.4)
	var generation: int = ambience.playback_generation
	var active_player: AudioStreamPlayer = ambience.players[ambience.active_index]
	expect(active_player.playing and active_player.stream is AudioStreamOggVorbis and active_player.stream.get_length() > 90.0, "visible zombie starts the complete supplied recording")
	expect(not active_player.stream.loop, "decoder hard loop is disabled in favor of the crossfade")
	var enemy: Dictionary = game.threats[0]
	enemy.hp = 10000.0
	enemy.max_hp = 10000.0
	var hp: float = float(enemy.hp)
	var shots_before: int = main.shots.size()
	game._tick_guards(999.0)
	expect(enemy.hp == hp and main.shots.size() == shots_before, "voice scheduling leaves guards under manual control")
	game.shot_cooldown = 0.0
	expect(game.shoot(int(enemy.id)), "real simulation accepts a manual shot")
	ambience._process(0.02)
	expect(active_player.playing and ambience.duck_gain < 0.8 and playing_weapon(), "manual shot ducks the zombie bed and plays the supplied gunshot")
	expect(ambience.playback_generation == generation, "shooting never restarts the zombie recording")
	await create_timer(0.24).timeout
	for weapon_key: String in ["shotgun", "sniper", "smg"]:
		for player: AudioStreamPlayer in main.audio_pool:
			player.stop()
		main.reload_queue.clear()
		game.threats.clear()
		game._add_threat("brute", 180.0)
		game.threats[0].hp = 10000.0
		game.threats[0].max_hp = 10000.0
		game.weapon = weapon_key
		game.ammo = 10
		game.shot_cooldown = 0.0
		expect(game.shoot(int(game.threats[0].id)) and main.reload_queue.size() == 1 and playing_weapon(), weapon_key + ": shot immediately plays its report and queues one reload")
		main._update_reload_audio(0.01)
		expect(main.reload_queue.size() == 1 and not playing_sound("reload_" + weapon_key), weapon_key + ": reload follows the firing transient")
		expect(not game.shoot(int(game.threats[0].id)) and main.reload_queue.size() == 1, weapon_key + ": cooldown clicks create no duplicate action sound")
		main._update_reload_audio(1.0)
		expect(main.reload_queue.is_empty() and playing_sound("reload_" + weapon_key), weapon_key + ": delayed mechanical recording actually plays")
		await create_timer(0.02).timeout
	main.reload_queue.clear()
	game.paused = true
	ambience._process(0.0)
	var visitor: Dictionary = game.visitors[0]
	var before_admission: int = ambience.playback_generation
	main.ui.show_visitor(int(visitor.id))
	expect(game.paused and main.ui.panel_kind == "visitor" and ambience.playback_generation == before_admission, "real admission panel opens without restarting character audio")
	expect(Voices.civilian(int(visitor.citizen.look), 0) == null and active_player.stream_paused, "survivors remain silent and the zombie recording pauses during admission")
	main.ui._show_settings()
	ambience._process(0.01)
	expect(game.paused and active_player.stream_paused, "opening real settings keeps recording suspended")
	ambience._process(0.5)
	expect(ambience.playback_generation == before_admission and active_player.stream_paused, "settings never retrigger zombie audio")
	main.ui._close_modal()
	main.ui._return_to_main_menu()
	ambience._process(0.5)
	expect(main.in_main_menu and game.paused and ambience.playback_generation == before_admission and not ambience.players[0].playing and not ambience.players[1].playing, "returning through the real menu flow fades and stops both streams")
	var saved_cursor: float = ambience._positions[ambience.active_index]
	main.ui._start_game()
	ambience._process(0.0)
	expect(not main.in_main_menu and ambience.playback_generation == before_admission + 1 and ambience.players[ambience.active_index].playing, "Continue resumes the zombie bed through the real menu flow")
	expect(ambience._positions[ambience.active_index] >= saved_cursor - 0.04, "Continue keeps the saved recording passage instead of resetting it")
	main.ui._return_to_main_menu()
	ambience._process(0.5)
	await process_frame
	await process_frame
	var feedback: CanvasLayer
	for child: Node in main.get_children():
		if child.get_script() == PointerFeedback:
			feedback = child
	feedback.pulse_started.connect(func(_point: Vector2) -> void: pulses += 1)
	var settings: Button = find_button(main.ui.menu_layer, "Impostazioni")
	expect(settings != null, "real title menu exposes its settings button")
	if settings:
		click(settings.get_global_rect().get_center())
		expect(pulses == 1 and feedback.effect_count == 1 and main.ui.panel_kind == "settings" and game.paused, "paused menu click creates exactly one ripple and still opens settings")
	await teardown()

func teardown() -> void:
	main.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	for path: String in [game.save_path, game.save_path + ".tmp", game.save_path + ".bak", preferences.settings_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("POLISH INTEGRATION: ", checks, " checks; ", failures, " failures")
	quit(0 if failures == 0 else 1)
