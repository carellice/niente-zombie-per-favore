extends SceneTree
## Exercise Android-style touch plus emulated mouse through the real viewport.

var checks: int = 0
var failures: int = 0
var game: Node
var layout: Node
var main: Control
var ui: CanvasLayer
var activations: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("TOUCH SCROLL FAIL: ",message)

func settle(frames: int = 6) -> void:
	for frame: int in range(frames): await process_frame

func screen_rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,control.size)

func motion(point: Vector2, relative: Vector2, held: bool) -> void:
	if held:
		var drag: InputEventScreenDrag = InputEventScreenDrag.new()
		drag.position = point
		drag.relative = relative
		drag.index = 0
		root.push_input(drag,true)
	var mouse: InputEventMouseMotion = InputEventMouseMotion.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.position = point
	mouse.global_position = point
	mouse.relative = relative
	mouse.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(mouse,true)

func contact(point: Vector2, pressed: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = point
	touch.pressed = pressed
	touch.index = 0
	root.push_input(touch,true)
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.position = point
	mouse.global_position = point
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = pressed
	root.push_input(mouse,true)

func swipe(start: Vector2, offset: Vector2) -> void:
	motion(start,Vector2.ZERO,false)
	contact(start,true)
	for step: int in range(1,9):
		motion(start+offset*float(step)/8.0,offset/8.0,true)
		await process_frame
	contact(start+offset,false)
	await settle(2)

func open_panel(kind: String) -> void:
	ui._close_modal()
	match kind:
		"armory": ui._show_armory()
		"expeditions": ui._show_expeditions()
		"expedition_team":
			ui._show_expeditions()
			ui._set_expedition_step(2)
		"citizens": ui._show_citizens()
		"build": ui._show_build()
		"settings": ui._show_settings()
		"quests": ui._show_quests()
		"visitor":
			if game.visitors.is_empty(): game._spawn_visitor()
			ui.show_visitor(int(game.visitors[0].id))
		"building": ui.show_building(int(game.buildings[1].id))
		"credits": ui._show_credits()
		"help": ui.show_help()
	await settle()
	ui._stop_modal_motion()
	ui._modal_motion_progress = 1.0
	await settle()

func first_visible_card() -> Control:
	var visible: Rect2 = screen_rect(ui.modal_scroll)
	for child: Node in ui.modal_content.get_children():
		if child is PanelContainer and screen_rect(child).intersection(visible).size.y>32:
			return child
	return ui.modal_content

func check_swipe(kind: String, surface: Control, label: String) -> void:
	var scroll: ScrollContainer = ui.modal_scroll
	var scroll_id: int = scroll.get_instance_id()
	var before: float = scroll.get_v_scroll_bar().value
	var available: float = scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page-before
	var visible: Rect2 = screen_rect(surface).intersection(screen_rect(scroll))
	expect(visible.has_area(),label+": gesture starts on visible content")
	var start: Vector2 = visible.get_center()
	if surface is PanelContainer: start.x = visible.position.x+8.0*layout.ui_scale()
	var coins_before: float = game.coins
	var camera_before: float = main.target_camera
	var ground_before: float = main._ground()
	var zone_before: int = ui.selected_zone
	activations = 0
	if surface is Button:
		surface.pressed.connect(func() -> void: activations += 1)
	await swipe(start,Vector2(0,-100.0*layout.ui_scale()))
	expect(is_instance_id_valid(scroll_id) and ui.modal_scroll==scroll,label+": swipe keeps the dialog open")
	if not is_instance_id_valid(scroll_id) or ui.modal_scroll!=scroll: return
	expect(scroll.scroll_vertical>before+minf(30,available*0.5),label+": first swipe scrolls without repeated attempts")
	expect(activations==0 and is_equal_approx(game.coins,coins_before) and ui.selected_zone==zone_before,label+": swipe never purchases or selects an action")
	expect(is_equal_approx(main.target_camera,camera_before) and is_equal_approx(main._ground(),ground_before),label+": gesture does not move the world or its street")
	expect(ui.panel_kind==("expeditions" if kind=="expedition_team" else kind),label+": gesture does not switch panels")

func button_in_content(enabled: bool) -> Button:
	for child: Node in ui.modal_content.find_children("*","Button",true,false):
		if child.disabled!=enabled: return child as Button
	return null

func run() -> void:
	game = root.get_node("Game")
	layout = root.get_node("DeviceLayout")
	var test_directory: String = OS.get_environment("NZPF_TEST_DATA_DIR")
	if test_directory.is_empty(): test_directory = ProjectSettings.globalize_path("res://.runtime")
	DirAccess.make_dir_recursive_absolute(test_directory)
	game.save_path = test_directory.path_join("touch-scroll-test.json")
	root.get_node("Preferences").settings_path = test_directory.path_join("touch-scroll-settings.cfg")
	game.set_process(false)
	game._new_game()
	game.skip_tutorial()
	game.coins = 200000
	game.supplies = 10000
	game.build("residence")
	game.build("cafe")
	for index: int in range(8): game.citizens.append(game._make_citizen())
	layout.mobile = true
	root.min_size = Vector2i.ZERO
	# The engine uses this flag to expose its native touchscreen scrolling path.
	# Events below are already paired, so push_input bypasses Input emulation.
	Input.emulate_touch_from_mouse = true
	expect(DisplayServer.is_touchscreen_available(),"Tests exercise native touchscreen scrolling")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	ui = main.ui
	ui._start_game()
	main.set_process(false)
	await settle()
	for screen: Vector2i in [Vector2i(1920,1080),Vector2i(2400,1080),Vector2i(2048,1536)]:
		root.size = screen
		await settle()
		layout.refresh()
		await settle()
		var prefix: String = "%dx%d " % [screen.x,screen.y]
		for kind: String in ["armory","expeditions","expedition_team","citizens","build","settings","quests","visitor","building","credits","help"]:
			await open_panel(kind)
			var bar: VScrollBar = ui.modal_scroll.get_v_scroll_bar()
			if bar.max_value<=bar.page+1:
				expect(screen_rect(ui.modal_scroll).grow(2).encloses(screen_rect(ui.modal_content)),prefix+kind+": short content is fully visible without scrolling")
				continue
			expect(ui.modal_content.size.y>ui.modal_scroll.size.y,prefix+kind+": overflowing content has a scrollable range")
			await check_swipe(kind,first_visible_card(),prefix+kind+" card")
		# Buttons must pass drags through, including disabled entries in the armory.
		for kind: String in ["armory","expeditions","expedition_team","citizens","build"]:
			for enabled: bool in [true,false]:
				await open_panel(kind)
				var button: Button = button_in_content(enabled)
				if button==null: continue
				ui.modal_scroll.ensure_control_visible(button)
				await settle()
				# Leave enough content below the starting point for an upward swipe.
				if ui.modal_scroll.get_v_scroll_bar().max_value-ui.modal_scroll.get_v_scroll_bar().page-ui.modal_scroll.scroll_vertical<40: continue
				await check_swipe(kind,button,prefix+kind+(" enabled" if enabled else " disabled")+" button")
		await open_panel("expeditions")
		var previous: int = 0
		for repeat: int in range(4):
			var start: Vector2 = screen_rect(ui.modal_scroll).get_center()
			await swipe(start,Vector2(0,-65.0*layout.ui_scale()))
			expect(ui.modal_scroll.scroll_vertical>previous+20,prefix+"consecutive swipe %d continues scrolling" % repeat)
			previous = ui.modal_scroll.scroll_vertical
		await swipe(screen_rect(ui.modal_scroll).get_center(),Vector2(0,100.0*layout.ui_scale()))
		expect(ui.modal_scroll.scroll_vertical<previous-30,prefix+"reversing the gesture scrolls back toward the top")
		# Swiping beyond the top must still cancel the button's click.
		await open_panel("expeditions")
		var top_button: Button = button_in_content(true)
		ui.modal_scroll.ensure_control_visible(top_button)
		await settle()
		var to_top: float = (ui.modal_scroll.scroll_vertical+70.0)*layout.ui_scale()
		activations = 0
		top_button.pressed.connect(func() -> void: activations += 1)
		await swipe(screen_rect(top_button).get_center(),Vector2(0,to_top))
		expect(ui.modal_scroll.scroll_vertical==0,prefix+"overscroll is clamped at the top")
		expect(activations==0,prefix+"overscroll does not click the starting button")
		# A deliberate tap still selects a destination exactly once.
		await open_panel("expeditions")
		var choose: Button = ui.modal_content.find_child("ExpeditionZone_1",true,false)
		ui.modal_scroll.ensure_control_visible(choose)
		await settle()
		activations = 0
		choose.pressed.connect(func() -> void: activations += 1)
		var point: Vector2 = screen_rect(choose).get_center()
		motion(point,Vector2.ZERO,false)
		contact(point,true)
		await process_frame
		contact(point,false)
		await settle()
		expect(activations==1 and ui.selected_zone==1,prefix+"a stationary tap selects exactly one destination")
		ui.selected_zone = 0
		await open_panel("settings")
		var slider: HSlider = ui.modal_content.find_children("*","HSlider",true,false)[0]
		ui.modal_scroll.ensure_control_visible(slider)
		await settle()
		var scroll_before: int = ui.modal_scroll.scroll_vertical
		var slider_rect: Rect2 = screen_rect(slider)
		await swipe(slider_rect.position+slider_rect.size*Vector2(.25,.5),Vector2(slider_rect.size.x*.25,0))
		expect(slider.value>20 and slider.value<80,prefix+"horizontal volume slider remains usable")
		expect(ui.modal_scroll.scroll_vertical==scroll_before,prefix+"horizontal adjustment does not move the dialog")
		ui._close_modal()
	# A player can start swiping while the opening animation is still running.
	# The fullscreen phone armory fits without scrolling; use a longer list.
	ui._show_expeditions()
	await settle(2)
	var early_card: Control = first_visible_card()
	var early_rect: Rect2 = screen_rect(early_card).intersection(screen_rect(ui.modal_scroll))
	await swipe(early_rect.position+Vector2(8,early_rect.size.y*0.5),Vector2(0,-120.0*layout.ui_scale()))
	expect(ui.modal_scroll.scroll_vertical>40,"A swipe during dialog entrance is not reset or lost")
	# Desktop wheel input keeps working over a card.
	Input.emulate_touch_from_mouse = false
	layout.mobile = false
	root.size = Vector2i(1440,900)
	layout.refresh()
	await open_panel("armory")
	var card_rect: Rect2 = screen_rect(first_visible_card()).intersection(screen_rect(ui.modal_scroll))
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.position = card_rect.get_center()
	wheel.global_position = wheel.position
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	root.push_input(wheel,true)
	await settle()
	expect(ui.modal_scroll.scroll_vertical>0,"Desktop mouse wheel still scrolls over cards")
	main.queue_free()
	await settle()
	print("TOUCH SCROLL: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
