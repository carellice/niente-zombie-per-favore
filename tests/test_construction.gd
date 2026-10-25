extends SceneTree
## Real construction lifecycle, pacing, tutorial, migration and offline elapsed time.
var model: Node
var checks: int = 0
var failures: int = 0
var completed: Array[int] = []
func _initialize() -> void: run.call_deferred()
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("CONSTRUCTION FAIL: ",message)
func fresh(tutorial: bool=false) -> void:
	model._new_game()
	model._is_loading = true
	if not tutorial: model.skip_tutorial()
	model.coins = 1000000000
	model.supplies = 10000
	model.wave_clock = 1000000000
	model._visitor_timer = 1000000000
	completed.clear()
func write_save(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(model.save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
func snapshot() -> Dictionary:
	model._is_loading = false
	expect(model.save_game(),"Construction save succeeds")
	return JSON.parse_string(FileAccess.get_file_as_string(model.save_path))
func age(data: Dictionary, seconds: float) -> void:
	data.timestamp = Time.get_unix_time_from_system()-seconds
	data.highest_timestamp = data.timestamp
	write_save(data)
func run() -> void:
	root.get_node("Game").set_process(false)
	model = load("res://scripts/game_state.gd").new()
	var folder: String = OS.get_environment("NZPF_TEST_DATA_DIR")
	if folder.is_empty(): folder = ProjectSettings.globalize_path("res://.runtime/construction-model")
	DirAccess.make_dir_recursive_absolute(folder)
	model.save_path = folder.path_join("colony.json")
	for suffix: String in ["",".tmp",".bak"]: DirAccess.remove_absolute(model.save_path+suffix)
	root.add_child(model)
	model.set_process(false)
	model.building_completed.connect(func(id: int) -> void: completed.append(id))
	test_lifecycle()
	test_pacing()
	test_persistence()
	test_suspend_resume()
	test_tutorial()
	model.queue_free()
	await process_frame
	print("CONSTRUCTION MODEL: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
func test_lifecycle() -> void:
	for kind: String in model.BUILDING_NAMES:
		fresh()
		var money: float = model.coins
		var cost: int = model.next_build_cost(kind)
		var duration: float = model.next_build_duration(kind)
		expect(duration>0 and model.build(kind),kind+": starts a timed construction")
		var site: Dictionary = model.buildings[0]
		expect(model.coins==money-cost and site.construction_duration==duration,kind+": price and quoted duration are locked at start")
		expect(model.is_under_construction(site) and model.capacity()==0 and model.income_rate()==0,kind+": site is not operational before completion")
		expect(int(model.stats.built)==0 and int(model.stats.get("built_"+kind,0))==0,kind+": diary counts completed buildings only")
		var citizen: Dictionary = model._make_citizen()
		model.citizens.append(citizen)
		var before: float = model.coins
		var supplies: int = model.supplies
		var bills: int = model.gems
		expect(not model.assign(int(citizen.id),int(site.id)),kind+": unfinished building cannot receive a worker")
		expect(not model.restock(int(site.id),1) and not model.speed_up(int(site.id),1),kind+": production cannot bypass the construction timer")
		expect(model.coins==before and model.supplies==supplies and model.gems==bills and citizen.job==-1,kind+": rejected operations consume nothing")
		model.advance(duration*0.5)
		expect(is_equal_approx(model.construction_progress(site),0.5) and model.construction_stage(site)=="Struttura",kind+": real time advances the building stages")
		expect(model.capacity()==0 and model.stats.built==0,kind+": half-built sites still provide no rewards or beds")
		var remaining: float = site.construction_remaining
		model.paused = true
		model._process(duration)
		expect(site.construction_remaining==remaining,kind+": live pause freezes construction")
		model.paused = false
		model._process(remaining)
		expect(not model.is_under_construction(site) and site.construction_remaining==0 and model.construction_progress(site)==1.0,kind+": completion automatically makes the building ready")
		expect(model.stats.built==1 and model.stats.get("built_"+kind,0)==1 and completed==[int(site.id)],kind+": completion counts and signals exactly once")
		if kind=="residence": expect(model.capacity()==5,kind+": beds become available only at completion")
		else: expect(model.assign(int(citizen.id),int(site.id)) and model.restock(int(site.id),1),kind+": workers and production work after completion")
		model._tick_construction(100000,true)
		expect(model.stats.built==1 and completed.size()==1,kind+": later ticks never award the same building twice")
	fresh()
	model.coins = 0
	expect(not model.build("residence") and model.buildings.is_empty(),"Unaffordable site never starts")
	expect(not model.build("missing") and model.next_build_duration("missing")==0,"Unknown building is rejected")
func test_pacing() -> void:
	fresh()
	expect(model.next_build_duration("residence")<model.next_build_duration("cafe") and model.next_build_duration("cafe")<model.next_build_duration("waterworks"),"Building type controls base construction duration")
	var previous: float = 0
	for index: int in range(24):
		var quoted: float = model.next_build_duration("residence")
		expect(quoted>previous,"Expansion lengthens the next residence at lot "+str(index))
		expect(model.build("residence") and model.buildings.back().construction_duration==quoted,"Pending lots cannot evade the pacing curve")
		previous = quoted
	expect(model.stats.built==0 and model.capacity()==0,"Parallel unfinished houses still grant no beds or diary progress")
	var sites: Array = model.buildings.duplicate()
	model._tick_construction(float(sites[0].construction_duration),true)
	expect(not model.is_under_construction(sites[0]) and model.is_under_construction(sites.back()),"Parallel sites keep independent timers")
	for index: int in range(200): model.buildings.append(model._make_building("garden"))
	expect(model.next_build_duration("clinic")==model.MAX_CONSTRUCTION_TIME,"Late-game durations have a finite half-hour cozy limit")
func test_persistence() -> void:
	fresh()
	model.build("residence")
	model.advance(5)
	var data: Dictionary = snapshot()
	var remaining: float = model.buildings[0].construction_remaining
	age(data.duplicate(true),3)
	expect(model.load_game(),"Loads a partially built residence")
	expect(absf(model.buildings[0].construction_remaining-(remaining-3))<0.5,"Offline time below twenty seconds still advances construction")
	expect(model.capacity()==0 and model.stats.built==0,"Reloading a pending site never activates it early")
	age(data.duplicate(true),remaining+5)
	expect(model.load_game(),"Loads a site that finished while closed")
	expect(model.capacity()==5 and model.stats.built==1 and model.offline_report.get("construction_ready",0)==1,"Offline completion activates beds, counts once and reports the finished site")
	var complete_save: Dictionary = snapshot()
	age(complete_save,40)
	expect(model.load_game() and model.stats.built==1 and model.capacity()==5,"Repeated reload never duplicates completion")
	var rollback: Dictionary = data.duplicate(true)
	rollback.timestamp = Time.get_unix_time_from_system()-120
	rollback.highest_timestamp = Time.get_unix_time_from_system()+600
	write_save(rollback)
	expect(model.load_game() and is_equal_approx(model.buildings[0].construction_remaining,remaining),"Clock rollback cannot finish construction early")
	for values: Array in [[null,10],[-1,0],[10,11],[10,-1],[21601,10]]:
		var invalid: Dictionary = data.duplicate(true)
		invalid.buildings[0].construction_duration = values[0]
		invalid.buildings[0].construction_remaining = values[1]
		write_save(invalid)
		expect(not model.load_game(),"Rejects invalid or non-finite construction timer: "+str(values))
	var legacy: Dictionary = complete_save.duplicate(true)
	legacy.buildings[0].erase("construction_duration")
	legacy.buildings[0].erase("construction_remaining")
	age(legacy,0)
	expect(model.load_game() and model.capacity()==5 and model.stats.built==1 and not model.is_under_construction(model.buildings[0]),"Legacy buildings stay ready and keep their progress")
func test_tutorial() -> void:
	fresh(true)
	model.tutorial_stage = "build_residence"
	expect(model.next_build_duration("residence")==6 and model.build("residence"),"First guided house has a short six-second construction")
	expect(model.tutorial_stage=="build_residence" and model.visitors.is_empty(),"Tutorial waits for actual beds before inviting the first visitor")
	var money: float = model.coins
	expect(not model.build("residence") and not model.build("cafe") and model.coins==money,"Tutorial protects its budget while the first site is pending")
	model.advance(5.9)
	expect(model.visitors.is_empty() and model.capacity()==0,"Tutorial does not advance one frame early")
	model.advance(0.1)
	expect(model.tutorial_stage=="welcome_visitor" and model.capacity()==5 and model.visitors.size()==1,"Completing the house advances the real tutorial")
	expect(model.accept_visitor(int(model.visitors[0].id)),"First resident can enter the completed house")
	expect(model.next_build_duration("cafe")==10 and model.build("cafe"),"Guided cafe takes ten seconds")
	expect(model.tutorial_stage=="build_cafe" and not model.assign(int(model.citizens[0].id),int(model.buildings[1].id)),"Guide does not offer jobs in an unfinished cafe")
	var saved: Dictionary = snapshot()
	age(saved,11)
	expect(model.load_game() and model.tutorial_stage=="assign_worker","Returning after a short closure completes the guided cafe")
	expect(model.assign(int(model.citizens[0].id),int(model.buildings[1].id)) and model.tutorial_stage=="restock","Tutorial continues normally after construction")

func test_suspend_resume() -> void:
	fresh()
	model.build("waterworks")
	var site: Dictionary = model.buildings[0]
	var now: float = Time.get_unix_time_from_system()
	var time_before: float = model.time_played
	var hp_before: float = model.gate_hp
	model._suspend_construction(now)
	model._suspend_construction(now+2)
	model.advance(4)
	expect(site.construction_remaining==131,"A background frame may legitimately advance construction")
	model._resume_construction(now+30)
	expect(is_equal_approx(site.construction_remaining,105),"Resume catches up to wall time without counting background frames twice")
	expect(is_equal_approx(model.time_played,time_before+4) and model.gate_hp==hp_before,"Resume does not simulate extra combat or game days")
	model._resume_construction(now+60)
	expect(site.construction_remaining==105,"Duplicate resume notifications cannot advance the same absence twice")
	model._suspend_construction(now+60)
	model._resume_construction(now+40)
	expect(site.construction_remaining==105,"A backward wall clock cannot advance a suspended construction")
	model._suspend_construction(now+100)
	expect(model._resume_construction(now+300)==1 and not model.is_under_construction(site),"An Android-style suspend can finish a building without restarting the process")
	expect(model.stats.built==1 and completed.size()==1,"Suspension completion awards a building once")
	model._resume_construction(now+600)
	expect(model.stats.built==1 and completed.size()==1,"Repeated foreground notifications do not duplicate completion")
