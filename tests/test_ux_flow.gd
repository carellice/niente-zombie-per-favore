extends SceneTree
## Real actions, persistence, pinned controls and scaled viewport input.

var checks: int = 0
var failures: int = 0
var main: Control
var ui: CanvasLayer
var game: Node
var preferences: Node
var layout: Node
var captures: bool = false

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("UX FAIL: ",message)

func settle(frames: int = 6) -> void:
	for frame: int in range(frames): await process_frame

func finish_opening() -> void:
	await settle()
	ui._stop_modal_motion()
	ui._modal_motion_progress = 1.0
	await settle()

func button_named(node: Node, caption: String) -> Button:
	for button: Node in node.find_children("*","Button",true,false):
		if button.text==caption: return button
	return null

func tap(control: Control) -> void:
	expect(control!=null and is_instance_valid(control),"A real control exists for the tap")
	if control==null: return
	var point: Vector2 = control.get_global_transform_with_canvas()*(control.size*0.5)
	var hover: InputEventMouseMotion = InputEventMouseMotion.new()
	hover.device = InputEvent.DEVICE_ID_EMULATION
	hover.position = point
	hover.global_position = point
	root.push_input(hover,true)
	for down: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.device = InputEvent.DEVICE_ID_EMULATION
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = down
		root.push_input(event,true)
		await process_frame
	await finish_opening()

func capture(label: String) -> void:
	if not captures or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/UX-"+label+".png")

func check_dialog(label: String, pinned: bool = true) -> void:
	var box: Rect2 = ui._modal_box.get_global_rect()
	expect(layout.safe_rect().grow(2).encloses(box),label+": dialog respects safe area")
	expect(ui.modal_scroll.size.x+2>=ui.modal_content.get_combined_minimum_size().x,label+": content has no horizontal clipping")
	if not pinned: return
	expect(ui.modal_actions.visible,label+": important actions have a fixed area")
	var before: Rect2 = ui.modal_actions.get_global_rect()
	ui.modal_scroll.scroll_vertical = int(ui.modal_scroll.get_v_scroll_bar().max_value)
	await settle()
	expect(before.is_equal_approx(ui.modal_actions.get_global_rect()),label+": scrolling does not move the actions")
	expect(box.grow(2).encloses(ui.modal_actions.get_global_rect()),label+": actions stay inside the cabinet")
	for button: Node in ui.modal_actions.find_children("*","Button",true,false):
		expect(box.grow(2).encloses(button.get_global_rect()),label+": pinned button fits: "+button.text)
		expect(not ui.modal_scroll.is_ancestor_of(button),label+": action is independent of the scrolling list")

func run() -> void:
	game = root.get_node("Game")
	preferences = root.get_node("Preferences")
	layout = root.get_node("DeviceLayout")
	var data: String = OS.get_environment("NZPF_TEST_DATA_DIR")
	if data.is_empty(): data = ProjectSettings.globalize_path("res://.runtime/ux-flow")
	DirAccess.make_dir_recursive_absolute(data)
	game.save_path = data.path_join("colony.json")
	preferences.settings_path = data.path_join("preferences.cfg")
	preferences.apply_settings({"interface_size":"compact","fullscreen":false},false)
	game.set_process(false)
	game._new_game()
	game.skip_tutorial()
	game.coins = 20000
	game.supplies = 1000
	ready_build(game,"residence")
	ready_build(game,"residence")
	ready_build(game,"cafe")
	for index: int in range(6): game.citizens.append(game._make_citizen())
	game._spawn_visitor()
	layout.mobile = true
	root.min_size = Vector2i.ZERO
	Input.emulate_touch_from_mouse = true
	captures = OS.get_cmdline_user_args().has("--capture-ux")
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	ui = main.ui
	main.set_process(false)
	await settle()
	ui._start_game()
	await settle()
	# Every preference must remain usable in all supported landscape formats.
	var quick: bool = OS.get_cmdline_user_args().has("--quick-ux")
	var screens: Array = [Vector2i(2400,1080)] if quick else [Vector2i(1920,1080),Vector2i(2400,1080),Vector2i(2560,1600),Vector2i(2048,1536)]
	for screen: Vector2i in screens:
		root.size = screen
		layout.preview_insets = Vector4(22,0,0,8)
		await settle()
		for size: String in (["compact"] if quick else ["compact","medium","large"]):
			ui._close_modal()
			preferences.apply_settings({"interface_size":size},false)
			layout.refresh()
			await settle()
			var label: String = "%dx%d %s" % [screen.x,screen.y,size]
			ui.show_main_menu()
			await settle()
			expect(layout.safe_rect().grow(2).encloses(ui._menu_cabinet.get_global_rect()),label+": main menu fits")
			for button: Node in ui._menu_cabinet.find_children("*","Button",true,false):
				expect(layout.safe_rect().grow(2).encloses(button.get_global_rect()),label+": menu action stays reachable: "+button.text)
			if screen==Vector2i(2400,1080) and size=="large": await capture("MENU-GRANDE")
			ui._start_game()
			await settle()
			expect(layout.safe_rect().grow(2).encloses(ui._header.get_global_rect()),label+": header fits")
			expect(layout.safe_rect().grow(2).encloses(ui._footer.get_global_rect()),label+": navigation fits")
			ui.set_world_context(true)
			expect(layout.safe_rect().grow(2).encloses(ui._context_root.get_global_rect()),label+": contextual HUD fits")
			expect(ui._defense_context.size.x+1>=ui._defense_context.get_combined_minimum_size().x,label+": defense information fits its card")
			ui.show_visitor(int(game.visitors[0].id))
			await finish_opening()
			await check_dialog(label+" admission")
			ui.modal_scroll.scroll_vertical = 0
			if screen==Vector2i(2400,1080) and size=="compact": await capture(label+"-AMMISSIONE")
			ui._show_armory()
			await finish_opening()
			await check_dialog(label+" armory")
			ui.modal_scroll.scroll_vertical = 0
			if screen==Vector2i(2400,1080) and size=="compact": await capture(label+"-ARMERIA")
			ui._show_expeditions()
			await finish_opening()
			await check_dialog(label+" destinations",false)
			if screen==Vector2i(2400,1080) and size=="compact":
				ui.modal_scroll.scroll_vertical = 0
				await settle(2)
				await capture(label+"-DESTINAZIONI")
			ui._set_expedition_step(1)
			await finish_opening()
			await check_dialog(label+" expedition details")
			ui._set_expedition_step(2)
			await finish_opening()
			await check_dialog(label+" team")
			ui._show_settings()
			await finish_opening()
			await check_dialog(label+" settings")
			ui.show_gate()
			await finish_opening()
			await check_dialog(label+" gate")
	# Persistence and real taps while the canvas changes scale.
	ui._show_settings()
	await finish_opening()
	var coins_before: float = game.coins
	var camera_before: float = main.camera_x
	var count_before: int = game.citizens.size()
	var previous_scale: float = 0.0
	for size: String in ["compact","medium","large"]:
		var choice: Button = ui.modal.find_child("InterfaceSize_"+size,true,false)
		ui.modal_scroll.ensure_control_visible(choice)
		await settle()
		await tap(choice)
		expect(preferences.interface_size==size and layout.ui_scale()>previous_scale,"Real tap applies the "+size+" interface scale")
		previous_scale = layout.ui_scale()
	await capture("IMPOSTAZIONI-GRANDE")
	preferences.interface_size = "compact"
	expect(preferences.load_settings()==OK and preferences.interface_size=="large","Interface size survives a settings reload")
	expect(game.coins==coins_before and game.citizens.size()==count_before and main.camera_x==camera_before,"Changing interface scale preserves the colony and world camera")
	preferences.apply_settings({"interface_size":"compact"},false)
	root.size = Vector2i(2400,1080)
	await settle()
	layout.refresh()
	ui._close_modal()
	ui._show_expeditions()
	await finish_opening()
	ui._select_zone(8)
	await finish_opening()
	var supplies_before: int = game.supplies
	await tap(ui.modal_actions.find_child("PrepareTeam",true,false))
	expect(ui.expedition_step==2 and ui.selected_zone==8,"Preparation retains the selected destination")
	expect(game.supplies==supplies_before,"Preparing a team does not spend supplies")
	for index: int in range(3):
		var select: Button = button_named(ui.modal_content,"Seleziona")
		ui.modal_scroll.ensure_control_visible(select)
		await settle()
		await tap(select)
		expect(ui.selected_members.size()==index+1,"A real tap adds member %d to the team" % (index+1))
	var members: Array = ui.selected_members.duplicate()
	await tap(ui.modal_actions.find_child("BackToDetails",true,false))
	expect(ui.expedition_step==1 and ui.selected_members==members,"Back to details retains the selected team")
	await tap(ui.modal_actions.find_child("BackToDestinations",true,false))
	expect(ui.expedition_step==0 and ui.selected_members==members,"Back retains the selected team")
	ui._select_zone(1)
	await finish_opening()
	await tap(ui.modal_actions.find_child("PrepareTeam",true,false))
	expect(ui.selected_zone==1 and ui.selected_members==members,"A changed destination retains the team")
	await capture("2400x1080-SQUADRA")
	var launch: Button = ui.modal_actions.find_child("LaunchExpedition",true,false)
	expect(not launch.disabled,"Complete affordable team can depart")
	var cost: int = game.expedition_cost(1)
	await tap(launch)
	expect(game.expedition.status=="running" and game.supplies==supplies_before-cost,"Departure charges the chosen destination exactly once")
	expect(game.expedition.members==members,"The actual selected citizens depart")
	game._tick_expedition(float(game.expedition.duration))
	ui._show_expeditions()
	await finish_opening()
	expect(ui.modal_actions.find_child("ClaimExpedition",true,false)!=null,"Returned rewards have a pinned claim action")
	await tap(ui.modal_actions.find_child("ClaimExpedition",true,false))
	expect(game.expedition.status=="idle" and ui.expedition_step==0,"Claiming rewards returns to destination selection")
	# Catalog -> detail -> purchase -> catalog keeps identity and scroll state.
	ui._show_armory()
	await finish_opening()
	var inspect: Button = ui.modal_content.find_child("WeaponDetails_shotgun",true,false)
	ui.modal_scroll.ensure_control_visible(inspect)
	await settle()
	var catalog_scroll: int = ui.modal_scroll.scroll_vertical
	await tap(inspect)
	expect(ui.panel_kind=="weapon_details" and ui.panel_id==1,"Tapping the shotgun opens its own specifications")
	await capture("2400x1080-DETTAGLIO-ARMA")
	coins_before = game.coins
	supplies_before = game.supplies
	await tap(ui.modal_actions.find_child("WeaponDetailsAction",true,false))
	expect(game.weapon=="shotgun" and game.coins==coins_before-620 and game.supplies==supplies_before-24,"Detail purchase uses the authoritative weapon cost")
	ui._return_to_armory()
	await finish_opening()
	expect(abs(ui.modal_scroll.scroll_vertical-catalog_scroll)<=2,"Returning from details restores the catalog position")
	var ammo_before: int = game.ammo
	coins_before = game.coins
	await tap(ui.modal_actions.find_child("BuyAmmo",true,false))
	expect(game.ammo==ammo_before+30 and game.coins==coins_before-40,"Pinned ammunition action purchases exactly once")
	# Attention shortcuts open the relevant product rather than the top of a shop.
	ui._close_modal()
	var cafe: Dictionary = game.buildings[2]
	game.assign(int(game.citizens[0].id),int(cafe.id))
	game.assign(int(game.citizens[1].id),int(cafe.id))
	cafe.products[0].status = "ready"
	cafe.products[1].status = "empty"
	main.focus_city()
	main.camera_x = main.target_camera
	main._process(0.0)
	ui._update_hud()
	await settle()
	expect(not ui._defense_view and ui._ready_shop_button.visible and ui._empty_shop_button.visible,"Village context exposes ready and empty products")
	await capture("2400x1080-VILLAGGIO")
	await tap(ui._ready_shop_button)
	expect(ui.panel_kind=="building" and ui.panel_id==int(cafe.id),"Ready shortcut opens the correct shop")
	if ui.panel_kind!="building":
		quit(1)
		return
	var stock: Button
	for control: Node in ui.modal_content.find_children("*","Button",true,false):
		if control.text.begins_with("Riempi gli scaffali"): stock = control; break
	expect(stock!=null and ui.modal_scroll.get_global_rect().grow(2).encloses(stock.get_global_rect()),"Attention shortcut reveals the actionable product")
	ui._close_modal()
	var expedition_before: Dictionary = game.expedition.duplicate(true)
	game.expedition = {"status":"running","remaining":123.0}
	root.size = Vector2i(2048,1536)
	await settle()
	for size: String in ["compact","medium","large"]:
		preferences.apply_settings({"interface_size":size},false)
		ui._update_hud()
		await settle()
		expect(ui._town_context.get_combined_minimum_size().x<=ui._town_context.size.x+1,"All three village shortcuts fit the "+size+" tablet layout")
		expect(ui._expedition_status_button.is_visible_in_tree() and "02:03" in ui._expedition_status_button.get_meta("caption").text,"Village shortcut exposes the expedition countdown")
	game.expedition = expedition_before
	preferences.apply_settings({"interface_size":"compact"},false)
	root.size = Vector2i(2400,1080)
	await settle()
	main.focus_gate()
	main.camera_x = main.target_camera
	main._process(0.0)
	game.weapon = "sniper"
	game.ammo = 8
	game.shot_cooldown = 0.7
	ui._update_defense_status()
	expect(ui._defense_view and ui._defense_context.visible and not ui._town_context.visible,"Gate view switches to defense information")
	expect("Precisione" in ui._defense_ammo.text and "8" in ui._defense_ammo.text and ui._defense_weapon.kind=="sniper","Defense HUD identifies the actual weapon and ammunition")
	expect("Ricarica" in ui._defense_status.text and ui._defense_ready.value<100,"Cooldown is visible during weapon recovery")
	await capture("2400x1080-DIFESA")
	game.shot_cooldown = 0.0
	ui._update_defense_status()
	expect(ui._defense_status.text=="Pronto" and ui._defense_ready.value==100,"Defense HUD becomes ready with the weapon")
	# Recreate the scene so these checks use the desktop header/footer builders.
	main.queue_free()
	await settle()
	layout.mobile = false
	layout.preview_insets = Vector4.ZERO
	root.size = Vector2i(1440,900)
	preferences.apply_settings({"interface_size":"compact"},false)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	ui = main.ui
	await settle()
	for size: String in ["compact","medium","large"]:
		preferences.apply_settings({"interface_size":size},false)
		ui.show_main_menu()
		await settle()
		expect(layout.safe_rect().grow(2).encloses(ui._menu_cabinet.get_global_rect()),"Desktop "+size+": main menu fits")
		ui._start_game()
		await settle()
		expect(layout.safe_rect().grow(2).encloses(ui._header.get_global_rect()),"Desktop "+size+": header fits")
		expect(layout.safe_rect().grow(2).encloses(ui._footer.get_global_rect()),"Desktop "+size+": navigation fits")
		ui._show_armory()
		await finish_opening()
		await check_dialog("Desktop "+size+" armory")
		if size=="compact":
			ui.modal_scroll.scroll_vertical = 0
			await capture("DESKTOP-ARMERIA")
		ui._close_modal()
	preferences.apply_settings({"interface_size":"medium"},false)
	game._new_game()
	expect(preferences.interface_size=="medium","A new colony preserves a nondefault interface preference")
	preferences.apply_settings({"interface_size":"compact"},false)
	ui._close_modal()
	main.queue_free()
	await settle()
	print("UX FLOW: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

func ready_build(model: Node, kind: String) -> bool:
	var fixture: Script = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	return fixture.build_ready(model,kind)
