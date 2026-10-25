extends SceneTree
## Real world input: long hold opens a reversible confirmation, never a deletion.
var checks: int = 0
var failures: int = 0
var game: Node
var layout: Node
var preferences: Node
var scene: Control
var ui: CanvasLayer
var fixture: Script
func _initialize() -> void: run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("DEMOLITION UI FAIL: ",message)
func settle(frames: int=4) -> void:
	for frame: int in range(frames): await process_frame
func opened() -> void:
	await settle()
	ui._stop_modal_motion()
	ui._modal_motion_progress = 1.0
	await settle()
func pointer(point: Vector2, down: bool, touch: bool) -> void:
	if touch:
		var finger: InputEventScreenTouch = InputEventScreenTouch.new()
		finger.index = 0
		finger.position = point
		finger.pressed = down
		root.push_input(finger,true)
	var mouse: InputEventMouseButton = InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION if touch else 0
	mouse.position = point
	mouse.global_position = point
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = down
	root.push_input(mouse,true)
	await process_frame
func tap(button: Control, touch: bool) -> void:
	expect(is_instance_valid(button),"The confirmation action exists")
	if not is_instance_valid(button): return
	await settle()
	if ui.modal_scroll.is_ancestor_of(button):
		ui.modal_scroll.ensure_control_visible(button)
		await settle()
	var point: Vector2 = button.get_global_transform_with_canvas()*(button.size*0.5)
	await pointer(point,true,touch)
	await pointer(point,false,touch)
	await opened()
func frame(delta: float) -> void:
	scene._process(delta)
	await settle()
func world_point(id: int) -> Vector2:
	var rect: Rect2 = scene._building_rect(id)
	return rect.position+rect.size*Vector2(0.5,0.45)
func fresh() -> int:
	ui._close_modal()
	game._new_game()
	game._is_loading = true
	game.skip_tutorial()
	game.coins = 10000
	game.supplies = 1000
	for kind: String in ["residence","cafe","bakery"]: fixture.build_ready(game,kind)
	var person: Dictionary = game._make_citizen()
	game.citizens.append(person)
	game.assign(person.id,game.buildings[1].id)
	game.buildings[1].products[0].status = "stocked"
	game.buildings[1].products[0].stock = 8
	ui._start_game()
	ui.toast_stack.hide()
	scene.zoom = scene._zoom_min()
	scene.target_zoom = scene.zoom
	scene.camera_x = scene._city_start()+scene._lot_step()+155*layout.building_scale()-scene.size.x*0.5/scene.zoom
	scene.target_camera = scene.camera_x
	scene._process(0)
	return int(game.buildings[1].id)
func capture(name: String) -> void:
	var folder: String = OS.get_environment("NZPF_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(folder.path_join("DEMOLITION-"+name+".png"))==OK,"Capture saved: "+name)
func run() -> void:
	game = root.get_node("Game")
	layout = root.get_node("DeviceLayout")
	preferences = root.get_node("Preferences")
	game.set_process(false)
	fixture = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	var data: String = OS.get_environment("NZPF_TEST_DATA_DIR")
	if data.is_empty(): data = ProjectSettings.globalize_path("res://.runtime/demolition-ui")
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
		preferences.apply_settings({"interface_size":"compact","sound_enabled":false,"screen_shake":false,"fullscreen":false},false)
		layout.refresh()
		scene = load("res://main.tscn").instantiate()
		if scene.get_script()==null:
			expect(false,"The production scene compiles")
			quit(1)
			return
		root.add_child(scene)
		scene.set_process(false)
		ui = scene.ui
		await settle()
		for scale_name: String in ["compact","medium","large"]:
			preferences.apply_settings({"interface_size":scale_name},false)
			layout.refresh()
			var id: int = fresh()
			await settle()
			var touch: bool = profile[2]
			var label: String = str(profile[0])+" "+scale_name
			var point: Vector2 = world_point(id)
			await pointer(point,true,touch)
			await frame(0.25)
			expect(ui.panel_kind.is_empty(),label+": a short press does not open demolition")
			await pointer(point,false,touch)
			await opened()
			expect(ui.panel_kind=="building" and ui.panel_id==id,label+": ordinary tap still opens the building")
			ui._close_modal()
			await settle()
			await pointer(point,true,touch)
			await frame(0.3)
			if scale_name=="compact": await capture(str(profile[0])+"-HOLD")
			await frame(0.4)
			await opened()
			expect(ui.panel_kind=="demolition" and ui.panel_id==id and game.buildings.size()==3,label+": hold opens confirmation without demolishing")
			await pointer(point,false,touch)
			await frame(1.0)
			expect(ui.panel_kind=="demolition" and game.buildings.size()==3,label+": releasing the original hold never confirms or reopens a normal building")
			expect(ui.modal_scroll.size.x+2>=ui.modal_content.get_combined_minimum_size().x,label+": confirmation has no horizontal clipping")
			if scale_name=="compact": await capture(str(profile[0])+"-CONFIRM")
			await tap(ui.modal.find_child("CancelDemolition",true,false),touch)
			expect(ui.panel_kind.is_empty() and game.get_building(id).size()>0 and game.citizens[0].job==id,label+": cancel preserves building and worker")
			# The sign is also a long-press target.
			var sign: Vector2 = scene._building_logo_rect(id).get_center()
			await pointer(sign,true,touch)
			await frame(0.7)
			await opened()
			await pointer(sign,false,touch)
			expect(ui.panel_kind=="demolition" and ui.panel_id==id,label+": the emblem holds the same building identity")
			var money: float = game.coins
			await tap(ui.modal.find_child("ConfirmDemolition",true,false),touch)
			expect(ui.panel_kind.is_empty() and game.get_building(id).is_empty() and game.buildings.size()==2 and game.citizens[0].job==-1 and game.coins==money,label+": explicit confirmation demolishes once and frees the worker")
			ui._show_build()
			await opened()
			expect(ui.modal_content.find_child("BuildCount_cafe",true,false).text=="Già costruiti: 0",label+": catalog reflects demolition")
			id = fresh()
			await settle()
			point = world_point(id)
			await pointer(point,true,touch)
			var motion: InputEventMouseMotion = InputEventMouseMotion.new()
			motion.device = InputEvent.DEVICE_ID_EMULATION if touch else 0
			motion.position = point+Vector2(30,0)
			motion.global_position = motion.position
			motion.relative = Vector2(30,0)
			root.push_input(motion,true)
			await frame(1)
			await pointer(motion.position,false,touch)
			expect(ui.panel_kind.is_empty() and game.buildings.size()==3,label+": dragging cancels the hold and its release click")
			id = fresh()
			await settle()
			point = world_point(id)
			await pointer(point,true,touch)
			var second: InputEventScreenTouch = InputEventScreenTouch.new()
			second.index = 1
			second.position = point+Vector2(100,0)
			second.pressed = true
			root.push_input(second,true)
			await frame(1)
			second.pressed = false
			root.push_input(second,true)
			await pointer(point,false,touch)
			expect(ui.panel_kind.is_empty(),label+": an additional finger cancels long press")
			await pointer(point,true,touch)
			var cancelled: InputEventScreenTouch = InputEventScreenTouch.new()
			cancelled.index = 0
			cancelled.position = point
			cancelled.pressed = false
			cancelled.canceled = true
			root.push_input(cancelled,true)
			await frame(1)
			await pointer(point,false,touch)
			expect(ui.panel_kind.is_empty(),label+": cancelled touch cannot become a long press or a normal tap")
			await pointer(point,true,touch)
			var hud_point: Vector2 = ui.pause_button.get_global_transform_with_canvas()*(ui.pause_button.size*0.5)
			await pointer(hud_point,false,touch)
			await frame(1)
			expect(ui.panel_kind.is_empty() and not scene.dragging,label+": release consumed by the HUD ends the world gesture")
			await pointer(point,true,touch)
			scene.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			await frame(1)
			await pointer(point,false,touch)
			expect(ui.panel_kind.is_empty(),label+": app focus loss cancels long press")
			await pointer(point,true,touch)
			ui._show_pause()
			await frame(1)
			await pointer(point,false,touch)
			expect(ui.panel_kind=="pause",label+": another dialog cancels the pending action")
			ui._close_modal()
			await settle()
			await pointer(point,true,touch)
			scene._zoom_button(1)
			await frame(1)
			await pointer(point,false,touch)
			expect(ui.panel_kind.is_empty(),label+": zoom cancels a pending hold and its release tap")
			# The only inhabited house remains protected by the authoritative model.
			var house: int = game.buildings[0].id
			ui.show_demolition(house)
			await opened()
			expect(ui.modal.find_child("ConfirmDemolition",true,false).disabled and ui.modal.find_child("DemolitionReason",true,false).text.contains("alloggi"),label+": insufficient housing visibly disables confirmation")
			ui._close_modal()
		game._is_loading = false
	if is_instance_valid(scene): scene.queue_free()
	await settle()
	await create_timer(1.6).timeout
	print("DEMOLITION UI: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
