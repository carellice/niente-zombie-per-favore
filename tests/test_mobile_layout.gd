extends SceneTree
## Layout integration checks with the same phone canvas used by Android.

var checks: int = 0
var failures: int = 0
var main: Control
var ui: CanvasLayer
var layout: Node
var game: Node
var captures: bool = false

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("MOBILE FAIL: ",message)

func settle() -> void:
	for index: int in range(8): await process_frame

func contains(outer: Rect2, inner: Rect2) -> bool:
	return outer.grow(2).encloses(inner)

func expect_button_contents_fit(button: Button, label: String) -> void:
	var content: Control = button.get_node("ButtonContent")
	var minimum: Vector2 = content.get_combined_minimum_size()
	expect(content.size.x+1>=minimum.x and content.size.y+1>=minimum.y,label+": icon and text fit inside the compact button")

func capture(label: String) -> void:
	if not captures: return
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/MOBILE-"+label+".png")

func tap_control(control: Control) -> void:
	var position: Vector2 = control.get_global_transform_with_canvas()*(control.size*0.5)
	for pressed: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.device = InputEvent.DEVICE_ID_EMULATION
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		root.push_input(event,true)
		await process_frame

func run() -> void:
	game = root.get_node("Game")
	layout = root.get_node("DeviceLayout")
	layout.mobile = true
	root.min_size = Vector2i.ZERO
	game.save_path = "res://.runtime/mobile-layout-test.json"
	root.get_node("Preferences").settings_path = "res://.runtime/mobile-layout-preferences.cfg"
	game.set_process(false)
	game._new_game()
	game.skip_tutorial()
	game.coins = 20000
	game.supplies = 1000
	ready_build(game,"residence")
	ready_build(game,"cafe")
	game.citizens.append(game._make_citizen())
	captures = OS.get_cmdline_user_args().has("--capture-mobile")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	ui = main.ui
	await settle()
	# Safe rectangles are in screen pixels; include nonzero window origin.
	var mapped: Rect2 = layout.safe_rect_in_ui(Rect2(100,50,2400,1080),Rect2(180,50,2320,1020),Vector2(1066.6667,480))
	expect(mapped.position.is_equal_approx(Vector2(35.55556,0)),"Notch is converted from physical pixels into UI coordinates")
	expect(absf(mapped.end.y-453.3333)<0.01,"Navigation inset is converted without stretching the scene")
	for screen: Vector2i in [Vector2i(1920,1080),Vector2i(2400,1080),Vector2i(2560,1600),Vector2i(2048,1536)]:
		root.size = screen
		layout.preview_insets = Vector4(22,0,0,8)
		await settle()
		layout.refresh()
		await settle()
		var safe: Rect2 = layout.safe_rect()
		var label: String = str(screen.x)+"x"+str(screen.y)
		expect(absf(root.get_visible_rect().size.aspect()-Vector2(screen).aspect())<0.005,label+": viewport fills the device aspect without bars")
		expect(ui.root.size.is_equal_approx(layout.ui_size()),label+": phone UI uses its own logical size")
		ui.show_main_menu()
		await settle()
		expect(contains(safe,ui._menu_cabinet.get_global_rect()),label+": menu remains within safe area")
		expect(ui._menu_cabinet.size.y<=safe.size.y*0.74,label+": menu actions leave vertical space around them")
		await capture(label+"-MENU")
		ui._start_game()
		await settle()
		expect(contains(safe,ui._header.get_global_rect()),label+": header fits")
		expect(contains(safe,ui._footer.get_global_rect()),label+": footer fits")
		expect((ui._header.size.y+ui._footer.size.y)<=safe.size.y*0.30,label+": HUD leaves at least 70 percent of the height for the world")
		var navigation_width: float = ui.gate_button.get_global_rect().end.x-ui.nav_buttons.rifugio.get_global_rect().position.x
		expect(navigation_width<=safe.size.x*0.85,label+": navigation does not stretch across the whole display")
		for button: Button in ui.nav_buttons.values():
			expect(button.size.y>=layout.TOUCH_TARGET,label+": navigation preserves a touch target at the compact scale")
			expect(contains(safe,button.get_global_rect()),label+": navigation is inside screen")
			expect_button_contents_fit(button,label)
		expect_button_contents_fit(ui.gate_button,label+": gate")
		expect(ui.pause_button.size.y>=layout.TOUCH_TARGET,label+": pause preserves a touch target at the compact scale")
		ui._show_toast("Prima notifica")
		ui._show_toast("Ultima notifica")
		expect(ui.toast_stack.get_child_count()==1,label+": mobile notifications do not accumulate over the world")
		await capture(label+"-GIOCO")
		await tap_control(ui.nav_buttons.armory)
		await settle()
		expect(ui.panel_kind=="armory",label+": an emulated touch activates the scaled HUD through the real viewport")
		ui._close_modal()
		await settle()
		for panel: String in ["armory","citizens","build","settings","pause","visitor","building"]:
			match panel:
				"armory": ui._show_armory()
				"citizens": ui._show_citizens()
				"build": ui._show_build()
				"settings": ui._show_settings()
				"pause": ui._show_pause()
				"visitor":
					game._spawn_visitor()
					ui.show_visitor(int(game.visitors[-1].id))
				"building": ui.show_building(int(game.buildings[1].id))
			await settle()
			# Ignore the brief entrance scale and compare the final cabinet geometry.
			ui._stop_modal_motion()
			ui._modal_motion_progress = 1.0
			await settle()
			expect(contains(safe,ui._modal_box.get_global_rect()),label+": "+panel+" dialog fits "+str(ui._modal_box.get_global_rect())+" inside "+str(safe))
			expect(ui._modal_box.size.y<=safe.size.y*0.85,label+": "+panel+" leaves space above and below the dialog")
			expect(ui.modal_scroll.size.x+2>=ui.modal_content.get_combined_minimum_size().x,label+": "+panel+" has no clipped horizontal content")
			for button: Node in ui.modal.find_children("*","Button",true,false):
				expect(button.size.y>=layout.TOUCH_TARGET,label+": "+panel+" action preserves its touch target")
			if panel in ["armory","settings","pause","visitor","building"]: await capture(label+"-"+panel.to_upper())
		ui._close_modal()
	# The first launch guide must fit as well as a populated refuge.
	root.size = Vector2i(1920,1080)
	await settle()
	layout.refresh()
	await settle()
	game._new_game()
	ui._start_game()
	await settle()
	ui._stop_modal_motion()
	ui._modal_motion_progress = 1.0
	expect(ui.panel_kind=="tutorial_intro","A new mobile game opens the guided introduction")
	expect(contains(layout.safe_rect(),ui._modal_box.get_global_rect()),"Mobile introduction stays inside safe area")
	game.start_tutorial()
	ui._close_modal()
	await settle()
	expect(ui.tutorial_panel.visible,"First zombie has an on-screen guide")
	expect(contains(layout.safe_rect(),ui.tutorial_panel.get_global_rect()),"Expanded guide fits the phone")
	expect(ui.tutorial_panel.get_global_rect().end.y<=ui._footer.get_global_rect().position.y,"Guide does not cover navigation")
	for step: String in ["first_zombie","build_residence","welcome_visitor","build_cafe","assign_worker","restock","stock"]:
		game.tutorial_stage = step
		ui._update_tutorial()
		await settle()
		expect(ui.tutorial_panel.get_global_rect().end.y<=ui._footer.get_global_rect().position.y,step+": guide does not cover navigation")
		expect(ui.tutorial_panel.get_global_rect().position.y>=ui._header.get_global_rect().end.y,step+": guide does not cover resources")
	ui._toggle_tutorial_minimized()
	await settle()
	expect(contains(layout.safe_rect(),ui.tutorial_panel.get_global_rect()),"Collapsed guide fits the phone")
	ui.queue_free()
	main.queue_free()
	await settle()
	print("MOBILE LAYOUT: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

func ready_build(model: Node, kind: String) -> bool:
	var fixture: Script = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	return fixture.build_ready(model,kind)
