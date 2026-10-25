extends SceneTree
## Real build taps, countdowns, world art and automatic site-to-shop transition.
var checks: int = 0
var failures: int = 0
var game: Node
var layout: Node
var preferences: Node
var scene: Control
var ui: CanvasLayer
func _initialize() -> void: run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("CONSTRUCTION UI FAIL: ",message)
func settle(frames: int=5) -> void:
	for frame: int in range(frames): await process_frame
func opened() -> void:
	await settle()
	ui._stop_modal_motion()
	ui._modal_motion_progress = 1.0
	await settle()
func capture(name: String) -> void:
	var folder: String = OS.get_environment("NZPF_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name()=="headless": return
	scene.queue_redraw()
	await settle()
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(folder.path_join("CONSTRUCTION-"+name+".png"))==OK,"Capture saved: "+name)
func tap(button: Control) -> void:
	expect(button!=null,"The real construction button exists")
	if button==null: return
	ui.modal_scroll.ensure_control_visible(button)
	await settle()
	var point: Vector2 = button.get_global_transform_with_canvas()*(button.size*0.5)
	await tap_at(point)
func tap_at(point: Vector2) -> void:
	for down: bool in [true,false]:
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.index = 0
		touch.position = point
		touch.pressed = down
		root.push_input(touch,true)
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.device = InputEvent.DEVICE_ID_EMULATION
		mouse.position = point
		mouse.global_position = point
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = down
		root.push_input(mouse,true)
		await process_frame
	await settle()
func run() -> void:
	game = root.get_node("Game")
	layout = root.get_node("DeviceLayout")
	preferences = root.get_node("Preferences")
	game.set_process(false)
	var folder: String = OS.get_environment("NZPF_TEST_DATA_DIR")
	if folder.is_empty(): folder = ProjectSettings.globalize_path("res://.runtime/construction-ui")
	DirAccess.make_dir_recursive_absolute(folder)
	game.save_path = folder.path_join("colony.json")
	preferences.settings_path = folder.path_join("preferences.cfg")
	var fixtures: Script = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	for profile: Array in [["PHONE169",Vector2i(1920,1080),true,400.0],["PHONE",Vector2i(2400,1080),true,400.0],["TABLET",Vector2i(2048,1536),true,800.0],["DESKTOP",Vector2i(1440,900),false,0.0]]:
		if is_instance_valid(scene):
			scene.queue_free()
			await settle()
		root.min_size = Vector2i.ZERO
		root.size = profile[1]
		layout.mobile = profile[2]
		layout.preview_android_shortest_dp = profile[3]
		layout.preview_insets = Vector4(24,6,12,8) if profile[2] else Vector4.ZERO
		preferences.apply_settings({"interface_size":"compact","sound_enabled":false,"screen_shake":false,"fullscreen":false},false)
		layout.refresh()
		scene = load(get_script().resource_path.get_base_dir().path_join("world_render_probe.gd")).new()
		scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(scene)
		scene.set_process(false)
		ui = scene.ui
		await settle()
		for size_name: String in ["compact","medium","large"]:
			ui._close_modal()
			game._new_game()
			game._is_loading = true
			game.skip_tutorial()
			game.coins = 100000
			game.supplies = 1000
			fixtures.build_ready(game,"residence")
			fixtures.build_ready(game,"cafe")
			game.wave_clock = 1000000000
			game._visitor_timer = 1000000000
			preferences.apply_settings({"interface_size":size_name},false)
			layout.refresh()
			ui._start_game()
			ui.toast_stack.hide()
			await settle()
			ui._show_build()
			await opened()
			var label: String = str(profile[0])+" "+size_name
			var button: Button = ui.modal_content.find_child("BuildAction_bakery",true,false)
			expect(ui.modal_content.find_child("BuildCount_residence",true,false).text=="Già costruiti: 1" and ui.modal_content.find_child("BuildCount_bakery",true,false).text=="Già costruiti: 0",label+": catalog counts existing buildings by type")
			var cost: int = game.next_build_cost("bakery")
			var duration: float = game.next_build_duration("bakery")
			expect(button.text.contains(str(cost)+" monete") and button.text.contains(ui._time(duration)),label+": both price and duration are visible before purchase")
			var money: float = game.coins
			await tap(button)
			var site: Dictionary = game.buildings.back()
			expect(site.type=="bakery" and game.is_under_construction(site) and site.construction_duration==duration,label+": real tap starts the chosen construction")
			expect(game.coins==money-cost and game.stats.built==2,label+": start charges once without awarding completion")
			expect(ui.modal_content.find_child("BuildCount_bakery",true,false).text=="Già costruiti: 0 · In costruzione: 1",label+": pending site is distinct from a completed building")
			ui.show_building(int(site.id))
			await opened()
			var timer: Label = ui.modal_content.find_child("ConstructionCountdown",true,false)
			var bar: ProgressBar = ui.modal_content.find_child("ConstructionProgress",true,false)
			expect(timer!=null and bar!=null and timer.text.contains(ui._time(duration)),label+": tapping the site opens a live countdown")
			expect(ui.modal_scroll.size.x+2>=ui.modal_content.get_combined_minimum_size().x,label+": construction page has no horizontal clipping")
			if size_name=="compact": await capture(str(profile[0])+"-DIALOG")
			ui._close_modal()
			scene.zoom = scene._zoom_min()
			scene.target_zoom = scene.zoom
			var center: float = scene._city_start()+2*scene._lot_step()+155.0*layout.building_scale()
			scene.camera_x = center-scene.size.x*0.5/scene.zoom
			scene.target_camera = scene.camera_x
			scene._process(0.1)
			if size_name=="compact": await capture(str(profile[0])+"-FOUNDATION")
			game.advance(duration*0.5)
			scene._process(0.2)
			if size_name=="compact": await capture(str(profile[0])+"-HALF")
			ui.show_building(int(site.id))
			await opened()
			ui._update_hud()
			bar = ui.modal_content.find_child("ConstructionProgress",true,false)
			timer = ui.modal_content.find_child("ConstructionCountdown",true,false)
			expect(is_equal_approx(bar.value,50.0) and timer.text.contains(ui._time(duration*0.5)),label+": countdown and progress follow the actual timer")
			game.advance(float(site.construction_remaining))
			ui._update_hud()
			await opened()
			expect(not game.is_under_construction(site) and game.stats.built==3,label+": timer completes the actual building once")
			expect(ui.panel_kind=="building" and ui.panel_id==int(site.id) and ui.modal_content.find_child("ConstructionCountdown",true,false)==null,label+": open page changes automatically from site to operational shop")
			ui._close_modal()
			scene._process(0.1)
			if size_name=="compact": await capture(str(profile[0])+"-COMPLETE")
			await settle()
			expect(not scene.rendered_labels.has(str(site.name).to_upper()) and scene.rendered_building_logos.any(func(value: Dictionary) -> bool: return value.id==site.id and value.type=="bakery"),label+": the painted bakery emblem replaces the old world name")
			await tap_at(scene._building_logo_rect(int(site.id)).get_center())
			await opened()
			expect(ui.panel_kind=="building" and ui.panel_id==int(site.id),label+": tapping the emblem opens its own building")
			ui._show_build()
			await opened()
			expect(ui.modal_content.find_child("BuildCount_bakery",true,false).text=="Già costruiti: 1",label+": completion increments the type's completed count")
		game._is_loading = false
	if is_instance_valid(scene): scene.queue_free()
	await settle()
	await create_timer(0.5).timeout
	print("CONSTRUCTION UI: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
