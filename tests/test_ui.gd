extends SceneTree
## Rendering + action smoke test. Run with the normal rendering driver.

var failures: Array[String] = []
var game: Node
var main: Control
var ui: CanvasLayer

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	if condition:
		print("UI PASS: " + description)
	else:
		failures.append(description)
		push_error("UI FAIL: " + description)

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var output: Image = get_root().get_texture().get_image()
	check(output.save_png("res://.runtime/ui-"+name+".png")==OK,"capture "+name)

func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://.runtime")
	game = get_root().get_node("Game")
	game.save_path = "res://.runtime/ui-test-save.json"
	game.reset_game()
	game.coins = 10000
	game.supplies = 1000
	game.paused = true
	main = load("res://main.tscn").instantiate()
	get_root().add_child(main)
	await process_frame
	ui = main.ui
	ui._start_game()
	game.paused = true
	ui._show_citizens()
	check(ui.panel_kind=="citizens","citizens opens")
	await capture("citizens")
	var cid: int = game.citizens[0].id
	ui._show_job_select(cid)
	check(ui.panel_kind=="job_select","job selector opens")
	await capture("job-select")
	var cafe: Dictionary = game.buildings[1]
	ui._show_assignment(cafe.id)
	check(ui.panel_kind=="assignment","assignment opens")
	await capture("assignment")
	ui.show_building(cafe.id)
	check(ui.panel_kind=="building","shop opens")
	await capture("building")
	ui.show_building(game.buildings[0].id)
	await capture("residence")
	ui._show_build()
	check(ui.panel_kind=="build","construction opens")
	await capture("build")
	var old_count: int = game.buildings.size()
	ui._build("workshop")
	check(game.buildings.size()==old_count+1,"construction action")
	ui._show_armory()
	check(ui.panel_kind=="armory","armory opens")
	await capture("armory")
	ui._equip("shotgun")
	check(game.weapon=="shotgun","weapon unlock / equip")
	ui._citizen_equipment(1,cid,game.owned_weapons)
	check(game.citizens[0].weapon=="shotgun","citizen equipment action")
	var old_ammo: int = game.ammo
	ui._ammo()
	check(game.ammo==old_ammo+30,"ammo preparation")
	ui.show_gate()
	check(ui.panel_kind=="gate","gate opens")
	await capture("gate")
	game.gate_hp -= 100
	ui._repair()
	check(game.gate_hp==game.gate_max,"gate repair action")
	var old_level: int = game.gate_level
	ui._upgrade()
	check(game.gate_level==old_level+1,"gate upgrade action")
	ui._show_expeditions()
	check(ui.panel_kind=="expeditions","expeditions opens")
	await capture("expeditions")
	ui._select_member(cid)
	ui._launch_expedition()
	check(game.expedition.status=="running","expedition departure action")
	await capture("expedition-running")
	game._tick_expedition(500)
	ui._show_expeditions()
	check(game.expedition.status=="ready","expedition ready")
	await capture("expedition-ready")
	ui._claim_expedition()
	check(game.expedition.status=="idle","claim expedition action")
	game.citizens[0].hp = 50
	ui._heal(cid)
	check(game.citizens[0].hp==100,"heal citizen action")
	ui._show_quests()
	check(ui.panel_kind=="quests","quest diary opens")
	await capture("quests")
	ui.show_help()
	check(ui.panel_kind=="help","help opens")
	await capture("help")
	game.paused = false
	ui._show_pause()
	check(game.paused,"pause action")
	await capture("pause")
	ui._close_modal()
	check(not game.paused,"resume action")
	game.paused = true
	if game.visitors.size()>0:
		var visitor_id: int = game.visitors[0].id
		ui.show_visitor(visitor_id)
		check(ui.panel_kind=="visitor","visitor dialog opens")
		await capture("visitor")
		ui._accept_visitor(visitor_id)
		check(game.visitors.is_empty(),"visitor decision action")
	ui._close_modal()
	await capture("cozy-overview")
	print("UI SMOKE RESULT: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
