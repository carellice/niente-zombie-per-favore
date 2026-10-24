extends SceneTree
## Device classification, fullscreen phone dialogs and actual world draw sizes.

var checks: int = 0
var failures: int = 0
var game: Node
var layout: Node
var preferences: Node
var scene: Control
var ui: CanvasLayer
var snapshots: Dictionary = {}
var captures: bool = false

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("ANDROID PHONE FAIL: ",message)

func settle(frames: int = 6) -> void:
	for frame: int in range(frames): await process_frame

func finish_opening() -> void:
	await settle()
	ui._stop_modal_motion()
	ui._modal_motion_progress = 1.0
	await settle()

func capture(name: String) -> void:
	if not captures or DisplayServer.get_name()=="headless": return
	scene.queue_redraw()
	await settle(2)
	await RenderingServer.frame_post_draw
	var directory: String = OS.get_environment("NZPF_CAPTURE_DIR")
	if directory.is_empty(): directory = ProjectSettings.globalize_path("res://docs")
	root.get_texture().get_image().save_png(directory.path_join("ANDROID-"+name+".png"))

func tap(point: Vector2) -> void:
	var hover: InputEventMouseMotion = InputEventMouseMotion.new()
	hover.position = point
	hover.global_position = point
	root.push_input(hover,true)
	for down: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.device = InputEvent.DEVICE_ID_EMULATION
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
		await process_frame
	await settle()

func open_panel(kind: String) -> void:
	ui._close_modal()
	game.expedition = {"status":"idle"}
	match kind:
		"armory": ui._show_armory()
		"weapon": ui._show_weapon_details("sniper")
		"settings": ui._show_settings()
		"visitor": ui.show_visitor(int(game.visitors[0].id))
		"expeditions": ui._show_expeditions()
		"expedition_running":
			game.expedition = {"status":"running","zone":1,"name":"Stazione ferroviaria","remaining":65.0,"duration":95.0,"members":[game.citizens[0].id]}
			ui._show_expeditions()
		"expedition_ready":
			game.expedition = {"status":"ready","zone":1,"success":false,"members":[game.citizens[0].id],"rewards":{"coins":124,"supplies":15,"gems":0,"ammo":7}}
			ui._show_expeditions()
		"expedition_details": ui._show_expeditions(); ui._set_expedition_step(1)
		"team": ui._show_expeditions(); ui._set_expedition_step(2)
		"citizens": ui._show_citizens()
		"equipment": ui._show_citizen_equipment(int(game.citizens[0].id))
		"building": ui.show_building(int(game.buildings[1].id))
		"building_help": ui._show_building_help(int(game.buildings[1].id))
		"assignment": ui._show_assignment(int(game.buildings[1].id))
		"job": ui._show_job_select(int(game.citizens[0].id))
		"build": ui._show_build()
		"gate": ui.show_gate()
		"pause": ui._show_pause()
		"quests": ui._show_quests()
		"help": ui.show_help()
		"credits": ui._show_credits()
		"reset": ui._confirm_reset()
		"tutorial":
			game.tutorial_stage = "intro"
			ui._show_tutorial_intro()
	await finish_opening()
	if kind=="tutorial": game.tutorial_stage = "complete"

func check_panel(label: String, phone: bool) -> void:
	expect(is_instance_valid(ui._modal_box),label+": requested panel opens")
	if not is_instance_valid(ui._modal_box): return
	var box: Rect2 = ui._modal_box.get_global_rect()
	var safe: Rect2 = layout.safe_rect()
	if phone:
		expect(box.is_equal_approx(Rect2(Vector2.ZERO,layout.ui_size())),label+": background fills the display including the notch margin")
		var contents: Rect2 = ui._phone_safe.get_child(0).get_global_rect()
		expect(safe.grow(2).encloses(contents),label+": interactive contents stay inside the safe area")
		expect(contents.position.x>=safe.position.x+15 and contents.end.x<=safe.end.x-15,label+": outer contents respect both horizontal insets")
		expect(contents.position.y>=safe.position.y+11 and contents.end.y<=safe.end.y-11,label+": contents have vertical padding beyond the safe insets")
		expect(ui._phone_page.size.x<=ui.modal_scroll.size.x-46,label+": page retains real left and right padding")
		expect(ui.modal_scroll.is_ancestor_of(ui._phone_page.get_node("PhonePageTitle")),label+": title scrolls with the content instead of occupying a fixed app bar")
	else:
		expect(safe.grow(2).encloses(box),label+": panel stays inside safe area")
		expect(box.size.y<=safe.size.y*0.85 if layout.mobile else box.size.y<safe.size.y,label+": previous windowed presentation is retained")
	expect(ui.modal_scroll.size.x+2>=ui.modal_content.get_combined_minimum_size().x,label+": content is not clipped horizontally")
	if ui.panel_kind=="build":
		var cards: int = 0
		var bottom_gap: float = -1
		for card: Node in ui.modal_content.find_children("*","VBoxContainer",true,false):
			if not card.has_meta("building_kind"): continue
			cards += 1
			var kind: String = card.get_meta("building_kind")
			var action: Button = card.find_child("BuildAction_"+kind,true,false)
			expect(action!=null,label+": "+kind+" retains its own construction action")
			if action==null: continue
			var bounds: Rect2 = card.get_global_rect()
			var button_rect: Rect2 = action.get_global_rect()
			expect(bounds.grow(1).encloses(button_rect),label+": "+kind+" action stays inside its card")
			expect(absf(button_rect.size.x-bounds.size.x)<2,label+": "+kind+" uses a full-width bottom action")
			var gap: float = bounds.end.y-button_rect.end.y
			if bottom_gap<0: bottom_gap = gap
			expect(absf(gap-bottom_gap)<2,label+": "+kind+" aligns its action like every other building")
		expect(cards==8,label+": all eight building cards, including the bakery, are present")
	if ui.modal_actions.visible:
		var actions: Rect2 = ui.modal_actions.get_global_rect()
		var close: Control = ui.modal.find_child("PhoneClose",true,false) if phone else null
		var close_rect: Rect2 = close.get_global_rect() if phone else Rect2()
		ui.modal_scroll.scroll_vertical = int(ui.modal_scroll.get_v_scroll_bar().max_value)
		await settle(2)
		if phone:
			expect(ui.modal_scroll.is_ancestor_of(ui.modal_actions),label+": actions live in the page instead of a fixed footer")
			expect(close_rect.is_equal_approx(close.get_global_rect()) and safe.encloses(close_rect),label+": closing stays available without consuming a top bar")
			for button: Node in ui.modal_actions.find_children("*","Button",true,false):
				ui.modal_scroll.ensure_control_visible(button)
				await settle(2)
				expect(ui.modal_scroll.get_global_rect().grow(2).encloses(button.get_global_rect()),label+": action remains reachable by scrolling")
		else:
			expect(actions.is_equal_approx(ui.modal_actions.get_global_rect()),label+": important actions remain pinned")
			expect(safe.grow(2).encloses(ui.modal_actions.get_global_rect()),label+": pinned actions remain reachable")
		ui.modal_scroll.scroll_vertical = 0

func setup(profile: String, pixels: Vector2i, shortest_dp: float) -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await settle()
	layout.mobile = profile!="DESKTOP"
	layout.preview_android_shortest_dp = shortest_dp
	layout.preview_insets = Vector4(24,6,12,8) if layout.mobile else Vector4.ZERO
	root.min_size = Vector2i.ZERO
	root.size = pixels
	preferences.apply_settings({"interface_size":"compact","sound_enabled":false},false)
	layout.refresh()
	game._new_game()
	game.skip_tutorial()
	game.coins = 10000
	game.supplies = 1000
	ready_build(game,"residence")
	ready_build(game,"cafe")
	for index: int in range(8): game.citizens.append(game._make_citizen())
	game._spawn_visitor()
	game.visitors[0].x = 150.0
	game.threats.append({"id":9900,"kind":"walker","x":-100.0,"hp":200.0,"max_hp":200.0,"speed":0.0,"damage":0.0,"attack_clock":1.0,"appearance":"infected"})
	await settle()
	scene = load(get_script().resource_path.get_base_dir().path_join("phone_measured_world.gd")).new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(scene)
	scene.set_process(false)
	ui = scene.ui
	await settle()
	await capture(profile+"-MENU")
	ui._start_game()
	await settle()

func sample_world() -> Dictionary:
	scene.observed.clear()
	scene.queue_redraw()
	await settle()
	return {"building":scene._building_rect(int(game.buildings[0].id)).size,"visitor":float(scene.observed.get(str(150.0),0)),"zombie":float(scene.observed.get(str(-100.0),0)),"zoom":scene.zoom}

func check_overview(label: String) -> void:
	var top: float = (layout.safe_rect().position.y+layout.PHONE_HEADER_HEIGHT+8)*layout.ui_scale()
	var bottom: float = (layout.safe_rect().end.y-layout.PHONE_FOOTER_HEIGHT)*layout.ui_scale()
	var stored_zoom: float = scene.zoom
	var stored_target: float = scene.target_zoom
	scene.zoom = scene._zoom_min()
	scene.target_zoom = scene.zoom
	for building: Dictionary in game.buildings:
		var bounds: Rect2 = scene._building_rect(int(building.id))
		expect(bounds.position.y>=top and bounds.end.y<=bottom,label+": the complete building height fits above the navigation")
	var gate: Rect2 = scene._gate_rect()
	expect(gate.position.y>=top and gate.end.y<=bottom,label+": the entire checkpoint fits in the overview")
	var soldier: Vector2 = scene._guard_post(0)
	expect(soldier.y-82.0*scene._actor_zoom()>=top and soldier.y<=bottom,label+": the tower soldier is fully visible")
	var bubble_top: float = scene._ground()-319.0*scene._building_zoom()-46.0
	expect(bubble_top>=top,label+": shop status balloons fit below the upper HUD")
	var label_bottom: float = scene._ground()+94.0+scene.body.get_descent(26)+6.0
	expect(label_bottom<=bottom,label+": workplace counters fit above the lower HUD")
	scene.zoom = stored_zoom
	scene.target_zoom = stored_target

func run() -> void:
	game = root.get_node("Game")
	layout = root.get_node("DeviceLayout")
	preferences = root.get_node("Preferences")
	var data: String = OS.get_environment("NZPF_TEST_DATA_DIR")
	if data.is_empty(): data = ProjectSettings.globalize_path("res://.runtime/android-phone-test")
	DirAccess.make_dir_recursive_absolute(data)
	game.save_path = data.path_join("colony.json")
	preferences.settings_path = data.path_join("preferences.cfg")
	game.set_process(false)
	Input.emulate_touch_from_mouse = true
	captures = OS.get_cmdline_user_args().has("--capture-phone")
	for metrics: Array in [
		[true,Vector2i(2400,1080),420,true],
		[true,Vector2i(1920,1080),480,true],
		[true,Vector2i(1280,720),320,true],
		[true,Vector2i(1920,1200),240,false],
		[true,Vector2i(2400,1080),240,false],
		[true,Vector2i(2048,1536),320,false],
		[true,Vector2i(1440,900),240,false],
		[false,Vector2i(2400,1080),420,false],
		[true,Vector2i(2400,1080),0,false]]:
		expect(layout.android_phone_for_display(metrics[0],metrics[1],metrics[2])==metrics[3],"Device classification respects Android, density and 600 dp: "+str(metrics))
	for profile: Array in [["DESKTOP",Vector2i(2400,1080),0.0],["TABLET",Vector2i(2400,1080),800.0],["PHONE",Vector2i(2400,1080),400.0],["PHONE169",Vector2i(1920,1080),400.0]]:
		var name: String = profile[0]
		var phone: bool = name.begins_with("PHONE")
		await setup(name,profile[1],profile[2])
		expect(layout.android_phone()==phone,name+": correct runtime device profile")
		if phone:
			expect(is_equal_approx(scene.zoom,scene._zoom_min()),name+": starting the game opens the complete overview")
			check_overview(name+" initial")
		scene.focus_city()
		scene.zoom = scene.target_zoom
		scene.camera_x = scene.target_camera
		await capture(name+"-VILLAGE")
		scene.focus_gate()
		scene.zoom = scene.target_zoom
		scene.camera_x = scene.target_camera
		var normal: Dictionary = await sample_world()
		expect(normal.visitor>0 and normal.zombie>0,name+": actor heights are observed from real draw calls")
		await capture(name+"-WORLD")
		scene.focus_gate()
		scene.zoom = scene.target_zoom
		scene.camera_x = scene.target_camera
		scene._zoom_button(100)
		scene.zoom = scene.target_zoom
		scene.camera_x = scene.target_camera
		var maximum: Dictionary = await sample_world()
		expect(is_equal_approx(maximum.zoom,scene._zoom_max()),name+": optional zoom respects the intended maximum")
		await capture(name+"-WORLD-MAX")
		snapshots[name] = {"normal":normal,"maximum":maximum}
		if phone:
			var reference: Dictionary = snapshots.TABLET
			for sample: String in ["normal","maximum"]:
				var camera_ratio: float = snapshots[name][sample].zoom/reference[sample].zoom
				expect(snapshots[name][sample].building.is_equal_approx(reference[sample].building*1.6*camera_ratio),name+": buildings have their own art scale at "+sample)
				expect(is_equal_approx(snapshots[name][sample].visitor,reference[sample].visitor*2.2*camera_ratio),name+": survivor art is enlarged independently of camera zoom at "+sample)
				expect(is_equal_approx(snapshots[name][sample].zombie,reference[sample].zombie*2.2*camera_ratio),name+": zombie art is enlarged independently of camera zoom at "+sample)
			expect(is_equal_approx(normal.zoom,scene._phone_overview_zoom()) and normal.zoom<1.1,name+": the default view is a fitted overview, not forced magnification")
			expect(scene._world_text_scale()==2.0,name+": world labels are twice as large")
		elif name=="TABLET":
			expect(normal.building.is_equal_approx(snapshots.DESKTOP.normal.building),"Tablet keeps the desktop world scale")
			expect(maximum.building.is_equal_approx(snapshots.DESKTOP.maximum.building),"Tablet keeps the previous maximum zoom")
		# Inverse coordinates and picking remain aligned with the enlarged art.
		game.threats[0].x = scene.camera_x+100.0
		var point: Vector2 = Vector2(scene._sx(game.threats[0].x),scene._ground()-32.0*scene._actor_zoom())
		expect(absf(scene._wx(point.x)-game.threats[0].x)<0.001,name+": world/screen conversion is consistent")
		var picked: Dictionary = scene._pick_actor(point)
		expect(picked.get("kind","")=="enemy" and int(picked.get("id",-1))==9900,name+": visible zombie has the correct hit area")
		var hp_before: float = game.threats[0].hp
		await tap(point)
		expect(game.threats[0].hp<hp_before,name+": actual viewport tap shoots the enlarged target")
		for size: String in ["compact","medium","large"]:
			if phone:
				layout.preview_insets = Vector4(12,8,40,10) if size=="medium" else Vector4(24,6,12,8)
				layout.refresh()
			preferences.apply_settings({"interface_size":size},false)
			await settle()
			if phone: check_overview(name+" "+size)
			var zoom_before: float = scene.zoom
			for kind: String in ["armory","settings","visitor","expeditions","expedition_details","team","expedition_running","expedition_ready","building","building_help","assignment","job","build","gate","pause","quests","citizens","equipment","weapon","help","credits","reset","tutorial"]:
				await open_panel(kind)
				await check_panel(name+" "+size+" "+kind,phone)
				if phone and size=="compact" and kind=="armory":
					for key: String in ["pistol","shotgun","sniper","smg"]:
						var action: Control = ui.modal_content.find_child("WeaponAction_"+key,true,false)
						ui.modal_scroll.ensure_control_visible(action)
						await settle(2)
						expect(ui.modal_scroll.get_global_rect().grow(2).encloses(action.get_global_rect()),name+": weapon action is reachable: "+key)
					ui.modal_scroll.scroll_vertical = 0
				if phone and size=="compact" and kind=="settings":
					expect(ui._settings_grid.columns==(2 if layout.safe_rect().size.x>=900 else 1),name+": settings respect the page width")
				if size=="compact" and kind in ["armory","settings","visitor","expeditions","expedition_details","team","expedition_running","expedition_ready","citizens","build","pause","building"]: await capture(name+"-"+kind.to_upper())
				if size=="compact" and kind=="build":
					ui.modal_scroll.ensure_control_visible(ui.modal_content.find_child("BuildAction_bakery",true,false))
					await settle(2)
					await capture(name+"-BUILD-BAKERY")
				if size=="compact" and kind=="expedition_details":
					ui.modal_scroll.scroll_vertical = int(ui.modal_scroll.get_v_scroll_bar().max_value)
					await settle(2)
					await capture(name+"-EXPEDITION-TRADEOFFS")
			ui._close_modal()
			expect(is_equal_approx(scene.zoom,zoom_before),name+": interface size and dialogs do not alter world zoom")
		# Fullscreen phone panels keep their safe rectangle throughout their fade.
		if phone:
			ui._show_armory()
			await settle()
			ui._stop_modal_motion()
			for progress: float in [0.1,0.5,1.0]:
				ui._modal_motion_progress = progress
				await settle(2)
				expect(ui._modal_box.get_global_rect().is_equal_approx(Rect2(Vector2.ZERO,layout.ui_size())),name+": entrance fade stays fullscreen")
			ui._close_modal()
		# Pinch/magnify input and the zoom buttons share the new limits.
		scene.in_main_menu = false
		scene.panel_open = false
		var gesture: InputEventMagnifyGesture = InputEventMagnifyGesture.new()
		gesture.factor = 20.0
		scene._unhandled_input(gesture)
		expect(is_equal_approx(scene.target_zoom,scene._zoom_max()),name+": magnify input respects the zoom maximum")
		gesture.factor = 0.01
		scene._unhandled_input(gesture)
		expect(is_equal_approx(scene.target_zoom,scene._zoom_min()),name+": zoom-out returns to the full overview")
	if is_instance_valid(scene): scene.queue_free()
	await settle()
	print("ANDROID PHONE: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

func ready_build(model: Node, kind: String) -> bool:
	var fixture: Script = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	return fixture.build_ready(model,kind)
