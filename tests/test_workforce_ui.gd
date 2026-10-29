extends SceneTree
var checks: int = 0
var failures: int = 0
var game: Node
var ui: CanvasLayer
var layout: Node
var fixture: Script
var workforce: Script
var a: Dictionary
var ideal: Dictionary
var skilled: Dictionary
var transfer: Dictionary
var traveler: Dictionary
var cafe: Dictionary
var other_cafe: Dictionary
var bakery: Dictionary
var capture_prefix: String = ""
func _initialize() -> void: run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("WORKFORCE UI FAIL: ",capture_prefix,": ",message)
func settle(frames: int=5) -> void:
	for frame: int in range(frames): await process_frame
func node(name: String) -> Control: return ui.modal.find_child(name,true,false)
func opened() -> void:
	await settle()
	ui._stop_modal_motion()
	ui._modal_motion_progress = 1.0
	ui._update_hud()
	await settle()
	expect(ui.modal_scroll.get_h_scroll_bar().max_value<=ui.modal_scroll.size.x+2,"No horizontal overflow")
	if layout.android_phone(): expect(ui._modal_box.size.distance_to(layout.ui_size())<3,"Phone workforce pages use the full display")
	for button: Node in ui.modal.find_children("*","Button",true,false):
		if button.is_visible_in_tree() and layout.mobile: expect(button.size.y>=layout.TOUCH_TARGET-1,"Touch target stays comfortable: "+str(button.name))
func tap(button: Button) -> void:
	expect(button!=null,"Requested workforce action exists")
	if button==null: return
	if ui.modal_scroll.is_ancestor_of(button): ui.modal_scroll.ensure_control_visible(button)
	await settle()
	var point: Vector2 = button.get_global_transform_with_canvas()*(button.size*0.5)
	for down: bool in [true,false]:
		if layout.mobile:
			var finger: InputEventScreenTouch = InputEventScreenTouch.new()
			finger.position = point
			finger.pressed = down
			root.push_input(finger,true)
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.device = InputEvent.DEVICE_ID_EMULATION if layout.mobile else 0
		mouse.position = point
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = down
		root.push_input(mouse,true)
		await process_frame
	await opened()
func capture(name: String) -> void:
	var folder: String = OS.get_environment("NZPF_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name()=="headless": return
	ui.modal_scroll.scroll_vertical = 0
	await settle()
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(folder.path_join("LAVORI-"+capture_prefix+"-"+name+".png"))==OK,"Save workforce preview")
func citizen(dream: String, food: int) -> Dictionary:
	var person: Dictionary = game._make_citizen()
	person.dream = dream
	person.food = food
	game.citizens.append(person)
	return person
func fresh() -> void:
	ui._close_modal()
	game._new_game()
	game.skip_tutorial()
	game.coins = 50000
	game.supplies = 1000
	for kind: String in ["residence","residence","cafe","cafe","bakery","workshop"]: fixture.build_ready(game,kind)
	cafe = game.buildings[2]
	other_cafe = game.buildings[3]
	bakery = game.buildings[4]
	a = citizen("bakery",8)
	ideal = citizen("cafe",2)
	skilled = citizen("garden",9)
	transfer = citizen("workshop",5)
	traveler = citizen("clinic",4)
	game.assign(int(a.id),int(cafe.id))
	game.assign(int(traveler.id),int(cafe.id))
	game.assign(int(transfer.id),int(other_cafe.id))
	expect(game.start_expedition(0,[traveler.id]),"Fixture uses an actual expedition for the absent employee")
func comparison(person_id: int, kind: String) -> Control:
	return node("JobComparison_"+str(person_id)).get_node(kind)
func run() -> void:
	game = root.get_node("Game")
	layout = root.get_node("DeviceLayout")
	game.set_process(false)
	game.save_path = "user://workforce-test-save.json"
	root.get_node("Preferences").settings_path = "user://workforce-test-preferences.cfg"
	fixture = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	workforce = load("res://scripts/workforce_panel.gd")
	var folder: String = OS.get_environment("NZPF_CAPTURE_DIR")
	if not folder.is_empty(): DirAccess.make_dir_recursive_absolute(folder)
	for profile: Array in [["PHONE169",Vector2i(1920,1080),400,true],["PHONE",Vector2i(2400,1080),400,true],["TABLET",Vector2i(2048,1536),800,true],["DESKTOP",Vector2i(1440,900),0,false]]:
		root.min_size = Vector2i.ZERO
		root.size = profile[1]
		layout.mobile = profile[3]
		layout.preview_android_shortest_dp = profile[2]
		layout.preview_insets = Vector4(24,6,40,8) if profile[3] else Vector4.ZERO
		for size_name: String in ["compact","large"]:
			capture_prefix = str(profile[0])+"-"+size_name
			root.get_node("Preferences").apply_settings({"interface_size":size_name,"sound_enabled":false},false)
			layout.refresh()
			ui = load("res://scripts/game_ui.gd").new()
			root.add_child(ui)
			await settle()
			ui._start_game()
			ui.toast_stack.hide()
			fresh()
			ui._show_job_select(int(a.id))
			await opened()
			expect(ui.modal.find_child("DialogBalances",true,false)==null,"Free job changes are not presented as currency purchases")
			expect(comparison(int(a.id),"DesiredJob").get_meta("job_kind")=="bakery","Desired job is explicit and has the right emblem")
			expect(comparison(int(a.id),"AssignedJob").get_meta("job_kind")=="cafe","Current assignment is shown separately")
			expect(comparison(int(a.id),"AssignedJob").find_child("JobName",true,false).text=="Caffè · 1","Identical shops have distinct left-to-right labels")
			expect(workforce.building_name(game,other_cafe)=="Caffè · 2","Second copy has its own visible number")
			expect(node("ChooseJob_"+str(cafe.id)).disabled and node("ChooseJob_"+str(cafe.id)).text=="Già assegnato","Current workplace cannot be mistaken for a new assignment")
			expect(node("ChooseJob_"+str(bakery.id)).text=="Trasferisci qui","A move is described as a transfer")
			var destinations: Array = ui.modal.find_children("*","VBoxContainer",true,false).filter(func(card: Node) -> bool: return card.has_meta("job_building"))
			expect(destinations[0].get_meta("job_building")==bakery.id,"Desired workplaces are presented first")
			if size_name=="compact": await capture("SCELTA")
			ui._show_assignment(int(cafe.id))
			await opened()
			expect(node("StaffCount").text=="2 / 3 assegnati · 1 al lavoro","Occupied slots and present employees are distinguished")
			expect(node("ReleaseWorker_"+str(traveler.id)).disabled,"An absent employee keeps the slot and cannot be released")
			var candidates: Array = ui.modal.find_children("*","VBoxContainer",true,false).filter(func(card: Node) -> bool: return card.has_meta("candidate_citizen"))
			expect(candidates[0].get_meta("candidate_citizen")==ideal.id,"An available person desiring this workplace is recommended first")
			if size_name=="compact": await capture("SQUADRA")
			var base_stock: int = int(cafe.products[0].max_stock)
			await tap(node("AssignWorker_"+str(ideal.id)))
			expect(ui.panel_kind=="assignment" and cafe.workers.size()==3 and int(ideal.job)==int(cafe.id),"Assignment updates the same team screen and the real roster")
			expect(cafe.dream_bonus and int(cafe.products[0].max_stock)==base_stock*2,"Matching the desired job unlocks the real stock bonus")
			expect(node("AssignWorker_"+str(skilled.id)).disabled and node("AssignWorker_"+str(skilled.id)).text=="Completo","Full shop explains why another assignment is unavailable")
			await tap(node("ReleaseWorker_"+str(ideal.id)))
			expect(int(ideal.job)==-1 and cafe.workers.size()==2,"Release frees a slot without removing the citizen")
			expect(cafe.dream_bonus and int(cafe.products[0].max_stock)==base_stock*2,"Permanent dream bonus remains after the employee leaves")
			await tap(node("AssignWorker_"+str(transfer.id)))
			expect(int(transfer.job)==int(cafe.id) and not other_cafe.workers.has(transfer.id) and cafe.workers.has(transfer.id),"Transfer moves the person between the correct shops exactly once")
			ui._show_job_select(int(skilled.id))
			await opened()
			expect(node("ChooseJob_"+str(cafe.id)).disabled,"Citizen selector also respects the full roster")
			await tap(node("ChooseJob_"+str(cafe.id)))
			expect(int(skilled.job)==-1 and cafe.workers.size()==3,"Disabled destination never changes an existing assignment")
			ui._show_job_select(int(traveler.id))
			await opened()
			expect(node("ReleaseCitizen").disabled and node("ChooseJob_"+str(bakery.id)).text=="In spedizione","Away citizen cannot change jobs and sees the reason")
			expect(comparison(int(traveler.id),"AssignedJob").get_meta("job_kind")=="cafe","Travel status never hides the retained workplace")
			expect(comparison(int(traveler.id),"DesiredJob").find_child("JobName",true,false).text=="Clinica","An unbuilt desired workplace is still understandable")
			game._tick_expedition(float(game.expedition.duration)+1)
			ui._update_hud()
			await opened()
			expect(not node("ReleaseCitizen").disabled and not node("ChooseJob_"+str(bakery.id)).disabled,"Return updates the current selector without reopening it")
			ui._show_job_select(int(a.id))
			await opened()
			await tap(node("ChooseJob_"+str(bakery.id)))
			expect(ui.panel_kind=="job_select" and int(a.job)==int(bakery.id),"Citizen assignment remains open and displays the chosen job")
			expect(comparison(int(a.id),"DesiredJob").get_meta("job_kind")==comparison(int(a.id),"AssignedJob").get_meta("job_kind"),"A fulfilled desire is visually verifiable")
			if size_name=="compact": await capture("ASSEGNATO")
			await tap(node("ReleaseCitizen"))
			expect(int(a.job)==-1 and node("ReleaseCitizen").disabled,"Clearing the current job is explicit and becomes unavailable when already free")
			ui._show_citizens()
			await opened()
			expect(comparison(int(a.id),"AssignedJob").find_child("JobName",true,false).text=="Nessun lavoro","Citizens list shares the same clear job vocabulary")
			ui._close_modal()
			ui.queue_free()
			await settle()
	# New colonies and construction keep explicit empty/unavailable states.
	ui = load("res://scripts/game_ui.gd").new()
	root.add_child(ui)
	await settle()
	game._new_game()
	game.skip_tutorial()
	game.coins = 50000
	fixture.build_ready(game,"residence")
	a = citizen("cafe",7)
	ui._show_job_select(int(a.id))
	await opened()
	expect(ui.modal.find_children("ChooseJob_*","Button",true,false).is_empty(),"Homes are never offered as workplaces")
	game.build("cafe")
	var site: Dictionary = game.buildings.back()
	ui._show_job_select(int(a.id))
	await opened()
	expect(node("ChooseJob_"+str(site.id)).disabled and node("ChooseJob_"+str(site.id)).text=="In costruzione","Desired construction explains why it is not ready")
	game._tick_construction(float(site.construction_remaining)+1)
	ui._update_hud()
	await opened()
	expect(not node("ChooseJob_"+str(site.id)).disabled,"Completing construction makes the workplace available live")
	ui.queue_free()
	print("WORKFORCE UI: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
