extends SceneTree
## Real batch/medical timers, persistence and in-world markers at device zoom limits.
var checks: int = 0
var failures: int = 0
var game: Node
var layout: Node
var activity: Script
var rules: Script
var observation: Script
var fixture: Script
var cafe: Dictionary
var garden: Dictionary
var workshop: Dictionary
var scene: Control

func _initialize() -> void: run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("ACTIVITY FAIL: ",message)
func settle(frames: int=4) -> void:
	for frame: int in range(frames): await process_frame
func fresh() -> void:
	game._new_game()
	game.skip_tutorial()
	game.coins = 50000
	game.supplies = 1000
	game.wave_clock = 100000
	game._visitor_timer = 100000
	for kind: String in ["residence","cafe","garden","workshop"]: fixture.build_ready(game,kind)
	cafe = game.buildings[1]
	garden = game.buildings[2]
	workshop = game.buildings[3]
	for index: int in range(3):
		var citizen: Dictionary = game._make_citizen()
		citizen.food = 8
		citizen.dream = "clinic"
		game.citizens.append(citizen)
		game.assign(int(citizen.id),int(cafe.id))
func visitor() -> Dictionary:
	game._spawn_visitor()
	var v: Dictionary = game.visitors.back()
	v.x = game.visitor_destination(game.visitors.size()-1)
	return v
func run() -> void:
	game = root.get_node("Game")
	layout = root.get_node("DeviceLayout")
	game.set_process(false)
	game.save_path = "user://activity-indicators-colony.json"
	root.get_node("Preferences").settings_path = "user://activity-indicators-preferences.cfg"
	root.get_node("Preferences").apply_settings({"sound_enabled":false,"fullscreen":false,"interface_size":"compact"},false)
	# This render/input suite repeatedly creates worlds with audio disabled.
	# Skip the ambient decoder altogether; audio assets have their own suite.
	var sound_bank: Script = load("res://scripts/sound_bank.gd")
	sound_bank._cache["res://assets/audio/shelter_ambience.ogg"] = null
	activity = load("res://scripts/activity_indicator.gd")
	rules = load("res://scripts/cozy_rules.gd")
	observation = load("res://scripts/visitor_observation.gd")
	fixture = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	test_batches()
	test_observation()
	await test_rendering()
	scene = null
	cafe = {}
	garden = {}
	workshop = {}
	await settle()
	print("ACTIVITY INDICATORS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func test_batches() -> void:
	fresh()
	expect(activity.preparations(game,cafe).is_empty(),"Idle shops have no preparation marker")
	expect(game.restock(int(cafe.id),1),"Start a real skilled-worker batch")
	var p: Dictionary = cafe.products[0]
	var actual: float = float(p.remaining)
	expect(actual<float(p.duration) and is_equal_approx(float(p.restock_duration),actual),"Store the actual shortened duration once per batch")
	expect(is_zero_approx(activity.product_progress(p)),"The ring starts at zero despite worker skills")
	game._tick_products(actual*0.5)
	expect(is_equal_approx(activity.product_progress(p),0.5),"Half the actual production duration fills half the ring")
	expect(game.restock(int(cafe.id),2) and game.restock(int(cafe.id),3),"Concurrent product tiers use actual production actions")
	var tasks: Array = activity.preparations(game,cafe)
	expect(tasks.size()==3 and tasks[0].progress==0.5 and tasks[1].progress==0.0 and tasks[2].progress==0.0,"Each concurrent batch keeps its independent segment")
	game.assign(int(game.citizens[2].id),-1)
	var third_remaining: float = float(cafe.products[2].remaining)
	game._tick_products(1.0)
	tasks = activity.preparations(game,cafe)
	expect(tasks[2].paused and not tasks[0].paused and not tasks[1].paused,"Only products missing their required worker count show pause")
	expect(float(cafe.products[2].remaining)==third_remaining and tasks[0].progress>0.5,"Paused product stays still while other segments advance")
	game.paused = true
	var before: Array = activity.preparations(game,cafe)
	game._process(2.0)
	expect(activity.preparations(game,cafe)==before,"Game pause freezes every production segment")
	game.paused = false
	expect(game.save_game() and game.load_game(),"Actual batch timers survive save/load")
	cafe = game.buildings[1]
	p = cafe.products[0]
	expect(is_equal_approx(float(p.restock_duration),actual) and absf(activity.product_progress(p)-float(before[0].progress))<0.03,"Reload keeps the original duration and visible advancement")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	var legacy: Dictionary = saved.duplicate(true)
	for product: Dictionary in legacy.buildings[1].products: product.erase("restock_duration")
	expect(game._valid_save(legacy),"Legacy saves without optional batch duration remain valid")
	expect(activity.product_progress({"remaining":5.0,"duration":10.0})==0.5,"Legacy progress uses the original base duration")
	for invalid: Variant in [null,-1.0,0.0,86401.0,INF,NAN]:
		var bad: Dictionary = saved.duplicate(true)
		bad.buildings[1].products[0].restock_duration = invalid
		expect(not game._valid_save(bad),"Reject malformed batch duration: "+str(invalid))
	expect(game.speed_up(int(cafe.id),1),"Express delivery completes an actual batch")
	expect(activity.preparations(game,cafe).size()==2,"Ready goods no longer show as preparing")
	cafe.auto_shelves = true
	game.assign(int(game.citizens[2].id),int(cafe.id))
	game._tick_products(1000.0)
	expect(activity.preparations(game,cafe).is_empty() and cafe.products[1].status=="stocked","Automatic shelves clear completed preparation markers")
	for b: Dictionary in [game.buildings[2],game.buildings[3]]:
		game.assign(int(game.citizens[0].id),int(b.id))
		expect(rules.service(game,int(b.id)),"Start the actual shared service for "+str(b.type))
		var duration: float = float(b.service.remaining)
		rules.tick(game,duration*0.5)
		expect(activity.preparations(game,b).size()==1 and activity.preparations(game,b)[0].progress==0.5,"Shared service uses its real garden/workshop duration")
		game.assign(int(game.citizens[0].id),-1)
		rules.tick(game,1.0)
		expect(activity.preparations(game,b)[0].paused and float(b.service.remaining)==duration*0.5,"An unstaffed shared service shows frozen progress")
		game.assign(int(game.citizens[0].id),int(b.id))
		rules.tick(game,duration)
		expect(activity.preparations(game,b).is_empty(),"Ready shared services stop displaying preparation")
func test_observation() -> void:
	for medical: bool in [false,true]:
		fresh()
		if medical: game.community.discoveries.append("lab")
		var v: Dictionary = visitor()
		expect(not activity.visitor_visible(v),"Unobserved arrivals have no medical progress marker")
		expect(rules.observe(game,int(v.id)),"Start the real medical check")
		var duration: float = 30.0 if medical else 60.0
		expect(activity.visitor_visible(v) and observation.preview(game,v).progress==0.0,"Medical ring appears only when the check starts")
		rules.tick(game,duration*0.5)
		expect(observation.preview(game,v).progress==50.0,"Medical icon follows the dialog's exact real countdown")
		if not medical:
			game.community.discoveries.append("lab")
			expect(observation.preview(game,v).duration==60.0 and observation.preview(game,v).progress==50.0,"A new medical discovery cannot jump an existing ring")
		game.paused = true
		game._process(3.0)
		expect(observation.preview(game,v).progress==50.0,"Pause freezes medical advancement too")
		game.paused = false
		rules.tick(game,duration)
		expect(not activity.visitor_visible(v),"Completed medical checks remove their waiting marker")
	fresh()
	var v: Dictionary = visitor()
	rules.observe(game,int(v.id))
	game.reject_visitor(int(v.id))
	expect(game.visitors.is_empty() and game.departing_visitors.size()==1 and not activity.visitor_visible(game.departing_visitors[0],true),"Rejected observed survivors leave without a medical marker")
func capture(name: String) -> void:
	var folder: String = OS.get_environment("NZPF_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name()=="headless": return
	DirAccess.make_dir_recursive_absolute(folder)
	for ripple: Control in scene.find_children("ClickRipples","Control",true,false):
		ripple.pulses.clear()
		ripple.queue_redraw()
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(folder.path_join("ATTIVITA-"+name+".png"))==OK,"Save native world progress preview")
func rendered_colors(rect: Rect2, paused: bool=false) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var scale: Vector2 = Vector2(image.get_size())/scene.size
	var pixels: Rect2i = Rect2i(Rect2(rect.position*scale,rect.size*scale)).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	var green: int = 0
	var amber: int = 0
	for y: int in range(pixels.position.y,pixels.end.y):
		for x: int in range(pixels.position.x,pixels.end.x):
			var color: Color = image.get_pixel(x,y)
			if absf(color.r-activity.SAGE.r)+absf(color.g-activity.SAGE.g)+absf(color.b-activity.SAGE.b)<0.04: green += 1
			if absf(color.r-activity.GOLD.r)+absf(color.g-activity.GOLD.g)+absf(color.b-activity.GOLD.b)<0.04: amber += 1
	expect(green>6,"The real renderer paints the progress ring inside its own icon bounds")
	if paused: expect(amber>6,"The paused segment is actually painted amber inside the shop icon")
func click(point: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.device = InputEvent.DEVICE_ID_EMULATION if layout.mobile else 0
	motion.position = point
	motion.global_position = point
	root.push_input(motion,true)
	for down: bool in [true,false]:
		if layout.mobile:
			var finger: InputEventScreenTouch = InputEventScreenTouch.new()
			finger.position = point
			finger.pressed = down
			root.push_input(finger,true)
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.device = InputEvent.DEVICE_ID_EMULATION if layout.mobile else 0
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.position = point
		mouse.global_position = point
		mouse.pressed = down
		root.push_input(mouse,true)
		await process_frame
	await settle()
func test_rendering() -> void:
	for profile: Array in [["PHONE169",Vector2i(1920,1080),400,true],["PHONE209",Vector2i(2400,1080),400,true],["TABLET",Vector2i(2048,1536),800,true],["DESKTOP",Vector2i(1440,900),0,false]]:
		root.min_size = Vector2i.ZERO
		root.size = profile[1]
		layout.mobile = profile[3]
		layout.preview_android_shortest_dp = profile[2]
		layout.preview_insets = Vector4(24,6,40,8) if profile[3] else Vector4.ZERO
		layout.refresh()
		fresh()
		game.restock(int(cafe.id),1)
		game.restock(int(cafe.id),2)
		game._tick_products(float(cafe.products[0].remaining)*0.5)
		game.assign(int(game.citizens[2].id),-1)
		game.assign(int(game.citizens[1].id),-1)
		var v: Dictionary = visitor()
		rules.observe(game,int(v.id))
		rules.tick(game,24.0)
		scene = load("res://main.tscn").instantiate()
		root.add_child(scene)
		scene.set_process(false)
		await settle()
		scene.ui._start_game()
		scene.ui.toast_stack.hide()
		await settle()
		for close: bool in [false,true]:
			scene.zoom = scene._zoom_max() if close else scene._zoom_min()
			scene.target_zoom = scene.zoom
			var zoom_name: String = "MAX" if close else "MIN"
			scene.camera_x = scene._city_start()+scene._lot_step()+155.0*layout.building_scale()-scene.size.x/(2.0*scene.zoom)
			scene.target_camera = scene.camera_x
			scene.queue_redraw()
			await settle()
			var sign: Rect2 = scene._building_logo_rect(int(cafe.id))
			expect(Rect2(Vector2.ZERO,scene.size).encloses(sign),str(profile[0])+": production sign stays visible at "+zoom_name)
			expect(activity.preparations(game,cafe).size()==2 and activity.preparations(game,cafe)[1].paused,"Native scene includes both active and paused segments")
			await rendered_colors(sign,true)
			await capture(str(profile[0])+"-NEGOZIO-"+zoom_name)
			if not close:
				await click(sign.get_center())
				expect(scene.ui.panel_kind=="building" and scene.ui.panel_id==int(cafe.id),str(profile[0])+": progress emblem retains shop click target (actual "+scene.ui.panel_kind+"/"+str(scene.ui.panel_id)+")")
				scene.ui._close_modal()
				await settle(12)
			scene.camera_x = float(v.x)-scene.size.x*0.45/scene.zoom
			scene.target_camera = scene.camera_x
			scene.queue_redraw()
			await settle()
			var rect: Rect2 = activity.visitor_bounds(scene,v)
			expect(Rect2(Vector2.ZERO,scene.size).encloses(rect),str(profile[0])+": observed visitor badge remains inside the display at "+zoom_name)
			expect(rect.end.y<scene._ground()-71.0*scene._actor_zoom(),"Medical marker stays above the person's head")
			var first_x: float = rect.position.x
			scene.camera_x += 20.0
			expect(is_equal_approx(activity.visitor_bounds(scene,v).position.x,first_x-20.0*scene.zoom),"Medical marker follows horizontal camera movement")
			scene.camera_x -= 20.0
			await rendered_colors(rect)
			await capture(str(profile[0])+"-OSSERVAZIONE-"+zoom_name)
			if not close:
				await click(Vector2(scene._sx(float(v.x)),scene._ground()-28.0*scene._actor_zoom()))
				expect(scene.ui.panel_kind=="visitor" and scene.ui.panel_id==int(v.id),str(profile[0])+": observation marker preserves survivor click target (actual "+scene.ui.panel_kind+"/"+str(scene.ui.panel_id)+")")
				scene.ui._close_modal()
				await settle(12)
		# Native Ogg playback stops on the audio thread; let it release its voice
		# before repeatedly destroying world scenes in this render-only suite.
		if is_instance_valid(scene.ambience_player):
			scene.ambience_player.stop()
			scene.ambience_player.stream = null
			await create_timer(0.08).timeout
		scene.queue_free()
		await settle()
