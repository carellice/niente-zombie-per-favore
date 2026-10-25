extends SceneTree
const Rules = preload("res://scripts/cozy_rules.gd")
var Fixture: Script
var game: Node
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("COZY FAIL: ",message)
func fresh() -> void:
	game._new_game()
	game._is_loading = true
	game.skip_tutorial()
	game.coins = 100000
	game.supplies = 10000
func building(kind: String) -> Dictionary:
	expect(Fixture.build_ready(game,kind),"Build fixture "+kind)
	return game.buildings.back()
func staffed(kind: String) -> Dictionary:
	var b: Dictionary = building(kind)
	var c: Dictionary = game._make_citizen()
	game.citizens.append(c)
	expect(game.assign(c.id,b.id),"Staff "+kind)
	return b
func run() -> void:
	Fixture = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	root.get_node("Game").set_process(false)
	game = load("res://scripts/game_state.gd").new()
	game.save_path = "user://cozy-test.json"
	root.add_child(game)
	game.set_process(false)
	fresh()
	expect(game.community==Rules.fresh(),"New game has no free discoveries or rewards")
	var base: Dictionary = game.defense_profile()
	expect(base.count_max==5 and base.interval_min==90,"Cozy initial pressure")
	for count: int in [1,5,10,20,50,100,500]:
		game.citizens.clear()
		for i: int in range(count): game.citizens.append(game._make_citizen())
		var profile: Dictionary = game.defense_profile()
		expect(profile.count_max<=11 and profile.interval_min>=63,"Pressure stays capped")
		expect(game.community_income_bonus()>1 and game.community_income_bonus()<=1.30,"Population gives capped income benefit")
	fresh()
	var cafe: Dictionary = staffed("cafe")
	expect(game.defense_profile().interval_min>base.interval_min,"Cafe provides a calmer interval")
	var interval: float = game.defense_profile().interval_min
	staffed("cafe")
	# Population itself changes pressure; compare with all residents absent except cafe staff.
	var expected: float = 90.0*lerpf(1.0,0.70,2.0/22.0)*1.2
	expect(is_equal_approx(game.defense_profile().interval_min,expected),"Cafe copies do not stack")
	var garden: Dictionary = staffed("garden")
	expect(Rules.service(game,garden.id),"Start harvest")
	var supplies: int = game.supplies
	expect(not Rules.service(game,garden.id),"No duplicate active harvest")
	Rules.tick(game,120)
	expect(Rules.service(game,garden.id) and game.supplies==supplies+12,"Harvest gives supplies")
	expect(not Rules.service_preview(game,cafe.id).valid,"Cafe cannot claim a harvest")
	game.community.discoveries.append("allotments")
	expect(Rules.service_preview(game,garden.id).amount==18,"Seed discovery improves next harvest")
	expect(Rules.service(game,garden.id),"A new harvest uses the improved recipe")
	var suspended_at: float = Time.get_unix_time_from_system()
	game._suspend_construction(suspended_at)
	game._resume_construction(suspended_at+60)
	expect(garden.service.remaining==60,"Android resume recovers the missed service time")
	game._resume_construction(suspended_at+120)
	expect(garden.service.remaining==60,"Repeated resume cannot advance a timer twice")
	game.get_citizen(garden.workers[0]).away = true
	Rules.tick(game,30)
	expect(garden.service.remaining==60,"A service needs its worker during preparation")
	game.get_citizen(garden.workers[0]).away = false
	var workshop: Dictionary = staffed("workshop")
	expect(Rules.service(game,workshop.id),"Start materials")
	Rules.tick(game,150)
	expect(Rules.service(game,workshop.id) and game.community.parts==3,"Workshop makes materials")
	var clinic: Dictionary = staffed("clinic")
	expect(game.healing_cost()==2 and game.expedition_damage(false)==7,"Clinic changes healing and wounds")
	game.community.discoveries.append("pharmacy")
	expect(game.healing_cost()==1,"Medical discovery improves healing")
	var c: Dictionary = game.citizens[0]
	c.hp = 45
	var before: int = game.supplies
	expect(game.heal_citizen(c.id) and c.hp==100 and game.supplies==before-1,"Real discounted healing")
	var baseline: Dictionary = game.expedition_preview(0,[c.id])
	staffed("waterworks")
	expect(game.expedition_cost(0)==3,"Water saves voyage supplies")
	staffed("bakery")
	expect(game.expedition_preview(0,[c.id]).full_rewards.coins>baseline.full_rewards.coins,"Bakery improves expedition loot")
	staffed("tailor")
	expect(game.expedition_preview(0,[c.id]).chance>=baseline.chance,"Tailor improves probability")
	game.community.parts = 100
	expect(not Rules.upgrade(game,cafe.id,false),"Storage requires its discovery")
	game.community.discoveries.append("minimarket")
	var old_max: int = cafe.products[0].max_stock
	expect(Rules.upgrade(game,cafe.id,false) and cafe.products[0].max_stock==old_max*2,"Storage doubles actual capacity")
	expect(not Rules.upgrade(game,cafe.id,false),"Storage never charges twice")
	game.community.discoveries.append("depot")
	expect(Rules.upgrade(game,cafe.id,true),"Automatic shelves purchase")
	cafe.products[0].status = "restocking"
	cafe.products[0].remaining = 1
	game._tick_products(2)
	expect(cafe.products[0].status=="stocked","Automatic shelves expose completed goods")
	var coins_before: float = game.coins
	game._tick_products(999)
	expect(cafe.products[0].status=="empty" and game.coins>coins_before,"Automatic shelves sell but never start spending")
	var quote: Dictionary = game.batch_preview()
	game.coins = 0
	expect(not game.batch_production() and cafe.products[0].status=="empty","Unaffordable batch changes nothing")
	game.coins = 100000
	expect(game.batch_production() and cafe.products[0].status=="restocking","Batch starts unlocked productions")
	game._add_threat("walker",game.GATE_X-100)
	var enemy_x: float = game.threats[0].x
	game.management_open = true
	game.advance(2)
	expect(game.threats[0].x==enemy_x and cafe.products[0].remaining<float(cafe.products[0].duration),"Menus pause combat while production progresses")
	game.management_open = false
	game.advance(1)
	expect(game.threats[0].x>enemy_x,"Combat resumes on closing menus")
	fresh()
	game._spawn_visitor()
	var v: Dictionary = game.visitors[0]
	v.x = game.visitor_destination(0)
	v.suspicious = false
	expect(Rules.ask(game,v.id,"journey") and Rules.ask(game,v.id,"health"),"Questions store stable answers")
	expect(not Rules.ask(game,v.id,"nonsense"),"Unknown question rejected")
	expect(Rules.observe(game,v.id),"Observation is free and available at gate")
	expect(not game.accept_visitor(v.id),"Cannot admit during observation")
	game._spawn_visitor()
	game.visitors[1].x = game.visitor_destination(1)
	expect(not Rules.observe(game,game.visitors[1].id),"Only one observation slot")
	Rules.tick(game,60)
	expect(v.observation=="done" and Rules.visitor_report(v).contains("nessun segno"),"Healthy diagnosis completes")
	building("residence")
	expect(game.accept_visitor(v.id),"Healthy observed resident can enter")
	v = game.visitors[0]
	v.x = game.visitor_destination(0)
	v.suspicious = true
	expect(Rules.observe(game,v.id),"Observation slot frees after admission")
	Rules.tick(game,60)
	expect(not game.accept_visitor(v.id) and game.threats.is_empty(),"Confirmed infection cannot enter or create threat")
	game.reject_visitor(v.id)
	expect(game.visitors.is_empty() and game.departing_visitors.size()==1,"Refused person walks away")
	fresh()
	building("residence")
	building("residence")
	staffed("cafe")
	while game.citizens.size()<3: game.citizens.append(game._make_citizen())
	expect(Rules.complete_project(game),"First community chapter")
	building("garden")
	building("waterworks")
	game.stats.expeditions = 1
	expect(Rules.complete_project(game),"Self-sufficiency chapter")
	building("workshop")
	expect(not Rules.complete_project(game),"Radio requires the station discovery")
	game.community.discoveries.append("station")
	game.community.parts = 100
	expect(Rules.complete_project(game) and game.community.projects.has("radio"),"Radio project activates")
	while game.citizens.size()<10: game.citizens.append(game._make_citizen())
	game.stats.zones_explored = 4
	expect(Rules.complete_project(game),"Network chapter unlocks exchanges")
	expect(not Rules.complete_project(game),"No duplicate chapter reward")
	for i: int in range(9):
		game.day += 1
		expect(Rules.deliver(game),"Repeatable exchange %d" % i)
		expect(not Rules.deliver(game),"No duplicate exchange same day")
	game._is_loading = false
	expect(game.save_game(),"Save new systems")
	var snapshot: Dictionary = game.community.duplicate(true)
	var loaded: bool = game.load_game()
	expect(loaded and game.community==snapshot,"Community roundtrip without duplicated rewards")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_path))
	data.community.parts = -1
	expect(not game._valid_save(data),"Negative materials invalid")
	data.erase("community")
	expect(game._valid_save(data),"Old saves remain valid")
	for zone_index: int in range(game.zones.size()):
		game.expedition = {"status":"idle"}
		var member: Dictionary = game.citizens[0]
		member.away = false
		expect(game.start_expedition(zone_index,[member.id]),"Visit destination %d" % zone_index)
		game._tick_expedition(1000)
		var materials: int = game.community.parts
		expect(game.claim_expedition() and game.community.parts>materials,"Voyage gives materials")
		expect(Rules.found(game,str(game.zones[zone_index].id)),"Guaranteed first discovery")
	var saved_discoveries: int = game.community.discoveries.size()
	game.expedition = {"status":"idle"}
	game.start_expedition(0,[game.citizens[0].id])
	game._tick_expedition(1000)
	game.claim_expedition()
	expect(game.community.discoveries.size()==saved_discoveries,"Discoveries never duplicate")
	# The expedition quotes its injury at departure; a staffing change cannot worsen it.
	var medic: Dictionary = staffed("clinic")
	game.expedition = {"status":"idle"}
	var medic_id: int = medic.workers[0]
	var medical_quote: Dictionary = game.expedition_preview(0,[medic_id])
	expect(game.start_expedition(0,[medic_id]),"The clinic worker can travel")
	var injury: int = int(medical_quote.success_damage) if game.expedition.success else int(medical_quote.failure_damage)
	game._tick_expedition(1000)
	expect(game.get_citizen(medic_id).hp==100-injury,"Returning injuries match the departure quote even when staffing changes")
	# Each advanced tower weapon has a concrete advantage while the basic pistol stays reliable.
	for key: String in ["pistol","shotgun","sniper","smg"]:
		game.threats.clear()
		game.owned_weapons = ["pistol","shotgun","sniper","smg"]
		game.weapon = key
		game.ammo = 100
		game.shot_cooldown = 0
		var kind: String = "brute" if key=="sniper" else "runner" if key=="smg" else "walker"
		game._add_threat(kind,game.GATE_X-150)
		if key=="shotgun":
			game._add_threat("walker",game.GATE_X-180)
			game._add_threat("walker",game.GATE_X-200)
		expect(game.shoot(game.threats[0].id) and game.threats.is_empty(),"Real weapon role: "+key)
	game.coins = 100000
	game._breach()
	expect(game.coins==99950 and game.citizens.size()==11,"Breach cost capped and residents safe")
	for suffix: String in ["",".tmp",".bak"]:
		if FileAccess.file_exists(game.save_path+suffix): DirAccess.remove_absolute(game.save_path+suffix)
	game.queue_free()
	await process_frame
	print("COZY GAMEPLAY: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
