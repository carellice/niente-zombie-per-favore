extends SceneTree
## Exercises the actual menu callbacks against disposable colony/settings files.

var failures: Array[String] = []
var checks: int = 0
var ui: CanvasLayer
var game: Node
var preferences: Node
var capture_enabled: bool = false

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("FAIL: ",description)

func button_named(node: Node, caption: String) -> Button:
	if node is Button and node.text == caption:
		return node
	for child: Node in node.get_children():
		var found: Button = button_named(child,caption)
		if found != null:
			return found
	return null

func first_slider(node: Node) -> HSlider:
	if node is HSlider:
		return node
	for child: Node in node.get_children():
		var found: HSlider = first_slider(child)
		if found != null:
			return found
	return null

func portrait_with_look(node: Node, look: int) -> TextureRect:
	if node is TextureRect and node.get_meta("citizen_look",-1) == look:
		return node
	for child: Node in node.get_children():
		var found: TextureRect = portrait_with_look(child,look)
		if found != null:
			return found
	return null

func capture(filename: String) -> void:
	if not capture_enabled:
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png("res://.runtime/"+filename+".png")==OK,"Capture "+filename)

func run() -> void:
	game = root.get_node("Game")
	preferences = root.get_node("Preferences")
	game.save_path = "res://tests/.menu-save.json"
	preferences.settings_path = "res://tests/.menu-settings.cfg"
	game._new_game()
	game.set_process(false)
	game.paused = false
	capture_enabled = OS.get_cmdline_user_args().has("--capture-menu")
	root.size = Vector2i(1440,900)
	ui = load("res://scripts/game_ui.gd").new()
	root.add_child(ui)
	await process_frame
	ui.show_main_menu()
	await process_frame
	expect(ui.main_menu_active and game.paused,"Opening the menu freezes the colony")
	expect(not ui.hud.visible,"Gameplay HUD is hidden on the title screen")
	expect(not FileAccess.file_exists(game.save_path),"Opening the menu does not create or replace a save")
	expect(button_named(ui.menu_layer,"Gioca  →") != null,"A fresh colony offers Gioca")
	for caption: String in ["Nuova partita","Impostazioni","Crediti","Esci"]:
		var button: Button = button_named(ui.menu_layer,caption)
		expect(button != null and button.size.y >= 52,"Menu has a large "+caption+" button")
	await capture("menu-title")
	ui._show_settings()
	await process_frame
	expect(ui.panel_kind=="settings" and game.paused,"Settings keep the title screen paused")
	var slider: HSlider = first_slider(ui.modal)
	expect(slider != null,"Settings expose real volume sliders")
	slider.value = 37
	expect(is_equal_approx(preferences.master_volume,.37),"Volume slider changes the applied preference")
	preferences.master_volume = .99
	expect(preferences.load_settings()==OK and is_equal_approx(preferences.master_volume,.37),"Volume survives a preference reload")
	await capture("menu-settings")
	ui._close_modal()
	await process_frame
	expect(ui.main_menu_active and game.paused,"Closing settings returns to the frozen title screen")
	ui._show_credits()
	await process_frame
	expect(ui.panel_kind=="credits","Credits can be opened")
	await capture("menu-credits")
	ui._close_modal()
	ui._confirm_reset()
	await process_frame
	var people_before: Array = game.citizens.duplicate(true)
	var coins_before: float = game.coins
	button_named(ui.modal,"Annulla, conserva il rifugio").pressed.emit()
	await process_frame
	expect(game.citizens==people_before and game.coins==coins_before,"Cancel new game preserves the colony")
	expect(game.paused and ui.main_menu_active,"Cancel new game stays in the title screen")
	ui._start_game()
	await process_frame
	expect(not ui.main_menu_active and ui.hud.visible and not game.paused,"Gioca restores the HUD and starts the colony")
	expect(ui.panel_kind=="tutorial_intro" and game.citizens.is_empty() and game.buildings.is_empty(),"Fresh Gioca opens the tutorial for a completely empty refuge")
	game.skip_tutorial()
	ui._close_modal()
	ui._show_pause()
	expect(game.paused,"Pause suspends gameplay")
	ui._close_modal()
	expect(not game.paused,"Closing pause restores a running colony")
	game.paused = true
	ui._show_pause()
	ui._close_modal()
	expect(game.paused,"Closing pause preserves an already-paused preview")
	game.paused = false
	game._spawn_visitor(true)
	var visitor: Dictionary = game.visitors[0]
	visitor.citizen.look = 7
	ui.show_visitor(visitor.id)
	await process_frame
	var portrait: TextureRect = portrait_with_look(ui.modal,7)
	expect(portrait != null and portrait.texture == load("res://scripts/actor_visuals.gd").texture(7),"Admission portrait uses the exact street identity mapping")
	expect(button_named(ui.modal,"✓  Accogli nel rifugio") != null and button_named(ui.modal,"Rifiuta l'ingresso") != null,"Admission has distinct accept and reject actions")
	await capture("menu-admission")
	ui._close_modal()
	ui._return_to_main_menu()
	await process_frame
	expect(FileAccess.file_exists(game.save_path),"Returning to menu saves the colony")
	expect(button_named(ui.menu_layer,"Continua la partita  →") != null,"An existing colony offers Continue")
	ui._show_settings()
	preferences.apply_settings({"sound_enabled":false,"screen_shake":false,"fullscreen":false})
	expect(not ui.sound_enabled,"HUD sound follows persistent settings")
	ui._close_modal()
	ui._confirm_reset()
	await process_frame
	game.coins = 1
	button_named(ui.modal,"Sì, ricomincia da zero").pressed.emit()
	await process_frame
	expect(game.coins>1 and not game.paused and not ui.main_menu_active,"Confirmed new game resets and starts a fresh colony")
	expect(game.citizens.is_empty() and game.buildings.is_empty() and game.tutorial_stage=="intro","Confirmed New Game does not reuse the old population or buildings")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(preferences.settings_path))
	print("MENU TESTS: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
