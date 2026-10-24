extends SceneTree
## Run with Godot --headless --path . --script tests/test_simulation.gd

var failures: Array[String] = []
var model: Node
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func run() -> void:
	var singleton = root.get_node_or_null("Game")
	if singleton:
		singleton.set_process(false)
	var state_script = load("res://scripts/game_state.gd")
	if state_script == null:
		printerr("Game simulation could not be loaded")
		quit(1)
		return
	model = state_script.new()
	model.save_path = "res://tests/.simulation-test.json"
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(model.save_path + suffix):
			DirAccess.remove_absolute(model.save_path + suffix)
	root.add_child(model)
	model.set_process(false)
	model._rng.seed = 250

	expect(model.citizens.size() == 4, "Initial population is four")
	expect(model.capacity() == 5, "Initial residence provides five beds")
	expect(model.buildings.size() == 3, "Initial city contains three buildings")
	expect(model.income_rate() > 0.0, "Starter shops are trading")

	# A visitor becomes a resident; capacity is enforced before mutation.
	var visitor = model.visitors[0]
	expect(model.accept_visitor(int(visitor.id)), "First visitor can enter")
	expect(model.citizens.size() == 5, "Accepted visitor joins population")
	model._spawn_visitor(true)
	var waiting_id = int(model.visitors[0].id)
	expect(not model.accept_visitor(waiting_id), "A full residence rejects admission")
	expect(model.visitors.size() == 1, "Full residence leaves visitor at gate")
	var money_before = model.coins
	var house_cost = model.next_build_cost("residence")
	expect(ready_build(model,"residence"), "Residence construction succeeds with funds")
	expect(is_equal_approx(model.coins, money_before - house_cost), "Construction charges the displayed price")
	expect(model.capacity() == 10, "Second residence adds five beds")
	expect(model.accept_visitor(waiting_id), "Additional beds permit admission")

	# Worker allocation, dream bonus, tiers, production and passive sales.
	var garden = model.buildings[2]
	var ada = model.citizens[4]
	var old_stock = int(garden.products[0].max_stock)
	expect(model.assign(int(ada.id), int(garden.id)), "Resident can join a shop")
	expect(garden.dream_bonus, "Matching dream job permanently unlocks bonus")
	expect(garden.products[0].max_stock == old_stock * 2, "Dream job doubles stock")
	expect(model.assign(int(ada.id), -1), "A worker can be made available")
	expect(garden.dream_bonus, "Dream bonus persists when worker leaves")
	expect(model.assign(int(ada.id), int(garden.id)), "A worker can return")
	expect(garden.products[0].max_stock == old_stock * 2, "Dream bonus is applied once")
	expect(not model.restock(int(garden.id), 3), "Locked tier cannot be produced")
	var product = garden.products[0]
	product.status = "empty"
	product.stock = 0
	money_before = model.coins
	expect(model.restock(int(garden.id), 1), "Unlocked product starts production")
	expect(model.coins == money_before - product.cost, "Production charges its cost")
	model._tick_products(300.0)
	expect(product.status == "ready", "Finished goods wait for manual shelving")
	expect(model.restock(int(garden.id), 1), "Tap shelves finished goods")
	expect(product.status == "stocked" and product.stock == product.max_stock, "Shelving fills stock")
	money_before = model.coins
	model._tick_products(float(product.sell_interval))
	expect(model.coins > money_before, "Stock sells passively")
	expect(product.stock == product.max_stock - 1, "One sale removes one item")

	# Weapons, cooldowns, area damage and guarded state mutations.
	model.threats.clear()
	model._add_threat("walker", 0.0)
	var target_id = int(model.threats[0].id)
	model.shot_cooldown = 0.0
	expect(model.shoot(target_id), "Pistol can fire")
	expect(not model.shoot(target_id), "Cooldown prevents immediate second shot")
	model.shot_cooldown = 0.0
	expect(model.shoot(target_id), "Pistol fires after cooldown")
	expect(model.threats.is_empty(), "Two pistol shots defeat starter walker")
	expect(int(model.stats.kills) == 1, "Kill updates progression")
	model.coins = 3000
	model.supplies = 200
	expect(model.equip_weapon("shotgun"), "Shotgun is purchasable")
	model._add_threat("walker", 0.0)
	model._add_threat("runner", 30.0)
	target_id = int(model.threats[0].id)
	model.shot_cooldown = 0.0
	var ammo_before = model.ammo
	expect(model.shoot(target_id), "Shotgun can fire")
	expect(model.ammo == ammo_before - 1, "Advanced weapon consumes ammo")
	expect(model.threats.is_empty(), "Shotgun damages clustered enemies")
	model.ammo = 0
	model._add_threat("walker", 0.0)
	model.shot_cooldown = 0.0
	expect(model.shoot(int(model.threats[0].id)), "Empty advanced gun falls back safely")
	expect(model.weapon == "pistol", "Fallback equips infinite pistol")
	model.paused = true
	model.shot_cooldown = 0.0
	expect(not model.shoot(int(model.threats[0].id)), "Paused game rejects shooting")
	model.paused = false

	# A tower defender fires only on an explicit player shot, never while waiting.
	var guard_shots: Array = []
	var guard_listener: Callable = func(shooter_id: int, enemy_id: int, target_x: float) -> void:
		guard_shots.append([shooter_id, enemy_id, target_x, model.threats.size()])
	model.guard_fired.connect(guard_listener)
	var previous_threats: Array = model.threats.duplicate(true)
	var previous_guard_timer: float = model._guard_timer
	var sentry: Dictionary = model.citizens[3]
	model.threats.clear()
	model._add_threat("walker", 80.0)
	var guard_target: Dictionary = model.threats[0]
	guard_target.hp = 1.0
	var guard_target_id: int = int(guard_target.id)
	model._guard_timer = 0.0
	model._tick_guards(20.0)
	expect(guard_shots.is_empty() and guard_target.hp == 1.0,"Waiting twenty seconds never triggers an automatic guard shot")
	model.shot_cooldown = 0.0
	model.shoot(guard_target_id)
	expect(guard_shots.size() == 1, "One player command emits exactly one tower shot event")
	expect(guard_shots[0][0] == int(sentry.id) and guard_shots[0][1] == guard_target_id and is_equal_approx(guard_shots[0][2], 80.0), "Guard event identifies shooter, target and impact position")
	expect(guard_shots[0][3] == 1 and model.threats.is_empty(), "Guard event is emitted before lethal damage removes the target")
	model._add_threat("walker", 70.0)
	sentry.away = true
	model._guard_timer = 0.0
	model.shot_cooldown = 0.0
	model.shoot(int(model.threats[0].id))
	expect(guard_shots.size() == 1, "An away guard emits no shot event")
	sentry.away = false
	model.threats[0].x = -300.0
	model._guard_timer = 0.0
	model._tick_guards(60.0)
	expect(guard_shots.size() == 1, "A distant target never triggers automatic firing")
	model.threats[0].x = 70.0
	model.shoot(int(model.threats[0].id))
	expect(guard_shots.size() == 1, "Player weapon cooldown prevents a second tower event")
	model.guard_fired.disconnect(guard_listener)
	model.threats.clear()
	for saved_threat: Dictionary in previous_threats:
		model.threats.append(saved_threat)
	model._guard_timer = previous_guard_timer

	# Workers cannot be duplicated between job, guard and away status.
	var citizen = model.citizens[0]
	expect(model.toggle_guard(int(citizen.id)), "A shop worker can become guard")
	expect(citizen.guard and citizen.job == -1, "Guard is removed from shop role")
	for building in model.buildings:
		expect(not building.workers.has(citizen.id), "Guard has no stale worker slot")
	var members = [int(citizen.id), int(model.citizens[1].id)]
	expect(model.start_expedition(0, members), "Two person expedition can depart")
	expect(citizen.away, "Expedition marks members unavailable")
	expect(not model.assign(int(citizen.id), int(garden.id)), "Away members cannot be reassigned")
	expect(not model.start_expedition(1, members), "Second concurrent expedition is rejected")
	model._tick_expedition(60.0)
	expect(model.expedition.status == "ready", "Expedition completes with elapsed time")
	expect(not citizen.away, "Returning members resume their roles")
	money_before = model.coins
	expect(model.claim_expedition(), "Completed expedition rewards can be collected")
	expect(model.coins > money_before and model.expedition.status == "idle", "Rewards collected and run cleared")
	expect(not model.claim_expedition(), "Expedition cannot be claimed twice")

	# Quests, repairs, breach recovery, and endless wave dispatch.
	expect(model.claim_quest(0), "Completed acceptance quest can be claimed")
	expect(not model.claim_quest(0), "Quest rewards are only paid once")
	model.gate_hp = 100
	expect(model.repair_gate(), "Damaged gate can be repaired")
	expect(model.gate_hp == model.gate_max, "Repair restores all structure")
	expect(not model.repair_gate(), "Full gate cannot charge another repair")
	var old_max = model.gate_max
	expect(model.upgrade_gate(), "Gate can be upgraded")
	expect(model.gate_max > old_max and model.gate_hp == model.gate_max, "Upgrade expands and repairs gate")
	model._breach()
	expect(model.gate_hp > 0.0 and model.threats.is_empty(), "Breach recovers to a playable state")
	model.wave_clock = 0
	var old_wave = model.wave
	model._tick_waves(0.1)
	expect(model.wave == old_wave + 1 and not model._spawn_queue.is_empty(), "New wave queues more enemies")

	# Save files round-trip IDs and preserve transactions. Offline combat is suspended.
	model.threats.clear()
	model._spawn_queue.clear()
	model.save_game()
	var expected_coins = model.coins
	var expected_citizens = model.citizens.size()
	model.coins = 0
	expect(model.load_game(), "Valid save can be restored")
	expect(is_equal_approx(model.coins, expected_coins), "Save preserves wallet")
	expect(model.citizens.size() == expected_citizens, "Save preserves citizens")
	expect(not model.get_citizen(int(model.citizens[0].id)).is_empty(), "Integer IDs survive JSON roundtrip")
	var save_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(model.save_path))
	save_data.timestamp = Time.get_unix_time_from_system() - 100000.0
	save_data.highest_timestamp = save_data.timestamp
	save_data.buildings[1].products[0].status = "stocked"
	save_data.buildings[1].products[0].stock = 30
	_write_save(save_data)
	var hp_before = model.gate_hp
	expect(model.load_game(), "Offline save is accepted")
	expect(model.offline_report.seconds == 28800.0, "Offline accumulation is capped at eight hours")
	expect(model.offline_report.capped, "Cap is disclosed to the interface")
	expect(model.offline_report.coins >= 120, "Offline stocked goods sell correctly")
	expect(model.gate_hp == hp_before, "Offline defense takes no surprise damage")
	save_data.highest_timestamp = Time.get_unix_time_from_system() + 100000.0
	_write_save(save_data)
	expect(model.load_game(), "Clock anomaly does not destroy a save")
	expect(model.offline_report.clock_warning and model.offline_report.coins == 0, "Backwards clock prevents offline awards")
	_write_text("{invalid")
	var population_before = model.citizens.size()
	expect(not model.load_game(), "Malformed save is rejected")
	expect(model.citizens.size() == population_before, "Rejected save preserves current state")

	# Two accelerated hours exercise recurrent waves, commerce, day progression,
	# visitors, expeditions, and timestamp saves without using real waiting.
	model._new_game()
	model.coins = 100000.0
	model.supplies = 10000
	model.gate_max = 100000.0
	model.gate_hp = model.gate_max
	model.owned_weapons = ["pistol", "shotgun", "sniper"]
	model.weapon = "sniper"
	model.ammo = 30000
	model._save_timer = -100000000.0
	var invariant_violation = false
	for tick in range(14400):
		model.advance(0.5)
		if not model.threats.is_empty():
			var closest: Dictionary = model.threats[0]
			for threat in model.threats:
				if float(threat.x) > float(closest.x):
					closest = threat
			model.shoot(int(closest.id))
		if tick % 20 == 0:
			for building in model.buildings:
				for item in building.products:
					if item.status in ["ready", "empty"] and building.workers.size() >= int(item.tier):
						model.restock(int(building.id), int(item.tier))
			if model.expedition.status == "ready":
				model.claim_expedition()
			elif model.expedition.status == "idle":
				model.start_expedition(0, [int(model.citizens[2].id)])
		if model.coins < 0 or model.supplies < 0 or model.ammo < 0 or model.gate_hp <= 0 or not is_finite(model.coins):
			invariant_violation = true
			break
		for building in model.buildings:
			for item in building.products:
				if int(item.stock) < 0 or int(item.stock) > int(item.max_stock):
					invariant_violation = true
	expect(not invariant_violation, "Two hour simulation keeps currencies, health, ammo and stock valid")
	expect(model.wave >= 30, "Wave progression continues beyond the initial sequence")
	expect(model.day >= 40, "Day progression continues through long sessions")
	expect(model.stats.kills > 200, "Long session resolves hundreds of combat transactions")
	expect(model.stats.expeditions > 50, "Repeated expeditions return and remain claimable")
	print("Endurance: day " + str(model.day) + ", wave " + str(model.wave) + ", kills " + str(model.stats.kills) + ", expeditions " + str(model.stats.expeditions))

	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(model.save_path + suffix):
			DirAccess.remove_absolute(model.save_path + suffix)
	print("Simulation checks: " + str(checks) + "; failures: " + str(failures.size()))
	model.queue_free()
	quit(0 if failures.is_empty() else 1)

func _write_save(data: Dictionary) -> void:
	_write_text(JSON.stringify(data))

func _write_text(text: String) -> void:
	var file = FileAccess.open(model.save_path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func ready_build(model: Node, kind: String) -> bool:
	var fixture: Script = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	return fixture.build_ready(model,kind)
