extends SceneTree
## Demolition transactions, housing, worker ownership and historical pacing.
var model: Node
var checks: int = 0
var failures: int = 0
var removed: Array[int] = []
var fixture: Script
func _initialize() -> void: run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("DEMOLITION FAIL: ",message)
func fresh() -> void:
	model._new_game()
	model._is_loading = true
	model.skip_tutorial()
	model.coins = 100000
	model.supplies = 1000
	removed.clear()
func ready(kind: String) -> Dictionary:
	expect(fixture.build_ready(model,kind),"Fixture constructs "+kind)
	return model.buildings.back()
func run() -> void:
	root.get_node("Game").set_process(false)
	fixture = load(get_script().resource_path.get_base_dir().path_join("construction_fixture.gd"))
	model = load("res://scripts/game_state.gd").new()
	var data: String = OS.get_environment("NZPF_TEST_DATA_DIR")
	if data.is_empty(): data = ProjectSettings.globalize_path("res://.runtime/demolition-model")
	DirAccess.make_dir_recursive_absolute(data)
	model.save_path = data.path_join("colony.json")
	root.add_child(model)
	model.set_process(false)
	model.building_demolished.connect(func(id: int) -> void: removed.append(id))
	for kind: String in model.BUILDING_NAMES:
		fresh()
		ready("residence")
		ready("residence")
		var target: Dictionary = ready(kind)
		var id: int = target.id
		for index: int in range(2):
			var person: Dictionary = model._make_citizen()
			model.citizens.append(person)
			model.buy_citizen_weapon(person.id,"sniper")
			if kind!="residence": model.assign(person.id,id)
		if kind!="residence":
			target.products[0].status = "stocked"
			target.products[0].stock = 7
			target.products[1].status = "ready"
			target.products[2].status = "restocking"
			target.products[2].remaining = 20
		model.start_expedition(0,[model.citizens[1].id])
		var before_people: Array = model.citizens.duplicate(true)
		var money: float = model.coins
		var supply: int = model.supplies
		var diary: int = model.stats.built
		var next_time: float = model.next_build_duration("residence")
		var preview: Dictionary = model.demolition_preview(id)
		expect(preview.can_demolish and preview.workers==(0 if kind=="residence" else 2),kind+": preview counts workers, including an absent worker")
		if kind!="residence": expect(preview.stock==7 and preview.ready_batches==1 and preview.restocking==1,kind+": preview discloses all stock and production losses")
		expect(model.demolish_building(id) and model.buildings.size()==2 and model.get_building(id).is_empty(),kind+": only the selected building is removed")
		expect(model.coins==money and model.supplies==supply and model.stats.built==diary,kind+": no demolition fee, refund or diary rollback")
		expect(removed==[id] and not model.demolish_building(id) and removed==[id],kind+": a building cannot be demolished twice")
		for index: int in range(2):
			var person: Dictionary = model.citizens[index]
			expect(person.job==-1 and person.id==before_people[index].id and person.personal_weapons==before_people[index].personal_weapons and person.personal_ammo==before_people[index].personal_ammo,kind+": every citizen and their equipment are preserved")
		expect(model.citizens[1].away and model.expedition.status=="running",kind+": the expedition remains in progress")
		model._tick_expedition(100,true)
		expect(not model.citizens[1].away and model.citizens[1].job==-1,kind+": returning worker does not resume a removed job")
		expect(model.construction_count()==3 and model.next_build_duration("residence")==next_time,kind+": demolition never resets construction progression")
		model._is_loading = false
		expect(model.save_game() and model.load_game(),kind+": the compacted refuge reloads")
		expect(model.get_building(id).is_empty() and model.buildings.size()==2 and model.construction_count()==3,kind+": removal and construction history persist")
		model._is_loading = true
	fresh()
	var house: Dictionary = ready("residence")
	for index: int in range(5): model.citizens.append(model._make_citizen())
	model.citizens[4].away = true
	expect(not model.demolition_preview(house.id).can_demolish and not model.demolish_building(house.id) and model.capacity()==5,"Needed housing cannot be removed, including beds for absent residents")
	model.build("residence")
	expect(not model.demolish_building(house.id),"An unfinished replacement does not provide beds")
	model._tick_construction(10000,true)
	expect(model.demolish_building(house.id) and model.capacity()==5 and model.citizens.size()==5,"An occupied house can be replaced when other housing is actually ready")
	fresh()
	model.build("cafe")
	var site: Dictionary = model.buildings.back()
	var money: float = model.coins
	var built: int = model.stats.built
	expect(model.demolition_preview(site.id).pending and model.demolish_building(site.id),"A pending construction can be cancelled")
	model._tick_construction(10000,true)
	expect(model.buildings.is_empty() and model.coins==money and model.stats.built==built and model.capacity()==0,"Cancelled construction never refunds, completes or awards a building")
	expect(model.build("cafe") and model.buildings[0].id>site.id and model.next_build_duration("cafe")>45.0,"Rebuilding uses fresh IDs and keeps historical waiting times")
	model._new_game()
	model._is_loading = true
	model.build("residence")
	expect(not model.demolish_building(model.buildings[0].id),"The guided start cannot lose its required construction")
	model.skip_tutorial()
	expect(model.demolish_building(model.buildings[0].id),"Skipping the guide unlocks demolition")
	# Old saves have no started counter; their existing lots establish its floor.
	fresh()
	ready("residence")
	ready("cafe")
	model._is_loading = false
	model.save_game()
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(model.save_path))
	legacy.stats.erase("construction_started")
	var file: FileAccess = FileAccess.open(model.save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	expect(model.load_game() and model.construction_count()==2,"Legacy construction history starts from the existing lots")
	var previous: float = model.next_build_duration("cafe")
	expect(model.demolish_building(model.buildings[1].id) and model.next_build_duration("cafe")==previous,"A legacy colony also preserves pacing after demolition")
	for value: Variant in [-1,0.5,"3",NAN]:
		var broken: Dictionary = legacy.duplicate(true)
		broken.stats.construction_started = value
		expect(not model._valid_save(broken),"Invalid demolition pacing history is rejected")
	fresh()
	var last_house: Dictionary = ready("residence")
	model.coins = 0
	model.supplies = 0
	expect(model.demolish_building(last_house.id) and model.buildings.is_empty() and model.coins==0 and model.supplies==0,"An unneeded last building can be removed with no resources")
	model.queue_free()
	await process_frame
	print("DEMOLITION MODEL: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
