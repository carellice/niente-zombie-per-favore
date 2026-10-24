extends SceneTree
## Acceptance checks for the four tasks selected from the Notion board.
const Roaming = preload("res://scripts/citizen_roaming.gd")
const Catalog = preload("res://scripts/survivor_catalog.gd")
var checks: int = 0
var failures: int = 0
var game: Node
var ui: CanvasLayer
var scene: Control
var layout: Node
var preferences: Node
func _initialize() -> void: run.call_deferred()
func expect(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("BOARD FAIL: ",detail)
func settle(frames: int=5) -> void:
	for frame: int in range(frames): await process_frame
func opened() -> void:
	await settle()
	ui._stop_modal_motion()
	ui._modal_motion_progress = 1
	await settle()
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	var folder: String = OS.get_environment("NZPF_CAPTURE_DIR")
	if folder.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder.path_join("BOARD-"+name+".png"))
func run() -> void:
	game = root.get_node("Game")
	layout = root.get_node("DeviceLayout")
	preferences = root.get_node("Preferences")
	game.set_process(false)
	var data: String = OS.get_environment("NZPF_TEST_DATA_DIR")
	if data.is_empty(): data = ProjectSettings.globalize_path("res://.runtime/board-oct24")
	DirAccess.make_dir_recursive_absolute(data)
	game.save_path = data.path_join("colony.json")
	preferences.settings_path = data.path_join("preferences.cfg")
	game._new_game()
	game.skip_tutorial()
	game.coins = 100000
	game.supplies = 10000
	ready_build(game,"residence")
	ready_build(game,"cafe")
	game._is_loading = true
	test_names()
	test_paths()
	game._is_loading = false
	game._spawn_visitor()
	game.visitors[0].citizen.look = 3
	game.visitors[0].citizen.name = "Chiara De Luca"
	for profile: Array in [["PHONE169",Vector2i(1920,1080),true,400.0],["PHONE",Vector2i(2400,1080),true,400.0],["TABLET",Vector2i(2048,1536),true,800.0],["DESKTOP",Vector2i(1280,800),false,0.0]]:
		if is_instance_valid(scene):
			scene.queue_free()
			await settle()
		root.min_size = Vector2i.ZERO
		root.size = profile[1]
		layout.mobile = profile[2]
		layout.preview_android_shortest_dp = profile[3]
		layout.preview_insets = Vector4(24,6,12,8) if profile[2] else Vector4.ZERO
		preferences.apply_settings({"interface_size":"compact","sound_enabled":false},false)
		layout.refresh()
		scene = load("res://main.tscn").instantiate()
		root.add_child(scene)
		scene.set_process(false)
		ui = scene.ui
		await settle()
		ui._start_game()
		game.paused = true
		for scale_name: String in ["compact","medium","large"]:
			ui._close_modal()
			preferences.apply_settings({"interface_size":scale_name},false)
			layout.refresh()
			await settle()
			var label: String = str(profile[0])+" "+scale_name
			expect(ui._header.is_ancestor_of(ui._defense_context),label+": weapon information lives in the top bar")
			expect(layout.safe_rect().grow(2).encloses(ui._header.get_global_rect()),label+": the full header fits the display")
			expect(ui._header.get_global_rect().grow(2).encloses(ui._defense_context.get_global_rect()),label+": weapon state fits inside the header")
			expect(ui._defense_context.position.x>ui.population_label.get_global_rect().end.x-ui._defense_context.get_parent().global_position.x,label+": weapon follows the population counter")
			for defense: bool in [false,true]:
				ui.set_world_context(defense)
				expect(ui._defense_context.is_visible_in_tree(),label+": weapon remains visible in village and road")
			game.weapon = "sniper"
			game.ammo = 123
			game.shot_cooldown = 0.8
			ui._update_defense_status()
			expect(ui._defense_ammo.text.contains("123") and ui._defense_status.text.contains("0,8"),label+": actual ammunition and recharge update")
			if scale_name=="compact": await capture(str(profile[0])+"-HUD")
			game.shot_cooldown = 0
			for kind: String in ui.PURCHASE_PANELS:
				ui._open(kind,"Prova")
				await opened()
				var balances: Control = ui.modal.find_child("DialogBalances",true,false)
				expect(balances!=null and balances.is_visible_in_tree(),label+": balances available in "+kind)
				if balances==null: continue
				expect(not ui.modal_scroll.is_ancestor_of(balances),label+": balances remain visible when scrolling "+kind)
				expect(layout.safe_rect().grow(2).encloses(balances.get_global_rect()),label+": balances have safe margins in "+kind)
				var coins: Label = balances.find_child("DialogCoins",true,false)
				var supplies: Label = balances.find_child("DialogSupplies",true,false)
				expect(coins.text==str(int(game.coins)) and supplies.text==str(game.supplies),label+": exact integer funds shown in "+kind)
				game.coins -= 12
				game.supplies -= 3
				ui._update_hud()
				expect(coins.text==str(int(game.coins)) and supplies.text==str(game.supplies),label+": counters update after a transaction in "+kind)
			ui.show_visitor(int(game.visitors[0].id))
			await opened()
			expect(ui.modal_content.find_child("ChiaraCherries",true,false)!=null,label+": nurse admission has the painted cherry badge")
			if scale_name=="compact": await capture(str(profile[0])+"-CHIARA")
			ui._show_citizens()
			await opened()
			expect(ui.modal_content.find_child("ChiaraCherries",true,false)!=null,label+": resident cards retain the cherry badge")
			ui._show_armory()
			await opened()
			if scale_name=="compact": await capture(str(profile[0])+"-ARMORY")
	if is_instance_valid(scene): scene.queue_free()
	await settle()
	print("NOTION BOARD: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func test_names() -> void:
	game.citizens.clear()
	for look: int in [3,7]:
		expect(Catalog.is_nurse(look) and Catalog.names_for_look(look)==["Chiara"],"Nurse and legacy alias always use Chiara")
	for index: int in range(70):
		var citizen: Dictionary = game._make_citizen()
		citizen.look = 3
		citizen.name = game._unique_citizen_name(3)
		game.citizens.append(citizen)
		expect(str(citizen.name).begins_with("Chiara "),"Even an exhausted surname pool keeps the nurse's first name")
	var names: Dictionary = {}
	for citizen: Dictionary in game.citizens: names[citizen.name] = true
	expect(names.size()==70,"Nurse identities remain distinct")
	game.citizens.resize(4)
	game.citizens[0].name = "Marta De Luca"
	game.citizens[1].name = "Chiara Rossi"
	game.citizens[2].look = 7
	game.citizens[2].name = "Marta Rossi"
	game._migrate_citizen_names()
	expect(game.citizens[0].name=="Chiara De Luca","Existing nurse keeps her multiword surname")
	var once: Array = game.citizens.map(func(c: Dictionary) -> String: return c.name)
	game._migrate_citizen_names()
	expect(once==game.citizens.map(func(c: Dictionary) -> String: return c.name),"Repeated migration preserves names")
func test_paths() -> void:
	var roaming: RefCounted = Roaming.new()
	var people: Array = [{"id":1,"job":-1,"away":false},{"id":2,"job":-1,"away":false}]
	var previous: float = roaming.position(1,600)
	var left: bool = false
	var right: bool = false
	var stops: int = 0
	var discontinuous: bool = false
	for tick: int in range(1800):
		roaming.advance(people,600,30,0.1)
		var x: float = roaming.position(1,600)
		var step: float = x-previous
		left = left or step<0
		right = right or step>0
		if absf(step)<0.001: stops += 1
		if absf(step)>3.001 or x<30 or x>570: discontinuous = true
		previous = x
	expect(left and right and stops>10,"Idle citizens walk both ways and pause between destinations")
	expect(not discontinuous,"Every step is continuous and stays within the village")
	expect(absf(roaming.position(1,600)-roaming.position(2,600))>0.01,"Different residents have independent itineraries")
	people[0].away = true
	var fixed: float = roaming.position(1,600)
	roaming.advance(people,600,30,2)
	expect(is_equal_approx(fixed,roaming.position(1,600)),"Away citizens do not roam")
	people[0].away = false
	people[0].job = 2
	roaming.advance(people,600,30,2)
	expect(is_equal_approx(fixed,roaming.position(1,600)),"Working residents retain their building placement")
	roaming.advance([],600,30,1)
	expect(roaming.states.is_empty(),"Removed residents leave no stale path state")

func ready_build(model: Node, kind: String) -> bool:
	var fixture: Script = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	return fixture.build_ready(model,kind)
