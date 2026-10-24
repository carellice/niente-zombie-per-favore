extends SceneTree
## Walks every guided action through the real main scene and real UI callbacks.
## Only time is accelerated; no progress, resources, actors or tutorial stages
## are injected. All files live in the isolated user profile used by this test.

var game: Node
var scene: Control
var ui: CanvasLayer
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("TUTORIAL WALKTHROUGH FAIL: ",description)

func find_button(node: Node, caption: String, prefix: bool = false) -> Button:
	if node is Button and (node.text.begins_with(caption) if prefix else node.text==caption): return node
	for child: Node in node.get_children():
		var result: Button = find_button(child,caption,prefix)
		if result!=null: return result
	return null

func contains_text(node: Node, fragment: String) -> bool:
	if node is Label and fragment in node.text: return true
	for child: Node in node.get_children():
		if contains_text(child,fragment): return true
	return false

func settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func press(caption: String, parent: Node, prefix: bool = false) -> bool:
	var target: Button = find_button(parent,caption,prefix)
	expect(target!=null,"UI action exists: "+caption)
	if target==null: return false
	expect(not target.disabled,"UI action enabled: "+caption)
	if target.disabled: return false
	target.pressed.emit()
	await settle()
	return true

func world_click(point: Vector2) -> void:
	for pressed: bool in [true,false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	await settle()

func advance(seconds: float) -> void:
	var remaining: float = seconds
	while remaining>0.0001:
		var delta: float = minf(remaining,0.1)
		game.advance(delta)
		scene._process(delta)
		remaining-=delta
	await settle()

func stage(expected_stage: String, caption: String) -> void:
	expect(game.tutorial_stage==expected_stage,"Progress reached "+expected_stage)
	if is_instance_valid(ui.modal):
		ui._close_modal()
	await settle()
	ui._update_hud()
	expect(ui.tutorial_panel.visible,"Guidance visible during "+expected_stage)
	expect(find_button(ui.tutorial_panel,caption)!=null,"Guidance action matches "+expected_stage)
	expect(not game.paused and not scene.panel_open,"Guidance leaves the live world playable during "+expected_stage)

func capture(path: String) -> void:
	if DisplayServer.get_name()=="headless" or not OS.get_cmdline_user_args().has("--capture-tutorial"): return
	scene.queue_redraw()
	await settle()
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(path)==OK,"Native tutorial capture saved")

func run() -> void:
	game = root.get_node("Game")
	var folder: String = OS.get_environment("NZPF_TEST_DATA_DIR")
	if folder.is_empty(): folder = ProjectSettings.globalize_path("res://.runtime/tutorial-construction")
	DirAccess.make_dir_recursive_absolute(folder)
	game.save_path = folder.path_join("colony.json")
	game.set_process(false)
	game._new_game()
	var preferences: Node = root.get_node("Preferences")
	preferences.settings_path = folder.path_join("preferences.cfg")
	preferences.apply_settings({"sound_enabled":false,"screen_shake":false,"fullscreen":false},false)
	root.size = Vector2i(1440,900)
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await settle()
	scene.set_process(false)
	ui = scene.ui
	expect(ui.main_menu_active and game.paused,"Actual scene starts at the paused main menu")
	expect(scene._guard_ids()==[0],"Empty world has exactly the permanent military character")
	if not await press("Gioca  →",ui.menu_layer):
		await finish(preferences)
		return
	expect(ui.panel_kind=="tutorial_intro","Play presents the introductory tutorial dialog")
	expect(game.citizens.is_empty() and game.buildings.is_empty(),"Introduction starts with no residents or buildings")
	if not await press("Cominciamo · Vai alla torretta",ui.modal):
		await finish(preferences)
		return
	await stage("first_zombie","Vai alla torretta")
	expect(game.threats.size()==1 and float(game.threats[0].x)<-1000.0,"First teaching zombie walks from outside the screen")
	# Walk the controlled arrival to a clear part of the street, then use actual
	# viewport pointer events rather than calling the simulation's shoot method.
	await advance(22.0)
	for attempt: int in range(4):
		if game.threats.is_empty(): break
		var zombie: Dictionary = game.threats[0]
		await world_click(Vector2(scene._sx(float(zombie.x)),scene._ground()-32.0*scene.zoom))
		if not game.threats.is_empty(): await advance(0.4)
	expect(int(game.stats.kills)==1 and game.threats.is_empty(),"Pointer shooting completes the first defence lesson")
	await stage("build_residence","Costruisci una casa")
	if not await press("Costruisci una casa",ui.tutorial_panel):
		await finish(preferences)
		return
	expect(ui.panel_kind=="build","House guidance opens the actual construction catalog")
	if not await press("Costruisci  ·  320 monete",ui.modal,true):
		await finish(preferences)
		return
	expect(game.buildings.size()==1 and game.buildings[0].type=="residence" and game.capacity()==0,"House button starts construction before granting beds")
	await stage("build_residence","Guarda il cantiere")
	await advance(float(game.buildings[0].construction_remaining)+0.1)
	expect(game.capacity()==5,"Finishing the actual timer creates five real beds")
	await stage("welcome_visitor","Vai al cancello")
	expect(game.visitors.size()==1 and float(game.visitors[0].x)<-1000.0,"The first teaching survivor also enters from outside the screen")
	await press("Vai al cancello",ui.tutorial_panel)
	await advance(44.0)
	var visitor: Dictionary = game.visitors[0]
	await world_click(Vector2(scene._sx(float(visitor.x)),scene._ground()-30.0*scene.zoom))
	expect(ui.panel_kind=="visitor" and ui.panel_id==int(visitor.id),"Street pointer opens the arriving survivor's own admission card")
	if not await press("✓  Accogli nel rifugio",ui.modal):
		await finish(preferences)
		return
	expect(game.citizens.size()==1 and game.visitors.is_empty(),"Admission transfers the actual visitor into the refuge")
	await stage("build_cafe","Costruisci il caffè")
	await press("Costruisci il caffè",ui.tutorial_panel)
	if not await press("Costruisci  ·  420 monete",ui.modal,true):
		await finish(preferences)
		return
	expect(game.buildings.size()==2 and game.buildings[1].type=="cafe","Café is constructed through its catalog button")
	await stage("build_cafe","Guarda il cantiere")
	await advance(float(game.buildings[1].construction_remaining)+0.1)
	await stage("assign_worker","Apri il caffè")
	await press("Apri il caffè",ui.tutorial_panel)
	expect(ui.panel_kind=="building" and ui.panel_id==int(game.buildings[1].id),"Guidance opens the specific café dialog")
	await press("Gestisci i lavoratori",ui.modal)
	if not await press("Assegna al negozio",ui.modal):
		await finish(preferences)
		return
	expect(game.buildings[1].workers==[game.citizens[0].id],"Assignment gives the café the actual accepted citizen")
	await stage("restock","Avvia il primo rifornimento")
	await press("Avvia il primo rifornimento",ui.tutorial_panel)
	if not await press("Avvia rifornimento  ·  ",ui.modal,true):
		await finish(preferences)
		return
	var product: Dictionary = game.buildings[1].products[0]
	expect(product.status=="restocking","Rifornimento button starts the first actual product timer")
	expect(not game.paused,"Building dialog does not pause the production timer")
	await stage("stock","Controlla il caffè")
	await press("Controlla il caffè",ui.tutorial_panel)
	await advance(float(product.remaining)+0.2)
	expect(product.status=="ready" and find_button(ui.modal,"Riempi gli scaffali  →")!=null,"Production finishes while the café dialog stays open and refreshes itself")
	if not await press("Riempi gli scaffali  →",ui.modal):
		await finish(preferences)
		return
	expect(product.status=="stocked" and int(product.stock)>0,"Shelving button makes the first product available for sale")
	expect(game.tutorial_stage=="complete" and int(game.stats.restocked)==1,"All seven lessons complete through actual actions")
	ui._close_modal()
	await settle()
	expect(not ui.tutorial_panel.visible,"Finished tutorial removes its guidance card")
	var coins_before: float = game.coins
	await advance(6.0)
	expect(game.coins>coins_before,"The completed tutorial leaves a working café earning real coins")
	expect(game.citizens.size()==1 and game.buildings.size()==2 and scene._guard_ids()==[0],"Final world contains the built house, working café, accepted citizen and permanent military")
	var arrival_profile: Dictionary = game.defense_profile()
	expect(game.wave_clock>=float(arrival_profile.interval_min)-6.1 and game.wave_clock<=float(arrival_profile.interval_max)-5.9,"Normal arrivals use the population-adjusted interval after six seconds of normal play")
	scene.focus_city()
	scene._update_camera(3.0)
	ui.toast_stack.hide()
	await capture("C:/Users/flavi/Desktop/CODEX_niente_zombie_per_favore/docs/TUTORIAL-COMPLETATO-v04.png")
	await finish(preferences)

func finish(preferences: Node) -> void:
	scene.queue_free()
	await settle()
	await create_timer(0.15).timeout
	for path: String in [game.save_path,game.save_path+".tmp",game.save_path+".bak",preferences.settings_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("TUTORIAL_WALKTHROUGH_CHECKS ",checks," FAILURES ",failures)
	quit(0 if failures==0 else 1)
