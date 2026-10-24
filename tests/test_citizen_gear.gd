extends SceneTree
## Real purchases, route-specific choices, atomic ammunition and save migration.
var checks: int = 0
var failures: int = 0
var model: Node
func _initialize() -> void: run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("PERSONAL GEAR FAIL: ",message)
func fresh() -> void:
	model._new_game()
	model._is_loading = true
	model.skip_tutorial()
	model.coins = 100000
	model.supplies = 10000
	for index: int in range(3): model.citizens.append(model._make_citizen())
func payload() -> Dictionary:
	model._is_loading = false
	expect(model.save_game(),"Isolated state saved")
	model._is_loading = true
	return JSON.parse_string(FileAccess.get_file_as_string(model.save_path))
func write(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(model.save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
func run() -> void:
	root.get_node("Game").set_process(false)
	model = load("res://scripts/game_state.gd").new()
	var data: String = OS.get_environment("NZPF_TEST_DATA_DIR")
	if data.is_empty(): data = ProjectSettings.globalize_path("res://.runtime/personal-gear-model")
	DirAccess.make_dir_recursive_absolute(data)
	model.save_path = data.path_join("colony.json")
	root.add_child(model)
	model.set_process(false)
	test_purchases()
	test_routes_and_departures()
	test_legacy_and_validation()
	test_tutorial_budget()
	model.queue_free()
	await process_frame
	print("PERSONAL GEAR MODEL: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func test_purchases() -> void:
	fresh()
	var a: Dictionary = model.citizens[0]
	var b: Dictionary = model.citizens[1]
	model.owned_weapons = ["pistol","shotgun","sniper","smg"]
	expect(not model.equip_citizen(a.id,"sniper"),"Tower unlocks never grant a free citizen weapon")
	model.owned_weapons = ["pistol"]
	for key: String in ["shotgun","sniper","smg"]:
		var definition: Dictionary = model.ExpeditionGear.WEAPONS[key]
		var money: float = model.coins
		var supplies: int = model.supplies
		var tower: int = model.ammo
		expect(model.buy_citizen_weapon(a.id,key),"Personal copy can be purchased independently: "+key)
		expect(model.coins==money-int(definition.cost) and model.supplies==supplies-int(definition.supplies),"Exact weapon price charged: "+key)
		expect(a.weapon==key and a.personal_weapons.has(key) and int(a.personal_ammo[key])==int(definition.pack),"Only the buyer owns and equips the starter pack: "+key)
		expect(not b.personal_weapons.has(key) and not model.equip_citizen(b.id,key) and model.ammo==tower and model.owned_weapons==["pistol"],"No second copy, tower unlock or tower ammunition is granted: "+key)
		money = model.coins
		expect(not model.buy_citizen_weapon(a.id,key) and model.coins==money,"Duplicate purchase is rejected without charge: "+key)
		expect(not model.buy_citizen_ammo(b.id,key),"Cannot buy ammo for an unowned copy: "+key)
		expect(model.buy_citizen_ammo(a.id,key) and int(a.personal_ammo[key])==int(definition.pack)*2,"Refill belongs to the correct weapon and person: "+key)
		expect(model.coins==money-int(definition.ammo_cost) and model.ammo==tower,"Personal ammunition has its own exact price: "+key)
		a.personal_ammo[key] = model.ExpeditionGear.MAX_AMMO
		money = model.coins
		expect(not model.buy_citizen_ammo(a.id,key) and model.coins==money,"Full ammo capacity cannot be overcharged: "+key)
	for key: String in ["pistol","invalid"]:
		expect(not model.buy_citizen_weapon(a.id,key) and not model.buy_citizen_ammo(a.id,key),"Free pistol and unknown purchases cannot charge")
	expect(not model.buy_citizen_weapon(99999,"sniper"),"Missing citizen cannot buy")
	b.away = true
	expect(not model.buy_citizen_weapon(b.id,"sniper") and not model.equip_citizen(b.id,"pistol"),"Absent citizens cannot change equipment")
	b.away = false
	model.coins = 624.75
	model.supplies = 24
	expect(not model.buy_citizen_weapon(b.id,"sniper") and model.coins==624.75,"Fractional insufficient funds are rejected")
	model.coins = 625
	model.supplies = 23
	expect(not model.buy_citizen_weapon(b.id,"sniper") and model.coins==625,"Missing provisions are rejected")
	model.supplies = 24
	expect(model.buy_citizen_weapon(b.id,"sniper") and model.coins==0 and model.supplies==0,"Exact personal purchase budget is accepted")
	model.coins = 35.75
	model.supplies = 4
	expect(not model.buy_citizen_ammo(b.id,"sniper"),"Ammo also checks fractional funds")
	model.coins = 36
	model.supplies = 3
	expect(not model.buy_citizen_ammo(b.id,"sniper"),"Ammo also checks provisions")
	model.supplies = 4
	expect(model.buy_citizen_ammo(b.id,"sniper") and model.coins==0 and model.supplies==0,"Exact refill budget is accepted")
func test_routes_and_departures() -> void:
	for zone_index: int in range(model.zones.size()):
		fresh()
		var a: Dictionary = model.citizens[0]
		for key: String in ["shotgun","sniper","smg"]: model.buy_citizen_weapon(a.id,key)
		var terrain: String = model.ExpeditionGear.terrain(model.zones[zone_index])
		var winner: String = {"close":"shotgun","open":"sniper","crowded":"smg","mixed":"smg"}[terrain]
		for key: String in ["shotgun","sniper","smg"]:
			if key!=winner: expect(float(model.citizen_gear_preview(a.id,winner,zone_index).factor)>float(model.citizen_gear_preview(a.id,key,zone_index).factor),"Recommended weapon is actually best on "+str(model.zones[zone_index].id))
		for key: String in ["pistol","shotgun","sniper","smg"]:
			fresh()
			a = model.citizens[0]
			if key!="pistol": model.buy_citizen_weapon(a.id,key)
			var gear: Dictionary = model.citizen_gear_preview(a.id,key,zone_index)
			var rounds: int = int(gear.ammo)
			var required: int = int(gear.required)
			var tower: int = model.ammo
			var money: float = model.coins
			var supplies: int = model.supplies
			var rng: int = model._rng.state
			var preview: Dictionary = model.expedition_preview(zone_index,[a.id])
			expect(preview.can_depart and preview.loadout_ready and int(preview.loadout[0].ammo)==required,"The route advertises the actual ammunition requirement")
			expect(model.coins==money and model.supplies==supplies and model._rng.state==rng and int(model.citizen_gear_preview(a.id,key).ammo)==rounds,"Preview never spends rounds, resources or randomness")
			if key!="pistol":
				a.personal_ammo[key] = required-1
				expect(not model.expedition_preview(zone_index,[a.id]).can_depart and not model.start_expedition(zone_index,[a.id]),"Insufficient personal ammo blocks departure")
				expect(model.supplies==supplies and model.coins==money and int(a.personal_ammo[key])==required-1 and not a.away,"Failed departure is atomic")
				a.personal_ammo[key] = rounds
			expect(model.start_expedition(zone_index,[a.id]),"Prepared team can depart: "+key)
			expect(model.ammo==tower and model.coins==money and model.supplies==supplies-int(preview.cost),"Only the shown provisions and personal ammunition are paid")
			expect(is_equal_approx(model.expedition.chance,preview.chance) and is_equal_approx(model.expedition.power,preview.power),"Outcome uses exactly the advertised power and probability")
			var after: int = int(model.citizen_gear_preview(a.id,key).ammo)
			expect(after==rounds-required,"Exactly the displayed rounds are charged once")
			expect(not model.start_expedition(zone_index,[a.id]) and not model.buy_citizen_ammo(a.id,key) and not model.equip_citizen(a.id,"pistol"),"An active trip cannot launch or rearm again")
			payload()
			expect(model.load_game(),"In-progress personal loadout reloads")
			a = model.get_citizen(int(a.id))
			expect(int(model.citizen_gear_preview(a.id,key).ammo)==after and model.ammo==tower,"Reload does not charge rounds again")
			model._tick_expedition(10000,true)
			model._tick_expedition(10000,true)
			expect(int(model.citizen_gear_preview(a.id,key).ammo)==after and not a.away,"Repeated offline return never charges rounds")
			expect(model.claim_expedition() and not model.claim_expedition() and int(model.citizen_gear_preview(a.id,key).ammo)==after,"Claiming loot cannot spend or refund personal rounds")
			model._is_loading = true
	# A bad last member cannot partially debit the first member's weapon.
	fresh()
	for person: Dictionary in model.citizens: model.buy_citizen_weapon(person.id,"sniper")
	var first: Dictionary = model.citizens[0]
	model.citizens[2].personal_ammo.sniper = 0
	var stock: int = first.personal_ammo.sniper
	var supply: int = model.supplies
	expect(not model.start_expedition(8,[first.id,model.citizens[1].id,model.citizens[2].id]) and first.personal_ammo.sniper==stock and model.supplies==supply,"The whole team is validated before any charge")
func test_legacy_and_validation() -> void:
	fresh()
	model.citizens[0].weapon = "sniper"
	model._spawn_visitor()
	var data: Dictionary = payload()
	for person: Dictionary in data.citizens:
		person.erase("personal_weapons")
		person.erase("personal_ammo")
	data.visitors[0].citizen.erase("personal_weapons")
	data.visitors[0].citizen.erase("personal_ammo")
	var id: int = int(data.citizens[0].id)
	data.expedition = {"status":"running","zone":8,"name":"Viaggio precedente","members":[id],"remaining":30,"duration":60,"rewards":{"coins":100,"supplies":10,"gems":0,"ammo":5},"chance":0.42,"power":33.0,"success":true}
	data.citizens[0].away = true
	write(data)
	expect(model.load_game(),"Legacy citizens and running trip migrate")
	var person: Dictionary = model.get_citizen(id)
	expect(person.weapon=="sniper" and person.personal_weapons==["pistol","sniper"] and int(person.personal_ammo.sniper)==6,"Legacy equipped advanced weapon is preserved with one starter pack")
	expect(model.citizens[1].personal_weapons==["pistol"] and model.visitors[0].citizen.personal_weapons==["pistol"],"Other citizens and arrivals do not gain free advanced copies")
	expect(model.expedition.chance==0.42 and model.expedition.power==33.0,"Migration preserves the already rolled legacy outcome")
	model._tick_expedition(60,true)
	expect(person.personal_ammo.sniper==6 and not person.away,"A legacy trip does not retroactively charge ammunition")
	var valid: Dictionary = payload()
	expect(model.load_game() and int(model.get_citizen(id).personal_ammo.sniper)==6,"Saving the migration prevents a second starter grant")
	for invalid: Variant in [-1,0.5,10000,"6",NAN]:
		var broken: Dictionary = valid.duplicate(true)
		broken.citizens[0].personal_ammo.sniper = invalid
		expect(not model._valid_save(broken),"Malformed personal ammunition rejected: "+str(invalid))
	for alteration: String in ["missing","duplicate","unknown","unowned","equipped"]:
		var broken: Dictionary = valid.duplicate(true)
		match alteration:
			"missing": broken.citizens[0].erase("personal_ammo")
			"duplicate": broken.citizens[0].personal_weapons.append("sniper")
			"unknown": broken.citizens[0].personal_weapons.append("laser")
			"unowned": broken.citizens[0].personal_ammo.smg = 12
			"equipped": broken.citizens[0].weapon = "shotgun"
		expect(not model._valid_save(broken),"Malformed personal ownership rejected: "+alteration)
func test_tutorial_budget() -> void:
	model._new_game()
	model._is_loading = true
	model.citizens.append(model._make_citizen())
	var id: int = model.citizens[0].id
	var reserve: int = 22+model.next_build_cost("residence")+model.next_build_cost("cafe")
	model.coins = 625+reserve-1
	model.supplies = 100
	expect(not model.buy_citizen_weapon(id,"sniper"),"Personal gear respects the protected tutorial budget")
	model.coins += 1
	expect(model.buy_citizen_weapon(id,"sniper") and model.coins==reserve,"Personal gear can spend funds above the reserve")
