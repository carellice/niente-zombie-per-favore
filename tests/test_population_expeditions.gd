extends SceneTree
## Population pressure, persisted rest progress and truthful expedition previews.
var model: Node
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("POPULATION EXPEDITIONS FAIL: ",label)
func fresh(population: int=0) -> void:
	model._new_game()
	model.skip_tutorial()
	model._is_loading = true
	model.supplies = 1000
	for index: int in range(population): model.citizens.append(model._make_citizen())
func run() -> void:
	root.get_node("Game").set_process(false)
	model = load("res://scripts/game_state.gd").new()
	var data: String = OS.get_environment("NZPF_TEST_DATA_DIR")
	if data.is_empty(): data = ProjectSettings.globalize_path("res://.runtime/population-expeditions")
	DirAccess.make_dir_recursive_absolute(data)
	model.save_path = data.path_join("colony.json")
	for suffix: String in ["",".tmp",".bak"]: DirAccess.remove_absolute(model.save_path+suffix)
	root.add_child(model)
	model.set_process(false)
	test_pressure()
	test_rest_and_save()
	test_preview_and_departure()
	for suffix: String in ["",".tmp",".bak"]: DirAccess.remove_absolute(model.save_path+suffix)
	model.queue_free()
	await process_frame
	print("POPULATION EXPEDITIONS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func test_pressure() -> void:
	var previous_count: float = 0
	var previous_wait: float = INF
	for population: int in [0,5,20,60,200]:
		fresh(population)
		model._rng.seed = 6732
		var profile: Dictionary = model.defense_profile()
		var count_sum: float = 0
		var wait_sum: float = 0
		for index: int in range(100):
			model._spawn_queue.clear()
			model._start_wave()
			var count: int = model._spawn_queue.size()
			expect(count>=int(profile.count_min) and count<=int(profile.count_max),"Population %d keeps random group %d inside its bounds" % [population,index])
			expect(model.wave_clock>=profile.interval_min and model.wave_clock<=profile.interval_max,"Population %d draws a bounded rest" % population)
			count_sum += count
			wait_sum += model.wave_clock
		expect(count_sum>previous_count and wait_sum<previous_wait,"More residents increase mean group size and reduce mean rest: "+str(population))
		previous_count = count_sum
		previous_wait = wait_sum
		model._spawn_queue.clear()
		model._rng.seed = 6732
		model.wave = 5
		model._arrivals_without_variant = 0
		model._start_wave()
		var early: Array = model._spawn_queue.duplicate()
		model._spawn_queue.clear()
		model._rng.seed = 6732
		model.wave = 5000
		model._arrivals_without_variant = 0
		model._start_wave()
		expect(early==model._spawn_queue,"Elapsed wave number does not escalate population pressure")
	fresh(20)
	model._spawn_visitor()
	expect(model.present_population()==20,"Visitors outside the gate never attract extra groups")
	for index: int in range(3): model.citizens[index].away = true
	expect(model.present_population()==17 and model.defense_profile().population==17,"Expedition members do not count until their return")
	expect(model.defense_profile().interval_min>23 and model.defense_profile().count_max<=24,"Pressure has a fixed difficulty ceiling")
func test_rest_and_save() -> void:
	fresh()
	model.wave_clock = 40.0
	model._wave_wait_scale = 1.0
	for index: int in range(20): model.citizens.append(model._make_citizen())
	model._tick_waves(0)
	var scale: float = model.defense_profile().interval_scale
	expect(is_equal_approx(model.wave_clock,40.0*scale),"Admitting residents preserves fractional rest progress")
	model._tick_waves(0)
	expect(is_equal_approx(model.wave_clock,40.0*scale),"Unchanged population never compounds the rescaling")
	model._is_loading = false
	expect(model.save_game(),"Population-adjusted timer saves")
	expect(model.load_game(),"Population-adjusted timer loads")
	model._tick_waves(0)
	expect(is_equal_approx(model.wave_clock,40.0*scale),"Reloading does not apply population scaling twice")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(model.save_path))
	data.erase("wave_wait_scale")
	data.wave_rules = 3
	data.wave_clock = 40.0
	var file: FileAccess = FileAccess.open(model.save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	expect(model.load_game(),"Legacy saves retain the existing colony")
	model._tick_waves(0)
	expect(is_equal_approx(model.wave_clock,40.0*scale),"Legacy unscaled timer migrates once to the present population")
	for citizen: Dictionary in model.citizens: citizen.away = true
	model._tick_waves(0)
	expect(is_equal_approx(model.wave_clock,40.0),"Departing residents lengthen the remaining rest proportionately")
	model._add_threat("walker",0)
	model._tick_waves(1000)
	expect(model.wave_clock==40.0 and model._spawn_queue.is_empty(),"Living zombies prevent an overlapping group")
	model._new_game()
	model._tick_waves(1000)
	expect(model.threats.is_empty() and model._spawn_queue.is_empty(),"Empty-refuge tutorial remains protected from random arrivals")
func test_preview_and_departure() -> void:
	fresh(4)
	var id: int = model.citizens[0].id
	model.citizens[0].hp = 50
	var state: int = model._rng.state
	var supply: int = model.supplies
	var preview: Dictionary = model.expedition_preview(8,[id])
	expect(preview.can_depart and preview.cost==28 and preview.duration==280,"Preview displays authoritative route cost and duration")
	expect(preview.full_rewards=={"coins":980,"supplies":120,"gems":6,"ammo":48},"Full loot matches the route")
	expect(preview.reduced_rewards=={"coins":392,"supplies":48,"gems":0,"ammo":19},"Difficult return gives 40 percent integer loot and no bills")
	expect(preview.full_net_supplies==92 and preview.reduced_net_supplies==20,"Net supplies subtract the launch cost from both outcomes")
	expect(model._rng.state==state and model.supplies==supply and not model.citizens[0].away,"Preview neither spends resources nor rolls the outcome")
	model.citizens[0].hp = 100
	var healthy: Dictionary = model.expedition_preview(8,[id])
	model.citizens[0].weapon = "sniper"
	var equipped: Dictionary = model.expedition_preview(8,[id])
	expect(healthy.chance>preview.chance and equipped.chance>healthy.chance,"Health and equipment improve the displayed probability")
	for ids: Array in [[],[id,id],[99999],[id,model.citizens[1].id,model.citizens[2].id,model.citizens[3].id]]:
		expect(not model.expedition_preview(8,ids).can_depart,"Empty, duplicate, missing and oversized teams cannot depart")
	model.citizens[0].away = true
	expect(not model.expedition_preview(8,[id]).can_depart,"An absent citizen cannot be selected for a new expedition")
	model.citizens[0].away = false
	model.supplies = 27
	expect(not model.expedition_preview(8,[id]).can_depart and not model.start_expedition(8,[id]),"Insufficient supplies cannot bypass the disabled launch button")
	model.supplies = 28
	preview = model.expedition_preview(8,[id])
	expect(model.start_expedition(8,[id]) and model.supplies==0,"Exact funds pay the departure once")
	expect(is_equal_approx(model.expedition.chance,preview.chance) and is_equal_approx(model.expedition.power,preview.power),"The actual outcome uses the shown team power and chance")
	expect(model.present_population()==3 and model.citizens[0].away,"Departing immediately removes the resident from refuge pressure")
	expect(not model.start_expedition(8,[model.citizens[1].id]) and model.supplies==0,"Repeated launch never charges or starts a second team")
	var success: bool = model.expedition.success
	var rewards: Dictionary = preview.full_rewards if success else preview.reduced_rewards
	expect(model.expedition.rewards==rewards,"Actual loot matches one of the two advertised outcomes")
	model._tick_expedition(280)
	expect(model.expedition.status=="ready" and model.present_population()==4,"The team returns and counts toward pressure even before claiming loot")
	expect(model.citizens[0].hp==(92 if success else 75),"Actual health loss matches the description")
	var coins: float = model.coins
	expect(model.claim_expedition() and model.coins==coins+int(rewards.coins) and model.supplies==int(rewards.supplies),"Claim awards exactly the advertised loot without another fee")
	expect(not model.claim_expedition(),"Loot cannot be claimed twice")
