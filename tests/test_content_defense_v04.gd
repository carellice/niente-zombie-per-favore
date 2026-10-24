extends SceneTree
## Behavior tests for ranged combat, the expanded economy and save migration.

var model: Node
var checks = 0
var failures: Array[String] = []
var shots = 0
var sounds = 0
var reloads = 0
var notices: Array[String] = []

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
	model.save_path = "res://tests/.content-defense-v04-save.json"
	cleanup()
	root.add_child(model)
	model.set_process(false)
	model._rng.seed = 20261026
	model.shot_fired.connect(func(_id, _damage): shots += 1)
	model.sfx.connect(func(_kind): sounds += 1)
	model.reload_started.connect(func(_weapon, _duration): reloads += 1)
	model.toast.connect(func(message): notices.append(message))
	test_range()
	test_arrivals()
	test_buildings_and_progress()
	test_zones()
	test_migration()
	test_appearances()
	cleanup()
	model.queue_free()
	await process_frame
	print("CONTENT DEFENSE V04: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func cleanup() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(model.save_path + suffix):
			DirAccess.remove_absolute(model.save_path + suffix)

func fresh() -> void:
	model._new_game()
	model.skip_tutorial()
	model.coins = 100000.0
	model.supplies = 10000
	model.ammo = 1000
	model._is_loading = true

func test_range() -> void:
	fresh()
	expect(not model.is_target_in_range(-999) and not model.can_shoot_target(-999), "Missing target is never in range")
	for key in ["pistol", "shotgun", "smg", "sniper"]:
		model.weapon = key
		model.shot_cooldown = 0.0
		model.threats.clear()
		var reach = float(model.WEAPONS[key]["range"])
		model._add_threat("brute", model.GATE_X - reach - 0.1)
		var target = model.threats[0]
		target.hp = 1000.0
		target.max_hp = 1000.0
		var shot_before = shots
		var sounds_before = sounds
		var reload_before = reloads
		var ammo_before = model.ammo
		expect(is_equal_approx(model.threat_distance(int(target.id)), reach + 0.1), key + " measures range from the gate")
		expect(not model.can_shoot_target(int(target.id)) and not model.shoot(int(target.id)), key + " cannot shoot beyond its range")
		expect(model.ammo == ammo_before and model.shot_cooldown == 0.0 and target.hp == 1000.0, key + " blocked range uses no ammo, cooldown or health")
		expect(shots == shot_before and sounds == sounds_before and reloads == reload_before, key + " blocked range creates no sound, tracer or reload")
		target.x = model.GATE_X - reach
		expect(model.is_target_in_range(int(target.id), key) and model.can_shoot_target(int(target.id)), key + " exact range boundary is inclusive")
		expect(model.shoot(int(target.id)) and target.hp < 1000.0, key + " fires once the target approaches")
		expect(shots == shot_before + 1, key + " successful shot emits exactly one shot")
	model.weapon = "sniper"
	model.ammo = 0
	model.shot_cooldown = 0.0
	model.threats.clear()
	model._add_threat("walker", -1000.0)
	var target = model.threats[0]
	expect(not model.can_shoot_target(int(target.id)) and not model.shoot(int(target.id)), "Empty sniper cannot borrow sniper range for fallback pistol")
	target.x = -100.0
	expect(model.shoot(int(target.id)) and model.weapon == "pistol", "Empty sniper switches to pistol when the target is in pistol range")
	model.threats.clear()
	model._add_threat("walker", 0.0)
	model.paused = true
	model.shot_cooldown = 0.0
	expect(not model.can_shoot_target(int(model.threats[0].id)) and not model.shoot(int(model.threats[0].id)), "Paused combat rejects all shots")
	model.paused = false

func test_arrivals() -> void:
	fresh()
	var kinds: Dictionary = {}
	var ordinary = 0
	var total = 0
	var no_variant_streak = 0
	var max_streak = 0
	for iteration in range(180):
		model._spawn_queue.clear()
		model.threats.clear()
		model._start_wave()
		var has_variant = false
		for kind in model._spawn_queue:
			kinds[kind] = true
			total += 1
			if kind == "walker":
				ordinary += 1
			else:
				has_variant = true
		if iteration == 0:
			expect(has_variant, "The first normal arrival already includes a variant")
		no_variant_streak = 0 if has_variant else no_variant_streak + 1
		max_streak = maxi(max_streak, no_variant_streak)
		expect(model._spawn_queue.size() >= 2 and model._spawn_queue.size() <= 8, "Arrival size remains bounded %d" % iteration)
		model._tick_waves(0.1)
		expect(model._spawn_timer >= 2.5 and model._spawn_timer <= 5.0, "Arrival spawn cadence remains bounded %d" % iteration)
	expect(max_streak <= 2, "At least every third arrival contains a variant")
	expect(kinds.has("walker") and kinds.has("runner") and kinds.has("brute"), "All three zombie types occur")
	expect(float(ordinary) / total > 0.6, "Ordinary walkers remain the clear majority")
	model._spawn_queue.clear()
	model.threats.clear()
	model._wave_pending_reward = true
	notices.clear()
	model._tick_waves(0.1)
	expect(notices.size() == 1 and notices[0].begins_with("Zombie respinti!"), "Victory uses an unnumbered zombie notice")
	expect(not "Ondata" in notices[0] and model.wave_clock >= 55.0 and model.wave_clock <= 95.0, "No numbered wave notice and a shorter rest")
	for kind in ["walker", "runner", "brute"]:
		model._add_threat(kind, -500.0)
	expect(model.threats[0].speed == 54.0 and model.threats[1].speed == 104.0 and model.threats[2].speed == 37.0, "All zombie archetypes have the faster fixed speeds")

func test_buildings_and_progress() -> void:
	fresh()
	expect(model.BUILDING_NAMES.size() == 8 and model.quests.size() == 32, "Expanded catalogue offers eight buildings and thirty-two diary goals")
	var quest_ids: Dictionary = {}
	for quest in model.quests:
		expect(not quest_ids.has(quest.id), "Diary goal has a stable unique id " + str(quest.id))
		quest_ids[quest.id] = true
	for kind in ["bakery", "waterworks", "tailor"]:
		expect(model.build(kind), "New building is constructible: " + kind)
		var building = model.buildings.back()
		expect(building.products.size() == 3 and int(model.stats["built_" + kind]) == 1, "Building has three products and real construction progress: " + kind)
		for i in range(3):
			var citizen = model._make_citizen()
			citizen.dream = kind
			citizen[model.BUILDING_SKILLS[kind]] = 9
			model.citizens.append(citizen)
			expect(model.assign(int(citizen.id), int(building.id)), "Resident works in new building " + kind + " " + str(i))
			expect(model.restock(int(building.id), i + 1), "New product can be produced " + kind + " " + str(i))
			expect(building.products[i].icon_key == kind + "_" + str(i + 1), "New product has a stable image key")
		expect(building.dream_bonus and building.products[0].max_stock == 60, "Dream job doubles new building capacity exactly once: " + kind)
		model._tick_products(200.0)
		for tier in range(1, 4):
			expect(model.restock(int(building.id), tier), "Completed production can be shelved: " + kind)
		expect(int(model.stats["stocked_" + kind]) == 3, "Shelving advances the matching diary goal: " + kind)
	var money_before = model.coins
	model._tick_products(400.0)
	model._sync_quests()
	expect(model.coins > money_before and int(model.stats.sold) >= 100, "New businesses sell actual goods and advance sales goals")
	expect(int(model.stats.assignments) == 9 and int(model.stats.dreams) == 3, "Assignments and dream work increment real stats")
	var bakery_goal = quest_index("bakery_first")
	var money_at_reward = model.coins
	expect(model.claim_quest(bakery_goal), "Completed new diary goal can be claimed")
	var earned_reward = model.coins
	expect(earned_reward > money_at_reward and not model.claim_quest(bakery_goal) and model.coins == earned_reward, "Diary reward is paid once only")
	var citizen = model.citizens[0]
	citizen.hp = 45
	expect(model.heal_citizen(int(citizen.id)) and int(model.stats.healed) == 1, "Healing updates its own diary stat")

func test_zones() -> void:
	fresh()
	expect(model.zones.size() == 9, "Nine expeditions are available")
	expect(model.zones[0].id == "minimarket" and model.zones[1].id == "station" and model.zones[2].id == "lab", "Original expedition indexes remain unchanged")
	var citizen = model._make_citizen()
	model.citizens.append(citizen)
	for index in range(model.zones.size()):
		var zone = model.zones[index]
		var supplies_before = model.supplies
		expect(model.start_expedition(index, [int(citizen.id)]), "Expedition can start: " + str(zone.id))
		expect(model.supplies == supplies_before - int(zone.cost) and model.expedition_cost(index) == int(zone.cost), "Expedition charges its displayed individual cost: " + str(zone.id))
		model._tick_expedition(float(zone.duration))
		expect(model.claim_expedition(), "Expedition can be completed and claimed: " + str(zone.id))
		expect(int(model.stats["zone_" + str(zone.id)]) == 1, "Expedition increments its own zone stat: " + str(zone.id))
	expect(int(model.stats.expeditions) == 9 and int(model.stats.zones_explored) == 9, "All distinct expedition destinations contribute to the diary")
	model._sync_quests()
	expect(int(model.quests[quest_index("team_explorer")].progress) == 4, "Exploration diary goal completes from actual distinct zones")

func test_migration() -> void:
	fresh()
	model.build("bakery")
	model.build("residence")
	model.owned_weapons = ["pistol", "shotgun", "smg"]
	model.coins = 1962.0
	model._is_loading = false
	model.save_game()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(model.save_path))
	data.erase("quest_content_version")
	data.quests.resize(8)
	for quest in data.quests:
		quest.erase("id")
	data.quests[0].claimed = true
	data.quests[0].progress = 1
	data.quests[1].progress = 4
	data.stats = {"kills": 2, "built": 99, "accepted": 1}
	write_save(data)
	expect(model.load_game(), "Pre-catalogue save loads without a forced restart")
	expect(model.coins == 1962.0 and model.buildings.size() == 2, "Migration never spends resources or discards buildings")
	expect(model.quests.size() == 32 and model.quests[0].claimed, "Original claimed rewards survive diary expansion")
	expect(int(model.quests[1].progress) == 4 and int(model.stats.kills) == 4, "Saved historical quest progress is retained when old stats were lower")
	expect(int(model.stats.built) == 99 and int(model.stats.built_bakery) == 1, "One-time backfill derives existing construction without reducing lifetime totals")
	expect(int(model.quests[quest_index("bakery_first")].progress) == 1 and not model.quests[quest_index("bakery_first")].claimed, "New construction goal is claimable, never silently rewarded")
	expect(not model.claim_quest(0) and model.coins == 1962.0, "Legacy claimed reward cannot be paid a second time")
	model.save_game()
	var first_stats = model.stats.duplicate(true)
	var first_quests = model.quests.duplicate(true)
	var reloaded = model.load_game()
	var same_stats = model.stats.size() == first_stats.size()
	for key in model.stats:
		if model.stats[key] != first_stats.get(key):
			same_stats = false
	var same_quests = model.quests.size() == first_quests.size()
	for i in range(model.quests.size()):
		if model.quests[i] != first_quests[i]:
			same_quests = false
	expect(reloaded and same_stats and same_quests, "Reloading a migrated save is idempotent")
	data = JSON.parse_string(FileAccess.get_file_as_string(model.save_path))
	expect(int(data.quest_content_version) == 1, "Save records the completed catalogue migration version")
	model._new_game()
	expect(model.buildings.is_empty() and int(model.stats.built) == 0 and not model.quests[0].claimed, "Explicit new game clears expanded progress and claimed rewards")

func test_appearances() -> void:
	fresh()
	model.wave = 4
	var healthy_dirty = 0
	var infected = 0
	var healthy_clean = 0
	for i in range(100):
		model._spawn_visitor()
		var visitor = model.visitors.back()
		expect(visitor.appearance == visitor.citizen.appearance, "Arrival and portrait share appearance %d" % i)
		if visitor.suspicious:
			infected += 1
			expect(visitor.appearance == "infected", "Disguised infected arrival has the subtle painted infection variant")
		elif visitor.appearance == "dirty":
			healthy_dirty += 1
		else:
			healthy_clean += 1
	expect(healthy_dirty > 12 and infected > 5 and healthy_clean > 20, "Dirt appears on healthy people too, leaving a real visual doubt")
	var dirty_person: Dictionary = {}
	var hidden_person: Dictionary = {}
	for visitor in model.visitors:
		if visitor.appearance == "dirty" and not visitor.suspicious:
			dirty_person = visitor
		if visitor.suspicious:
			hidden_person = visitor
	model.build("residence")
	var original_look = int(hidden_person.citizen.look)
	hidden_person.x = -500.0
	expect(model.accept_visitor(int(hidden_person.id)), "An infiltrator can reveal itself on admission")
	expect(model.threats.back().x == -500.0 and model.threats.back().look == original_look and model.threats.back().appearance == "infected", "Revealed infiltrator retains exact position, identity and painted appearance")
	expect(model.accept_visitor(int(dirty_person.id)) and model.citizens.back().appearance == "dirty", "Admitted healthy person keeps the same dirt variant")
	model._is_loading = false
	model.save_game()
	expect(model.load_game() and model.citizens.back().appearance == "dirty", "Accepted appearance survives saving")
	var departed = model.visitors[0]
	var appearance_before = str(departed.appearance)
	model.reject_visitor(int(departed.id))
	expect(model.departing_visitors.back().appearance == appearance_before, "Walking away preserves the exact appearance")
	model.save_game()
	expect(model.load_game() and model.departing_visitors.back().citizen.appearance == appearance_before, "Departure appearance survives saving")

func quest_index(stable_id: String) -> int:
	for index in range(model.quests.size()):
		if model.quests[index].id == stable_id:
			return index
	return -1

func write_save(data: Dictionary) -> void:
	var file = FileAccess.open(model.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
