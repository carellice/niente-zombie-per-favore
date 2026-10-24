extends SceneTree
## Native input/audio regression; can also run against the exported resource pack.
const SoundBank = preload("res://scripts/sound_bank.gd")

var game: Node
var preferences: Node
var scene: Control
var events: Array[String] = []
var ui_playbacks: int = 0
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ",description)

func settle() -> void:
	await process_frame
	await process_frame

func tap(point: Vector2) -> void:
	for pressed: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)

func prepare_capture() -> void:
	events.clear()
	ui_playbacks = 0
	for player: AudioStreamPlayer in scene.audio_pool:
		player.stop()

func capture_sound(kind: String) -> void:
	events.append(kind)
	# Main's listener runs first. Observe actual playback immediately, before a
	# cold dialog builds its textures and the short click can already finish.
	if kind=="ui" and playing("ui"):
		ui_playbacks += 1

func playing(kind: String) -> bool:
	for player: AudioStreamPlayer in scene.audio_pool:
		if player.playing and player.stream == SoundBank.sound(kind):
			return true
	return false

func effects_are_silent() -> bool:
	for player: AudioStreamPlayer in scene.audio_pool:
		if player.playing:
			return false
	return true

func close_button(node: Node) -> Button:
	if node is Button and node.tooltip_text.begins_with("Chiudi"):
		return node
	for child: Node in node.get_children():
		var button: Button = close_button(child)
		if button != null:
			return button
	return null

func tap_close() -> void:
	var button: Button = close_button(scene.ui.modal)
	if button != null:
		tap(button.get_global_rect().get_center())
	else:
		printerr("Missing dialog close button")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Run test_interface_audio.gd with the native renderer to verify real audio playback.")
		quit(1)
		return
	game = root.get_node("Game")
	preferences = root.get_node("Preferences")
	game.save_path = "user://interface-audio-save.json"
	preferences.settings_path = "user://interface-audio-settings.cfg"
	preferences.apply_settings({"sound_enabled":true,"effects_volume":0.6,"master_volume":0.5,"music_volume":0.0,"fullscreen":false},false)
	game._new_game()
	game.skip_tutorial()
	game.coins = 10000
	game.set_process(false)
	game.build("cafe")
	game._spawn_visitor(true)
	var visitor: Dictionary = game.visitors[0]
	visitor.x = 180.0
	var building_id: int = int(game.buildings[0].id)
	root.size = Vector2i(1440,900)
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.character_ambience.set_process(false)
	await settle()
	scene.ui._start_game()
	scene.ui.set_process(false)
	scene.camera_x = 0.0
	scene.target_camera = 0.0
	scene.zoom = 1.0
	scene.target_zoom = 1.0
	scene.shake = 0.0
	await settle()
	game.sfx.connect(capture_sound)
	expect(not scene.in_main_menu and scene.audio_pool.size()>0 and SoundBank.sound("ui")!=null,"Gameplay has a loaded click sample and real audio players")

	prepare_capture()
	tap(scene._building_rect(building_id).get_center())
	expect(scene.ui.panel_kind=="building" and events.count("ui")==1 and ui_playbacks==1,"A building click opens its dialog with exactly one audible click")

	prepare_capture()
	scene.ui._refresh_current()
	scene.ui.show_building(building_id)
	await settle()
	expect(events.is_empty() and effects_are_silent() and scene.ui.panel_kind=="building","Refreshing an existing building dialog adds no interface sound")

	# Wait for the animated cabinet to settle before clicking its actual X.
	await create_timer(0.32).timeout
	prepare_capture()
	tap_close()
	expect(scene.ui.modal==null and events.count("ui")==1 and ui_playbacks==1,"The actual dialog X closes it and plays one click")
	await settle()

	prepare_capture()
	tap(Vector2(scene._sx(float(visitor.x)),scene._ground()-28.0))
	expect(scene.ui.panel_kind=="visitor" and int(scene.ui.panel_id)==int(visitor.id) and events.count("ui")==1 and ui_playbacks==1,"A survivor click opens the correct admission dialog with one sound")

	prepare_capture()
	scene.ui._close_modal()
	await settle()
	expect(events.is_empty() and effects_are_silent(),"Programmatic dialog cleanup stays silent")

	prepare_capture()
	tap(scene._gate_rect().get_center())
	expect(scene.ui.panel_kind=="gate" and events.count("ui")==1 and ui_playbacks==1,"The world checkpoint opens its dialog with one audible click")
	scene.ui._close_modal()
	await settle()

	prepare_capture()
	tap(Vector2(1100.0,200.0))
	expect(scene.ui.modal==null and events.is_empty() and effects_are_silent(),"Clicking empty scenery does not produce an interface click")

	prepare_capture()
	var extension_x: float = scene.CITY_START+game.buildings.size()*scene.LOT_STEP
	tap(Vector2(scene._sx(extension_x)+130.0,scene._ground()-95.0))
	expect(scene.ui.panel_kind=="build" and events.count("ui")==1 and ui_playbacks==1,"The expansion lot opens construction with one audible click")
	scene.ui._close_modal()
	await settle()

	prepare_capture()
	var armory_button: Button = scene.ui.nav_buttons["armory"]
	tap(armory_button.get_global_rect().get_center())
	expect(scene.ui.panel_kind=="armory" and events.count("ui")==1 and ui_playbacks==1,"HUD navigation opens a dialog without doubling its existing button sound")
	scene.ui._close_modal()
	await settle()

	game._add_threat("brute",90.0)
	var enemy: Dictionary = game.threats.back()
	var hp_before: float = float(enemy.hp)
	game.weapon = "pistol"
	game.shot_cooldown = 0.0
	prepare_capture()
	tap(Vector2(scene._sx(float(enemy.x)),scene._ground()-32.0))
	expect(float(enemy.hp)<hp_before and events.count("ui")==0 and playing("shot_pistol"),"Clicking a zombie keeps its gunshot and adds no interface click")
	scene.shake = 0.0
	game.threats.clear()

	preferences.apply_settings({"sound_enabled":false},false)
	prepare_capture()
	tap(scene._building_rect(building_id).get_center())
	expect(scene.ui.panel_kind=="building" and events.count("ui")==1 and effects_are_silent() and AudioServer.is_bus_mute(0),"Muted world clicks still work while no effect player starts")
	await create_timer(0.32).timeout
	prepare_capture()
	tap_close()
	expect(scene.ui.modal==null and events.count("ui")==1 and effects_are_silent(),"The dialog X also respects the sound mute setting")
	await settle()

	preferences.apply_settings({"sound_enabled":true,"effects_volume":0.0},false)
	prepare_capture()
	tap(scene._building_rect(building_id).get_center())
	expect(scene.ui.panel_kind=="building" and events.count("ui")==1 and effects_are_silent() and not AudioServer.is_bus_mute(0),"The effects slider can silence clicks independently of master mute")
	await create_timer(0.32).timeout
	preferences.apply_settings({"effects_volume":0.6},false)
	prepare_capture()
	tap_close()
	expect(scene.ui.modal==null and events.count("ui")==1 and ui_playbacks==1,"Re-enabling effects immediately restores the close-button sound")

	scene.queue_free()
	await settle()
	for path: String in [game.save_path,game.save_path+".tmp",game.save_path+".bak",preferences.settings_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("INTERFACE_AUDIO_CHECKS ",checks," FAILURES ",failures.size())
	quit(0 if failures.is_empty() else 1)
