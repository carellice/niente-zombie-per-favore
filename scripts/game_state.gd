extends Node
## Authoritative local simulation. Scene presentation deliberately lives elsewhere.

signal changed
signal toast(message: String)
signal sfx(kind: String)
signal wave_started
signal shot_fired(threat_id: int, damage: float)
signal guard_fired(citizen_id: int, threat_id: int, target_x: float)
signal enemy_defeated(threat_id: int, world_x: float)
signal visitor_attacked(visitor_id: int, world_x: float, damage: float)
signal visitor_lost(visitor_id: int, world_x: float, person_name: String)
signal reload_started(weapon_key: String, duration: float)
signal building_completed(building_id: int)

const SAVE_VERSION = 2
const OFFLINE_CAP = 28800.0
const GATE_X = 265.0
const SurvivorCatalog = preload("res://scripts/survivor_catalog.gd")
const ContentCatalog = preload("res://scripts/content_catalog.gd")
const VISITOR_SPEED = 52.0
const TUTORIAL_WALK_SPEED = 72.0
const CITIZEN_WALK_SPEED = 30.0
const DEPARTURE_SPEED = 62.0
const THREAT_STATS = {
	"walker": [68.0,54.0,5.0], "runner": [44.0,104.0,4.0],
	"brute": [225.0,37.0,13.0], "infiltrator": [85.0,46.0,8.0]
}
const DEPARTURE_EXIT_X = -1100.0
const TUTORIAL_STAGES = ["intro", "first_zombie", "build_residence", "welcome_visitor", "build_cafe", "assign_worker", "restock", "stock", "complete"]
const WAVE_INTERVAL_MIN = 55.0
const WAVE_INTERVAL_MAX = 95.0
const EXPEDITION_PARTIAL_REWARD = 0.4
const EXPEDITION_SUCCESS_DAMAGE = 8
const EXPEDITION_FAILURE_DAMAGE = 25
const EXPEDITION_HEALTH_FLOOR = 45
const MAX_CONSTRUCTION_TIME = 21600.0
const BUILDING_NAMES = ContentCatalog.BUILDING_NAMES
const BUILDING_SKILLS = ContentCatalog.BUILDING_SKILLS
const BUILDING_DESCRIPTIONS = ContentCatalog.BUILDING_DESCRIPTIONS
const PRODUCT_NAMES = ContentCatalog.PRODUCT_NAMES
const PRODUCT_DESCRIPTIONS = ContentCatalog.PRODUCT_DESCRIPTIONS
const FIRST_NAMES = SurvivorCatalog.FIRST_NAMES
const LAST_NAMES = SurvivorCatalog.LAST_NAMES
const QUIRKS = SurvivorCatalog.QUIRKS
const WEAPONS = {
	"pistol": {"name": "Pistola", "damage": 68.0, "cooldown": 0.29, "cost": 0, "supplies": 0, "range": 650.0},
	"shotgun": {"name": "Fucile a pompa", "damage": 79.0, "cooldown": 0.85, "cost": 620, "supplies": 24, "range": 430.0},
	"sniper": {"name": "Fucile di precisione", "damage": 175.0, "cooldown": 1.15, "cost": 1250, "supplies": 48, "range": 1800.0},
	"smg": {"name": "Mitragliatore", "damage": 38.0, "cooldown": 0.12, "cost": 980, "supplies": 35, "range": 800.0}
}

var coins: float = 1000.0
var supplies: int = 65
var gems: int = 12
var citizens: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var threats: Array[Dictionary] = []
var visitors: Array[Dictionary] = []
var departing_visitors: Array[Dictionary] = []
var wave: int = 0
var day: int = 1
var gate_hp: float = 260.0
var gate_max: float = 260.0
var gate_level: int = 1
var ammo: int = 24
var weapon: String = "pistol"
var owned_weapons: Array = ["pistol"]
var shot_cooldown: float = 0.0
var wave_clock: float = 75.0
var tutorial_stage: String = "intro"
var entrance_x: float = -1100.0
var exit_x: float = DEPARTURE_EXIT_X
var visitor_spacing: float = 54.0
var expedition: Dictionary = {"status": "idle"}
var quests: Array = []
var paused: bool = false
var time_played: float = 0.0
var save_path: String = "user://rifugio_save.json"
var offline_report: Dictionary = {}
var stats: Dictionary = {}
var zones: Array[Dictionary] = _make_zones()

var _rng = RandomNumberGenerator.new()
var _next_id: int = 100
var _ui_timer: float = 0.0
var _save_timer: float = 0.0
var _visitor_timer: float = 36.0
var _guard_timer: float = 1.5
var _spawn_timer: float = 0.0
var _spawn_queue: Array = []
var _wave_pending_reward: bool = false
var _gate_alarm_timer: float = 0.0
var _is_loading: bool = false
var _dirty: bool = false
var _highest_timestamp: float = 0.0
var _tutorial_visitor_id: int = -1
var _range_feedback_timer: float = 0.0
var _arrivals_without_variant: int = 0
var _wave_wait_scale: float = 1.0
var _construction_sleep_at: float = -1.0
var _construction_background_advanced: float = 0.0

func _make_zones() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for zone in ContentCatalog.ZONES:
		result.append(zone.duplicate(true))
	return result

func _ready() -> void:
	_rng.randomize()
	_new_game()
	load_game()
	get_tree().auto_accept_quit = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_suspend_construction(Time.get_unix_time_from_system())
		save_game()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_resume_construction(Time.get_unix_time_from_system())
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_game()

func _new_game() -> void:
	coins = 1000.0
	supplies = 65
	gems = 12
	gate_hp = 260.0
	gate_max = 260.0
	gate_level = 1
	ammo = 24
	weapon = "pistol"
	owned_weapons = ["pistol"]
	shot_cooldown = 0.0
	wave = 0
	day = 1
	wave_clock = 75.0
	tutorial_stage = "intro"
	_tutorial_visitor_id = -1
	time_played = 0.0
	paused = false
	_next_id = 100
	_spawn_queue.clear()
	_spawn_timer = 0.0
	_wave_pending_reward = false
	_guard_timer = 1.5
	_visitor_timer = 38.0
	_gate_alarm_timer = 0.0
	_save_timer = 0.0
	_ui_timer = 0.0
	_range_feedback_timer = 0.0
	_arrivals_without_variant = 0
	_wave_wait_scale = 1.0
	_construction_sleep_at = -1.0
	_construction_background_advanced = 0.0
	_dirty = false
	_is_loading = false
	_highest_timestamp = Time.get_unix_time_from_system()
	offline_report = {}
	stats = _default_stats()
	buildings.clear()
	citizens.clear()
	threats.clear()
	visitors.clear()
	visitor_spacing = 54.0
	departing_visitors.clear()
	expedition = {"status": "idle"}
	quests = ContentCatalog.make_quests()
	_dirty = true

func _id() -> int:
	_next_id += 1
	return _next_id

func _make_citizen() -> Dictionary:
	var dreams = BUILDING_SKILLS.keys()
	var look = _varied_citizen_look()
	return {
		"id": _id(), "name": _unique_citizen_name(look),
		"look": look, "gender": SurvivorCatalog.gender_for_look(look), "appearance": "clean", "food": _rng.randi_range(1, 9), "goods": _rng.randi_range(1, 9), "services": _rng.randi_range(1, 9),
		"dream": dreams[_rng.randi_range(0, dreams.size() - 1)], "job": -1, "guard": false,
		"hp": 100, "max_hp": 100, "damage": _rng.randi_range(10, 16), "precision": _rng.randi_range(75, 95),
		"weapon": "pistol", "happiness": _rng.randi_range(72, 95), "away": false, "quirk": QUIRKS[_rng.randi_range(0, QUIRKS.size() - 1)]
	}

func _outside_civilians() -> Array[Dictionary]:
	var people: Array[Dictionary] = []
	people.append_array(visitors)
	people.append_array(departing_visitors)
	return people

func _unique_citizen_name(look: int) -> String:
	var first_names: Array = SurvivorCatalog.names_for_look(look)
	var used: Dictionary = {}
	for citizen in citizens:
		used[str(citizen["name"])] = true
	for visitor in _outside_civilians():
		used[str(visitor["citizen"]["name"])] = true
	var combinations = first_names.size() * LAST_NAMES.size()
	var start = _rng.randi_range(0, combinations - 1)
	for offset in range(combinations):
		var index = (start + offset) % combinations
		var candidate: String = first_names[index % first_names.size()] + " " + LAST_NAMES[floori(float(index) / first_names.size())]
		if not used.has(candidate):
			return candidate
	# A settlement this large has exhausted every base combination.
	if SurvivorCatalog.is_nurse(look):
		var suffix: int = 2
		var family: String = str(LAST_NAMES[_rng.randi_range(0,LAST_NAMES.size()-1)])
		while used.has("Chiara "+family+" "+str(suffix)): suffix += 1
		return "Chiara "+family+" "+str(suffix)
	return "Nuovo arrivato " + str(_next_id)

func _varied_citizen_look() -> int:
	var counts: Dictionary = {}
	for look in SurvivorCatalog.LOOK_IDS:
		counts[look] = 0
	var people: Array[Dictionary] = []
	people.append_array(citizens)
	for visitor in _outside_civilians():
		people.append(visitor["citizen"])
	for citizen in people:
		var look = int(citizen.get("look", 0))
		if look >= 4 and look <= 7:
			look %= 4
		if counts.has(look):
			counts[look] = int(counts[look]) + 1
	var lowest = people.size() + 1
	var choices: Array[int] = []
	for look in SurvivorCatalog.LOOK_IDS:
		if int(counts[look]) < lowest:
			lowest = int(counts[look])
			choices.clear()
		if int(counts[look]) == lowest:
			choices.append(look)
	return choices[_rng.randi_range(0, choices.size() - 1)]

func set_world_view(left_edge: float, _right_edge: float) -> void:
	## Only future arrivals use this position. Existing actors always keep walking.
	if not is_finite(left_edge):
		return
	entrance_x = minf(-1100.0, left_edge - 180.0)
	exit_x = minf(DEPARTURE_EXIT_X, left_edge - 180.0)

func tutorial_active() -> bool:
	return tutorial_stage != "complete"

func start_tutorial() -> bool:
	if tutorial_stage != "intro":
		return false
	tutorial_stage = "first_zombie"
	_add_threat("walker", entrance_x)
	threats.back()["speed"] = TUTORIAL_WALK_SPEED
	_spawn_timer = 0.0
	_commit()
	return true

func skip_tutorial() -> bool:
	if not tutorial_active():
		return false
	tutorial_stage = "complete"
	_visitor_timer = 18.0
	_reset_wave_rest()
	_commit()
	return true

func _has_building(kind: String, ready_only: bool=false) -> bool:
	for building in buildings:
		if building["type"] == kind and (not ready_only or not is_under_construction(building)):
			return true
	return false

func _can_spend_optional_coins(cost: int, notify: bool=true) -> bool:
	if not tutorial_active():
		return true
	var reserve = 22 if int(stats.get("restocked", 0)) == 0 else 0
	if not _has_building("residence"):
		reserve += next_build_cost("residence")
	if not _has_building("cafe"):
		reserve += next_build_cost("cafe")
	if coins - cost < reserve:
		if notify:
			toast.emit("Teniamo da parte le monete per la prima casa, il caffè e il suo rifornimento.")
		return false
	return true

func _tutorial_cafe() -> Dictionary:
	for building in buildings:
		if building["type"] == "cafe" and not is_under_construction(building):
			return building
	return {}

func _sync_tutorial() -> void:
	## Check real game state so saves and actions made ahead of a step stay coherent.
	for _step in range(TUTORIAL_STAGES.size()):
		var previous = tutorial_stage
		match tutorial_stage:
			"first_zombie":
				if int(stats.get("kills", 0)) > 0 and threats.is_empty():
					tutorial_stage = "build_residence"
				elif threats.is_empty():
					_add_threat("walker", entrance_x)
					threats.back()["speed"] = TUTORIAL_WALK_SPEED
			"build_residence":
				if _has_building("residence",true):
					tutorial_stage = "welcome_visitor"
			"welcome_visitor":
				if not citizens.is_empty():
					tutorial_stage = "build_cafe"
				elif visitors.is_empty():
					# Replace a rejected teaching visitor: the tutorial cannot get stuck.
					_spawn_visitor(true)
					_tutorial_visitor_id = int(visitors.back()["id"])
			"build_cafe":
				if _has_building("cafe",true):
					tutorial_stage = "assign_worker"
			"assign_worker":
				var cafe = _tutorial_cafe()
				if not cafe.is_empty() and _available_workers(cafe) > 0:
					tutorial_stage = "restock"
			"restock":
				var cafe = _tutorial_cafe()
				if not cafe.is_empty() and cafe["products"][0]["status"] != "empty":
					tutorial_stage = "stock"
			"stock":
				if int(stats.get("restocked", 0)) > 0:
					tutorial_stage = "complete"
					_visitor_timer = 26.0
					_reset_wave_rest()
		if tutorial_stage == previous:
			break

func _migrate_citizen_names() -> void:
	var used: Dictionary = {}
	var people: Array[Dictionary] = []
	people.append_array(citizens)
	for visitor in _outside_civilians():
		people.append(visitor["citizen"])
	for citizen in people:
		var look = int(citizen.get("look", 0))
		var names: Array = SurvivorCatalog.names_for_look(look)
		citizen["gender"] = SurvivorCatalog.gender_for_look(look)
		citizen["guard"] = false
		var full_name = str(citizen["name"])
		var pieces = full_name.split(" ", false, 1)
		var first = pieces[0] if not pieces.is_empty() else ""
		if names.has(first) and not used.has(full_name):
			used[full_name] = true
			continue
		var surname = str(pieces[1]) if pieces.size() > 1 else str(LAST_NAMES[posmod(int(citizen["id"]), LAST_NAMES.size())])
		var start = posmod(int(citizen["id"]), names.size())
		var assigned: bool = false
		for offset in range(names.size() * LAST_NAMES.size()):
			var family = surname if offset < names.size() else str(LAST_NAMES[posmod(int(citizen["id"]) + offset / names.size(), LAST_NAMES.size())])
			var candidate: String = str(names[(start + offset) % names.size()]) + " " + family
			if not used.has(candidate):
				citizen["name"] = candidate
				used[candidate] = true
				assigned = true
				break
		if not assigned and SurvivorCatalog.is_nurse(look):
			var suffix: int = 2
			while used.has("Chiara "+surname+" "+str(suffix)): suffix += 1
			citizen.name = "Chiara "+surname+" "+str(suffix)
			used[citizen.name] = true

func _make_building(kind: String) -> Dictionary:
	var products: Array = []
	if kind != "residence":
		for tier in range(1, 4):
			var base_stock = 20 + tier * 10
			products.append({
				"tier": tier, "name": PRODUCT_NAMES.get(kind, PRODUCT_NAMES["cafe"])[tier - 1], "icon_key": kind + "_" + str(tier),
				"cost": 12 + tier * tier * 10, "supply_cost": maxi(0, (tier - 1) * 3),
				"duration": float(8 + tier * tier * 10), "remaining": 0.0,
				"status": "empty", "stock": 0, "max_stock": base_stock,
				"price": float(2 + tier * 2 + (1 if kind == "clinic" else 0)),
				"sell_interval": 1.9 + tier * 0.6, "sale_clock": 0.0
			})
	return {"id": _id(), "type": kind, "name": BUILDING_NAMES.get(kind, "Nuova attività"), "workers": [], "products": products, "level": 1, "dream_bonus": false,"construction_duration":0.0,"construction_remaining":0.0}

func _process(delta: float) -> void:
	if paused:
		return
	advance(delta)

func advance(delta: float) -> void:
	## Deterministic entry point used by the live loop and automated simulation tests.
	if delta <= 0.0:
		return
	time_played += delta
	day = 1 + int(time_played / 180.0)
	shot_cooldown = maxf(0.0, shot_cooldown - delta)
	_gate_alarm_timer = maxf(0.0, _gate_alarm_timer - delta)
	_range_feedback_timer = maxf(0.0, _range_feedback_timer - delta)
	if _construction_sleep_at>=0.0: _construction_background_advanced += delta
	_tick_construction(delta)
	_tick_products(delta)
	_tick_expedition(delta)
	_tick_threats(delta)
	_tick_visitors(delta)
	_tick_waves(delta)
	_sync_tutorial()
	_ui_timer += delta
	_save_timer += delta
	if _ui_timer >= 0.25:
		_ui_timer = fmod(_ui_timer, 0.25)
		_sync_quests()
		changed.emit()
		_dirty = false
	if _save_timer >= 12.0:
		_save_timer = 0.0
		save_game()

func _tick_products(delta: float, offline: bool = false) -> float:
	var earned: float = 0.0
	for building in buildings:
		if is_under_construction(building): continue
		for product in building["products"]:
			if product["status"] == "restocking" and _available_workers(building) >= int(product["tier"]):
				product["remaining"] = maxf(0.0, float(product["remaining"]) - delta)
				if product["remaining"] <= 0.0:
					product["status"] = "ready"
					if not offline:
						toast.emit(building["name"] + ": merce pronta! Tocca per rifornire.")
						sfx.emit("ready")
			elif product["status"] == "stocked" and int(product["stock"]) > 0:
				product["sale_clock"] = float(product.get("sale_clock", 0.0)) + delta
				var interval = float(product["sell_interval"])
				var sold = mini(int(product["stock"]), int(float(product["sale_clock"]) / interval))
				if sold > 0:
					product["stock"] = int(product["stock"]) - sold
					product["sale_clock"] = fmod(float(product["sale_clock"]), interval)
					var revenue = sold * float(product["price"])
					coins += revenue
					earned += revenue
					stats["earned"] = float(stats.get("earned", 0.0)) + revenue
					_increment_stat("sold", sold)
					if int(product["stock"]) <= 0:
						product["status"] = "empty"
						product["sale_clock"] = 0.0
	return earned

func _available_workers(building: Dictionary) -> int:
	if is_under_construction(building): return 0
	var count = 0
	for worker_id in building["workers"]:
		var worker = get_citizen(int(worker_id))
		if not worker.is_empty() and not worker.get("away", false):
			count += 1
	return count

func capacity() -> int:
	var beds = 0
	for building in buildings:
		if building["type"] == "residence" and not is_under_construction(building):
			beds += 5 * int(building["level"])
	return beds

func income_rate() -> float:
	var result = 0.0
	for building in buildings:
		if is_under_construction(building): continue
		for product in building["products"]:
			if product["status"] == "stocked" and int(product["stock"]) > 0:
				result += float(product["price"]) / float(product["sell_interval"])
	return result

func next_build_cost(kind: String) -> int:
	if not BUILDING_NAMES.has(kind):
		return -1
	var count = 0
	for building in buildings:
		if building["type"] == kind:
			count += 1
	var base: int = ContentCatalog.BUILDING_COSTS[kind]
	return int(round(float(base) * pow(1.28, count)))

func is_under_construction(building: Dictionary) -> bool:
	return float(building.get("construction_remaining",0.0))>0.0

func active_construction() -> Dictionary:
	for building: Dictionary in buildings:
		if is_under_construction(building): return building
	return {}

func construction_progress(building: Dictionary) -> float:
	var duration: float = float(building.get("construction_duration",0.0))
	return clampf(1.0-float(building.get("construction_remaining",0.0))/duration,0.0,1.0) if duration>0.0 else 1.0

func construction_stage(building: Dictionary) -> String:
	var progress: float = construction_progress(building)
	if not is_under_construction(building): return "Completato"
	return "Fondamenta" if progress<0.25 else "Struttura" if progress<0.75 else "Finiture"

func next_build_duration(kind: String) -> float:
	if not ContentCatalog.BUILDING_TIMES.has(kind): return 0.0
	if tutorial_active():
		if kind=="residence" and not _has_building(kind): return 6.0
		if kind=="cafe" and not _has_building(kind): return 10.0
	# Pending lots count too: parallel starts never evade the progression curve.
	var lots: float = float(buildings.size())
	return minf(MAX_CONSTRUCTION_TIME,ceilf(float(ContentCatalog.BUILDING_TIMES[kind])*(1.0+0.28*lots+0.04*lots*lots)))

func _tick_construction(delta: float, offline: bool=false) -> int:
	if delta<=0.0: return 0
	var completed: int = 0
	for building: Dictionary in buildings:
		if not is_under_construction(building): continue
		building.construction_remaining = maxf(0.0,float(building.construction_remaining)-delta)
		if is_under_construction(building): continue
		completed += 1
		stats["built"] = int(stats.get("built",0))+1
		_increment_stat("built_"+str(building.type))
		_dirty = true
		building_completed.emit(int(building.id))
		if not offline:
			toast.emit(str(building.name)+" è pronto. Il rifugio cresce!")
			sfx.emit("ready")
	return completed

func _suspend_construction(now: float) -> void:
	if _construction_sleep_at>=0.0: return
	_construction_sleep_at = now
	_construction_background_advanced = 0.0

func _resume_construction(now: float) -> int:
	if _construction_sleep_at<0.0: return 0
	var elapsed: float = 0.0 if now+5.0<_highest_timestamp else clampf(now-_construction_sleep_at,0.0,OFFLINE_CAP)
	var missed: float = maxf(0.0,elapsed-_construction_background_advanced)
	_construction_sleep_at = -1.0
	_construction_background_advanced = 0.0
	_highest_timestamp = maxf(_highest_timestamp,now)
	var finished: int = _tick_construction(missed,true)
	_sync_tutorial()
	_sync_quests()
	changed.emit()
	if finished>0:
		toast.emit("Cantieri completati mentre eri via: %d. Gli edifici sono pronti!" % finished)
		sfx.emit("ready")
	save_game()
	return finished

func build(kind: String) -> bool:
	if tutorial_active():
		if not active_construction().is_empty():
			toast.emit("Il primo cantiere è in corso. Aspetta che sia pronto.")
			return false
		var expected = "residence" if not _has_building("residence") else ("cafe" if not _has_building("cafe") else "")
		if not expected.is_empty() and kind != expected:
			toast.emit("Per iniziare costruiamo " + ("una residenza per accogliere le persone." if expected == "residence" else "un caffè per far partire il rifugio."))
			return false
	var cost = next_build_cost(kind)
	if cost < 0:
		return false
	if coins < cost:
		toast.emit("Servono " + str(cost) + " monete per questo edificio.")
		return false
	var duration: float = next_build_duration(kind)
	coins -= cost
	var building = _make_building(kind)
	building["construction_duration"] = duration
	building["construction_remaining"] = duration
	buildings.append(building)
	toast.emit("Cantiere avviato: " + building["name"] + ".")
	sfx.emit("build")
	_commit()
	return true

func get_citizen(citizen_id: int) -> Dictionary:
	for citizen in citizens:
		if int(citizen["id"]) == citizen_id:
			return citizen
	return {}

func get_building(building_id: int) -> Dictionary:
	for building in buildings:
		if int(building["id"]) == building_id:
			return building
	return {}

func assign(citizen_id: int, building_id: int) -> bool:
	var citizen = get_citizen(citizen_id)
	if citizen.is_empty() or citizen.get("away", false):
		toast.emit("Questo cittadino è fuori in spedizione.")
		return false
	if building_id == -1:
		_remove_job(citizen)
		citizen["guard"] = false
		toast.emit(citizen["name"] + " è ora disponibile.")
		_commit()
		return true
	var building = get_building(building_id)
	if building.is_empty() or building["type"] == "residence" or is_under_construction(building):
		return false
	if int(citizen["job"]) == building_id:
		return true
	if building["workers"].size() >= 3:
		toast.emit("Questa attività ha già 3 lavoratori.")
		return false
	_remove_job(citizen)
	citizen["job"] = building_id
	citizen["guard"] = false
	building["workers"].append(citizen_id)
	_increment_stat("assignments")
	if citizen["dream"] == building["type"] and not building.get("dream_bonus", false):
		building["dream_bonus"] = true
		for product in building["products"]:
			product["max_stock"] = int(product["max_stock"]) * 2
		stats["dreams"] = int(stats.get("dreams", 0)) + 1
		citizen["happiness"] = 100
		toast.emit("Lavoro dei sogni! Capacità di " + building["name"] + " raddoppiata per sempre.")
		sfx.emit("reward")
	else:
		toast.emit(citizen["name"] + " lavora ora a " + building["name"] + ".")
		sfx.emit("click")
	_commit()
	return true

func _remove_job(citizen: Dictionary) -> void:
	for building in buildings:
		building["workers"].erase(citizen["id"])
	citizen["job"] = -1

func toggle_guard(citizen_id: int) -> bool:
	# Kept for old integrations; the permanent tower soldier handles manual shots.
	return false

func restock(building_id: int, tier: int) -> bool:
	var building = get_building(building_id)
	if building.is_empty() or is_under_construction(building) or tier < 1 or tier > building["products"].size():
		return false
	var product: Dictionary = building["products"][tier - 1]
	if product["status"] == "ready":
		product["status"] = "stocked"
		product["stock"] = int(product["max_stock"])
		product["sale_clock"] = 0.0
		stats["restocked"] = int(stats.get("restocked", 0)) + 1
		_increment_stat("stocked_" + str(building["type"]))
		toast.emit("Scaffali pieni! " + product["name"] + " è in vendita.")
		sfx.emit("cash")
		_commit()
		return true
	if product["status"] != "empty":
		return false
	if _available_workers(building) < tier:
		toast.emit("Assegna " + str(tier) + " lavoratori per sbloccare questo prodotto.")
		return false
	var cost = int(product["cost"])
	var supply_cost = int(product.get("supply_cost", 0))
	if coins < cost or supplies < supply_cost:
		toast.emit("Non ci sono abbastanza monete o provviste.")
		return false
	coins -= cost
	supplies -= supply_cost
	var affinity: float = 0.0
	var skill: String = BUILDING_SKILLS.get(str(building["type"]), "services")
	for worker_id in building["workers"]:
		var worker = get_citizen(int(worker_id))
		if not worker.is_empty() and not worker["away"]:
			affinity += float(worker[skill])
	product["status"] = "restocking"
	product["remaining"] = float(product["duration"]) * maxf(0.45, 1.0 - affinity * 0.018)
	toast.emit("Produzione avviata: " + product["name"] + ".")
	sfx.emit("click")
	_commit()
	return true

func speed_up(building_id: int, tier: int) -> bool:
	var building = get_building(building_id)
	if building.is_empty() or is_under_construction(building) or tier < 1 or tier > building["products"].size():
		return false
	var product = building["products"][tier - 1]
	if product["status"] != "restocking" or gems < 1:
		toast.emit("Serve una banconota per accelerare questa produzione.")
		return false
	gems -= 1
	product["remaining"] = 0.0
	product["status"] = "ready"
	toast.emit("Consegna espressa! La merce è pronta.")
	sfx.emit("ready")
	_commit()
	return true

func set_visitor_spacing(spacing: float) -> void:
	visitor_spacing = clampf(spacing,54.0,140.0)

func visitor_destination(index: int) -> float:
	return 195.0-index*visitor_spacing

func visitor_at_gate(visitor: Dictionary) -> bool:
	var index: int = visitors.find(visitor)
	return index>=0 and absf(float(visitor.x)-visitor_destination(index))<=0.01

func has_waiting_visitors() -> bool:
	for visitor: Dictionary in visitors:
		if visitor_at_gate(visitor): return true
	return false

func _tick_visitors(delta: float) -> void:
	if not tutorial_active():
		_visitor_timer -= delta
		if _visitor_timer <= 0.0:
			_visitor_timer = _rng.randf_range(55.0, 85.0)
			if visitors.size() < 3:
				_spawn_visitor()
	for i in range(visitors.size()):
		var visitor = visitors[i]
		_move_outside_civilian(visitor, visitor_destination(i), float(visitor.get("walk_speed", VISITOR_SPEED)), delta)
		if visitor_at_gate(visitor) and not bool(visitor.get("arrival_notified",false)):
			visitor["arrival_notified"] = true
			toast.emit("Qualcuno bussa al cancello. Controlla il nuovo arrivato.")
			sfx.emit("visitor")
			_dirty = true
	for visitor in departing_visitors.duplicate():
		_move_outside_civilian(visitor, exit_x, DEPARTURE_SPEED, delta)
		visitor["facing_left"] = true
		if float(visitor["x"]) <= exit_x:
			departing_visitors.erase(visitor)

func _move_outside_civilian(visitor: Dictionary, destination: float, speed: float, delta: float) -> void:
	var previous = float(visitor["x"])
	var next = move_toward(previous, destination, speed * delta)
	visitor["x"] = next
	if not is_equal_approx(next, previous):
		visitor["facing_left"] = next < previous

func _spawn_visitor(initial: bool = false) -> void:
	var suspicious = not initial and wave >= 2 and _rng.randf() < 0.16
	var citizen = _make_citizen()
	var appearance = "infected" if suspicious else ("dirty" if not initial and _rng.randf() < 0.37 else "clean")
	citizen["appearance"] = appearance
	if initial:
		citizen["food"] = 9
		citizen["dream"] = "cafe"
		citizen["quirk"] = "Una buona colazione aiuta sempre a ricominciare."
	var hint = "Sembra stanco, ma riesce a raccontare il viaggio. Chiede un posto sicuro."
	if appearance == "dirty":
		hint = ["Ha il viso impolverato e una macchia sul collo. Dice di aver dormito tra le rovine.", "Tosse e vestiti sporchi: racconta di un lungo cammino nella polvere.", "Una guancia arrossata, qualche graffio. Potrebbero essere i rovi lungo la strada."][_rng.randi_range(0, 2)]
	if suspicious:
		hint = ["Ha un occhio un po' velato e alcune macchie sulla pelle. Dice che gli manca solo il sonno.", "Una sfumatura insolita sul collo. Sostiene che sia un vecchio livido.", "Il pallore e un graffio fresco attirano l'attenzione. Potrebbe essere soltanto la stanchezza."][_rng.randi_range(0, 2)]
	visitors.append({"id": _id(), "citizen": citizen, "appearance": appearance, "x": entrance_x, "suspicious": suspicious, "hint": hint, "hit_flash": 0.0, "under_attack": false, "facing_left": false, "walk_speed": TUTORIAL_WALK_SPEED if initial else VISITOR_SPEED, "arrival_notified": false})
	_dirty = true

func accept_visitor(visitor_id: int) -> bool:
	for i in range(visitors.size()):
		var visitor = visitors[i]
		if int(visitor["id"]) != visitor_id:
			continue
		if citizens.size() >= capacity():
			toast.emit("Non ci sono letti liberi. Costruisci una residenza.")
			return false
		visitors.remove_at(i)
		if visitor["suspicious"]:
			gate_hp = maxf(1.0, gate_hp - 36.0)
			_add_threat("infiltrator", float(visitor["x"]))
			threats.back()["look"] = int(visitor["citizen"]["look"])
			threats.back()["appearance"] = str(visitor["citizen"].get("appearance", "infected"))
			toast.emit("Era un infiltrato! Difendi subito il cancello.")
			sfx.emit("alarm")
		else:
			citizens.append(visitor["citizen"])
			stats["accepted"] = int(stats.get("accepted", 0)) + 1
			toast.emit("Benvenuto, " + visitor["citizen"]["name"] + "! Assegnagli un compito.")
			sfx.emit("reward")
		_commit()
		return true
	return false

func reject_visitor(visitor_id: int) -> void:
	for i in range(visitors.size()):
		if int(visitors[i]["id"]) == visitor_id:
			var visitor = visitors[i]
			var suspicious: bool = visitor["suspicious"]
			visitors.remove_at(i)
			visitor["facing_left"] = true
			departing_visitors.append(visitor)
			toast.emit("L'infiltrato si allontana tra i denti. Ottimo intuito." if suspicious else "Il sopravvissuto riprende il cammino.")
			sfx.emit("click")
			_commit()
			return

func _add_threat(kind: String, x: float) -> void:
	var base: Array = THREAT_STATS.get(kind,THREAT_STATS.walker)
	var hp: float = base[0]
	var speed: float = base[1]
	var damage: float = base[2]
	threats.append({"id": _id(), "kind": kind, "x": x, "hp": hp, "max_hp": hp, "speed": speed, "damage": damage, "hit_flash": 0.0, "facing_left": false, "target_visitor_id": -1, "attack_clock": 0.0})

func _tick_threats(delta: float) -> void:
	var structural_damage: float = 0.0
	for visitor in _outside_civilians():
		visitor["hit_flash"] = maxf(0.0, float(visitor.get("hit_flash", 0.0)) - delta)
		visitor["under_attack"] = false
	for threat in threats:
		threat["hit_flash"] = maxf(0.0, float(threat.get("hit_flash", 0.0)) - delta)
		threat["attack_clock"] = 0.0
		threat["target_visitor_id"] = -1
		threat["facing_left"] = false
		if float(threat["x"]) < GATE_X:
			var travel_time = (GATE_X - float(threat["x"])) / maxf(0.01, float(threat["speed"]))
			threat["x"] = minf(GATE_X, float(threat["x"]) + float(threat["speed"]) * delta)
			structural_damage += float(threat["damage"]) * maxf(0.0, delta - travel_time)
		else:
			structural_damage += float(threat["damage"]) * delta
	if structural_damage > 0.0:
		gate_hp = maxf(0.0, gate_hp - structural_damage)
		if _gate_alarm_timer <= 0.0:
			_gate_alarm_timer = 4.0
			sfx.emit("alarm")
		if gate_hp <= 0.0:
			_breach()

func _breach() -> void:
	stats["breaches"] = int(stats.get("breaches", 0)) + 1
	if not tutorial_active():
		coins = maxf(0.0, coins * 0.82)
		supplies = maxi(0, supplies - 8)
	gate_hp = gate_max * 0.60
	threats.clear()
	_spawn_queue.clear()
	_wave_pending_reward = false
	_reset_wave_rest()
	for citizen in citizens:
		citizen["happiness"] = maxi(25, int(citizen["happiness"]) - 12)
	toast.emit("Il cancello è stato ripristinato. Tocca lo zombie per fermarlo: puoi riprovare." if tutorial_active() else "Breccia! Tutti al sicuro, ma hai perso il 18% delle monete. Il cancello è stato ricostruito.")
	sfx.emit("breach")
	_commit()

func threat_distance(threat_id: int) -> float:
	for threat in threats:
		if int(threat["id"]) == threat_id:
			return maxf(0.0, GATE_X - float(threat["x"]))
	return INF

func is_target_in_range(threat_id: int, weapon_key: String = "") -> bool:
	var key = weapon if weapon_key.is_empty() else weapon_key
	return WEAPONS.has(key) and threat_distance(threat_id) <= float(WEAPONS[key]["range"])

func can_shoot_target(threat_id: int) -> bool:
	var effective_weapon = "pistol" if weapon != "pistol" and ammo <= 0 else weapon
	return not paused and shot_cooldown <= 0.0 and is_target_in_range(threat_id, effective_weapon)

func shoot(threat_id: int) -> bool:
	if paused or shot_cooldown > 0.0:
		return false
	var target: Dictionary = {}
	for threat in threats:
		if int(threat["id"]) == threat_id:
			target = threat
			break
	if target.is_empty():
		return false
	var effective_weapon = "pistol" if weapon != "pistol" and ammo <= 0 else weapon
	if not is_target_in_range(threat_id, effective_weapon):
		if _range_feedback_timer <= 0.0:
			_range_feedback_timer = 2.0
			toast.emit("Troppo lontano per " + str(WEAPONS[effective_weapon]["name"]).to_lower() + ": aspetta che lo zombie si avvicini.")
		return false
	if weapon != "pistol" and ammo <= 0:
		weapon = "pistol"
		toast.emit("Munizioni finite. Pistola equipaggiata: colpi illimitati.")
	var definition: Dictionary = WEAPONS[weapon]
	shot_cooldown = float(definition["cooldown"])
	if weapon != "pistol":
		ammo -= 1
	_increment_stat("shots")
	var damage = float(definition["damage"])
	# The long rifle rewards picking off targets before they reach the gate.
	if weapon == "sniper" and float(target["x"]) < -80.0:
		damage *= 1.35
	shot_fired.emit(threat_id, damage)
	# The tower soldier is permanent and independent of the resident population.
	guard_fired.emit(0, threat_id, float(target["x"]))
	sfx.emit("shot_" + weapon)
	if weapon != "pistol":
		reload_started.emit(weapon, shot_cooldown)
	if weapon == "shotgun":
		var center = float(target["x"])
		for threat in threats.duplicate():
			if absf(float(threat["x"]) - center) < 145.0:
				_damage_threat(threat, damage if int(threat["id"]) == threat_id else damage * 0.62)
	else:
		_damage_threat(target, damage)
	_dirty = true
	_sync_tutorial()
	changed.emit()
	return true

func _damage_threat(threat: Dictionary, amount: float) -> void:
	if not threats.has(threat):
		return
	threat["hp"] = float(threat["hp"]) - amount
	threat["hit_flash"] = 0.15
	if float(threat["hp"]) <= 0.0:
		var reward: int = 13 if threat["kind"] != "brute" else 40
		coins += reward
		stats["earned"] = float(stats.get("earned", 0.0)) + reward
		supplies += 3 if threat["kind"] == "brute" else 1
		stats["kills"] = int(stats.get("kills", 0)) + 1
		_increment_stat("kills_" + str(threat["kind"]))
		enemy_defeated.emit(int(threat["id"]), float(threat["x"]))
		threats.erase(threat)
		sfx.emit("kill")

func _tick_guards(_delta: float) -> void:
	## Compatibility entry point: all shots now originate from shoot(), never a timer.
	pass

func present_population() -> int:
	var present: int = 0
	for citizen: Dictionary in citizens:
		if not bool(citizen.get("away",false)): present += 1
	return present

func defense_profile() -> Dictionary:
	var population: int = present_population()
	# A smooth population curve with fixed limits; wave numbers never add pressure.
	var pressure: float = float(population)/(float(population)+20.0)
	var interval_scale: float = lerpf(1.0,0.42,pressure)
	return {"population":population,"pressure":pressure,"interval_scale":interval_scale,
		"interval_min":WAVE_INTERVAL_MIN*interval_scale,"interval_max":WAVE_INTERVAL_MAX*interval_scale,
		"count_min":2+roundi(6.0*pressure),"count_max":8+roundi(16.0*pressure),
		"spawn_min":lerpf(2.5,1.6,pressure),"spawn_max":lerpf(5.0,3.0,pressure)}

func _reset_wave_rest() -> void:
	var profile: Dictionary = defense_profile()
	_wave_wait_scale = float(profile.interval_scale)
	wave_clock = _rng.randf_range(float(profile.interval_min),float(profile.interval_max))

func _tick_waves(delta: float) -> void:
	if tutorial_active():
		return
	if not _spawn_queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			var kind: String = _spawn_queue.pop_front()
			_add_threat(kind, entrance_x - _rng.randf_range(0.0, 110.0))
			var profile: Dictionary = defense_profile()
			_spawn_timer = _rng.randf_range(float(profile.spawn_min),float(profile.spawn_max))
	if _wave_pending_reward and threats.is_empty() and _spawn_queue.is_empty():
		_wave_pending_reward = false
		stats["waves"] = int(stats.get("waves", 0)) + 1
		var reward = _rng.randi_range(55, 105)
		coins += reward
		stats["earned"] = float(stats.get("earned", 0.0)) + reward
		if wave % 3 == 0:
			gems += 1
		toast.emit("Zombie respinti! +" + str(reward) + " monete.")
		sfx.emit("reward")
		_reset_wave_rest()
		return
	# The rest period begins after a wave is over, never while zombies remain.
	if _spawn_queue.is_empty() and threats.is_empty():
		var scale_now: float = float(defense_profile().interval_scale)
		# Preserve elapsed progress when residents enter, leave on a trip or return.
		wave_clock *= scale_now/maxf(_wave_wait_scale,0.001)
		_wave_wait_scale = scale_now
		wave_clock = maxf(0.0, wave_clock - delta)
		if wave_clock <= 0.0:
			_start_wave()

func _start_wave() -> void:
	wave += 1
	var profile: Dictionary = defense_profile()
	var count: int = _rng.randi_range(int(profile.count_min),int(profile.count_max))
	var brutes = 0
	var arrival: Array[String] = []
	var has_variant = false
	for index in range(count):
		var kind = "walker"
		var roll = _rng.randf()
		if roll < 0.20:
			kind = "runner"
		elif roll < 0.28 and brutes < 2:
			kind = "brute"
			brutes += 1
		if kind != "walker":
			has_variant = true
		arrival.append(kind)
	# The first encounter shows a variant; afterwards no three arrivals can be
	# all ordinary walkers. Most individual zombies still remain ordinary.
	if not has_variant and (wave == 1 or _arrivals_without_variant >= 2):
		arrival[_rng.randi_range(0, arrival.size() - 1)] = "runner" if _rng.randf() < 0.75 else "brute"
		has_variant = true
	_arrivals_without_variant = 0 if has_variant else _arrivals_without_variant + 1
	_spawn_queue.append_array(arrival)
	_spawn_timer = 0.0
	_reset_wave_rest()
	_wave_pending_reward = true
	sfx.emit("alarm")
	wave_started.emit()

func repair_cost() -> Dictionary:
	return {"coins": int(ceil((gate_max - gate_hp) * 0.32)), "supplies": int(ceil((gate_max - gate_hp) / 35.0))}

func repair_gate() -> bool:
	if gate_hp >= gate_max - 0.01:
		toast.emit("Il cancello è già in perfette condizioni.")
		return false
	var cost = repair_cost()
	if coins < int(cost["coins"]) or supplies < int(cost["supplies"]):
		toast.emit("Per riparare servono " + str(cost["coins"]) + " monete e " + str(cost["supplies"]) + " provviste.")
		return false
	coins -= int(cost["coins"])
	supplies -= int(cost["supplies"])
	gate_hp = gate_max
	stats["repaired"] = int(stats.get("repaired", 0)) + 1
	toast.emit("Cancello riparato. Si può respirare di nuovo.")
	sfx.emit("build")
	_commit()
	return true

func gate_upgrade_cost() -> Dictionary:
	return {"coins": 290 + gate_level * 140, "supplies": 12 + gate_level * 8}

func can_upgrade_gate() -> bool:
	var cost: Dictionary = gate_upgrade_cost()
	return coins>=int(cost.coins) and supplies>=int(cost.supplies) and _can_spend_optional_coins(int(cost.coins),false)

func upgrade_gate() -> bool:
	var cost = gate_upgrade_cost()
	if coins < int(cost["coins"]) or supplies < int(cost["supplies"]):
		toast.emit("Servono " + str(cost["coins"]) + " monete e " + str(cost["supplies"]) + " provviste.")
		return false
	if not _can_spend_optional_coins(int(cost["coins"])):
		return false
	coins -= int(cost["coins"])
	supplies -= int(cost["supplies"])
	gate_level += 1
	stats["gate_level"] = gate_level
	gate_max += 180.0 + gate_level * 35.0
	gate_hp = gate_max
	toast.emit("Difese al livello " + str(gate_level) + ". Più solide, più tranquille.")
	sfx.emit("build")
	_commit()
	return true

func equip_weapon(key: String) -> bool:
	if not WEAPONS.has(key):
		return false
	if not owned_weapons.has(key):
		var cost: Dictionary = WEAPONS[key]
		if coins < int(cost["cost"]) or supplies < int(cost["supplies"]):
			toast.emit("Servono " + str(cost["cost"]) + " monete e " + str(cost["supplies"]) + " provviste.")
			return false
		if not _can_spend_optional_coins(int(cost["cost"])):
			return false
		coins -= int(cost["cost"])
		supplies -= int(cost["supplies"])
		owned_weapons.append(key)
	stats["weapons_owned"] = owned_weapons.size()
	weapon = key
	shot_cooldown = 0.0
	toast.emit(WEAPONS[key]["name"] + " equipaggiato.")
	sfx.emit("click")
	_commit()
	return true

func buy_ammo() -> bool:
	if supplies < 10 or coins < 40:
		toast.emit("Servono 40 monete e 10 provviste per 30 munizioni.")
		return false
	if not _can_spend_optional_coins(40):
		return false
	supplies -= 10
	coins -= 40
	ammo += 30
	toast.emit("+30 munizioni. Meglio averne una scorta.")
	sfx.emit("ready")
	_commit()
	return true

func equip_citizen(citizen_id: int, key: String) -> bool:
	var citizen = get_citizen(citizen_id)
	if citizen.is_empty() or citizen.get("away", false) or not owned_weapons.has(key):
		return false
	citizen["weapon"] = key
	toast.emit(citizen["name"] + " ha equipaggiato " + WEAPONS[key]["name"] + ".")
	_commit()
	return true

func expedition_power(ids: Array) -> float:
	var power = 0.0
	for citizen_id in ids:
		var citizen = get_citizen(int(citizen_id))
		if not citizen.is_empty():
			var factor = 1.0
			if citizen.get("weapon", "pistol") == "shotgun":
				factor = 1.65
			elif citizen.get("weapon", "pistol") == "sniper":
				factor = 2.4
			elif citizen.get("weapon", "pistol") == "smg":
				factor = 1.95
			power += (float(citizen.get("damage", 12)) + float(citizen["services"]) * 0.7 + float(citizen["goods"]) * 0.35) * factor * float(citizen["hp"]) / 100.0
	return power

func expedition_cost(zone_index: int) -> int:
	if zone_index < 0 or zone_index >= zones.size():
		return 0
	return int(zones[zone_index].get("cost", 4 + zone_index * 5))

func expedition_preview(zone_index: int, ids: Array) -> Dictionary:
	if zone_index<0 or zone_index>=zones.size(): return {"valid":false,"can_depart":false,"reason":"Scegli una destinazione valida."}
	var zone: Dictionary = zones[zone_index]
	var members: Array = []
	var team_valid: bool = true
	for citizen_id: Variant in ids:
		var id: int = int(citizen_id)
		var citizen: Dictionary = get_citizen(id)
		if citizen.is_empty() or citizen.get("away",false) or members.has(id): team_valid = false
		else: members.append(id)
	var power: float = expedition_power(members)
	var chance: float = clampf(0.35+power/float(zone.threat)*0.45,0.35,1.0) if not members.is_empty() else 0.0
	var full: Dictionary = {}
	var reduced: Dictionary = {}
	for resource: String in ["coins","supplies","gems","ammo"]:
		full[resource] = int(zone.get(resource,0))
		reduced[resource] = 0 if resource=="gems" else int(int(full[resource])*EXPEDITION_PARTIAL_REWARD)
	var cost: int = expedition_cost(zone_index)
	var reason: String = ""
	if expedition.get("status","idle")!="idle": reason = "C'è già una squadra fuori dal rifugio."
	elif ids.is_empty() or ids.size()>3: reason = "Scegli da 1 a 3 cittadini."
	elif not team_valid: reason = "Alcune persone selezionate non sono disponibili."
	elif supplies<cost: reason = "Servono %d provviste per partire; ne hai %d." % [cost,supplies]
	return {"valid":true,"can_depart":reason.is_empty(),"reason":reason,"members":members,"power":power,"chance":chance,
		"cost":cost,"duration":float(zone.duration),"full_rewards":full,"reduced_rewards":reduced,
		"full_net_supplies":int(full.supplies)-cost,"reduced_net_supplies":int(reduced.supplies)-cost,
		"success_damage":EXPEDITION_SUCCESS_DAMAGE,"failure_damage":EXPEDITION_FAILURE_DAMAGE,"health_floor":EXPEDITION_HEALTH_FLOOR}

func start_expedition(zone_index: int, ids: Array) -> bool:
	if expedition.get("status", "idle") != "idle":
		toast.emit("C'è già una squadra in spedizione.")
		return false
	if zone_index < 0 or zone_index >= zones.size() or ids.is_empty() or ids.size() > 3:
		toast.emit("Scegli da 1 a 3 cittadini per la spedizione.")
		return false
	var members: Array = []
	for citizen_id in ids:
		var citizen = get_citizen(int(citizen_id))
		if citizen.is_empty() or citizen.get("away", false) or members.has(int(citizen_id)):
			toast.emit("La squadra selezionata non è disponibile.")
			return false
		members.append(int(citizen_id))
	var zone = zones[zone_index]
	var cost = expedition_cost(zone_index)
	if supplies < cost:
		toast.emit("Servono " + str(cost) + " provviste per partire.")
		return false
	var preview: Dictionary = expedition_preview(zone_index,members)
	supplies -= cost
	var power: float = preview.power
	var chance: float = preview.chance
	var success = _rng.randf() <= chance
	expedition = {
		"status": "running", "zone": zone_index, "name": zone["name"], "members": members,
		"remaining": float(zone["duration"]), "duration": float(zone["duration"]), "power": power, "chance": chance,
		"success": success, "rewards": preview.full_rewards.duplicate() if success else preview.reduced_rewards.duplicate()
	}
	for citizen_id in members:
		get_citizen(int(citizen_id))["away"] = true
	toast.emit("La squadra è partita verso " + zone["name"] + ". Buona fortuna!")
	sfx.emit("expedition")
	_commit()
	return true

func _tick_expedition(delta: float, offline: bool = false) -> void:
	if expedition.get("status", "idle") != "running":
		return
	expedition["remaining"] = maxf(0.0, float(expedition["remaining"]) - delta)
	if float(expedition["remaining"]) <= 0.0:
		expedition["status"] = "ready"
		for citizen_id in expedition.get("members", []):
			var citizen = get_citizen(int(citizen_id))
			if not citizen.is_empty():
				citizen["away"] = false
				citizen["hp"] = maxi(EXPEDITION_HEALTH_FLOOR, int(citizen.get("hp", 100)) - (EXPEDITION_SUCCESS_DAMAGE if expedition.get("success", false) else EXPEDITION_FAILURE_DAMAGE))
		if not offline:
			toast.emit("La squadra è tornata! Ritira il bottino nella mappa spedizioni.")
			sfx.emit("reward")

func claim_expedition() -> bool:
	if expedition.get("status", "idle") != "ready":
		return false
	var rewards: Dictionary = expedition.get("rewards", {})
	coins += int(rewards.get("coins", 0))
	supplies += int(rewards.get("supplies", 0))
	gems += int(rewards.get("gems", 0))
	ammo += int(rewards.get("ammo", 0))
	stats["earned"] = float(stats.get("earned", 0.0)) + int(rewards.get("coins", 0))
	stats["expeditions"] = int(stats.get("expeditions", 0)) + 1
	var zone_index = int(expedition.get("zone", 0))
	if zone_index >= 0 and zone_index < zones.size():
		_increment_stat("zone_" + str(zones[zone_index]["id"]))
		_refresh_explored_zones()
	toast.emit(("Spedizione riuscita!" if expedition.get("success", false) else "Spedizione difficile. Tutti sono tornati, con un bottino ridotto.") + " +%d monete, +%d provviste." % [int(rewards.get("coins", 0)),int(rewards.get("supplies", 0))])
	expedition = {"status": "idle"}
	sfx.emit("reward")
	_commit()
	return true

func heal_citizen(citizen_id: int) -> bool:
	var citizen = get_citizen(citizen_id)
	if citizen.is_empty() or citizen.get("away", false) or citizen["hp"] >= 100:
		return false
	if supplies < 5:
		toast.emit("Servono 5 provviste per curare un cittadino.")
		return false
	supplies -= 5
	citizen["hp"] = 100
	_increment_stat("healed")
	toast.emit(citizen["name"] + " si è ripreso completamente.")
	_commit()
	return true

func _default_stats() -> Dictionary:
	return {"kills": 0, "accepted": 0, "built": 0, "restocked": 0, "expeditions": 0, "earned": 0.0, "waves": 0, "dreams": 0, "repaired": 0, "breaches": 0, "assignments": 0, "sold": 0, "healed": 0, "weapons_owned": 1, "gate_level": 1, "zones_explored": 0, "shots": 0}

func _increment_stat(key: String, amount: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount

func _refresh_explored_zones() -> void:
	var count = 0
	for zone in zones:
		if int(stats.get("zone_" + str(zone["id"]), 0)) > 0:
			count += 1
	stats["zones_explored"] = count

func _migrate_quests(saved: Array, content_version: int) -> void:
	var definitions = ContentCatalog.make_quests()
	for definition in definitions:
		if not stats.has(str(definition["key"])):
			stats[str(definition["key"])] = 0
		for previous in saved:
			var same_id = str(previous.get("id", "")) == str(definition["id"])
			var legacy_match = not previous.has("id") and str(previous.get("key", "")) == str(definition["key"]) and int(previous.get("target", 0)) == int(definition["target"])
			if same_id or legacy_match:
				definition["claimed"] = bool(previous.get("claimed", false))
				definition["progress"] = mini(int(definition["target"]), int(previous.get("progress", 0)))
				var key: String = definition["key"]
				stats[key] = maxf(float(stats.get(key, 0)), float(previous.get("progress", 0)))
				break
	quests = definitions
	if content_version < ContentCatalog.QUEST_VERSION:
		# Only infer facts visible in the old save; never invent past rewards or
		# completed trips. Backfill runs once and never marks new quests claimed.
		stats["built"] = maxi(int(stats.get("built", 0)), buildings.filter(func(b: Dictionary) -> bool: return not is_under_construction(b)).size())
		stats["accepted"] = maxi(int(stats.get("accepted", 0)), citizens.size())
		var existing_assignments = 0
		var type_counts: Dictionary = {}
		var stocks: Dictionary = {}
		for building in buildings:
			if is_under_construction(building): continue
			var kind = str(building["type"])
			type_counts[kind] = int(type_counts.get(kind, 0)) + 1
			existing_assignments += building["workers"].size()
			for product in building["products"]:
				if product["status"] == "stocked":
					stocks[kind] = int(stocks.get(kind, 0)) + 1
		for kind in type_counts:
			var key = "built_" + str(kind)
			stats[key] = maxi(int(stats.get(key, 0)), int(type_counts[kind]))
		for kind in stocks:
			var key = "stocked_" + str(kind)
			stats[key] = maxi(int(stats.get(key, 0)), int(stocks[kind]))
		stats["assignments"] = maxi(int(stats.get("assignments", 0)), existing_assignments)
	stats["weapons_owned"] = owned_weapons.size()
	stats["gate_level"] = gate_level
	_refresh_explored_zones()
	_sync_quests()

func _sync_quests() -> void:
	for quest in quests:
		quest["progress"] = mini(int(quest["target"]), maxi(int(quest.get("progress", 0)), int(stats.get(quest["key"], 0))))

func claim_quest(index: int) -> bool:
	if index < 0 or index >= quests.size():
		return false
	_sync_quests()
	var quest: Dictionary = quests[index]
	if quest.get("claimed", false) or int(quest["progress"]) < int(quest["target"]):
		return false
	coins += int(quest["reward"])
	gems += int(quest.get("reward_gems", 0))
	quest["claimed"] = true
	toast.emit("Obiettivo completato: " + quest["name"] + ". +" + str(quest["reward"]) + " monete!")
	sfx.emit("reward")
	_commit()
	return true

func _commit() -> void:
	_sync_tutorial()
	_sync_quests()
	_dirty = true
	changed.emit()
	if not _is_loading:
		save_game()

func save_game() -> bool:
	if _is_loading:
		return false
	var now = Time.get_unix_time_from_system()
	_highest_timestamp = maxf(_highest_timestamp, now)
	var payload = {
		"version": SAVE_VERSION, "timestamp": now, "highest_timestamp": _highest_timestamp,
		"coins": coins, "supplies": supplies, "gems": gems, "citizens": citizens, "buildings": buildings,
		"wave": wave, "day": day, "gate_hp": gate_hp, "gate_max": gate_max, "gate_level": gate_level,
		"ammo": ammo, "weapon": weapon, "owned_weapons": owned_weapons, "wave_clock": wave_clock,
		"expedition": expedition, "quests": quests, "time_played": time_played, "stats": stats,
		"visitors": visitors, "departing_visitors": departing_visitors, "threats": threats, "spawn_queue": _spawn_queue,
		"wave_pending_reward": _wave_pending_reward, "next_id": _next_id, "visitor_timer": _visitor_timer,
		"tutorial_stage": tutorial_stage, "tutorial_visitor_id": _tutorial_visitor_id, "spawn_timer": _spawn_timer,
		"wave_rules": 4, "wave_wait_scale":_wave_wait_scale,"quest_content_version": ContentCatalog.QUEST_VERSION,
		"arrivals_without_variant": _arrivals_without_variant,
		"paused": paused
	}
	var file = FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		push_warning("Impossibile scrivere il salvataggio: " + save_path)
		return false
	file.store_string(JSON.stringify(payload))
	var write_error: Error = file.get_error()
	file.close()
	if write_error!=OK:
		push_warning("Impossibile completare la scrittura del salvataggio: " + str(write_error))
		return false
	var error = DirAccess.rename_absolute(save_path + ".tmp", save_path)
	if error != OK:
		# Some platforms do not replace existing targets with rename. Keep a backup.
		if FileAccess.file_exists(save_path):
			DirAccess.rename_absolute(save_path, save_path + ".bak")
		error = DirAccess.rename_absolute(save_path + ".tmp", save_path)
		if error != OK:
			push_warning("Impossibile completare il salvataggio: " + str(error))
			return false
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var text = FileAccess.get_file_as_string(save_path)
	var parser = JSON.new()
	if parser.parse(text) != OK:
		push_warning("Salvataggio danneggiato; mantenuta la partita corrente.")
		return false
	var data = parser.data
	if not data is Dictionary or int(data.get("version", 0)) != SAVE_VERSION:
		push_warning("Salvataggio non compatibile o danneggiato; mantenuta la nuova partita.")
		return false
	if not _valid_save(data):
		push_warning("Salvataggio incompleto; mantenuta la nuova partita.")
		return false
	_is_loading = true
	_construction_sleep_at = -1.0
	_construction_background_advanced = 0.0
	coins = maxf(0.0, float(data.get("coins", 1000.0)))
	supplies = maxi(0, int(data.get("supplies", 65)))
	gems = maxi(0, int(data.get("gems", 12)))
	citizens.clear()
	for citizen in data["citizens"]:
		citizen["id"] = int(citizen["id"])
		citizen["job"] = int(citizen.get("job", -1))
		_normalize_citizen_appearance(citizen)
		citizens.append(citizen)
	buildings.clear()
	for building in data["buildings"]:
		building["id"] = int(building["id"])
		# Buildings from older saves were already operational.
		building["construction_duration"] = float(building.get("construction_duration",0.0))
		building["construction_remaining"] = float(building.get("construction_remaining",0.0))
		var worker_ids: Array = []
		for worker_id in building.get("workers", []):
			worker_ids.append(int(worker_id))
		building["workers"] = worker_ids
		for product in building["products"]:
			product["icon_key"] = str(building["type"]) + "_" + str(product["tier"])
		buildings.append(building)
	wave = maxi(0, int(data.get("wave", 0)))
	gate_max = maxf(260.0, float(data.get("gate_max", 260.0)))
	gate_hp = clampf(float(data.get("gate_hp", gate_max)), 1.0, gate_max)
	gate_level = maxi(1, int(data.get("gate_level", 1)))
	ammo = maxi(0, int(data.get("ammo", 24)))
	weapon = str(data.get("weapon", "pistol"))
	if not WEAPONS.has(weapon):
		weapon = "pistol"
	owned_weapons = data.get("owned_weapons", ["pistol"])
	if not owned_weapons.has("pistol"):
		owned_weapons.append("pistol")
	wave_clock = clampf(float(data.get("wave_clock", 75.0)), 0.0, WAVE_INTERVAL_MAX)
	_wave_wait_scale = clampf(float(data.get("wave_wait_scale",1.0)),0.42,1.0)
	if int(data.get("wave_rules", 0)) < 3:
		wave_clock = minf(wave_clock, 75.0)
	_arrivals_without_variant = clampi(int(data.get("arrivals_without_variant", 0)), 0, 2)
	tutorial_stage = str(data.get("tutorial_stage", "complete"))
	if not TUTORIAL_STAGES.has(tutorial_stage):
		tutorial_stage = "complete"
	_tutorial_visitor_id = int(data.get("tutorial_visitor_id", -1))
	expedition = data.get("expedition", {"status": "idle"})
	time_played = maxf(0.0, float(data.get("time_played", 0.0)))
	day = 1 + int(time_played / 180.0)
	stats = _default_stats()
	stats.merge(data.get("stats", {}), true)
	visitors.clear()
	for visitor in data.get("visitors", []):
		_normalize_outside_civilian(visitor)
		visitors.append(visitor)
	departing_visitors.clear()
	for visitor in data.get("departing_visitors", []):
		_normalize_outside_civilian(visitor)
		visitor["facing_left"] = true
		departing_visitors.append(visitor)
	threats.clear()
	for threat in data.get("threats", []):
		threat["id"] = int(threat["id"])
		var base_stats: Array = THREAT_STATS.get(str(threat["kind"]),THREAT_STATS.walker)
		var health_ratio = clampf(float(threat["hp"]) / maxf(1.0, float(threat["max_hp"])), 0.0, 1.0)
		threat["max_hp"] = base_stats[0]
		threat["hp"] = maxf(1.0, base_stats[0] * health_ratio)
		threat["speed"] = TUTORIAL_WALK_SPEED if tutorial_stage == "first_zombie" else base_stats[1]
		threat["damage"] = base_stats[2]
		threat["facing_left"] = false
		threat["target_visitor_id"] = -1
		threat["attack_clock"] = 0.0
		threats.append(threat)
	_spawn_queue = data.get("spawn_queue", [])
	_spawn_timer = maxf(0.0, float(data.get("spawn_timer", 0.0)))
	_wave_pending_reward = bool(data.get("wave_pending_reward", false))
	_next_id = maxi(_next_id, int(data.get("next_id", _next_id)))
	for citizen in citizens:
		_next_id = maxi(_next_id, int(citizen["id"]))
	for building in buildings:
		_next_id = maxi(_next_id, int(building["id"]))
	for visitor in _outside_civilians():
		_next_id = maxi(_next_id, maxi(int(visitor["id"]), int(visitor["citizen"]["id"])))
	for threat in threats:
		_next_id = maxi(_next_id, int(threat["id"]))
	_visitor_timer = maxf(10.0, float(data.get("visitor_timer", 38.0)))
	shot_cooldown = 0.0
	_guard_timer = 1.5
	_gate_alarm_timer = 0.0
	_range_feedback_timer = 0.0
	_ui_timer = 0.0
	_save_timer = 0.0
	_migrate_citizen_names()
	_migrate_quests(data.get("quests", []), int(data.get("quest_content_version", 0)))
	# A loaded game opens unpaused so a previously hidden modal cannot freeze play.
	paused = false
	var now = Time.get_unix_time_from_system()
	var saved_time = float(data.get("timestamp", now))
	_highest_timestamp = maxf(float(data.get("highest_timestamp", saved_time)), saved_time)
	var elapsed = 0.0
	var clock_warning = now + 5.0 < _highest_timestamp
	if not clock_warning:
		elapsed = clampf(now - saved_time, 0.0, OFFLINE_CAP)
	_highest_timestamp = maxf(_highest_timestamp, now)
	offline_report = {}
	var completed_sites: int = _tick_construction(elapsed,true)
	if elapsed >= 20.0:
		var earned = _tick_products(elapsed, true)
		_tick_expedition(elapsed, true)
		# Combat does not progress while the application is closed.
		offline_report = {"seconds": elapsed, "coins": int(earned), "clock_warning": false, "capped": now - saved_time > OFFLINE_CAP, "expedition_ready": expedition.get("status", "idle") == "ready"}
	elif clock_warning:
		offline_report = {"seconds": 0, "coins": 0, "clock_warning": true, "capped": false}
	if completed_sites>0: offline_report["construction_ready"] = completed_sites
	_is_loading = false
	_sync_tutorial()
	_sync_quests()
	changed.emit()
	return true

func _normalize_outside_civilian(visitor: Dictionary) -> void:
	visitor["id"] = int(visitor["id"])
	visitor["citizen"]["id"] = int(visitor["citizen"]["id"])
	var appearance = str(visitor.get("appearance", visitor["citizen"].get("appearance", "")))
	if not appearance in ["clean", "dirty", "infected"]:
		appearance = "infected" if bool(visitor.get("suspicious", false)) else ("dirty" if int(visitor["id"]) % 3 == 0 else "clean")
	visitor["appearance"] = appearance
	visitor["citizen"]["appearance"] = appearance
	visitor["citizen"]["max_hp"] = maxf(1.0, float(visitor["citizen"].get("max_hp", 100.0)))
	visitor["citizen"]["hp"] = clampf(float(visitor["citizen"].get("hp", 100.0)), 0.0, float(visitor["citizen"]["max_hp"]))
	visitor["hit_flash"] = maxf(0.0, float(visitor.get("hit_flash", 0.0)))
	visitor["facing_left"] = bool(visitor.get("facing_left", false))
	visitor["under_attack"] = false
	visitor["walk_speed"] = TUTORIAL_WALK_SPEED if int(visitor.id)==_tutorial_visitor_id else VISITOR_SPEED
	# Old saves already announced their waiting visitors. Do not repeat the toast.
	var waiting: bool = absf(float(visitor.x)-visitor_destination(visitors.size()))<=0.01
	visitor["arrival_notified"] = bool(visitor.get("arrival_notified",waiting))

func _normalize_citizen_appearance(citizen: Dictionary) -> void:
	if not str(citizen.get("appearance", "")) in ["clean", "dirty", "infected"]:
		citizen["appearance"] = "clean"

func _valid_save(data: Dictionary) -> bool:
	if not data.get("citizens") is Array or not data.get("buildings") is Array:
		return false
	for citizen in data["citizens"]:
		if not _valid_citizen(citizen):
			return false
	for building in data["buildings"]:
		if not building is Dictionary or not building.has_all(["id", "type", "workers", "products", "level"]):
			return false
		if not BUILDING_NAMES.has(str(building["type"])) or not building["workers"] is Array or not building["products"] is Array:
			return false
		if building["workers"].size() > 3 or building["products"].size() > 3:
			return false
		for key: String in ["construction_duration","construction_remaining"]:
			if building.has(key) and (not _finite_number(building[key]) or float(building[key])<0.0): return false
		var duration: float = float(building.get("construction_duration",0.0))
		var remaining: float = float(building.get("construction_remaining",0.0))
		if duration>MAX_CONSTRUCTION_TIME or remaining>duration: return false
		if remaining>0.0 and not building["workers"].is_empty(): return false
		for product in building["products"]:
			if not product is Dictionary or not product.has_all(["tier", "cost", "duration", "status", "remaining", "stock", "max_stock", "price", "sell_interval"]):
				return false
			if not str(product["status"]) in ["empty", "restocking", "ready", "stocked"] or float(product["sell_interval"]) <= 0.0:
				return false
			if remaining>0.0 and (product["status"]!="empty" or int(product["stock"])!=0): return false
	var saved_expedition = data.get("expedition", {"status": "idle"})
	if not saved_expedition is Dictionary or not saved_expedition.get("status", "idle") in ["idle", "running", "ready"]:
		return false
	if saved_expedition.get("status", "idle") != "idle" and not saved_expedition.has_all(["remaining", "duration", "members", "rewards"]):
		return false
	for outside_key in ["visitors", "departing_visitors"]:
		if not data.get(outside_key, []) is Array:
			return false
		for visitor in data.get(outside_key, []):
			if not visitor is Dictionary or not visitor.has_all(["id", "citizen", "x", "suspicious"]) or not _valid_citizen(visitor["citizen"]):
				return false
			if not _valid_optional_outside_fields(visitor):
				return false
	for threat in data.get("threats", []):
		if not threat is Dictionary or not threat.has_all(["id", "kind", "x", "hp", "max_hp", "speed", "damage"]):
			return false
		for numeric_key in ["hit_flash", "attack_clock", "target_visitor_id"]:
			if threat.has(numeric_key) and not _finite_number(threat[numeric_key]):
				return false
		if threat.has("facing_left") and not threat["facing_left"] is bool:
			return false
	for quest in data.get("quests", []):
		if not quest is Dictionary or not quest.has_all(["name", "description", "key", "target", "progress", "reward", "claimed"]):
			return false
	return true

func _valid_optional_outside_fields(visitor: Dictionary) -> bool:
	for numeric_key in ["hit_flash"]:
		if visitor.has(numeric_key) and not _finite_number(visitor[numeric_key]):
			return false
	for boolean_key in ["under_attack", "facing_left"]:
		if visitor.has(boolean_key) and not visitor[boolean_key] is bool:
			return false
	var citizen: Dictionary = visitor["citizen"]
	if not _finite_number(visitor["x"]) or not _finite_number(citizen["hp"]):
		return false
	if citizen.has("max_hp") and (not _finite_number(citizen["max_hp"]) or float(citizen["max_hp"]) <= 0.0):
		return false
	return true

func _finite_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _valid_citizen(citizen) -> bool:
	return citizen is Dictionary and citizen.has_all(["id", "name", "food", "goods", "services", "dream", "hp", "look", "job", "guard", "away", "happiness", "weapon"])

func reset_game() -> void:
	_new_game()
	save_game()
	toast.emit("Un nuovo inizio. Il rifugio conta su di te!")
	changed.emit()

