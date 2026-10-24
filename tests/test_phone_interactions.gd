extends SceneTree
## Phone menus and real transactions, then a two-dimensional world gesture.
var checks: int = 0
var failures: int = 0
var game: Node
var layout: Node
var ui: CanvasLayer
var scene: Control

func _initialize() -> void: run.call_deferred()
func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("PHONE INPUT FAIL: ",label)
func settle(frames: int=6) -> void:
	for frame: int in range(frames): await process_frame
func finish_page() -> void:
	await settle()
	ui._stop_modal_motion()
	ui._modal_motion_progress = 1.0
	await settle()
func find_button(node: Node, text: String) -> Button:
	for button: Node in node.find_children("*","Button",true,false):
		if button.text==text: return button
		for label: Node in button.find_children("*","Label",true,false):
			if label.text==text: return button
	return null
func pointer(point: Vector2, down: bool) -> void:
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.position = point
	touch.index = 0
	touch.pressed = down
	root.push_input(touch,true)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.device = InputEvent.DEVICE_ID_EMULATION
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	root.push_input(event,true)
	await process_frame
func tap(button: Control) -> void:
	expect(is_instance_valid(button),"The actual visible action exists")
	if not is_instance_valid(button): return
	if is_instance_valid(ui.modal_scroll) and ui.modal_scroll.is_ancestor_of(button):
		ui.modal_scroll.ensure_control_visible(button)
		await settle()
	var point: Vector2 = button.get_global_transform_with_canvas()*(button.size*0.5)
	await pointer(point,true)
	await pointer(point,false)
	await finish_page()
func run() -> void:
	game = root.get_node("Game")
	layout = root.get_node("DeviceLayout")
	var preferences: Node = root.get_node("Preferences")
	var data: String = OS.get_environment("NZPF_TEST_DATA_DIR")
	if data.is_empty(): data = ProjectSettings.globalize_path("res://.runtime/phone-page-input")
	DirAccess.make_dir_recursive_absolute(data)
	game.save_path = data.path_join("colony.json")
	preferences.settings_path = data.path_join("preferences.cfg")
	preferences.apply_settings({"sound_enabled":false,"fullscreen":false,"interface_size":"compact"},false)
	game.set_process(false)
	game._new_game()
	game.skip_tutorial()
	game.coins = 10000
	game.supplies = 1000
	ready_build(game,"residence")
	ready_build(game,"cafe")
	for index: int in range(4): game.citizens.append(game._make_citizen())
	layout.mobile = true
	layout.preview_android_shortest_dp = 400.0
	layout.preview_insets = Vector4(12,8,40,10)
	root.min_size = Vector2i.ZERO
	root.size = Vector2i(1920,1080)
	layout.refresh()
	Input.emulate_touch_from_mouse = true
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	ui = scene.ui
	await settle()
	for mode: String in ["compact","medium","large"]:
		preferences.apply_settings({"interface_size":mode},false)
		await settle()
		var menu_safe: Rect2 = layout.safe_rect()
		for caption: String in ["Nuova partita","Impostazioni","Crediti","Esci"]:
			var action: Button = find_button(ui.menu_layer,caption)
			expect(action!=null and menu_safe.encloses(action.get_global_rect()),mode+": every main menu tile fits and retains a safe margin")
	preferences.apply_settings({"interface_size":"compact"},false)
	await settle()
	await tap(find_button(ui.menu_layer,"Impostazioni"))
	expect(ui.panel_kind=="settings" and ui.main_menu_active,"The redesigned menu opens its real settings page")
	for size: String in ["large","medium","compact"]:
		await tap(ui.modal.find_child("InterfaceSize_"+size,true,false))
		expect(preferences.interface_size==size,"The live phone interface size choice is applied")
		expect(ui._phone_page.size.x<=ui.modal_scroll.size.x-46,"Changing interface size keeps the right padding intact")
	await tap(ui.modal.find_child("PhoneClose",true,false))
	expect(ui.main_menu_active and not is_instance_valid(ui.modal),"The rail close button returns to the menu")
	await tap(ui.menu_layer.find_child("PlayButton",true,false))
	expect(not ui.main_menu_active and not scene.in_main_menu,"The primary play control starts the actual game")
	ui._show_pause()
	await finish_page()
	expect(game.paused and ui.modal_content.find_child("PauseResume",true,false)!=null,"Pause gives Resume a distinct primary action")
	await tap(ui.modal_content.find_child("PauseSettings",true,false))
	expect(game.paused and ui.panel_kind=="settings","Pause settings keep the simulation stopped")
	await tap(ui.modal.find_child("PhoneClose",true,false))
	expect(game.paused and ui.panel_kind=="pause","Back from settings returns to pause instead of resuming unexpectedly")
	await tap(ui.modal_content.find_child("PauseHelp",true,false))
	await tap(ui.modal.find_child("PhoneClose",true,false))
	expect(game.paused and ui.panel_kind=="pause","Back from the guide also returns to pause")
	await tap(ui.modal_content.find_child("PauseSave",true,false))
	expect(ui.modal_content.find_child("PauseSaveStatus",true,false).text=="Partita salvata." and FileAccess.file_exists(game.save_path),"Manual saving has visible, truthful feedback")
	await tap(ui.modal_content.find_child("PauseResume",true,false))
	expect(not game.paused and not scene.panel_open,"Resume explicitly restarts the game")
	ui._show_pause()
	await finish_page()
	await tap(ui.modal_content.find_child("PauseMainMenu",true,false))
	expect(ui.main_menu_active and game.paused,"The clearly labelled menu action leaves gameplay paused")
	await tap(ui.menu_layer.find_child("PlayButton",true,false))
	expect(not game.paused and not ui.main_menu_active,"Continue restores the same colony after leaving pause")
	ui._show_armory()
	await finish_page()
	var before_coins: float = game.coins
	await tap(ui.modal_content.find_child("WeaponAction_shotgun",true,false))
	expect(game.weapon=="shotgun" and game.owned_weapons.has("shotgun") and game.coins<before_coins,"A weapon tile buys and equips the selected gun")
	var before_ammo: int = game.ammo
	await tap(ui.modal_content.find_child("BuyAmmo",true,false))
	expect(game.ammo==before_ammo+30,"Scrolling to the inline ammo section performs the real purchase")
	await tap(ui.modal_content.find_child("WeaponDetails_sniper",true,false))
	expect(ui.panel_kind=="weapon_details","The weapon illustration opens the detailed phone page")
	await tap(ui.modal.find_child("PhoneClose",true,false))
	ui._show_expeditions()
	await finish_page()
	var chosen: Button = ui.modal_content.find_child("ExpeditionZone_1",true,false)
	var supplies_before: int = game.supplies
	await tap(chosen)
	expect(ui.selected_zone==1 and ui.expedition_step==1,"Selecting a phone destination shows its costs, rewards and trade-offs")
	await tap(ui.modal_actions.find_child("PrepareTeam",true,false))
	expect(ui.expedition_step==2 and game.supplies==supplies_before,"Preparing the team does not spend supplies")
	var select: Button = find_button(ui.modal_content,"Seleziona")
	await tap(select)
	expect(ui.selected_members.size()==1,"Team selection remains interactive in the scroll page")
	await tap(ui.modal_actions.find_child("LaunchExpedition",true,false))
	expect(game.expedition.status=="running","The inline departure action launches a real expedition")
	ui._close_modal()
	ui._show_build()
	await finish_page()
	var bakery_price: int = game.next_build_cost("bakery")
	var coins_before_build: float = game.coins
	var buildings_before: int = game.buildings.size()
	await tap(ui.modal_content.find_child("BuildAction_bakery",true,false))
	expect(game.buildings.size()==buildings_before+1 and game.buildings.back().type=="bakery" and game.coins==coins_before_build-bakery_price,"The bakery's uniform card builds the correct shop for its displayed price")
	var restore_coins: float = game.coins
	game.coins = 0
	ui._show_build()
	await finish_page()
	for action: Node in ui.modal_content.find_children("BuildAction_*","Button",true,false):
		expect(action.disabled,"Unaffordable construction is disabled: "+action.name)
	game.coins = restore_coins
	ui._close_modal()
	ui.show_building(int(game.buildings[1].id))
	await finish_page()
	# The second rail control is the building guide; it stays outside the scroll.
	var rail: VBoxContainer = ui.modal.find_child("PhoneControls",true,false)
	await tap(rail.get_child(1))
	expect(ui.panel_kind=="building_help","The building question mark remains reachable in the new rail")
	await tap(ui.modal.find_child("PhoneClose",true,false))
	ui.show_building(int(game.buildings[1].id))
	await finish_page()
	await tap(find_button(ui.modal_content,"Gestisci i lavoratori"))
	var assign: Button
	for candidate: Node in ui.modal_content.find_children("*","Button",true,false):
		if candidate.text=="Assegna al negozio" and not candidate.disabled:
			assign = candidate
			break
	await tap(assign)
	expect(game.buildings[1].workers.size()==1,"The phone worker page assigns an available citizen")
	await tap(find_button(ui.modal_actions,"← Torna al negozio"))
	var restock: Button
	for candidate: Node in ui.modal_content.find_children("*","Button",true,false):
		if candidate.text.begins_with("Avvia rifornimento"):
			restock = candidate
			break
	await tap(restock)
	expect(game.buildings[1].products[0].status=="restocking","The simplified shop page starts real production")
	ui._close_modal()
	# Vertical swipes are consumed as drags, without a vertical camera or a click.
	scene.focus_city()
	scene.zoom = scene.target_zoom
	scene.camera_x = scene.target_camera
	var camera_before: float = scene.target_camera
	var ground_before: float = scene._ground()
	var start: Vector2 = Vector2(scene.size.x*0.5,scene.size.y*0.4)
	await pointer(start,true)
	for index: int in range(1,9):
		var drag: InputEventScreenDrag = InputEventScreenDrag.new()
		drag.position = start+Vector2(0,index*20)
		drag.relative = Vector2(0,20)
		drag.index = 0
		root.push_input(drag,true)
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.device = InputEvent.DEVICE_ID_EMULATION
		motion.position = start+Vector2(0,index*20)
		motion.global_position = motion.position
		motion.relative = Vector2(0,20)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion,true)
		await process_frame
	await pointer(start+Vector2(0,160),false)
	scene._update_camera(1.0)
	expect(is_equal_approx(scene._ground(),ground_before) and is_equal_approx(scene.target_camera,camera_before),"A vertical swipe cannot move the view in either direction")
	expect(not scene.panel_open and not is_instance_valid(ui.modal),"Dragging the building never opens its dialog")
	expect(scene.get("vertical_pan")==null and scene.get("target_vertical_pan")==null,"The world has no vertical camera state")
	scene.focus_gate()
	scene._update_camera(1.5)
	expect(is_equal_approx(scene._ground(),ground_before),"Gate navigation keeps the same street height")
	var zoom_before: float = scene.target_zoom
	var first: Vector2 = Vector2(scene.size.x*0.4,scene.size.y*0.4)
	await pointer(first,true)
	var second: InputEventScreenTouch = InputEventScreenTouch.new()
	second.index = 1
	second.position = first+Vector2(100,0)
	second.pressed = true
	root.push_input(second,true)
	for width: int in [110,150]:
		var pinch: InputEventScreenDrag = InputEventScreenDrag.new()
		pinch.index = 1
		pinch.position = first+Vector2(width,0)
		pinch.relative = Vector2(40,0)
		root.push_input(pinch,true)
		await process_frame
	expect(scene.target_zoom>zoom_before and scene.target_zoom<=scene._zoom_max(),"Additional zoom is a deliberate two-finger gesture")
	expect(not scene.dragging and is_equal_approx(scene._ground(),ground_before),"Pinching cannot pan the world vertically")
	second.pressed = false
	root.push_input(second,true)
	await pointer(first,false)
	expect(scene.touch_points.is_empty() and not scene.panel_open,"Releasing a pinch cannot open a building or leave a stuck gesture")
	scene.focus_gate()
	scene._update_camera(1.5)
	game.threats.clear()
	game.weapon = "pistol"
	game.shot_cooldown = 0
	game._add_threat("walker",100.0)
	var target: Dictionary = game.threats[0]
	var point: Vector2 = Vector2(scene._sx(target.x),scene._ground()-32*scene._actor_zoom())
	await pointer(point,true)
	await pointer(point,false)
	expect(game.threats.is_empty(),"The enlarged target retains its correct touch area after vertical navigation")
	scene.queue_free()
	await settle()
	print("PHONE INTERACTIONS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

func ready_build(model: Node, kind: String) -> bool:
	var fixture: Script = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	return fixture.build_ready(model,kind)
