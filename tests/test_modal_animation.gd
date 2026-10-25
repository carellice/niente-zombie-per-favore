extends SceneTree
## Exercise real dialog callbacks; all colony/settings files are disposable.

var checks: int = 0
var failures: Array[String] = []
var ui: CanvasLayer
var game: Node
var preferences: Node

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		printerr("MODAL ANIMATION FAIL: ",description)

func settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func wait_for_opening() -> void:
	await create_timer(0.55).timeout
	await settle()

func check_settled(description: String) -> void:
	expect(is_equal_approx(float(ui._modal_motion_progress),1.0),description+": reaches its final state")
	expect(is_instance_valid(ui._modal_box) and ui._modal_box.scale.is_equal_approx(Vector2.ONE),description+": no lasting scale distortion")
	expect(is_equal_approx(ui._modal_box.modulate.a,1.0) and is_equal_approx(ui._modal_shade.modulate.a,1.0),description+": panel and backdrop finish visible")
	expect(ui._modal_box.pivot_offset.is_equal_approx(ui._modal_box.size*0.5),description+": pivot follows the laid-out cabinet")

func button_prefix(node: Node, prefix: String) -> Button:
	if node is Button and node.text.begins_with(prefix): return node
	for child: Node in node.get_children():
		var found: Button = button_prefix(child,prefix)
		if found!=null: return found
	return null

func run() -> void:
	game = root.get_node("Game")
	preferences = root.get_node("Preferences")
	game.save_path = "user://modal-animation-save.json"
	preferences.settings_path = "user://modal-animation-settings.cfg"
	game.set_process(false)
	game._new_game()
	game.skip_tutorial()
	game.coins = 20000
	game.supplies = 1000
	game.owned_weapons = ["pistol","shotgun","sniper","smg"]
	ready_build(game,"residence")
	ready_build(game,"cafe")
	ready_build(game,"garden")
	root.size = Vector2i(1440,900)
	ui = load("res://scripts/game_ui.gd").new()
	root.add_child(ui)
	await settle()
	ui._show_armory()
	expect(is_equal_approx(float(ui._modal_motion_progress),0.0),"New dialog starts its motion synchronously before first paint")
	expect(ui._modal_box.modulate.a<0.01 and ui._modal_shade.modulate.a<0.01,"Both cabinet and backdrop start transparent")
	expect(ui._modal_box.scale.x<1.0 and ui._modal_box.scale.y<1.0,"Cabinet initially has a subtle smaller scale")
	expect(ui._modal_motion_tween!=null and ui._modal_motion_tween.is_running(),"Opening owns one live tween")
	var first_tween: Tween = ui._modal_motion_tween
	await create_timer(0.065).timeout
	var midway: float = float(ui._modal_motion_progress)
	expect(midway>0.0 and midway<1.0,"Opening progresses over actual elapsed frames")
	expect(ui._modal_box.modulate.a>0.0 and ui._modal_box.modulate.a<1.0,"Fade has a visible intermediate state")
	var shade_midway: float = ui._modal_shade.modulate.a
	ui._show_armory()
	expect(is_equal_approx(float(ui._modal_motion_progress),midway),"Rebuilding the same dialog preserves the exact ongoing progress")
	expect(is_equal_approx(ui._modal_shade.modulate.a,shade_midway),"Same-dialog refresh preserves exact backdrop opacity without a brightness flash")
	expect(ui._modal_motion_tween==first_tween,"Same dialog reuses its active motion rather than restarting")
	expect(ui._modal_box.modulate.a>0.0,"Same-dialog refresh does not flash back to invisible")
	var previous: float = float(ui._modal_motion_progress)
	for i: int in range(7):
		await create_timer(0.04).timeout
		var current: float = float(ui._modal_motion_progress)
		expect(current>=previous and current<=1.00001,"Opening progress remains monotonic and bounded, sample "+str(i))
		previous = current
	await wait_for_opening()
	check_settled("Armory opening")
	# A transaction rebuilds the current panel through the actual button callback.
	ui.modal_scroll.scroll_vertical = 510
	var scroll_before: int = ui.modal_scroll.scroll_vertical
	var coins_before: float = float(game.coins)
	var ammo_before: int = int(game.ammo)
	var purchase: Button = button_prefix(ui.modal,"+30 colpi")
	expect(purchase!=null and not purchase.disabled,"Armory exposes an enabled real ammunition action")
	if purchase!=null: purchase.pressed.emit()
	expect(game.ammo==ammo_before+30 and is_equal_approx(float(game.coins),coins_before-40.0),"Purchase commits immediately, without waiting for a visual animation")
	expect(is_equal_approx(float(ui._modal_motion_progress),1.0),"A settled same-dialog transaction does not replay its entrance")
	await settle()
	expect(scroll_before>0 and abs(ui.modal_scroll.scroll_vertical-scroll_before)<=2,"Animated dialog retains scroll after its real purchase refresh")
	# Changing identities is a navigation; even equal building kinds are distinct.
	ui.show_building(int(game.buildings[1].id))
	expect(is_equal_approx(float(ui._modal_motion_progress),0.0),"Navigating to another dialog begins a new appearance")
	expect(ui._modal_box.modulate.a<0.01 and is_equal_approx(ui._modal_shade.modulate.a,1.0),"Navigation replays cabinet entrance while retaining the existing dark backdrop")
	await create_timer(0.05).timeout
	var previous_tween: Tween = ui._modal_motion_tween
	ui.show_building(int(game.buildings[2].id))
	expect(is_equal_approx(float(ui._modal_motion_progress),0.0),"Changing building ID restarts appearance for the new building")
	expect(ui._modal_motion_tween!=previous_tween and not previous_tween.is_running(),"Superseded entrance tween cannot animate the replacement")
	await wait_for_opening()
	check_settled("Building navigation")
	# Closing is logically immediate: gameplay must never wait for a cosmetic fade.
	ui._show_pause()
	expect(game.paused and ui.panel_kind=="pause","Pause takes effect before its opening animation")
	await wait_for_opening()
	check_settled("Paused game")
	ui._close_modal()
	expect(not game.paused and ui.panel_kind.is_empty() and ui.modal==null,"Closing pause resumes gameplay immediately")
	expect(ui._modal_box==null and ui._modal_shade==null,"Closing drops animation targets synchronously")
	ui._show_settings()
	await wait_for_opening()
	check_settled("Paused settings")
	ui._close_modal()
	expect(not game.paused,"Settings preserve existing pause ownership on close")
	ui.show_main_menu()
	ui._show_settings()
	await wait_for_opening()
	check_settled("Title-screen settings")
	ui._close_modal()
	expect(ui.main_menu_active and game.paused,"Closing title-screen settings keeps the title screen paused")
	ui._start_game()
	await settle()
	# Destroy an obsolete target while callbacks/tweens still have pending frames.
	for i: int in range(12):
		ui._show_armory()
		var obsolete: Control = ui.modal
		obsolete.free()
		ui._show_citizens()
		ui._close_modal()
	ui._show_armory()
	await wait_for_opening()
	expect(ui.panel_kind=="armory" and is_instance_valid(ui.modal_scroll),"Rapid open/free/close leaves the latest dialog alive")
	check_settled("Rapid replacement")
	# Resize during the movement, not only once its final geometry is stable.
	ui._show_pause()
	await create_timer(0.045).timeout
	root.size = Vector2i(960,600)
	await wait_for_opening()
	check_settled("Minimum-window resize")
	var visual_center: Vector2 = ui._modal_box.get_global_transform()*(ui._modal_box.size*0.5)
	var viewport_center: Vector2 = ui.root.size*0.5
	expect(visual_center.distance_to(viewport_center)<1.0,"Cabinet finishes centered after a resize during its entrance")
	expect(ui._modal_box.offset_top+ui._modal_box.offset_bottom==0.0,"Animation leaves no persistent slide offset")
	var retiring: Control = ui.modal
	ui._close_modal()
	expect(ui.modal==null and retiring.mouse_filter==Control.MOUSE_FILTER_IGNORE,"A fading departure releases input immediately")
	await create_timer(0.2).timeout
	expect(not is_instance_valid(retiring),"Departing dialog is freed after its short fade")
	preferences.apply_settings({"reduced_motion":true},false)
	ui._show_armory()
	expect(is_equal_approx(ui._modal_motion_progress,1) and ui._modal_motion_tween==null,"Reduced motion opens immediately without a tween")
	ui._close_modal()
	preferences.save_settings()
	preferences.reduced_motion = false
	preferences.load_settings()
	expect(preferences.reduced_motion,"Reduced motion preference persists")
	preferences.apply_settings({"reduced_motion":false},false)
	await settle()
	ui.queue_free()
	await settle()
	if DisplayServer.get_name()!="headless" and OS.get_cmdline_user_args().has("--capture-modal-animation"):
		await capture_sequence()
	for path: String in [game.save_path,game.save_path+".tmp",game.save_path+".bak",preferences.settings_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("MODAL_ANIMATION_CHECKS ",checks," FAILURES ",failures.size())
	quit(1 if not failures.is_empty() else 0)

func capture_sequence() -> void:
	root.size = Vector2i(1440,900)
	var scene: Control = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await settle()
	scene.ui._start_game()
	scene.set_process(false)
	scene.camera_x = 600.0
	scene.target_camera = scene.camera_x
	scene.zoom = 0.82
	scene.target_zoom = scene.zoom
	scene.queue_redraw()
	await settle()
	var view: CanvasLayer = scene.ui
	view._show_armory()
	view._modal_motion_tween.pause()
	for sample: Array in [[0.08,"INIZIO"],[0.5,"META"],[1.0,"FINE"]]:
		view._modal_motion_progress = float(sample[0])
		await settle()
		await RenderingServer.frame_post_draw
		var destination: String = "C:/Users/flavi/Desktop/CODEX_niente_zombie_per_favore/docs/DIALOGO-APERTURA-%s.png" % str(sample[1])
		expect(root.get_texture().get_image().save_png(destination)==OK,"Native opening frame: "+str(sample[1]))
	scene.queue_free()
	await settle()

func ready_build(model: Node, kind: String) -> bool:
	var fixture: Script = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	return fixture.build_ready(model,kind)
