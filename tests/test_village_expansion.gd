extends SceneTree
## The growing refuge must always leave the next lot fully reachable.
var checks: int = 0
var failures: int = 0
var game: Node
var layout: Node
var preferences: Node
var scene: Control

func _initialize() -> void: run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("EXPANSION FAIL: ",message)
func settle(frames: int=3) -> void:
	for frame: int in range(frames): await process_frame
func arrive() -> void:
	for frame: int in range(120): scene._update_camera(1.0/30.0)
	scene.queue_redraw()
	await settle()
func capture(name: String) -> void:
	var folder: String = OS.get_environment("NZPF_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(folder.path_join("EXPANSION-"+name+".png"))==OK,"Capture saved: "+name)
func pointer(point: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.device = InputEvent.DEVICE_ID_EMULATION
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	event.pressed = pressed
	root.push_input(event,true)
	await process_frame
func run() -> void:
	game = root.get_node("Game")
	layout = root.get_node("DeviceLayout")
	preferences = root.get_node("Preferences")
	game.set_process(false)
	var data: String = OS.get_environment("NZPF_TEST_DATA_DIR")
	if data.is_empty(): data = ProjectSettings.globalize_path("res://.runtime/village-expansion")
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
		scene = load(get_script().resource_path.get_base_dir().path_join("expansion_render_probe.gd")).new()
		scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(scene)
		scene.set_process(false)
		await settle()
		for scale_name: String in ["compact","medium","large"]:
			game._new_game()
			game._is_loading = true
			game.skip_tutorial()
			game.coins = 10000000
			preferences.apply_settings({"interface_size":scale_name},false)
			layout.refresh()
			scene.ui._start_game()
			scene.ui.toast_stack.hide()
			await settle()
			for count: int in [0,3,4,12]:
				while game.buildings.size()<count:
					expect(game.build("residence"),"Fixture starts an actual building")
				for view: String in ["overview","middle","maximum"]:
					scene.zoom = scene._zoom_min() if view=="overview" else (scene._zoom_max() if view=="maximum" else lerpf(scene._zoom_min(),scene._zoom_max(),0.5))
					scene.target_zoom = scene.zoom
					var ground: float = scene._ground()
					scene._pan_button(10000)
					await arrive()
					var label: String = "%s %s %d lots %s" % [profile[0],scale_name,count,view]
					var safe: Rect2 = Rect2(Vector2.ZERO,scene.size)
					if layout.mobile: safe = Rect2(layout.safe_rect().position*layout.ui_scale(),layout.safe_rect().size*layout.ui_scale())
					expect(scene.expansion_labels==4,label+": the next lot and all its labels are actually drawn")
					expect(scene.expansion_bounds.position.x>=safe.position.x and scene.expansion_bounds.end.x<=safe.end.x-23.0,label+": the entire construction action fits with a right margin, including the notch")
					expect(is_equal_approx(scene._ground(),ground) and is_equal_approx(scene.zoom,scene.target_zoom),label+": expansion preserves horizontal movement and the chosen zoom")
					if count==3 and view=="overview" and scale_name=="compact":
						await capture(str(profile[0])+"-THREE")
						var lot: Rect2 = scene._expansion_rect()
						# The visible top of the button must also be clickable.
						var point: Vector2 = lot.position+lot.size*Vector2(0.5,0.05)
						await pointer(point,true)
						await pointer(point,false)
						await settle()
						expect(scene.ui.panel_kind=="build",label+": real input on the fully visible next lot opens the build menu")
						scene.ui._close_modal()
						await settle()
						point = Vector2(lot.get_center().x,scene._ground()+32.0)
						await pointer(point,true)
						await pointer(point,false)
						expect(scene.ui.panel_kind=="build",label+": the caption below the lot remains clickable")
						scene.ui._close_modal()
					if count==12 and view=="overview" and scale_name=="compact": await capture(str(profile[0])+"-TWELVE")
				# Starting a new site must extend the previous pan limit immediately.
				if count==3:
					var previous: float = scene.target_camera
					expect(game.build("cafe"),"A fourth construction starts")
					scene._pan_button(10000)
					expect(is_equal_approx(scene.target_camera-previous,scene._lot_step()),str(profile[0])+": a new pending site opens exactly one additional lot without waiting for completion")
		game._is_loading = false
	if is_instance_valid(scene): scene.queue_free()
	await settle()
	# Let scheduled UI sounds/tweens finish before unloading the probe script.
	await create_timer(0.5).timeout
	print("VILLAGE EXPANSION: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
