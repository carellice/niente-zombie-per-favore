extends SceneTree
## Exercise the real asynchronous startup and circular adaptive-icon safe zone.

var checks: int = 0
var failures: int = 0
var destination: Node
var completed_count: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("LOADING FAIL: ",message)

func settle() -> void:
	for index: int in range(6): await process_frame

func run() -> void:
	var game: Node = root.get_node("Game")
	var layout: Node = root.get_node("DeviceLayout")
	game.save_path = "res://.runtime/loading-screen-test.json"
	root.get_node("Preferences").settings_path = "res://.runtime/loading-screen-preferences.cfg"
	game._new_game()
	var loader: Control = load("res://loading.tscn").instantiate()
	loader.auto_start = false
	root.add_child(loader)
	loader.completed.connect(func(scene: Node) -> void:
		destination = scene
		completed_count += 1
	)
	await settle()
	expect(game.paused,"The colony is paused throughout startup")
	expect(loader.phase=="waiting" and is_zero_approx(loader.target_progress),"Waiting for resources does not invent progress")
	expect(ProjectSettings.get_setting("application/run/main_scene")=="res://loading.tscn","The application enters through the branded loader")
	var splash: String = ProjectSettings.get_setting("application/boot_splash/image","")
	expect(not splash.is_empty() and ResourceLoader.exists(splash),"The engine splash uses a shipped game image")
	var native_splash: Image = Image.new()
	expect(native_splash.load_png_from_buffer(FileAccess.get_file_as_bytes(splash))==OK,"Native boot PNG is present as raw bytes, not only an imported texture")
	var original_mobile: bool = layout.mobile
	var captures: bool = OS.get_cmdline_user_args().has("--capture-loading")
	for screen: Vector2i in [Vector2i(1920,1080),Vector2i(2400,1080),Vector2i(2048,1536)]:
		layout.mobile = true
		root.min_size = Vector2i.ZERO
		root.size = screen
		layout.preview_insets = Vector4(22,0,0,8)
		await settle()
		layout.refresh()
		await settle()
		var safe: Rect2 = layout.safe_rect()
		expect(safe.grow(2).encloses(loader.content.get_global_rect()),"Brand and progress fit safe area: "+str(screen))
		if captures:
			await RenderingServer.frame_post_draw
			expect(root.get_texture().get_image().save_png("res://docs/CARICAMENTO-%dx%d.png" % [screen.x,screen.y])==OK,"Loading preview captured")
	layout.mobile = original_mobile
	layout.preview_insets = Vector4.ZERO
	root.size = Vector2i(1440,900)
	layout.refresh()
	await settle()
	var icon: Image = (load("res://assets/android/icon_foreground.png") as Texture2D).get_image()
	if icon.is_compressed(): icon.decompress()
	var max_radius: float = 0.0
	var visible: int = 0
	var center: Vector2 = Vector2(icon.get_size())*0.5
	for y: int in range(icon.get_height()):
		for x: int in range(icon.get_width()):
			if icon.get_pixel(x,y).a>0.02:
				visible += 1
				max_radius = maxf(max_radius,Vector2(x,y).distance_to(center)/icon.get_width())
	expect(icon.get_width()==icon.get_height() and icon.get_width()>=432,"Adaptive foreground has the required square resolution")
	expect(visible>10000,"Adaptive icon contains the full illustration")
	expect(max_radius<=66.0/108.0*0.5,"Every visible part of the badge fits even the conservative circular safe zone")
	expect(icon.get_pixel(0,0).a<0.01,"Icon margins are transparent")
	print("ANDROID ICON: visible radius ",max_radius," (safe limit ",66.0/108.0*0.5,")")
	var previous_progress: float = 0.0
	var monotonic: bool = true
	var entered_opening: bool = false
	var started: int = Time.get_ticks_msec()
	loader.start_loading()
	while destination==null and Time.get_ticks_msec()-started<30000:
		await process_frame
		if not is_instance_valid(loader): break
		monotonic = monotonic and loader.target_progress>=previous_progress
		previous_progress = loader.target_progress
		if loader.phase=="opening": entered_opening = true
		if loader.phase=="failed": break
	expect(monotonic,"Reported loading progress never goes backwards")
	expect(entered_opening,"Resources are prepared before opening the main scene")
	expect(destination!=null and completed_count==1,"Startup hands off exactly once to the real refuge")
	if destination!=null:
		expect(current_scene==destination,"Main scene replaces the loading scene")
		expect(destination.ui.main_menu_active,"Menu is ready when the loading screen disappears")
		expect(game.paused and game.citizens.is_empty() and game.buildings.is_empty() and game.coins==1000,"Loading does not advance or reset the colony")
		expect(is_equal_approx(previous_progress,100.0),"100% is reached only after the refuge is ready")
		await settle()
		expect(not is_instance_valid(loader),"Loading controls and preload references are released")
		await create_timer(1.6).timeout
		destination.queue_free()
	await settle()
	print("LOADING SCREEN: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
