extends SceneTree
var checks: int = 0
var failures: int = 0
var scene: Control
var game: Node
var ui: CanvasLayer
var layout: Node
var fixture: Script
func _initialize() -> void: run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("WORLD TOUCH FAIL: ",message)
func settle(frames: int=4) -> void:
	for frame: int in range(frames): await process_frame
func finger(point: Vector2, pressed: bool, index: int=0, canceled: bool=false) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.position = point
	event.index = index
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event,true)
	await process_frame
func drag(from: Vector2, to: Vector2, index: int=0) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = to
	event.relative = to-from
	event.velocity = (to-from)*12
	root.push_input(event,true)
	await process_frame
func mouse(point: Vector2, down: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.device = InputEvent.DEVICE_ID_EMULATION
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = down
	root.push_input(event,true)
	await process_frame
func reset_view(id: int) -> void:
	ui._close_modal()
	scene.world_touch.cancel(scene,true)
	scene.zoom = scene._zoom_min()
	scene.target_zoom = scene.zoom
	scene.camera_x = scene._city_start()+scene._lot_step()*2+150*layout.building_scale()-scene.size.x*0.5/scene.zoom
	scene.target_camera = scene.camera_x
	scene._limit_camera()
	scene.camera_x = scene.target_camera
	scene._process(0)
	await settle()
func run() -> void:
	game = root.get_node("Game")
	layout = root.get_node("DeviceLayout")
	game.set_process(false)
	fixture = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	var data: String = OS.get_environment("NZPF_TEST_DATA_DIR")
	if data.is_empty(): data = ProjectSettings.globalize_path("res://.runtime/world-touch-data")
	DirAccess.make_dir_recursive_absolute(data)
	game.save_path = data.path_join("colony.json")
	root.get_node("Preferences").settings_path = data.path_join("preferences.cfg")
	for profile: Array in [[Vector2i(1920,1080),400.0],[Vector2i(2400,1080),400.0],[Vector2i(2048,1536),800.0]]:
		if is_instance_valid(scene):
			scene.queue_free()
			await settle()
		root.min_size = Vector2i.ZERO
		root.size = profile[0]
		layout.mobile = true
		layout.preview_android_shortest_dp = profile[1]
		layout.preview_insets = Vector4(20,6,35,8)
		root.get_node("Preferences").apply_settings({"interface_size":"compact","sound_enabled":false,"screen_shake":false,"fullscreen":false},false)
		layout.refresh()
		game._new_game()
		game._is_loading = true
		game.skip_tutorial()
		game.coins = 50000
		for kind: String in ["residence","cafe","workshop","garden","bakery","waterworks"]: fixture.build_ready(game,kind)
		scene = load("res://main.tscn").instantiate()
		if scene.get_script()==null:
			expect(false,"Scene compiles")
			quit(1)
			return
		root.add_child(scene)
		scene.set_process(false)
		ui = scene.ui
		await settle()
		ui._start_game()
		ui.toast_stack.hide()
		var id: int = int(game.buildings[2].id)
		for origin_kind: String in ["building","sign","street","sky"]:
			await reset_view(id)
			var point: Vector2 = scene._building_rect(id).get_center()
			if origin_kind=="sign": point = scene._building_logo_rect(id).get_center()
			elif origin_kind=="street": point.y = scene._ground()+65*scene.zoom
			elif origin_kind=="sky": point.y = scene.size.y*0.33
			expect(not ui.world_input_blocked(point),"Starting surface is playable: "+origin_kind)
			var initial: float = scene.target_camera
			await finger(point,true)
			await drag(point,point-Vector2(150,2))
			expect(scene.target_camera>initial+80/scene.zoom,"Raw single-finger drag pans from "+origin_kind)
			expect(absf(scene.camera_x-scene.target_camera)<1,"Camera stays attached to the finger")
			expect(scene._building_hold.is_empty(),"Swiping cancels demolition")
			await finger(point-Vector2(150,2),false)
			expect(ui.panel_kind.is_empty(),"A swipe never opens a building")
			var released: float = scene.target_camera
			scene._process(0.10)
			expect(scene.target_camera>released,"Release has gentle horizontal inertia")
			scene._process(2)
			expect(absf(scene.world_touch.momentum)<2,"Inertia settles quickly")
		await reset_view(id)
		var point: Vector2 = scene._building_rect(id).get_center()
		await finger(point,true)
		await finger(point,false)
		expect(ui.panel_kind=="building" and ui.panel_id==id,"Raw short tap opens correct building")
		await reset_view(id)
		point = scene._building_logo_rect(id).get_center()
		await finger(point,true)
		scene._process(0.7)
		await settle()
		expect(ui.panel_kind=="demolition","Stationary long press preserves demolition")
		await finger(point,false)
		expect(game.buildings.size()==6,"Original release cannot confirm demolition")
		await reset_view(id)
		point = scene._building_rect(id).get_center()
		await finger(point,true)
		await finger(point+Vector2(100,0),true,1)
		var old_zoom: float = scene.target_zoom
		await drag(point+Vector2(100,0),point+Vector2(180,0),1)
		expect(scene.target_zoom>old_zoom,"Two raw fingers pinch immediately")
		await finger(point+Vector2(180,0),false,1)
		await finger(point,false)
		expect(ui.panel_kind.is_empty() and scene.touch_points.is_empty(),"Pinch release never taps or leaves stale fingers")
		await reset_view(id)
		point = scene._building_rect(id).get_center()
		await finger(point,true)
		await finger(point,false,0,true)
		expect(ui.panel_kind.is_empty() and scene.world_touch.claimed.is_empty(),"Canceled touch ends safely")
		await reset_view(id)
		var button: Control = ui.nav_buttons.build
		point = button.get_global_transform_with_canvas()*(button.size*0.5)
		var start: float = scene.target_camera
		await finger(point,true)
		await drag(point,point-Vector2(140,0))
		await finger(point-Vector2(140,0),false)
		expect(scene.target_camera==start and scene.world_touch.claimed.is_empty(),"Starting on HUD never grabs the world")
		await reset_view(id)
		point = scene._building_rect(id).get_center()
		await finger(point,true)
		var end: Vector2 = Vector2(point.x-170,scene.size.y-30)
		await drag(point,end)
		await finger(end,false)
		expect(ui.panel_kind.is_empty() and scene.world_touch.claimed.is_empty(),"A world swipe may cross HUD and release there")
		await reset_view(id)
		point = scene._building_rect(id).get_center()
		start = scene.target_camera
		await finger(point,true)
		await mouse(point,true)
		await drag(point,point-Vector2(130,0))
		await finger(point-Vector2(130,0),false)
		await mouse(point-Vector2(130,0),false)
		expect(is_equal_approx(scene.target_camera,start+130/scene.zoom),"Emulated mouse cannot duplicate the raw gesture")
		expect(ui.panel_kind.is_empty(),"Mixed Android events cannot create a stray tap")
		await reset_view(id)
		point = scene._building_rect(id).get_center()
		await finger(point,true)
		await drag(point,point-Vector2(90,0))
		await finger(point-Vector2(90,0),false)
		ui._show_build()
		expect(scene.world_touch.momentum==0,"Opening a menu stops residual camera motion")
		await reset_view(id)
		root.get_node("Preferences").reduced_motion = true
		point = scene._building_rect(id).get_center()
		await finger(point,true)
		await drag(point,point-Vector2(90,0))
		await finger(point-Vector2(90,0),false)
		expect(scene.world_touch.momentum==0,"Reduced motion keeps direct pan without release inertia")
		root.get_node("Preferences").reduced_motion = false
		await reset_view(id)
		ui.zombie_alert.show()
		point = ui.zombie_alert.get_global_transform_with_canvas()*(ui.zombie_alert.size*0.5)
		expect(ui.world_input_blocked(point),"Zombie shortcut outside the HUD tree still owns its taps")
		await finger(point,true)
		expect(scene.world_touch.claimed.is_empty(),"Alert never starts a world gesture")
		await finger(point,false)
		ui.zombie_alert.hide()
		# A swipe can begin on an enemy even when the automatic-burst weapon is equipped.
		scene.focus_defense()
		scene._update_camera(3)
		scene._process(0)
		game.threats.clear()
		game._add_threat("brute",game.GATE_X-160)
		game.weapon = "smg"
		game.ammo = 20
		game.shot_cooldown = 0
		point = Vector2(scene._sx(game.GATE_X-160),scene._ground()-40*scene._actor_zoom())
		await finger(point,true)
		scene._process(0.13)
		expect(scene.smg_held and game.ammo==19,"A stationary raw hold starts one real SMG shot")
		await drag(point,point-Vector2(120,0))
		var ammo: int = game.ammo
		scene._process(0.2)
		await finger(point-Vector2(120,0),false)
		expect(not scene.smg_held and game.ammo==ammo,"Dragging stops the burst and pans without release shots")
		game.weapon = "pistol"
		game.threats.clear()
		await reset_view(id)
		await finger(scene._building_rect(id).get_center(),true)
		scene._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
		expect(scene.world_touch.claimed.is_empty() and not scene.dragging,"Focus loss clears captured touch")
	scene.queue_free()
	await create_timer(1.6).timeout
	print("WORLD TOUCH: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
