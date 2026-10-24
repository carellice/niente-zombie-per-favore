extends SceneTree
## Isolated behavioral coverage for the empty refuge, tutorial and new combat rules.

var checks: int = 0
var failures: Array[String] = []
var model: Node
var shots: Array = []
var reloads: Array = []

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
	model = load("res://scripts/game_state.gd").new()
	model.save_path = "res://tests/.revision-simulation-save.json"
	_cleanup()
	root.add_child(model)
	model.set_process(false)
	model._rng.seed = 20261023
	model.guard_fired.connect(func(cid, tid, x): shots.append([cid, tid, x]))
	model.reload_started.connect(func(key, duration): reloads.append([key, duration]))
	_test_empty_and_tutorial()
	_test_safe_people_and_arrivals()
	_test_names_and_migration()
	_test_weapons()
	_test_random_waves()
	_test_endurance()
	_cleanup()
	model.queue_free()
	await process_frame
	print("REVISION SIMULATION: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(model.save_path + suffix):
			DirAccess.remove_absolute(model.save_path + suffix)

func _test_empty_and_tutorial() -> void:
	model._new_game()
	expect(model.citizens.is_empty() and model.buildings.is_empty(), "Fresh refuge has zero people and buildings")
	expect(model.threats.is_empty() and model.visitors.is_empty(), "No actors appear before the explicit introduction")
	expect(model.departing_visitors.is_empty() and model.expedition.status == "idle", "Fresh game clears travelers and expeditions")
	expect(model.tutorial_stage == "intro" and model.tutorial_active(), "Fresh game awaits tutorial introduction")
	expect(model.coins >= 320 + 420 + 22, "Starter budget funds every necessary tutorial action")
	model.save_game()
	expect(model.load_game(), "An empty refuge is a valid save")
	expect(model.tutorial_stage == "intro" and model.buildings.is_empty(), "Empty tutorial save preserves introduction")
	model.advance(900.0)
	expect(model.threats.is_empty() and model.visitors.is_empty(), "Waiting in introduction never creates surprise arrivals")
	model.set_world_view(-1600.0, 1000.0)
	expect(model.start_tutorial(), "Explicit introduction starts the first lesson")
	expect(not model.start_tutorial(), "Repeated introduction does not duplicate the zombie")
	expect(model.tutorial_stage == "first_zombie" and model.threats.size() == 1, "First lesson has exactly one zombie")
	expect(float(model.threats[0].x) < -1600.0, "Teaching zombie starts outside the camera")
	var id = int(model.threats[0].id)
	expect(not model.shoot(id), "Teaching zombie must walk into pistol range first")
	model._tick_threats((model.GATE_X - float(model.WEAPONS.pistol.range) - float(model.threats[0].x)) / model.TUTORIAL_WALK_SPEED + 0.01)
	expect(model.shoot(id), "Permanent soldier fires with an empty population")
	expect(shots.back()[0] == 0, "Shot belongs to the permanent tower soldier")
	expect(model.threats.is_empty() and model.tutorial_stage == "build_residence", "One pistol shot completes first combat lesson")
	expect(not ready_build(model,"clinic"), "Tutorial protects funds from an unrelated first building")
	expect(not model.equip_weapon("shotgun"), "Tutorial protects construction funds from optional equipment")
	expect(ready_build(model,"residence"), "First house is affordable")
	expect(model.tutorial_stage == "welcome_visitor" and model.visitors.size() == 1, "First house invites one safe newcomer")
	expect(not model.visitors[0].suspicious and float(model.visitors[0].x) < -1600.0, "Teaching survivor walks in safely from outside view")
	var first_id = int(model.visitors[0].id)
	model.reject_visitor(first_id)
	expect(model.departing_visitors.size() == 1 and model.visitors.size() == 1, "Rejected teaching survivor leaves and a replacement keeps tutorial playable")
	expect(model.visitors[0].citizen.name != model.departing_visitors[0].citizen.name, "Replacement tutorial visitor has a unique identity")
	expect(model.accept_visitor(int(model.visitors[0].id)), "First newcomer can enter the house")
	expect(model.tutorial_stage == "build_cafe" and model.citizens.size() == 1, "Admission progresses the tutorial")
	expect(ready_build(model,"cafe"), "First cafe is affordable after house")
	expect(model.tutorial_stage == "assign_worker", "Cafe construction asks for a worker")
	var cafe = model.buildings[1]
	var person = model.citizens[0]
	expect(model.assign(int(person.id), int(cafe.id)), "First resident can work in cafe")
	expect(model.tutorial_stage == "restock", "Worker assignment unlocks production guidance")
	expect(model.restock(int(cafe.id), 1), "First production is affordable")
	expect(model.tutorial_stage == "stock", "Production tutorial waits for actual shelving")
	model.save_game()
	expect(model.load_game() and model.tutorial_stage == "stock", "Saving during production preserves the tutorial step")
	cafe = model.buildings[1]
	model.advance(30.0)
	expect(cafe.products[0].status == "ready", "Production progresses without a hidden pause")
	expect(model.tutorial_stage == "stock", "Ready product still requires the shelving action")
	expect(model.restock(int(cafe.id), 1), "Ready products can be put on shelves")
	expect(model.tutorial_stage == "complete" and not model.tutorial_active(), "Actual shelving completes the tutorial")
	var profile: Dictionary = model.defense_profile()
	expect(model.wave_clock >= profile.interval_min and model.wave_clock <= profile.interval_max, "Normal arrivals start after a population-adjusted tutorial rest")
	expect(model.coins >= 0.0 and cafe.products[0].stock > 0, "Tutorial ends with a funded, working economy")
	model._new_game()
	model._spawn_queue.append("brute")
	model._spawn_timer = 9.0
	model._visitor_timer = 1.0
	model._gate_alarm_timer = 3.0
	model.shot_cooldown = 10.0
	model.expedition = {"status": "running"}
	model._new_game()
	expect(model._spawn_queue.is_empty() and model._spawn_timer == 0.0 and model.shot_cooldown == 0.0, "Reset clears pending combat and cooldowns")
	expect(model._visitor_timer == 38.0 and model._gate_alarm_timer == 0.0 and model.expedition.status == "idle", "Reset clears arrivals, alarms and expeditions")
	expect(model.skip_tutorial() and model.tutorial_stage == "complete", "Tutorial can be skipped explicitly")
	expect(not model.skip_tutorial(), "Skipping a completed tutorial does not reset its clocks")

func _test_safe_people_and_arrivals() -> void:
	model._new_game()
	model.skip_tutorial()
	model.set_world_view(-2400.0, -900.0)
	model._spawn_visitor()
	var visitor = model.visitors[0]
	expect(float(visitor.x) <= -2580.0, "Normal survivor spawns beyond the far-left camera margin")
	var original_x = float(visitor.x)
	model.set_world_view(-3000.0, -1500.0)
	expect(float(visitor.x) == original_x, "Panning the camera never teleports an existing survivor")
	visitor.x = 120.0
	model._add_threat("walker", 100.0)
	var health = float(visitor.citizen.hp)
	model._tick_threats(1.0)
	expect(float(visitor.citizen.hp) == health and not visitor.under_attack, "Adjacent zombie never damages the waiting survivor")
	expect(float(model.threats[0].x) == 154.0 and int(model.threats[0].target_visitor_id) == -1, "Faster zombie keeps moving to gate instead of targeting a person")
	model._tick_visitors(1.0)
	expect(float(visitor.x) == 172.0, "Survivor walks through the encounter without collision blocking")
	model.reject_visitor(int(visitor.id))
	expect(model.visitors.is_empty() and model.departing_visitors.size() == 1, "Refusal moves survivor into departure state")
	var departed = model.departing_visitors[0]
	var departure_x = float(departed.x)
	model._tick_visitors(1.0)
	expect(float(departed.x) < departure_x and departed.facing_left, "Refused survivor turns and walks away")
	model._tick_threats(10.0)
	expect(float(departed.citizen.hp) == health, "Departing survivor remains safe from zombies")
	model.threats.clear()
	model._tick_visitors(200.0)
	expect(model.departing_visitors.is_empty(), "Departure completes only past the offscreen exit")
	model._spawn_queue = ["runner"]
	model._spawn_timer = 0.0
	model._tick_waves(0.1)
	expect(float(model.threats[0].x) <= model.entrance_x and float(model.threats[0].x) < -3000.0, "Wave enemies use the current offscreen entrance")
	model.threats.clear()
	model.coins = 10000.0
	ready_build(model,"residence")
	model._spawn_visitor()
	var infiltrator = model.visitors.back()
	infiltrator.x = -430.0
	infiltrator.suspicious = true
	expect(model.accept_visitor(int(infiltrator.id)), "A disguised infiltrator can be revealed at its current location")
	expect(model.threats.size() == 1 and is_equal_approx(float(model.threats[0].x), -430.0), "Revealed infiltrator never teleports to the gate")

func _test_names_and_migration() -> void:
	model._new_game()
	model.skip_tutorial()
	var catalog = load("res://scripts/survivor_catalog.gd")
	var seen: Dictionary = {}
	for i in range(180):
		var citizen = model._make_citizen()
		model.citizens.append(citizen)
		var first = str(citizen.name).split(" ")[0]
		expect(catalog.names_for_look(int(citizen.look)).has(first), "Generated name matches appearance gender %d" % i)
		expect(citizen.gender == catalog.gender_for_look(int(citizen.look)), "Generated survivor stores canonical gender %d" % i)
		expect(not seen.has(citizen.name), "Generated active names remain unique %d" % i)
		seen[citizen.name] = true
	for legacy_look in range(4, 8):
		expect(catalog.gender_for_look(legacy_look) == catalog.gender_for_look(legacy_look % 4), "Legacy appearance alias preserves gender %d" % legacy_look)
	model.citizens.resize(4)
	var names = ["Bruno De Luca", "Marta Costa", "Leo Ferri", "Bruno De Luca"]
	var looks = [0, 5, 9, 0]
	for i in range(4):
		model.citizens[i].name = names[i]
		model.citizens[i].look = looks[i]
		model.citizens[i].guard = true
	model.coins = 2027.0
	model.wave = 80
	model._add_threat("walker", -123.0)
	model.threats[0].hp = 340.0
	model.threats[0].max_hp = 680.0
	model.threats[0].damage = 40.0
	model.threats[0].speed = 30.0
	model.save_game()
	var data = JSON.parse_string(FileAccess.get_file_as_string(model.save_path))
	data.erase("tutorial_stage")
	data.erase("wave_rules")
	var file = FileAccess.open(model.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	expect(model.load_game(), "Version2 legacy save migrates without a forced restart")
	expect(model.coins == 2027.0 and model.wave == 80 and model.tutorial_stage == "complete", "Legacy progress is preserved and tutorial remains completed")
	seen.clear()
	for i in range(4):
		var citizen = model.citizens[i]
		var first = str(citizen.name).split(" ")[0]
		expect(catalog.names_for_look(int(citizen.look)).has(first), "Legacy mismatched name is corrected %d" % i)
		expect(not citizen.guard and not seen.has(citizen.name), "Legacy citizen loses obsolete guardrole and stays unique %d" % i)
		seen[citizen.name] = true
	expect(str(model.citizens[0].name).ends_with(" De Luca") and str(model.citizens[3].name).ends_with(" De Luca"), "Migration preserves multiword surnames")
	expect(model.threats[0].max_hp == 68.0 and model.threats[0].hp == 34.0, "Legacy scaled enemy keeps damage fraction at new fixed health")
	expect(model.threats[0].x == -123.0 and model.threats[0].damage == 5.0 and model.threats[0].speed == 54.0, "Legacy enemy keeps position with the new fixed pace")
	var migrated_names = model.citizens.map(func(c): return c.name)
	model.save_game()
	model.load_game()
	expect(model.citizens.map(func(c): return c.name) == migrated_names, "Migration is deterministic and does not rename again")
	expect(not model.toggle_guard(int(model.citizens[0].id)), "Residents cannot be assigned to the permanent military post")

func _test_weapons() -> void:
	model._new_game()
	model.skip_tutorial()
	model.coins = 10000.0
	model.supplies = 1000
	model.wave = 9999
	model._add_threat("walker", 0.0)
	expect(model.threats[0].max_hp == 68.0, "A late-wave walker has the same health")
	expect(model.shoot(int(model.threats[0].id)) and model.threats.is_empty(), "Improved pistol kills walker in one shot even late in the game")
	expect(reloads.is_empty(), "Unlimited pistol does not play a reload cycle")
	for key in ["shotgun", "sniper", "smg"]:
		model.threats.clear()
		expect(model.equip_weapon(key), "Weapon can be bought and equipped: " + key)
		model._add_threat("brute", 0.0)
		var target = model.threats[0]
		var ammo_before = model.ammo
		var reload_before = reloads.size()
		var shot_before = shots.size()
		expect(model.shoot(int(target.id)) and float(target.hp) == 225.0 - float(model.WEAPONS[key].damage), "Weapon fires for its configured damage: " + key)
		expect(model.ammo == ammo_before - 1, "Weapon uses one round per successful shot: " + key)
		expect(reloads.size() == reload_before + 1 and reloads.back()[0] == key, "Successful shot starts exactly one reload event: " + key)
		expect(float(reloads.back()[1]) == float(model.WEAPONS[key].cooldown), "Reload duration matches fire cooldown: " + key)
		expect(shots.size() == shot_before + 1 and shots.back()[0] == 0, "Permanent military fires weapon: " + key)
		expect(not model.shoot(int(target.id)) and reloads.size() == reload_before + 1, "Blocked cooldown click creates no duplicate reload: " + key)
	model.ammo = 0
	model.shot_cooldown = 0.0
	model.threats.clear()
	model._add_threat("walker", 0.0)
	expect(model.shoot(int(model.threats[0].id)) and model.weapon == "pistol", "Empty automatic weapon falls back to the unlimited pistol")
	model.threats.clear()
	model._add_threat("brute", 0.0)
	var before_hp = float(model.threats[0].hp)
	model._tick_guards(100.0)
	expect(float(model.threats[0].hp) == before_hp, "Permanent soldier never shoots without player action")

func _test_random_waves() -> void:
	model._new_game()
	model.skip_tutorial()
	var seen_counts: Dictionary = {}
	var seen_kinds: Dictionary = {}
	var rose = false
	var fell = false
	var previous = -1
	for i in range(100):
		model.threats.clear()
		model._spawn_queue.clear()
		model._start_wave()
		var count = model._spawn_queue.size()
		expect(count >= 2 and count <= 8, "Random wave count stays bounded %d" % i)
		seen_counts[count] = true
		for kind in model._spawn_queue:
			seen_kinds[kind] = true
		if previous >= 0:
			rose = rose or count > previous
			fell = fell or count < previous
		previous = count
	expect(seen_counts.size() >= 5 and rose and fell, "Wave sizes vary upward and downward instead of escalating")
	expect(seen_kinds.has("walker") and seen_kinds.has("runner") and seen_kinds.has("brute"), "Random compositions include all zombie types")
	model._rng.seed = 561
	model.wave = 1
	model._arrivals_without_variant = 0
	model._spawn_queue.clear()
	model._start_wave()
	var early = model._spawn_queue.duplicate()
	model._rng.seed = 561
	model.wave = 10000
	model._arrivals_without_variant = 0
	model._spawn_queue.clear()
	model._start_wave()
	expect(model._spawn_queue == early, "Wave number never changes random composition for the same random draw")
	model._spawn_queue.clear()
	model.threats.clear()
	model._wave_pending_reward = true
	model._tick_waves(0.1)
	var rest = model.wave_clock
	expect(rest >= 55.0 and rest <= 95.0, "Completion starts a 55–95 second rest")
	model._add_threat("walker", 0.0)
	model._tick_waves(100.0)
	expect(model.wave_clock == rest, "Rest clock does not run while a zombie remains")
	model.threats.clear()
	model._tick_waves(rest - 0.1)
	expect(model._spawn_queue.is_empty() and model.wave_clock > 0.0, "Next wave waits the whole rest interval")
	model._tick_waves(0.2)
	expect(not model._spawn_queue.is_empty(), "A randomized wave begins after the full rest")

func _test_endurance() -> void:
	model._new_game()
	model.skip_tutorial()
	model._rng.seed = 20261023
	model.coins = 100000.0
	model.supplies = 10000
	model.gate_max = 100000.0
	model.gate_hp = model.gate_max
	model.owned_weapons = ["pistol", "shotgun", "sniper", "smg"]
	model.weapon = "sniper"
	model.ammo = 30000
	# No test transaction should create a production save or spend time on disk I/O.
	model._is_loading = true
	model._save_timer = -100000000.0
	ready_build(model,"residence")
	ready_build(model,"cafe")
	for i in range(3):
		var resident = model._make_citizen()
		model.citizens.append(resident)
		model.assign(int(resident.id), int(model.buildings[1].id))
	var invariant_violation = false
	for tick in range(14400):
		model.advance(0.5)
		if not model.threats.is_empty():
			model.shoot(int(model.threats[0].id))
		if tick % 20 == 0:
			for product in model.buildings[1].products:
				if product.status in ["ready", "empty"] and model._available_workers(model.buildings[1]) >= int(product.tier):
					model.restock(int(model.buildings[1].id), int(product.tier))
			if model.expedition.status == "ready":
				model.claim_expedition()
			elif model.expedition.status == "idle":
				model.start_expedition(0, [int(model.citizens[2].id)])
		if model.coins < 0 or model.supplies < 0 or model.ammo < 0 or model.gate_hp <= 0 or not is_finite(model.coins):
			invariant_violation = true
			break
		for product in model.buildings[1].products:
			if int(product.stock) < 0 or int(product.stock) > int(product.max_stock):
				invariant_violation = true
	model._is_loading = false
	expect(not invariant_violation, "Two-hour session preserves all currency, health, ammo and stock invariants")
	expect(model.wave >= 45 and model.wave <= 90, "More frequent random arrivals stay bounded over two hours")
	expect(model.day >= 40 and int(model.stats.kills) >= 70, "Two-hour session keeps days and manual combat progressing")
	expect(int(model.stats.expeditions) >= 80, "Repeated expeditions remain claimable during new wave pacing")
	expect(int(model.stats.restocked) >= 25 and float(model.stats.earned) > 1000.0, "Long-running production and commerce continue normally")
	print("Endurance: day %d, wave %d, kills %d, expeditions %d" % [model.day, model.wave, model.stats.kills, model.stats.expeditions])

func ready_build(model: Node, kind: String) -> bool:
	var fixture: Script = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	return fixture.build_ready(model,kind)
