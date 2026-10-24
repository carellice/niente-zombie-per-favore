extends SceneTree
## Verifies the real boot screen and input path against isolated state/settings.
var game: Node
var preferences: Node
var scene: Control
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ",description)

func button_named(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption:
		return node
	for child: Node in node.get_children():
		var found: Button = button_named(child,caption)
		if found:
			return found
	return null

func click(point: Vector2) -> void:
	for pressed: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func run() -> void:
	game = root.get_node("Game")
	preferences = root.get_node("Preferences")
	game.save_path = "user://main-flow-save.json"
	preferences.settings_path = "user://main-flow-settings.cfg"
	game._new_game()
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	expect(scene.in_main_menu and scene.ui.main_menu_active,"Application boots into the real title menu")
	expect(game.paused and not scene.ui.hud.visible,"Boot menu suspends simulation and hides gameplay HUD")
	var time_before: float = game.time_played
	var threats_before: int = game.threats.size()
	await create_timer(0.15).timeout
	expect(game.time_played == time_before and game.threats.size() == threats_before,"Waiting in title menu advances neither arrivals nor simulation")
	var settings: Button = button_named(scene.ui.menu_layer,"Impostazioni")
	await click(settings.get_global_rect().get_center())
	expect(scene.ui.panel_kind == "settings" and game.paused,"Settings button works through viewport input")
	preferences.apply_settings({"sound_enabled":false,"master_volume":0.42,"effects_volume":0.61,"music_volume":0.12})
	expect(not scene.sound_enabled and AudioServer.is_bus_mute(0),"Saved mute setting reaches actual audio output")
	expect(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)),0.42),"Master slider reaches audio mixer")
	scene.ui._close_modal()
	await process_frame
	var start: Button = button_named(scene.ui.menu_layer,"Gioca  →")
	if start == null:
		start = button_named(scene.ui.menu_layer,"Continua la partita  →")
	# This flow tests boot/settings/manual shooting; tutorial progression has its
	# own walkthrough. New games now correctly contain no pre-spawned enemy.
	game.tutorial_stage = "complete"
	await click(start.get_global_rect().get_center())
	expect(not scene.in_main_menu and not game.paused and scene.ui.hud.visible,"Clicking Play enters the actual game")
	game.set_process(false)
	game._add_threat("brute",180.0)
	scene.camera_x = -420.0
	scene.target_camera = -420.0
	scene.zoom = 1.0
	scene.target_zoom = 1.0
	var enemy: Dictionary = game.threats[0]
	var original_hp: float = enemy.hp
	game._tick_guards(999.0)
	expect(enemy.hp == original_hp and scene.shots.is_empty(),"A defender never fires just because time passes")
	game.shot_cooldown = 0.0
	await click(Vector2(scene._sx(enemy.x),scene._ground()-32*scene.zoom))
	expect(enemy.hp < original_hp and scene.shots.size()==1,"Player tap produces damage and exactly one shot")
	expect(scene.guard_flashes.has(scene._first_guard_id()),"Player tap drives the guard firing animation")
	scene.ui._return_to_main_menu()
	await process_frame
	expect(scene.in_main_menu and game.paused and FileAccess.file_exists(game.save_path),"Returning to title saves and blocks gameplay input")
	scene.queue_free()
	await process_frame
	for path: String in [game.save_path,game.save_path+".tmp",game.save_path+".bak",preferences.settings_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	print("MAIN FLOW: ",checks," checks; ",failures," failures")
	quit(0 if failures==0 else 1)
