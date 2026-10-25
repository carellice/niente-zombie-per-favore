extends SceneTree
var game: Node
var layout: Node
var preferences: Node
var scene: Control
var ui: CanvasLayer
var fixture: Script
var checks: int = 0
var failures: int = 0
var capture_prefix: String = ""
func _initialize() -> void: run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("COZY UI FAIL: ",capture_prefix,": ",message)
func settle(frames: int=5) -> void:
	for frame: int in range(frames): await process_frame
func opened() -> void:
	await settle()
	ui._stop_modal_motion()
	ui._modal_motion_progress = 1.0
	ui._update_hud()
	await settle()
	if not is_instance_valid(ui.modal_scroll): return
	var balances: Control = ui.modal.find_child("DialogBalances",true,false)
	if is_instance_valid(balances): expect(balances.size.y<80,"Wallet stays compact and readable")
	expect(ui.modal_scroll.get_h_scroll_bar().max_value<=ui.modal_scroll.size.x+2,"No horizontal overflow")
	if layout.android_phone():
		expect(ui._modal_box.size.distance_to(layout.ui_size())<3,"Phone pages fill entire display")
		var padding: Control = ui.modal_scroll.get_node("PhonePagePadding")
		expect(padding.get_theme_constant("margin_right")>=20 and padding.get_theme_constant("margin_left")>=20,"Both content gutters")
	for button: Node in ui.modal.find_children("*","Button",true,false):
		if layout.mobile: expect(button.size.y>=layout.TOUCH_TARGET-1,"Comfortable tap target: "+str(button.name))
func check_hud() -> void:
	if not layout.android_phone(): return
	var safe: Rect2 = layout.safe_rect().grow(2)
	var inverse: Transform2D = ui.root.get_global_transform_with_canvas().affine_inverse()
	var bounds: Array[Rect2] = []
	for node: Node in ui.hud.find_children("*","Control",true,false):
		if not node.is_visible_in_tree() or (not node is Button and not node.has_meta("hud_card")): continue
		var transform: Transform2D = inverse*node.get_global_transform_with_canvas()
		var rect: Rect2 = Rect2(transform*Vector2.ZERO,node.size)
		expect(safe.encloses(rect),"HUD control stays inside safe area: "+str(node.name))
		for previous: Rect2 in bounds: expect(not rect.grow(-1).intersects(previous.grow(-1)),"HUD controls have separate hit rectangles")
		bounds.append(rect)

func tap(node_name: String) -> void:
	var button: Button = ui.modal.find_child(node_name,true,false)
	expect(is_instance_valid(button),"Button exists: "+node_name)
	if not is_instance_valid(button): return
	if ui.modal_scroll.is_ancestor_of(button): ui.modal_scroll.ensure_control_visible(button)
	await settle()
	var point: Vector2 = button.get_global_transform_with_canvas()*(button.size*0.5)
	for down: bool in [true,false]:
		if layout.mobile:
			var finger: InputEventScreenTouch = InputEventScreenTouch.new()
			finger.index = 0
			finger.position = point
			finger.pressed = down
			root.push_input(finger,true)
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.device = InputEvent.DEVICE_ID_EMULATION if layout.mobile else 0
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = down
		root.push_input(event,true)
		await process_frame
	await opened()
func capture(name: String) -> void:
	var folder: String = OS.get_environment("NZPF_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name()=="headless": return
	if is_instance_valid(ui.modal_scroll): ui.modal_scroll.scroll_vertical = 0
	await settle()
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(folder.path_join("COZY-"+capture_prefix+"-"+name+".png"))==OK,"Capture "+name)
func fresh() -> void:
	ui._close_modal()
	game._new_game()
	game._is_loading = true
	game.skip_tutorial()
	game.coins = 12000
	game.supplies = 500
	for kind: String in ["residence","residence","cafe","garden","workshop","clinic","bakery","waterworks","tailor"]: fixture.build_ready(game,kind)
	for b: Dictionary in game.buildings:
		if b.type=="residence": continue
		var c: Dictionary = game._make_citizen()
		game.citizens.append(c)
		game.assign(c.id,b.id)
	game.community.parts = 30
	game.community.discoveries = ["minimarket","station","depot"]
	game.community.projects = ["home","pantry","radio"]
	ui.building_tab = "production"
	ui.journal_tab = "projects"
	ui._start_game()
	ui.toast_stack.hide()
func run() -> void:
	game = root.get_node("Game")
	layout = root.get_node("DeviceLayout")
	preferences = root.get_node("Preferences")
	game.set_process(false)
	fixture = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	var data: String = OS.get_environment("NZPF_TEST_DATA_DIR")
	if data.is_empty(): data = ProjectSettings.globalize_path("res://.runtime/cozy-ui")
	DirAccess.make_dir_recursive_absolute(data)
	game.save_path = data.path_join("colony.json")
	preferences.settings_path = data.path_join("preferences.cfg")
	for profile: Array in [["DESKTOP",Vector2i(1440,900),false,0.0],["PHONE169",Vector2i(1920,1080),true,400.0],["PHONE",Vector2i(2400,1080),true,400.0],["TABLET",Vector2i(2048,1536),true,800.0]]:
		if is_instance_valid(scene):
			scene.queue_free()
			await settle()
		root.min_size = Vector2i.ZERO
		root.size = profile[1]
		layout.mobile = profile[2]
		layout.preview_android_shortest_dp = profile[3]
		layout.preview_insets = Vector4(24,6,40,8) if profile[2] else Vector4.ZERO
		preferences.apply_settings({"interface_size":"compact","sound_enabled":false,"screen_shake":false,"reduced_motion":false,"fullscreen":false},false)
		layout.refresh()
		scene = load("res://main.tscn").instantiate()
		if scene.get_script()==null:
			expect(false,"Production scene compiles")
			quit(1)
			return
		root.add_child(scene)
		scene.set_process(false)
		ui = scene.ui
		await settle()
		for scale_name: String in ["compact","medium","large"]:
			capture_prefix = str(profile[0])+"-"+scale_name
			preferences.apply_settings({"interface_size":scale_name},false)
			layout.refresh()
			fresh()
			await settle()
			check_hud()
			if scale_name=="compact":
				scene.focus_city()
				scene._update_camera(3)
				scene._process(0)
				await capture("HUD-CITTA")
				scene.focus_defense()
				scene._update_camera(3)
				scene._process(0)
				await capture("HUD-DIFESA")
			ui.show_building(game.buildings[3].id)
			await opened()
			expect(game.management_open,"Inspection protects combat")
			if scale_name=="compact": await capture("BOTTEGA")
			await tap("Tab_service")
			expect(ui.building_tab=="service","Contribution tab actually responds")
			await tap("VillageService")
			expect(game.buildings[3].get("service",{}).get("status","")=="working","UI starts actual harvest")
			game.Cozy.tick(game,120)
			ui._update_hud()
			await tap("VillageService")
			expect(game.buildings[3].get("service",{}).get("status","")=="idle","UI collects harvest")
			await tap("Tab_upgrades")
			if scale_name=="compact": await capture("MIGLIORIE")
			ui._show_build()
			await opened()
			if scale_name=="compact": await capture("COSTRUISCI")
			ui._show_armory()
			await opened()
			if scale_name=="compact": await capture("ARMERIA")
			await tap("WeaponAction_sniper")
			expect(game.weapon=="sniper","Armory equips purchased weapon")
			ui._show_citizens()
			await opened()
			if scale_name=="compact": await capture("CITTADINI")
			ui._show_citizen_equipment(game.citizens[0].id)
			await opened()
			ui._show_quests()
			await opened()
			if scale_name=="compact": await capture("DIARIO")
			await tap("Tab_discoveries")
			expect(ui.journal_tab=="discoveries","Discovery tab responds")
			await tap("Tab_goals")
			ui._show_expeditions()
			await opened()
			if scale_name=="compact": await capture("SPEDIZIONI")
			await tap("ExpeditionZone_1")
			expect(ui.expedition_step==1,"Destination drill down")
			ui._set_expedition_step(2)
			await opened()
			game._spawn_visitor()
			game.visitors[0].x = game.visitor_destination(0)
			ui.show_visitor(game.visitors[0].id)
			await opened()
			if scale_name=="compact": await capture("ACCOGLIENZA")
			await tap("ObserveVisitor")
			expect(game.visitors[0].get("observation","")=="waiting","Observation starts through touch")
			ui._show_pause()
			await opened()
			if scale_name=="compact": await capture("PAUSA")
			ui._show_settings()
			await opened()
			if scale_name=="compact": await capture("IMPOSTAZIONI")
			ui.show_gate()
			await opened()
			expect(ui.modal.find_child("RepairWithMaterials",true,false).disabled,"Material repairs cannot charge for a healthy gate")
			ui.show_demolition(game.buildings[2].id)
			await opened()
			ui.show_help()
			await opened()
			ui._show_credits()
			await opened()
			ui._confirm_reset()
			await opened()
			ui._close_modal()
			expect(not game.management_open,"Closing releases combat protection")
			ui.show_main_menu()
			await settle()
			if scale_name=="compact": await capture("MENU")
			ui._start_game()
	ui._close_modal()
	scene.queue_free()
	await create_timer(1.6).timeout
	print("COZY UI: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
