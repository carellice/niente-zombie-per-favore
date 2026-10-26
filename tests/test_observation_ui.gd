extends SceneTree
const Observation = preload("res://scripts/visitor_observation.gd")
const Rules = preload("res://scripts/cozy_rules.gd")
var checks: int = 0
var failures: int = 0
var game: Node
var ui: CanvasLayer
var fixture: Script
var toasts: Array[String] = []
func _initialize() -> void: run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("OBSERVATION UI FAIL: ",message)
func settle(frames: int=4) -> void:
	for frame: int in range(frames): await process_frame
func opened() -> void:
	await settle()
	ui._stop_modal_motion()
	ui._modal_motion_progress = 1.0
	ui._update_hud()
	await settle()
	if not is_instance_valid(ui.modal_scroll): return
	expect(ui.modal_scroll.get_h_scroll_bar().max_value<=ui.modal_scroll.size.x+2,"Admission page never scrolls horizontally")
func node(name: String) -> Control: return ui.modal.find_child(name,true,false)
func tap(button: Control) -> void:
	ui.modal_scroll.ensure_control_visible(button)
	await settle()
	var point: Vector2 = button.get_global_transform_with_canvas()*(button.size*0.5)
	for down: bool in [true,false]:
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.pressed = down
		touch.position = point
		root.push_input(touch,true)
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.device = InputEvent.DEVICE_ID_EMULATION
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = down
		mouse.position = point
		root.push_input(mouse,true)
		await process_frame
	await opened()
func fresh() -> Dictionary:
	ui._close_modal()
	game._new_game()
	game.skip_tutorial()
	game.coins = 10000
	game.supplies = 100
	fixture.build_ready(game,"residence")
	game._spawn_visitor()
	var visitor: Dictionary = game.visitors[0]
	visitor.x = game.visitor_destination(0)
	return visitor
func capture(name: String) -> void:
	var folder: String = OS.get_environment("NZPF_CAPTURE_DIR")
	if folder.is_empty() or DisplayServer.get_name()=="headless": return
	ui.modal_scroll.ensure_control_visible(node("ObservationCard"))
	await settle()
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png(folder.path_join("OSSERVAZIONE-"+name+".png"))==OK,"Save observation state preview")
func on_toast(message: String) -> void: toasts.append(message)
func run() -> void:
	game = root.get_node("Game")
	game.set_process(false)
	game.save_path = "user://observation-ui-colony.json"
	root.get_node("Preferences").settings_path = "user://observation-ui-preferences.cfg"
	fixture = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	game.toast.connect(on_toast)
	var folder: String = OS.get_environment("NZPF_CAPTURE_DIR")
	if not folder.is_empty(): DirAccess.make_dir_recursive_absolute(folder)
	for profile: Array in [["PHONE169",Vector2i(1920,1080),400,true],["PHONE",Vector2i(2400,1080),400,true],["TABLET",Vector2i(2048,1536),800,true],["DESKTOP",Vector2i(1440,900),0,false]]:
		root.min_size = Vector2i.ZERO
		root.size = profile[1]
		var layout: Node = root.get_node("DeviceLayout")
		layout.mobile = profile[3]
		layout.preview_android_shortest_dp = profile[2]
		layout.preview_insets = Vector4(24,6,40,8) if profile[3] else Vector4.ZERO
		root.get_node("Preferences").apply_settings({"interface_size":"compact","sound_enabled":false},false)
		layout.refresh()
		ui = load("res://scripts/game_ui.gd").new()
		root.add_child(ui)
		await settle()
		ui._start_game()
		ui.toast_stack.hide()
		for infected: bool in [false,true]:
			var visitor: Dictionary = fresh()
			visitor.suspicious = infected
			if infected: game.community.discoveries.append("lab")
			var duration: float = 30.0 if infected else 60.0
			var undisclosed: Dictionary = Observation.preview(game,visitor)
			visitor.suspicious = not infected
			expect(Observation.preview(game,visitor)==undisclosed,"The unverified card never leaks hidden infection")
			visitor.suspicious = infected
			ui.show_visitor(int(visitor.id))
			await opened()
			expect(node("ObserveVisitor").text=="Verifica il contagio" and not node("ObserveVisitor").disabled,"Action explains what the observation verifies")
			expect(node("ObservationPurpose").text.contains("infiltrato") and node("ObservationPurpose").text.contains("cancello"),"Purpose explains the concrete admission risk")
			expect(node("ObservationTiming").get_child(0).get_node("Quantity").text=="%d s" % int(duration),"Displayed duration uses the real medical discovery")
			expect(not node("ObservationExplanation").visible,"Long explanation remains optional")
			await tap(node("ObservationHelp"))
			expect(node("ObservationExplanation").visible,"Why-observe explanation opens through real input")
			await tap(node("ObservationHelp"))
			if not infected: await capture(str(profile[0])+"-PRIMA")
			var coins: float = game.coins
			var supplies: int = game.supplies
			var beds: int = game.capacity()
			await tap(node("ObserveVisitor"))
			expect(visitor.get("observation","")=="waiting" and visitor.observation_duration==duration,"Real observation action stores its original duration")
			expect(game.coins==coins and game.supplies==supplies and game.capacity()==beds and game.citizens.is_empty(),"Observation is free and occupies no bed")
			expect(node("AcceptVisitor").disabled and node("AcceptVisitor").text=="Attendi l'esito","Admission explains why it is temporarily unavailable")
			expect(node("ObservationProgress").visible and is_zero_approx(node("ObservationProgress").value),"Observation begins with an empty progress bar")
			game._spawn_visitor()
			var other: Dictionary = game.visitors[1]
			other.x = game.visitor_destination(1)
			expect(Observation.preview(game,other).state=="busy" and not Observation.preview(game,other).can_start,"Another waiting person sees the occupied-slot reason")
			Rules.tick(game,15.0)
			ui._update_hud()
			await settle()
			expect(node("ObservationTiming").get_child(0).get_node("Quantity").text=="%d s" % int(duration-15),"Visible countdown follows actual remaining seconds")
			expect(is_equal_approx(node("ObservationProgress").value,1500.0/duration),"Visible progress reflects elapsed time")
			if not infected:
				game.community.discoveries.append("lab")
				expect(Observation.preview(game,visitor).duration==60.0,"Mid-observation discovery does not distort an existing timer")
				await capture(str(profile[0])+"-ATTESA")
			Rules.tick(game,60.0)
			ui._update_hud()
			await settle()
			expect(not node("ObserveVisitor").visible and not node("ObservationProgress").visible,"Completed check replaces the timer and action with the verdict")
			expect(node("ObservationTitle").text==("Contagio confermato" if infected else "Nessun contagio rilevato"),"Verdict explicitly distinguishes infected and healthy people")
			expect(node("AcceptVisitor").disabled==infected,"Only a confirmed healthy person is eligible for admission")
			expect(toasts.back().contains("contagio confermato" if infected else "nessun contagio"),"Completion notice reports the actual verdict")
			await capture(str(profile[0])+("-CONTAGIO" if infected else "-SANO"))
			if infected:
				expect(not game.accept_visitor(int(visitor.id)) and game.threats.is_empty(),"Confirmed infiltrator stays outside without causing damage")
			else:
				await tap(node("AcceptVisitor"))
				expect(game.citizens.size()==1,"A real tap welcomes the verified healthy survivor")
		var visitor: Dictionary = fresh()
		visitor.x = game.exit_x
		expect(Observation.preview(game,visitor).state=="arriving" and not Observation.preview(game,visitor).can_start,"Before arrival the card explains that the check must wait")
		visitor.x = game.visitor_destination(0)
		Rules.observe(game,int(visitor.id))
		Rules.tick(game,12)
		ui._close_modal()
		game._is_loading = false
		expect(game.save_game() and game.load_game(),"Observation can be saved and resumed")
		expect(game.visitors[0].observation_duration==60.0 and float(game.visitors[0].observation_remaining)>47,"Original duration and countdown survive restart")
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
		data.visitors[0].erase("observation_duration")
		expect(game._valid_save(data),"Earlier saves without duration remain valid")
		data.visitors[0].observation_duration = -10
		expect(not game._valid_save(data),"Invalid optional timer metadata is rejected")
		ui.queue_free()
		await settle()
	print("OBSERVATION UI: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
